interface FSM_101_bus (input logic clk);
  logic in;
  logic rst;
  logic out;
endinterface
module FSM_101_sva (input logic clk, input logic rst , input logic in , input logic out);

  // Detect 101
  property detect_101;
    @(posedge clk)
    disable iff (rst)
    (in ##1 !in ##1 in) |-> ##1 out;
  endproperty

  assert_101: assert property (detect_101);

  // No false trigger
  property no_false;
    @(posedge clk)
    disable iff (rst)
    out |-> ($past(in,1) && $past(!in,2) && $past(in,3));
  endproperty

  assert_no_false: assert property (no_false);

  // One cycle pulse
  property one_pulse;
    @(posedge clk)
    disable iff (rst)
    out |-> ##1 !out;
  endproperty

  assert_one_pulse: assert property (one_pulse);

endmodule
    
    bind FSM_101 FSM_101_sva sva_inst (.clk(clk),.rst(rst),.out(out),.in(in));

module tb;

  logic clk;
  FSM_101_bus inf(clk);

  // DUT
  FSM_101 dut (
    .in(inf.in),
    .rst(inf.rst),
    .out(inf.out),
    .clk(clk)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Stimulus
  initial begin
    inf.rst = 1;
    inf.in  = 0;
    #10 inf.rst = 0;

    // basic 101
    inf.in = 1; #10;
    inf.in = 0; #10;
    inf.in = 1; #10;

    // overlap case: 10101
    inf.in = 0; #10;
    inf.in = 1; #10;

    // noise
    inf.in = 1; #10;
    inf.in = 1; #10;
    inf.in = 0; #10;

    #50 $finish;
  end

endmodule
