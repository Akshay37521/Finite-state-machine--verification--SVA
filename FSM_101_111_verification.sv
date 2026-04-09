module sva_assertion(input logic clk,input logic din , input logic rst , input logic dout,input logic clk_out);
  property seq_101;
    @(posedge clk)
    disable iff(rst)
    (din ##1 !din ##1 din) |=> @(posedge clk_out)dout; 
  endproperty 
  assert property(seq_101);
  property seq_111;
    @(posedge clk)
    disable iff(rst)
    (din ##1 din ##1 din) |=> @(posedge clk_out) dout;
  endproperty
  assert property(seq_111);
    
   property no_false_trigger;
     @(posedge clk)
     disable iff(rst)
     dout |=>( ($past(din,1) && $past(!din,2) && $past(din,3) ) || dout|->($past(din,1) && $past(din,2) && $past(din,3)));
   endproperty
       assert property(no_false_trigger);
      
      
       
      
endmodule
    
    bind moore_dual_detector sva_assertion sva_inst(.clk(clk),.din(din),.dout(dout),.rst(rst),.clk_out(clk));
    
    module tb_dual;
    reg clk, rst, din,clk_out;
    wire dout;
      moore_dual_detector uut (.clk(clk), .rst(rst), .din(din), .dout(dout));
    
    always #5 clk = ~clk;
    always #5 clk_out = ~clk_out;
    

    initial begin
      $dumpfile();
      $dumpvars();
        clk = 0; rst = 1; din = 0;clk_out = 0;
        #10 rst = 0;
        // Test 101
        #10 din = 1; #10 din = 0; #10 din = 1; 
        // Test 111 (starts from the '1' of previous 101)
        #10 din = 1; #10 din = 1;
        #20 $finish;
    end
endmodule
