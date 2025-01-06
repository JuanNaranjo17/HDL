`timescale 1ns/10ps

module MCE_tb;               // A simulation environment has neither inputs nor outputs.
  logic [7:0] A, B;          // Declare variables that will be connected
                             // to the inputs/outputs of the module under test.
  wire  [7:0] MAX, MIN;           // The types must be compatible with the ports of the module and
                                  // their intended use.
                                  // A and B are declared as "logic" because their value will be
                                  // modified by an "always" or "initial" block.

  MCE I_MCE(.A(A), .B(B), .MAX(MAX), .MIN(MIN));        // Instantiate the module under test.

  initial begin: INPUTS                                 // Everything is handled here in a single
                                                        // "initial" block  which is named to allow local variable declarations.
    logic [7:0] RAND, vmin, vmax;                       // Four local variables.
                                                        // RAND will be used by the random generator, vmax and vmin will be used
                                                        // to calculate the expected values.
    repeat (1000) begin                        // We will simulate 1000 input vectors.
      RAND = $urandom;                         // Assign A and B a random value between 0 and 255.
      A = RAND;
      RAND = $urandom;
      B = RAND;
      #1;                                             // Wait for one time unit to allow the module
                                                      // under test to update its outputs.
      if (A < B) begin                                // Calculate the expected outputs using an
        vmin = A;                                     // algorithm different from the one used in
        vmax = B;                                     // the module under test.
      end
      else begin
        vmin = B;
        vmax = A;
      end
      if (MIN !== vmin || MAX !== vmax) begin           // If the outputs are not as expected.
        $display("Error: MIN = ", MIN, ", MAX = ", MAX,
                 " instead of MIN = ", vmin, ", MAX = ", vmax);
                                                        // Print an error message.
        $stop;                                          // Stop the simulation.
      end
    end
                                                        // When the simulation is complete, display a message.
    $display("Simulation completed successfully without any errors.");
    $finish;                                            // Terminate the simulation.

  end

endmodule
