//-----------------------------------------------------------------
// Avalon BlockRAM
//-----------------------------------------------------------------
//
// Le paramètre RAM_ADD_W permet de déterminer le nombre de mots de
// la mémoire RAM interne au module (2**RAM_ADD_W)
// Le paramètre BURSTCOUNT_W permet de déterminer la taille maximale
// du "burst" en mode BURST (2**(BURST_COUNT_W-1))
// (voir doc mnl_avalon_spec.pdf, page 17)
`timescale 1ns/1ps
`default_nettype none
module avalon_bram #(parameter integer RAM_ADD_W = 11, integer BURSTCOUNT_W = 4 ) (
      // Avalon  interface for an agent
      avalon_if.agent avalon_a
      );

      // Local Parameters
      parameter integer DATA_WIDTH = 8 * 4; // Data width: 4 bytes = 32 bits

      // Intern Registers
      reg [7:0] memory_byte0 [2**RAM_ADD_W];      // 2**11 = 2048
      reg [7:0] memory_byte1 [2**RAM_ADD_W];
      reg [7:0] memory_byte2 [2**RAM_ADD_W];
      reg [7:0] memory_byte3 [2**RAM_ADD_W];
      logic [DATA_WIDTH-1:0] read_data_reg;  // Register to save the read data
      logic readdatavalid_reg;               // Register to readdatavalid signal
      logic waitrequest_reg;                 // Register to waitrequest signal

      // Registers to rafale mode
      logic[2**(BURSTCOUNT_W-1):0] burstcount_reg;
      logic[2**(BURSTCOUNT_W-1):0] burstcount_count;
      logic[31:0] init_address;
      logic[31:0] addr;

      // Output assignment
      assign avalon_a.readdata = read_data_reg;
      assign avalon_a.readdatavalid = readdatavalid_reg;
      assign avalon_a.waitrequest = waitrequest_reg;

      // Process as a state machine
      typedef enum logic [2:0]{
            RESET,
            INIT,          // Initialization
            READ,          // Reading done
            READ_BURST,
            WRITE_BURST
      } read_state_t;

      read_state_t read_state;

      // State machine, transition states
      always_ff @(posedge avalon_a.clk or posedge avalon_a.reset) begin
            if (avalon_a.reset) begin
                  waitrequest_reg <= 1'b1;
                  readdatavalid_reg <= 1'b0;
                  burstcount_reg <= '0;
                  burstcount_count <= '0;
                  init_address <= '0;
                  read_state <= RESET;
            end
            else begin
                  case (read_state)
                        RESET: begin
                              waitrequest_reg <= 1'b0;
                              readdatavalid_reg <= 1'b0;
                              read_state <= INIT;
                        end
                        INIT: begin
                              if(avalon_a.read == 1) begin
                                    waitrequest_reg <= 1'b1;
                                    readdatavalid_reg <= 1'b1;
                                    if (avalon_a.burstcount == 1)
                                          read_state <= READ;
                                    else begin
                                          read_state <= READ_BURST;
                                          init_address <= avalon_a.address;
                                          burstcount_reg <= avalon_a.burstcount;
                                          burstcount_count <= 1;
                                    end
                              end
                              else begin
                                    waitrequest_reg <= 1'b0;
                                    readdatavalid_reg <= 1'b0;
                                    if (avalon_a.write) begin
                                          if (avalon_a.burstcount == 1)
                                                read_state <= INIT;
                                          else begin
                                                read_state <= WRITE_BURST;
                                                init_address <= avalon_a.address;
                                                burstcount_reg <= avalon_a.burstcount;
                                                burstcount_count <= 1;
                                          end
                                    end
                                    else read_state <= INIT;
                              end
                        end

                        READ: begin
                              waitrequest_reg <= 1'b0;
                              readdatavalid_reg <= 1'b0;
                              read_state <= INIT;
                        end

                        READ_BURST: begin
                              burstcount_count <= burstcount_count + 1;
                              if (burstcount_count + 1 == burstcount_reg)
                                    read_state <= READ;
                              else
                                    read_state <= READ_BURST;
                        end

                        WRITE_BURST: begin
                              if (avalon_a.write == 1) begin
                                    burstcount_count <= burstcount_count + 1;
                                    if (burstcount_count + 1 == burstcount_reg)
                                          read_state <= INIT;
                                    else
                                          read_state <= WRITE_BURST;
                              end
                              else read_state <= WRITE_BURST;
                        end

                        default: begin
                              waitrequest_reg <= 1'b0;
                              readdatavalid_reg <= 1'b0;
                              read_state <= INIT;
                        end
                  endcase
            end
      end
      // RAM handler
      always_ff @(posedge avalon_a.clk) begin
            if (avalon_a.write) begin
                  if (avalon_a.byteenable[0]) memory_byte0[addr] <= avalon_a.writedata[7:0];
                  if (avalon_a.byteenable[1]) memory_byte1[addr] <= avalon_a.writedata[15:8];
                  if (avalon_a.byteenable[2]) memory_byte2[addr] <= avalon_a.writedata[23:16];
                  if (avalon_a.byteenable[3]) memory_byte3[addr] <= avalon_a.writedata[31:24];
            end
            else if (avalon_a.read || read_state == READ_BURST) begin
                  read_data_reg <= {memory_byte3[addr],
                                    memory_byte2[addr],
                                    memory_byte1[addr],
                                    memory_byte0[addr]};
            end
      end

      always_comb
      begin
            case (read_state)
                  INIT:
                        addr = avalon_a.address[12:2];
                  default:
                        addr = init_address[12:2] + burstcount_count;
            endcase
      end


endmodule
