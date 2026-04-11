//================ TESTBENCH =================
module tb;

  seq_if vif();

  mailbox #(seq_txn) gen2drv = new();
  mailbox #(seq_txn) mon2scb = new();

  // MOVE DECLARATIONS HERE (Before any initial/always blocks)
  generator gen;
  driver drv;
  monitor mon;
  scoreboard scb;

  // DUT instance
  seq_detector dut (
    .clk(vif.clk),
    .rst(vif.rst),
    .in(vif.in),
    .detect_101(vif.detect_101),
    .detect_111(vif.detect_111)
  );

  // Clock
  initial vif.clk = 0;
  always #5 vif.clk = ~vif.clk;

  // Reset
  initial begin
    vif.rst = 1;
    vif.in  = 0;
    #20;
    vif.rst = 0;
  end

  // Build & run
  initial begin
    gen = new(gen2drv);
    drv = new(vif, gen2drv);
    mon = new(vif, mon2scb);
    scb = new(vif, mon2scb);

    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
    join_none

    #2000 $finish;
  end

endmodule

