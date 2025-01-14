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
module avalon_bram #(parameter integer RAM_ADD_W = 8, integer BURSTCOUNT_W = 4 ) (
      // Avalon  interface for an agent
      avalon_if.agent avalon_a
      );
      // a vous de jouer a partir d'ici

      // Local Parameters
      localparam integer DATA_WIDTH = 8 * 4; // Data width: 4 bytes = 32 bits

      // Registros internos
      logic [7:0] memory_byte0 [2**RAM_ADD_W];
      logic [7:0] memory_byte1 [2**RAM_ADD_W];
      logic [7:0] memory_byte2 [2**RAM_ADD_W];
      logic [7:0] memory_byte3 [2**RAM_ADD_W];
      logic [DATA_WIDTH-1:0] read_data_reg;  // Register to save the read data
      logic readdatavalid_reg;               // Register to readdatavalid signal
      logic waitrequest_reg;                 // Register to waitrequest signal

      // Output assignment
      assign avalon_a.readdata = read_data_reg;
      assign avalon_a.readdatavalid = readdatavalid_reg;
      assign avalon_a.waitrequest = waitrequest_reg;

      // Process as a state machine
      typedef enum logic [1:0] {
            INIT,          // Initialization
            IDLE,          // No active state
            READ_VALID     // Reading done
      } read_state_t;

      read_state_t read_state;

      always_ff @(posedge avalon_a.clk or posedge avalon_a.reset) begin
            if (avalon_a.reset) begin
                  read_state <= INIT;
                  read_data_reg <= 1'b0;
                  readdatavalid_reg <= 1'b0;
                  waitrequest_reg <= 1'b1;
            end else begin
                  // Initialization state, only for init
                  case (read_state)
                        INIT: begin
                              read_data_reg <= 1'b0;
                              readdatavalid_reg <= 1'b0;
                              waitrequest_reg <= 1'b0;
                              read_state <= IDLE;
                        end
                        IDLE: begin
                              if (avalon_a.read) begin
                                    waitrequest_reg <= 1'b1;      // Turn on waiting signal
                                    readdatavalid_reg <= 1'b1;
                                    read_data_reg <= {memory_byte3[avalon_a.address],
                                                      memory_byte2[avalon_a.address],
                                                      memory_byte1[avalon_a.address],
                                                      memory_byte0[avalon_a.address]};
                                    read_state <= READ_VALID;
                              end else if (avalon_a.write) begin
                                    if (avalon_a.address < (2**RAM_ADD_W)) begin
                                          // Writing without blocking the cycle
                                          if (avalon_a.byteenable[0]) memory_byte0[avalon_a.address] <= avalon_a.writedata[7:0];
                                          if (avalon_a.byteenable[1]) memory_byte1[avalon_a.address] <= avalon_a.writedata[15:8];
                                          if (avalon_a.byteenable[2]) memory_byte2[avalon_a.address] <= avalon_a.writedata[23:16];
                                          if (avalon_a.byteenable[3]) memory_byte3[avalon_a.address] <= avalon_a.writedata[31:24];
                                    end
                                    read_state <= IDLE;
                              end
                        end

                        READ_VALID: begin
                              readdatavalid_reg <= 1'b0; // Up just one cycle
                              waitrequest_reg <= 1'b0;
                              read_state <= IDLE;        // Back to no active
                        end

                        default: read_state <= INIT;
                  endcase
            end
      end

endmodule
