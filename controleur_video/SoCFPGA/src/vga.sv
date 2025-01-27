`default_nettype none
module vga
#(
    parameter integer HDISP = 800,  // Image length
    parameter integer VDISP = 480   // Image height
)
(
    input wire pixel_clk,
    input wire pixel_rst,
    video_if.master video_ifm
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

endmodule
