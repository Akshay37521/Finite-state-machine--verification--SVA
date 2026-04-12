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
    default input #1 output #1;
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
     /*   inf.din = 0;
        #10 inf.rst = 0;
        // Test 101
        #10 inf.din = 1; #10 inf.din = 0; #10 inf.din = 1; 
        // Test 111 (starts from the '1' of previous 101)
        #10 inf.din = 1; #10 inf.din = 1;
        #20 $finish;*/
    end
  moore_dual_detector dut(.clk(inf.clk),.rst(inf.rst),.din(inf.din),.dout(inf.dout));

FSM_tb tb(inf);
endmodule
    
    program FSM_tb(FSM_bus inf);
      class FSM_trans;
        rand bit din;
        rand bit rst;
        bit dout;
      endclass
      
      mailbox #(FSM_trans) mbx = new();
      mailbox #(FSM_trans) mbs = new();
      
      class FSM_gen;
        mailbox #(FSM_trans) mbx;
        function new (mailbox #(FSM_trans) mbx);
          this.mbx = mbx;
        endfunction
        
        task run();
          FSM_trans t;
          repeat(200) begin
          t = new();
            assert(t.randomize());
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
  bit [2:0] history = 3'b000; // Fixed bracket syntax
  bit expected =0;

  function new(mailbox #(FSM_trans) mbs);
    this.mbs = mbs;
  endfunction

  task run();
    FSM_trans t;
    forever begin
      mbs.get(t);
      
      
      history = {history[1:0], t.din};
      
       
      
      if (t.rst) begin
      history = 3'b000;
      expected = 0; 
    end else begin
      
      history= {history[1:0], t.din};
      
      expected = (history == 3'b101 || history == 3'b111);
    end
  

      if(expected == t.dout) begin
        pass++;
      end else begin
        fail++;
        $display("[%0t] FAIL: din=%b out=%b | Expected=%b (History=%b)", 
                 $time, t.din, t.dout, expected, history);
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
                     
            
                
            
                            
                          
        
      
        
         
            
          
            
          
      
    
    
