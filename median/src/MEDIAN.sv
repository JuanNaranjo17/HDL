module MEDIAN
#(
    parameter integer DATA_SIZE = 8,
    parameter integer NUM_REGISTERS = 9
)
(
    input  DSI,
    input  nRST,
    input  CLK,
    input  [DATA_SIZE - 1 : 0] DI,
    output [DATA_SIZE - 1 : 0] DO,
    output logic DSO
);

typedef enum logic[2:0] {
    WAITING,
    GET_DATA,
    BYP_OFF,
    BYP_ON,
    MED_VALUE
} state_t;

state_t state;

logic BYP;
logic[3:0] CLK_off, CLK_on, counter;

MED #(.DATA_SIZE(DATA_SIZE), .NUM_REGISTERS(NUM_REGISTERS)) I_MED(.DSI(DSI), .BYP(BYP), .CLK(CLK),
      .DI(DI), .DO(DO));

always_ff @(posedge CLK or negedge nRST)
begin
    if(!nRST) begin
        state <= WAITING;
    end
    else
        case (state)
            WAITING: begin
                if (DSI) begin
                    state <= GET_DATA;
                    CLK_off <= NUM_REGISTERS - 1;
                    CLK_on <= 0;
                    counter <= 1;
                end
            end

            GET_DATA: begin
                if (!DSI)
                    state <= BYP_OFF;
            end

            BYP_OFF: begin
                if (counter == CLK_off) begin
                    if (CLK_off == NUM_REGISTERS/2)
                        state <= MED_VALUE;
                    else begin
                        state <= BYP_ON;
                        CLK_on <= CLK_on + 1;
                        counter <= 1;
                    end
                end
                else
                    counter <= counter + 1;
            end

            BYP_ON: begin
                if (counter == CLK_on) begin
                    state <= BYP_OFF;
                    CLK_off <= CLK_off - 1;
                    counter <= 1;
                end
                else
                    counter <= counter + 1;
            end

            MED_VALUE: begin
                state <= WAITING;
            end

            default: begin
                state <= WAITING;
            end
        endcase
end

always_comb
begin
    DSO = 1'b0;
    BYP = 1'b0;
    case (state)
        GET_DATA:
            BYP = DSI;

        BYP_ON:
            BYP = 1'b1;

        MED_VALUE:
            DSO = 1'b1;

        default: begin
            DSO = 1'b0;
            BYP = 1'b0;
        end
    endcase
end


endmodule
