`default_nettype none
`ifdef SIMULATION
  localparam integer hcmpt1 = 50 ;
  localparam integer hcmpt2 = 16 ;
`else
  localparam integer hcmpt1 = 50000000 ;
  localparam integer hcmpt2 = 16000000 ;
`endif

module Top #(
    parameter integer HDISP = 800,
    parameter integer VDISP = 480
)
(
    // Les signaux externes de la partie FPGA
    input  wire  FPGA_CLK1_50,
    input  wire  [1:0] KEY,
    output logic [7:0] LED,
    input  wire  [3:0] SW,
    // Les signaux du support matériel son regroupés dans une interface
    hws_if.master       hws_ifm,
    video_if.master     video_ifm
);

//====================================
//  Déclarations des signaux internes
//====================================
  wire        sys_rst;   // Le signal de reset du système
  wire        sys_clk;   // L'horloge système a 100Mhz
  wire        pixel_clk; // L'horloge de la video 32 Mhz

//=======================================================
//  La PLL pour la génération des horloges
//=======================================================

sys_pll  sys_pll_inst(
            .refclk(FPGA_CLK1_50),   // refclk.clk
            .rst(1'b0),              // pas de reset
            .outclk_0(pixel_clk),    // horloge pixels a 32 Mhz
            .outclk_1(sys_clk)       // horloge systeme a 100MHz
);

//=============================
//  Les bus Avalon internes
//=============================
avalon_if #( .DATA_BYTES(4)) avalon_if_sdram  (sys_clk, sys_rst);
avalon_if #( .DATA_BYTES(4)) avalon_if_stream (sys_clk, sys_rst);


//=============================
//  Le support matériel
//=============================
hw_support hw_support_inst (
    .avalon_ifa (avalon_if_sdram),
    .avalon_ifh (avalon_if_stream),
    .hws_ifm  (hws_ifm),
    .sys_rst  (sys_rst), // output
    .SW_0     ( SW[0] ),
    .KEY      ( KEY )
 );

//=============================
// On neutralise l'interface
// du flux video pour l'instant
// A SUPPRIMER PLUS TARD
//=============================
assign avalon_if_stream.waitrequest = 1'b1;
assign avalon_if_stream.readdata = '0 ;


//=============================
// On neutralise l'interface SDRAM
// pour l'instant
// A SUPPRIMER PLUS TARD
//=============================
assign avalon_if_sdram.write  = 1'b0;
assign avalon_if_sdram.read   = 1'b0;
assign avalon_if_sdram.address = '0  ;
assign avalon_if_sdram.writedata = '0 ;
assign avalon_if_sdram.byteenable = '0 ;


//--------------------------
//------- Code Eleves ------
//--------------------------

assign LED[0] = KEY[0];

logic[26:0] counter1 = 0;

always_ff @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        counter1 <= 0;
        LED[1] <= 0;
    end
    else begin
        if (counter1 == hcmpt1 - 1) begin
            counter1 <= 0;
            LED[1] <= ~LED[1];
        end
        else
            counter1 <= counter1 + 1;
    end

end

logic pixel_rst;

logic ff1, ff2;     // Flip Flops D-type

always_ff @(posedge pixel_clk or posedge sys_rst) begin
    if (sys_rst) begin
        ff1 <= 1'b1;
        ff2 <= 1'b1;
    end else begin
        ff1 <= 1'b0;
        ff2 <= ff1;
    end
end

assign pixel_rst = ff2;

logic[26:0] counter2 = 0;

always_ff @(posedge pixel_clk or posedge pixel_rst) begin
    if (pixel_rst) begin
        counter2 <= 0;
        LED[2] <= 0;
    end
    else begin
        if (counter2 == hcmpt2 - 1) begin
            counter2 <= 0;
            LED[2] <= ~LED[2];
        end
        else
            counter2 <= counter2 + 1;
    end

end

vga #(
    .HDISP (HDISP),
    .VDISP (VDISP)
)
vga_inst (
    .pixel_clk (pixel_clk),
    .pixel_rst (pixel_rst),
    .video_ifm (video_ifm)
);


endmodule
`default_nettype wire
