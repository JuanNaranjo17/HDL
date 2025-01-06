module MCE
#(
parameter integer DATA_SIZE = 8
)
(
    input  [DATA_SIZE - 1:0] A,
    input  [DATA_SIZE - 1:0] B,
    output [DATA_SIZE - 1:0] MAX,
    output [DATA_SIZE - 1:0] MIN
);
assign {MAX,MIN} = A > B ? {A,B} : {B,A};

endmodule
