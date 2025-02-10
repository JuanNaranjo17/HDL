module avalon_intercon (
    avalon_if.agent avalon_ifa_vga,
    avalon_if.agent avalon_ifa_stream,
    avalon_if.host avalon_ifh_sdram
);

logic sel_vga;
//assign sel_vga = 1'b0;

//assign avalon_ifa_stream.waitrequest = 1'b1;
//assign avalon_ifa_stream.readdata = '0 ;



assign avalon_ifh_sdram.address     = (sel_vga) ? avalon_ifa_vga.address     : avalon_ifa_stream.address;
assign avalon_ifh_sdram.byteenable  = (sel_vga) ? avalon_ifa_vga.byteenable  : avalon_ifa_stream.byteenable;
assign avalon_ifh_sdram.read        = (sel_vga) ? avalon_ifa_vga.read        : avalon_ifa_stream.read;
assign avalon_ifh_sdram.write       = (sel_vga) ? avalon_ifa_vga.write       : avalon_ifa_stream.write;
assign avalon_ifh_sdram.writedata   = (sel_vga) ? avalon_ifa_vga.writedata   : avalon_ifa_stream.writedata;
assign avalon_ifh_sdram.burstcount  = (sel_vga) ? avalon_ifa_vga.burstcount  : avalon_ifa_stream.burstcount;

assign avalon_ifa_vga.readdata      = (sel_vga) ? avalon_ifh_sdram.readdata      : '0;
assign avalon_ifa_vga.waitrequest   = (sel_vga) ? avalon_ifh_sdram.waitrequest   : 1'b1;
assign avalon_ifa_vga.readdatavalid = (sel_vga) ? avalon_ifh_sdram.readdatavalid : 1'b0;

assign avalon_ifa_stream.readdata      = (sel_vga) ? '0   : avalon_ifh_sdram.readdata;
assign avalon_ifa_stream.waitrequest   = (sel_vga) ? 1'b1 : avalon_ifh_sdram.waitrequest;
assign avalon_ifa_stream.readdatavalid = (sel_vga) ? 1'b0 : avalon_ifh_sdram.readdatavalid;


logic vga_busy;
logic [3 : 0] vga_count;
logic [4 : 0] vga_burstcount;

typedef enum logic [1:0]{
            INIT,
            READ,
            DONE
        } read_state_t;

        read_state_t read_state;

always_ff @(posedge avalon_ifa_vga.clk) begin
    if (avalon_ifa_vga.reset) begin
        read_state <= INIT;
    end
    else begin
        case (read_state)
            INIT: begin
                if (!avalon_ifa_vga.waitrequest && avalon_ifa_vga.read && sel_vga) begin
                    read_state <= READ;
                    vga_count <= 0;
                    vga_burstcount <= avalon_ifa_vga.burstcount;
                end
            end

            READ: begin
                if (avalon_ifa_vga.readdatavalid) begin
                    vga_count <= vga_count + 1;
                    if (vga_count + 1 == vga_burstcount) begin
                        read_state <= DONE;
                    end
                end
            end

            DONE: begin
                read_state <= INIT;
            end

            default: begin
                read_state <= INIT;
            end

        endcase
    end
end

always_comb
begin
    case (read_state)
        INIT: begin
            //if (avalon_ifa_vga.read && !avalon_ifa_vga.waitrequest) vga_busy = 1;
            if (avalon_ifa_vga.read) vga_busy = 1;
            else vga_busy = 0;
        end

        READ: vga_busy = 1;
        DONE: vga_busy = avalon_ifa_vga.readdatavalid;

        default: begin
            vga_busy = 0;
        end
    endcase
end

logic stream_busy;
logic [3 : 0] stream_count;
logic [4 : 0] stream_burstcount;

typedef enum logic {
            INIT_W,
            WRITE
        } write_state_t;

        write_state_t write_state;

always_ff @(posedge avalon_ifa_stream.clk) begin
    if (avalon_ifa_stream.reset) begin
        write_state <= INIT_W;
    end
    else begin
        case (write_state)
            INIT_W: begin
                if (!avalon_ifa_stream.waitrequest && avalon_ifa_stream.write && !sel_vga) begin
                    write_state <= WRITE;
                    stream_count <= 1;
                    stream_burstcount <= avalon_ifa_stream.burstcount;
                end
            end

            WRITE: begin
                if (avalon_ifa_stream.write && !avalon_ifa_stream.waitrequest) begin
                    stream_count <= stream_count + 1;
                    if (stream_count + 1 == stream_burstcount) begin
                        write_state <= INIT_W;
                    end
                end
            end

            default: begin
                write_state <= INIT_W;
            end

        endcase
    end
end

always_comb
begin
    case (write_state)

        INIT_W: begin
            //if (avalon_ifa_stream.write && !avalon_ifa_stream.waitrequest) stream_busy = 1;
            if (avalon_ifa_stream.write) stream_busy = 1;
            else stream_busy = 0;
        end

        WRITE: stream_busy = 1;

        default: begin
            stream_busy = 0;
        end
    endcase
end

// Referee
always_comb begin
    case (sel_vga)
        1:
            if (!vga_busy && avalon_ifa_stream.write) sel_vga = 1'b0;
        0:
            if (!stream_busy && avalon_ifa_vga.read) sel_vga = 1'b1;
        default:
            sel_vga = 1'b1;
    endcase
end

endmodule
