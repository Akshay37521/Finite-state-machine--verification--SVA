module moore_dual_detector (
    input clk, rst, din,
    output reg dout
);
    reg [2:0] state, next_state;
    parameter S0=3'b000, S1=3'b001, S2=3'b010, S3=3'b011, S4=3'b100, S5=3'b101;

    
    always @(posedge clk or posedge rst) begin
        if (rst) state <= S0;
        else     state <= next_state;
    end

    
    always @(*) begin
        case (state)
            S0: next_state = din ? S1 : S0;
            S1: next_state = din ? S4 : S2; 
            S2: next_state = din ? S3 : S0; 
            S3: next_state = din ? S4 : S2; 
            S4: next_state = din ? S5 : S2; 
            S5: next_state = din ? S5 : S2; 
            default: next_state = S0;
        endcase
    end

   
    always @(*) begin
        dout = (state == S3 || state == S5);
    end
endmodule


interface FSM_bus(input logic clk);
  logic rst;
  logic din;
  logic dout; // Added semicolon here

  clocking cb @(posedge clk);
    default input #1 output ;
    input dout;       // Matches the logic name above
    output rst, din;
  endclocking

  clocking cb_mon @(posedge clk);
    default input #1;
    input dout, rst, din;
  endclocking

  modport tb (clocking cb, input clk);
  modport mon(clocking cb_mon , input clk);
    
    property seq_101;
    @(posedge clk)
    disable iff(rst)
    (din ##1 !din ##1 din) |=> @(posedge clk)dout; 
  endproperty 
  assert property(seq_101);
  property seq_111;
    @(posedge clk)
    disable iff(rst)
    (din ##1 din ##1 din) |=> @(posedge clk) dout;
  endproperty
  assert property(seq_111);
    
   property no_false_trigger;
     @(posedge clk)
     disable iff(rst)
     dout |=>( ($past(din,1) && $past(!din,2) && $past(din,3) ) || dout|->($past(din,1) && $past(din,2) && $past(din,3)));
   endproperty
       assert property(no_false_trigger);
endinterface

    
    
module tb;
    bit clk =0;
    always #5 clk = ~clk;
  FSM_bus inf(clk);
  moore_dual_detector dut(.clk(inf.clk),.rst(inf.rst),.din(inf.din),.dout(inf.dout));
  
    covergroup FSM_state_cov @(posedge clk);
    cp_state: coverpoint dut.state {
      bins s0 = {3'b000};
      bins s1 = {3'b001};
      bins s2 = {3'b010};
      bins s3 = {3'b011};
      bins s4 = {3'b100};
      bins s5 = {3'b101};
    }
  endgroup

  covergroup FSM_input_cov @(posedge clk);
    cp_din:  coverpoint inf.din  { bins zero={0}; bins one={1}; }
    cp_dout: coverpoint inf.dout { bins no_detect={0}; bins detect={1}; }
  endgroup

  covergroup FSM_seq_cov @(posedge clk);
    cp_seq: coverpoint dut.state {
      bins hit_101 = (3'b010 => 3'b011);
      bins hit_111 = (3'b100 => 3'b101);
    }
  endgroup
  
  FSM_state_cov sc;
  FSM_input_cov ic;
  FSM_seq_cov   qc;
   initial begin
    $dumpfile();
    $dumpvars();
    sc = new();
    ic = new();
    qc = new();
  end

FSM_tb tb(inf);
  final begin
    $display("State   Coverage = %.2f%%", sc.get_coverage());
    $display("Input   Coverage = %.2f%%", ic.get_coverage());
    $display("Seq     Coverage = %.2f%%", qc.get_coverage());
    $display("Overall Coverage = %.2f%%", $get_coverage());
  end
endmodule
    
program FSM_tb(FSM_bus inf);
 class FSM_trans;
  rand bit din;
  // rst is NOT rand anymore
  bit rst;
  bit dout;
endclass
  mailbox #(FSM_trans) mbx = new();
  mailbox #(FSM_trans) mbs = new();


class FSM_gen;
  mailbox #(FSM_trans) mbx;
  int num_test = 200;
  function new(mailbox #(FSM_trans) mbx);
    this.mbx = mbx;
  endfunction

  task send_rst();
    FSM_trans t;

    repeat(2) begin
    t = new();
    t.rst = 1;
    t.din = 0;
    mbx.put(t);
    end
    
    t = new();
    t.rst = 0;
    t.din = 0;
    mbx.put(t);
  endtask
  
  task send_101();
    FSM_trans t;
    bit[2:0] pattern = 3'b101;
    repeat(3) begin
      t = new();
      t.rst = 0;
      t.din = pattern[2];
      pattern =pattern<<1;
      mbx.put(t);
    end
  endtask
  
  task send_111();
    FSM_trans t;
   
    repeat(3) begin
      t = new();
      t.rst = 0;
      t.din = 1;
      mbx.put(t);
    end
  endtask
  
  task send_10111();
    FSM_trans t;
    bit[4:0] pattern = 5'b10111;
    repeat(5) begin
      t = new();
      t.rst = 0;
      t.din = pattern[4];
      pattern = pattern<<1;
      mbx.put(t);
    end
  endtask
  
  task send_11101();
    FSM_trans t;
    bit[4:0] pattern = 5'b11101;
    repeat(5) begin
      t = new();
      t.rst = 0;
      t.din = pattern[4];
      pattern = pattern<<1;
      mbx.put(t);
    end
  endtask
  
  task send_1111111();
    FSM_trans t;
    repeat(7) begin
      t = new();
      t.rst = 0;
      t.din = 1;
      mbx.put(t);
    end
  endtask
  
  task send_000000();
    FSM_trans t;
    repeat(7) begin
      t = new();
      t.rst = 0;
      t.din = 0;
      mbx.put(t);
    end
  endtask
  
  task send_random(int count);
    FSM_trans t;
    repeat(count) begin
      t = new();
      t.rst = 0;             // rst always 0 during stimulus
      assert(t.randomize()); // only din randomizes
      mbx.put(t);
    end
  endtask
  
  task run();
    send_rst();
    
    repeat(5) send_101();
    repeat(5) send_111();
    repeat(5) send_10111();
    repeat(5) send_11101();
    repeat(5) send_1111111();
    repeat(5) send_000000();
    send_random(150);
  endtask

 
endclass
      
      class FSM_drive;
        virtual FSM_bus inf;
        mailbox #(FSM_trans) mbx;
        function new(virtual FSM_bus inf,mailbox #(FSM_trans) mbx);
          this.inf = inf;
          this.mbx = mbx;
        endfunction
        
        task run();
          FSM_trans t;
          forever begin
            t = new();
            mbx.get(t);
            @(inf.cb);
            inf.cb.din<=t.din;
            inf.cb.rst<=t.rst;
          end
        endtask
      endclass
      
      class FSM_monitor;
        virtual FSM_bus inf;
        mailbox #(FSM_trans) mbs;
        function new(virtual FSM_bus inf , mailbox #(FSM_trans) mbs);
          this.inf = inf;
          this.mbs = mbs;
        endfunction
        
        task run();
          FSM_trans t;
          forever begin
            @(inf.cb_mon)
            t = new();
            t.din = inf.cb_mon.din;
            t.rst = inf.cb_mon.rst;
            t.dout = inf.cb_mon.dout;
            
            mbs.put(t);
          end
        endtask
       endclass
      
class FSM_Scoreb;
  mailbox #(FSM_trans) mbs;
  int pass = 0, fail = 0;

  // Queue to store expected outputs
  bit expected_q[$];

  // Shadow FSM state
  typedef enum logic [2:0] {S0, S1, S2, S3, S4, S5} state_t;
  state_t shadow_state;

  function new(mailbox #(FSM_trans) mbs);
    this.mbs = mbs;
    shadow_state = S0;
  endfunction

  // -------------------------------------------------------
  // Shadow FSM: mirrors DUT next-state + output logic exactly
  // -------------------------------------------------------
  function bit compute_expected(input bit din, input bit rst);
  bit dout_exp;
  state_t next;

  if (rst) begin
    shadow_state = S0;
    return 0;
  end

  // ✅ Step 1: Output from CURRENT state BEFORE transition
  dout_exp = (shadow_state == S3 || shadow_state == S5);

  // ✅ Step 2: Compute next state
  case (shadow_state)
    S0: next = din ? S1 : S0;
    S1: next = din ? S4 : S2;
    S2: next = din ? S3 : S0;
    S3: next = din ? S4 : S2;
    S4: next = din ? S5 : S2;
    S5: next = din ? S5 : S2;
    default: next = S0;
  endcase

  // ✅ Step 3: Transition AFTER output captured
  shadow_state = next;

  return dout_exp;
endfunction
  // -------------------------------------------------------
  // Run: get transaction, push expected to queue, compare
  // -------------------------------------------------------
  task run();
  FSM_trans t;
  bit exp;

  forever begin
    mbs.get(t);

    // Direct compare — no queue buffering needed
    exp = compute_expected(t.din, t.rst);

    if (exp === t.dout) begin
      pass++;
    end else begin
      fail++;
      $display("[%0t] FAIL: rst=%b din=%b | DUT=%b Expected=%b | PrevState=%s",
               $time, t.rst, t.din, t.dout, exp, shadow_state.name());
    end
  end
endtask

endclass
         
  

FSM_drive d;
FSM_gen g;
FSM_monitor m;
FSM_Scoreb s;

initial begin
    g = new(mbx);
    d = new(inf, mbx);
    m = new(inf, mbs);
    s = new(mbs);

    fork
      g.run();
      d.run();
      m.run();
      s.run();
    join_any

  wait(s.pass + s.fail == 303);
 
    #10;
    
    $display("  Total = %0d   Pass = %0d   Fail = %0d",
             s.pass + s.fail, s.pass, s.fail);
 end
endprogram

