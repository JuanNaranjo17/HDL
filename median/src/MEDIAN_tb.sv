/* The simulation environment of MEDIAN is simpler than that of
   MED because we do not have to generate the BYP control signal and because
   we know when the MEDIAN output is valid thanks to the DSO signal.
   The rest is very similar ... */

`timescale 1ns/10ps

module MEDIAN_tb;

  logic [7:0] DI;
  logic CLK, nRST, DSI;
  wire  [7:0] DO;
  wire  DSO;

  MEDIAN I_MEDIAN(  .DI(DI),.DO(DO),
                    .CLK(CLK), .DSI(DSI),
                    .nRST(nRST), .DSO(DSO)
                 );

  always #10ns CLK = ~CLK;

  initial begin: INPUTS

    int i, j, k, v[8+1], tmp;

    CLK  = 1'b0;
    DSI  = 1'b0;
    nRST = 1'b0;
    @(negedge CLK);
    nRST = 1'b1;
    repeat(1000) begin
      @(negedge CLK);
      DSI = 1'b1;
      for(j = 0; j < 9; j = j + 1) begin
        v[j] = {$urandom} % 256 ;
        DI   = v[j];
        @(negedge CLK);
      end
      DSI = 1'b0;
      forever
      begin
        @(posedge CLK);
           if (DSO == 1'b1) break;
      end
      for(j = 0; j < 8; j = j + 1)
        for(k = j + 1; k < 9; k = k + 1)
          if(v[j] < v[k]) begin
            tmp = v[j];
            v[j] = v[k];
            v[k] = tmp;
          end
      if(DO !== v[4]) begin
        $display("Error : DO = ", DO, " instead of ", v[4]);
        $stop;
      end
    end
    $display("Simulation completed successfully without any errors.");
    $finish;
  end

endmodule
