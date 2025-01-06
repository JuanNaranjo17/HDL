`timescale 1ns/10ps

module MED_tb;  // A simulation environment has no inputs or outputs.

  logic [7:0] DI;      // Declare the variables that will be connected
  logic CLK, BYP, DSI; // to the inputs and outputs of the module being tested.
  wire [7:0] DO;       // The types must be compatible with the module's
                       // ports and with how we use them.
                       // The variables that will serve as inputs are
                       // declared as "logic" because their value will be modified by
                       // "always" or "initial" blocks.

// Instantiate the module to be tesed.
  MED I_MED(.DI(DI), .DSI(DSI), .BYP(BYP), .CLK(CLK), .DO(DO));

  always #10ns CLK = ~CLK;  // Generate a clock

  initial begin: INPUTS     // Everything else is handled by a single "initial" block
                            // which we name to declare local variables.

    integer j, k, v[8+1], tmp;  // Five local variables. j and k
                                // will be used as loop indices. The table of 9 integers v
                                // will be used by the random generator to create the test vectors.
                                // tmp will be used to swap two values in the v table
                                // when verifying results.

    CLK = 1'b0;                 // Initialize the clock to 0 at the start of the simulation.
    DSI = 1'b0;                 // Initialize DSI to 0 at the start of the simulation.
    repeat (1000) begin                     // We will simulate 1000
                                            // vectors.
      @(posedge CLK);                       // Wait for a rising edge of CLK.
      DSI = 1'b1; // Set DSI and BYP high as we prepare to enter the
      BYP = 1'b1; // first test vector.
      for(j = 0; j < 9; j = j + 1) begin // For each of the 9 values
                                         // of the vector ...
        v[j] = {$urandom} % 256;         // we initialize the v table
                                         // with a random value
                                         // between 0 and 255,
        DI = v[j];                       // place the value on the
                                         // DI bus ...
        @(posedge CLK);                  // and wait for a rising
                                         // edge of CLK.
      end
      DSI = 1'b0; // Once the 9 values of the vector are entered,
      BYP = 1'b0; // set DSI and BYP low.

      /* The following part generates BYP so that the MED module can extract
        the median value. The sequence is as follows:
        - 8 periods at 0: the max of the 9 is in the R8 register of MED
        - 1 period at 1: the max is overwritten by the content of R7, R0 is invalid
        - 7 periods at 0: the max of the 8 remaining is in R8, R7 is invalid
        - 2 periods at 1: the max of the 8 is overwritten by the content of R7, then R6, R0, and R1 are invalid
        - 6 periods at 0: the max of the 7 remaining is in R8, R7 and R6 are invalid
        - 3 periods at 1: the max of the 7 is overwritten by the content of R7, R6 then R5, R0, R1, and R2 are invalid
        - 5 periods at 0: the max of the 6 remaining is in R8, R7, R6, and R5 are invalid
        - 4 periods at 1: the max of the 6 is overwritten by the content of R7, R6, R5, then R4, R0, R1, R2, and R3 are invalid
        - 4 periods at 0: the max of the 5 remaining, which is the desired median value, is in R8 */

      for(j = 0; j < 4; j = j + 1) begin
        for(k = 0; k < 8 - j; k = k + 1) @(posedge CLK);
        BYP = 1'b1;
        for(k = 0; k < j + 1; k = k + 1) @(posedge CLK);
        BYP = 1'b0;
      end
      for(j = 0; j < 4; j = j + 1)
        @(posedge CLK);

      @(posedge CLK); // Wait for half a period to ensure that the
                      // output DO of MED is valid.
      for(j = 0; j < 8; j = j + 1)       // Calculate the expected median value
        for(k = j + 1; k < 9; k = k + 1) // by performing a bubble sort.
          if(v[j] < v[k]) begin
            tmp = v[j];
            v[j] = v[k];
            v[k] = tmp;
          end
      if(DO !== v[4]) begin // If the output of MED is different from the
                            // expected value ...
        $display("Error: DO = ", DO, " instead of ", v[4]);
               // Display an error message.
        $stop; // And stop the simulation.
      end
    end
    // When the simulation ends, display a message.
    $display("Simulation completed successfully without any errors.");
    $finish; // And end the simulation.
  end

endmodule
