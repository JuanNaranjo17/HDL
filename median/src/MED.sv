module MED
#(
    parameter integer DATA_SIZE = 8,
    parameter integer NUM_REGISTERS = 9
)
(
    input  BYP,
    input  DSI,
    input  CLK,
    input  [DATA_SIZE - 1 : 0] DI,
    output [DATA_SIZE - 1 : 0] DO
);

logic [DATA_SIZE - 1: 0] R [NUM_REGISTERS];    // [DATA_SIZE - 1: 0] R [0 : NUM_REGISTERS - 1];

wire [DATA_SIZE - 1 : 0] A;
wire [DATA_SIZE - 1 : 0] B;
wire [DATA_SIZE - 1 : 0] MAX;
wire [DATA_SIZE - 1 : 0] MIN;

MCE #(.DATA_SIZE(DATA_SIZE)) I_MCE (.A(DO), .B(R[NUM_REGISTERS - 2]), .MAX(MAX), .MIN(MIN));

always_ff @(posedge CLK)
begin
    if(DSI)
        R[0] <= DI;
    else
        R[0] <= MIN;
    for (int i = 1; i < NUM_REGISTERS - 1; i++) begin
        R[i] <= R[i-1];
    end

    if(BYP)
        R[NUM_REGISTERS - 1] <= R[NUM_REGISTERS - 2];
    else
        R[NUM_REGISTERS - 1] <= MAX;
end

assign DO = R[NUM_REGISTERS - 1];

endmodule
