`timescale 1ns / 1ps

module booth_mul_tb();

  reg clk, start;
  reg [15:0] Multiplicand, Multiplier;
  wire [31:0] pr_out;
  wire count, done;

  booth_mul uut(
    .clk(clk),
    .start(start),
    .Multiplicand(Multiplicand),
    .Multiplier(Multiplier),
    .pr_out(pr_out),
    .count(count),
    .done(done)
  );

  // Clock: 10ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    start = 0;
    Multiplicand = 0;
    Multiplier = 0;

    #50;
    Multiplicand = 16'h0012;  // 18
    Multiplier   = 16'h2A34;  // 10804

    #10 start = 1;

    wait(done == 1);

    #10;
    $display("Multiplicand = %0d", $signed(Multiplicand));
    $display("Multiplier   = %0d", $signed(Multiplier));
    $display("Product      = %0d", $signed(pr_out));
    $display("Product HEX  = %h", pr_out);

    #20 $finish;
  end

endmodule
