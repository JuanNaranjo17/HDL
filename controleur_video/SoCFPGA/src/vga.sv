`default_nettype none
module vga
#(
    parameter integer HDISP = 800,  // Image length
    parameter integer VDISP = 480   // Image height
)
(
    input wire pixel_clk,
    input wire pixel_rst,
    video_if.master video_ifm,
    avalon_if.host avalon_ifh
);

localparam integer Fpix     = 32000000;     // Pixel frecuency
localparam integer Fdisp    = 66;           // Images per second
localparam integer HFP      = 40;           // Horizontal Front Porch
localparam integer HPULSE   = 48;           // Width of the synchro line
localparam integer HBP      = 40;           // Horizontal Back Porch
localparam integer VFP      = 13;           // Vertical Front Porch
localparam integer VPULSE   = 3;            // Width of the synchro image
localparam integer VBP      = 29;           // Vertical Back Porch

localparam integer MaxPixels     = HFP + HPULSE + HBP + HDISP;
localparam integer MaxRows       = VFP + VPULSE + VBP + VDISP;
localparam integer MaxPixelsBits = $clog2(MaxPixels);

localparam integer BURSTSIZE     = 16;

localparam integer MaxRowsBits   = $clog2(MaxRows);

logic[MaxPixelsBits - 1 : 0] pixel;      // Number of pixels in one row
logic[MaxRowsBits - 1 : 0] row;          // Number of lines in an image

assign video_ifm.CLK = pixel_clk;

always_ff @(posedge pixel_clk or posedge pixel_rst) begin
    if (pixel_rst) begin
        row <= 0;
        pixel <= 0;
    end
    else begin
        if (pixel + 1 == MaxPixels) begin
            pixel <= 0;
            if (row + 1 == MaxRows) row <= 0;
            else row <= row + 1 ;
        end
        else pixel <= pixel + 1;
    end
end

always_ff @(posedge pixel_clk or posedge pixel_rst) begin
    if (pixel_rst) begin
        video_ifm.HS <= 1'b1;
        video_ifm.VS <= 1'b1;
        video_ifm.BLANK <= 1'b1;
    end
    else begin

        // Signal HS
        if (pixel < HFP) begin
            video_ifm.HS <= 1'b1;
        end
        else if (pixel < HFP + HPULSE) begin
            video_ifm.HS <= 1'b0;
        end
        else begin
            video_ifm.HS <= 1'b1;
        end

        // Signal VS
        if (row < VFP) begin
            video_ifm.VS <= 1'b1;
        end
        else if (row < VFP + VPULSE) begin
            video_ifm.VS <= 1'b0;
        end
        else begin
            video_ifm.VS <= 1'b1;
        end

        // Signal BLANK
        if (pixel < HFP + HPULSE + HBP || row < VFP + VPULSE + VBP) begin
            video_ifm.BLANK <= 0;
        end
        else begin
            video_ifm.BLANK <= 1;
        end
    end
end

wire[MaxPixelsBits - 1:0] x_active = (pixel >= HFP + HPULSE + HBP) ? (pixel - (HFP + HPULSE + HBP)) : 0;
wire[MaxRowsBits - 1:0] y_active = (row   >= VFP + VPULSE + VBP) ? (row - (VFP + VPULSE + VBP)) : 0;
/*
wire is_column_white = (x_active % 16 == 0);
wire is_row_white = (y_active % 16 == 0);

always_ff @(posedge pixel_clk or posedge pixel_rst) begin
    if (pixel_rst) begin
        video_ifm.RGB <= {8'h00, 8'h00, 8'h00}; // Black  {R, G, B}
    end
    else begin
        if (is_column_white || is_row_white) begin
            video_ifm.RGB <= {8'hFF, 8'hFF, 8'hFF}; // White
        end
        else begin
            video_ifm.RGB <= {8'h00, 8'h00, 8'h00}; // Black
        end
    end
end
*/
// SDRAM controller
logic [3 : 0] data_counter;
logic walmost_full;

typedef enum logic [1:0]{
            INIT,
            READ,
            DONE
      } read_state_t;

      read_state_t read_state;

always_ff @(posedge avalon_ifh.clk) begin
    if (avalon_ifh.reset) begin
        avalon_ifh.read <= 0;
        avalon_ifh.write <= 0;
        avalon_ifh.address <= 0;
        avalon_ifh.burstcount <= 0;
        data_counter <= 0;
        read_state <= INIT;
    end
    else begin
        case (read_state)
            INIT: begin
                if(!avalon_ifh.waitrequest && !walmost_full) begin
                    avalon_ifh.read <= 1;
                    avalon_ifh.burstcount <= BURSTSIZE;
                    data_counter <= 0;
                    read_state <= READ;
                end
                else read_state <= INIT;
            end

            READ: begin
                avalon_ifh.read <= 0;
                if (avalon_ifh.readdatavalid) begin
                    data_counter <= data_counter + 1;
                    if (data_counter + 1 == BURSTSIZE) begin
                        read_state <= DONE;
                    end
                    else begin
                        read_state <= READ;
                    end
                end
            end

            DONE: begin
                read_state <= INIT;
                if ((avalon_ifh.address + 4*BURSTSIZE) >= 4 * VDISP * HDISP) avalon_ifh.address <= 0;
                else avalon_ifh.address <= avalon_ifh.address + 4*BURSTSIZE;
            end

            default: begin
                avalon_ifh.address <= 0;
                avalon_ifh.read <= 0;
                avalon_ifh.write <= 0;
                data_counter <= 0;
                read_state <= INIT;
            end

        endcase
    end
end

// FIFO

logic enable_read;

always_ff @(posedge pixel_clk or posedge avalon_ifh.reset) begin
    if (avalon_ifh.reset) enable_read <= 0;
    else begin
        if (walmost_full && (row < VFP + VPULSE + VBP)) enable_read <= 1;
    end
end

wire fifo_read = enable_read && video_ifm.BLANK;

async_fifo #(.DATA_WIDTH(24), .DEPTH_WIDTH(8), .ALMOST_FULL_THRESHOLD(256 - 16)) async_fifo0 (
    .rst(avalon_ifh.reset),
    .rclk(pixel_clk),
    .read(fifo_read),
    .rdata(video_ifm.RGB),
    .rempty(),
    .wclk(avalon_ifh.clk),
    .write(avalon_ifh.readdatavalid),
    .wdata(avalon_ifh.readdata[23:0]),
    .wfull(),
    .walmost_full(walmost_full)
);

endmodule
