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
endinterface

    
    
module tb;
    bit clk =0;
    always #5 clk = ~clk;
  FSM_bus inf(clk);
initial begin
     $dumpfile();
      $dumpvars();
     end
  moore_dual_detector dut(.clk(inf.clk),.rst(inf.rst),.din(inf.din),.dout(inf.dout));

FSM_tb tb(inf);
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
  function new(mailbox #(FSM_trans) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    FSM_trans t;

    // ----------------------------------------
    // Phase 1: Controlled Reset (not randomized)
    // ----------------------------------------
    t = new();
    t.rst = 1;
    t.din = 0;
    mbx.put(t);

    // Hold reset for 2 cycles
    t = new();
    t.rst = 1;
    t.din = 0;
    mbx.put(t);

    // De-assert reset
    t = new();
    t.rst = 0;
    t.din = 0;
    mbx.put(t);

    // ----------------------------------------
    // Phase 2: Randomize only din
    // ----------------------------------------
    repeat(200) begin
      t = new();
      t.rst = 0;             // rst always 0 during stimulus
      assert(t.randomize()); // only din randomizes
      mbx.put(t);
    end

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

    wait(s.pass + s.fail == 200);

    #10;
    
    $display("  Total = %0d   Pass = %0d   Fail = %0d",
             s.pass + s.fail, s.pass, s.fail);
    

    
  end
endprogram
                     
            
                
            
                            
                          
        
      
        
         
            
          
            
          
      
    
    
