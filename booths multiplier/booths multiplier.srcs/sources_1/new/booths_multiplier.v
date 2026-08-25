`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Booth Multiplier 16x16 -> 32 bit (Corrected)
//////////////////////////////////////////////////////////////////////////////////

module booth_mul(
    input  clk,
    input  start,
    input  [15:0] Multiplicand,
    input  [15:0] Multiplier,
    output [31:0] pr_out,
    output count,
    output done
);

wire qfict;
wire [2:0] state, next_state;
wire [15:0] mout, sum;
wire reset, qld, mld, as_ld, rshift, A_S;

Architecture A3(
    clk, reset, qld, mld, as_ld, rshift, A_S,
    Multiplicand, Multiplier,
    pr_out, qfict, count
);

controller C3(
    clk, start, pr_out[0], qfict, count,
    reset, qld, mld, as_ld, rshift, A_S,
    done, state, next_state
);

endmodule



//==================== DATAPATH ====================//
module Architecture(
    input clk,
    input reset,
    input qld,
    input mld,
    input as_ld,
    input rshift,
    input A_S,
    input signed [15:0] Multiplicand,
    input signed [15:0] Multiplier,
    output signed [31:0] pr_out,
    output qfict,
    output count
);

wire [4:0] Q;
wire signed [15:0] mout;
wire signed [15:0] sum;
wire cout; // unused

ProductRegister P1(clk, reset, Multiplier, sum, qld, as_ld, rshift, qfict, pr_out);
MRegister      M1(Multiplicand, clk, reset, mld, mout);
Add_Sub        A1(pr_out[31:16], mout, A_S, sum, cout);
upcounter      C1(clk, reset, Q, count, rshift);

endmodule



//==================== PRODUCT REGISTER ====================//
// pr_out = [A(15:0), Q(15:0)]
module ProductRegister(
    input clk,
    input reset,
    input signed [15:0] Multiplier,
    input signed [15:0] sum,
    input qld,
    input as_ld,
    input rshift,
    output reg qfict,
    output reg signed [31:0] pr_out
);

always @(posedge clk)
begin
    if(reset)
    begin
        pr_out <= 32'b0;
        qfict  <= 1'b0;
    end
    else if(qld)
    begin
        pr_out[31:16] <= 16'b0;
        pr_out[15:0]  <= Multiplier;
        qfict         <= 1'b0;     // ? important initialization
    end
    else if(as_ld)
    begin
        pr_out[31:16] <= sum;
    end
    else if(rshift)
    begin
        qfict  <= pr_out[0];
        pr_out <= (pr_out >>> 1);  // arithmetic shift
    end
end

endmodule



//==================== M REGISTER ====================//
module MRegister(
    input signed [15:0] Multiplicand,
    input clk,
    input reset,
    input mld,
    output reg signed [15:0] mout
);

always @(posedge clk)
begin
    if(reset)
        mout <= 16'b0;
    else if(mld)
        mout <= Multiplicand;
end

endmodule



//==================== ADD / SUB ====================//
module Add_Sub(
    input signed [15:0] a,
    input signed [15:0] b,
    input A_S,                  // 0 = add, 1 = sub
    output reg signed [15:0] sum,
    output cout
);

assign cout = 1'b0; // unused

always @(*)
begin
    if(A_S)
        sum = a - b;
    else
        sum = a + b;
end

endmodule



//==================== COUNTER ====================//
// ? Correct Booth iterations = 16 shifts
// ? So we stop when Q == 15 (0 to 15 = 16 counts)
module upcounter(
    input clk,
    input reset,
    output reg [4:0] Q,
    output count,
    input rshift
);

assign count = (Q == 5'd15);  // ? combinational "done at 16th step"

always @(posedge clk or posedge reset)
begin
    if(reset)
        Q <= 5'd0;
    else if(rshift)
        Q <= Q + 1'b1;
end

endmodule



//==================== CONTROLLER FSM ====================//
module controller(
    input clk,
    input start,
    input q0,
    input qfict,
    input count,
    output reg reset,
    output reg qld,
    output reg mld,
    output reg as_ld,
    output reg rshift,
    output reg A_S,
    output reg done,
    output reg [2:0] state,
    output reg [2:0] next_state
);

parameter INIT    = 3'b000,
          LOAD    = 3'b001,
          IDLE    = 3'b010,
          AS_LOAD = 3'b011,
          RSHIFT  = 3'b100,
          DONE    = 3'b101;


//---------------- STATE REGISTER ----------------//
always @(posedge clk)
begin
    if(!start)
        state <= INIT;
    else
        state <= next_state;
end


//---------------- NEXT STATE LOGIC ----------------//
always @(*)
begin
    next_state = INIT; // default

    case(state)

        INIT: next_state = LOAD;

        LOAD: next_state = IDLE;

        IDLE:
        begin
            // Booth encoding:
            // 00 or 11 => only shift
            // 01 => add M
            // 10 => sub M
            if({q0, qfict} == 2'b00 || {q0, qfict} == 2'b11)
                next_state = RSHIFT;
            else
                next_state = AS_LOAD;
        end

        AS_LOAD: next_state = RSHIFT;

        RSHIFT:
        begin
            if(count)
                next_state = DONE;
            else
                next_state = IDLE;
        end

        DONE: next_state = INIT;

        default: next_state = INIT;

    endcase
end


//---------------- OUTPUT LOGIC (Moore FSM) ----------------//
always @(*)
begin
    // defaults
    reset  = 1'b0;
    qld    = 1'b0;
    mld    = 1'b0;
    as_ld  = 1'b0;
    rshift = 1'b0;
    A_S    = 1'b0;
    done   = 1'b0;

    case(state)

        INIT:
        begin
            reset = 1'b1;
        end

        LOAD:
        begin
            qld = 1'b1;
            mld = 1'b1;
        end

        AS_LOAD:
        begin
            as_ld = 1'b1;

            // 01 => add
            // 10 => sub
            if({q0, qfict} == 2'b10)
                A_S = 1'b1; // subtract
            else
                A_S = 1'b0; // add
        end

        RSHIFT:
        begin
            rshift = 1'b1;
        end

        DONE:
        begin
            done = 1'b1;
        end

    endcase
end

endmodule
