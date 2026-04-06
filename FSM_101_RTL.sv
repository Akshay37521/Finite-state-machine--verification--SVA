module FSM_101 (in,rst,out,clk);
  input in,rst,clk;
  output reg out;
  reg[1:0] state;
  
  always@(posedge clk or posedge rst ) begin
    if(rst) begin
      state<=2'b00;
      out<=0;
    end
    
    else begin
      case(state)
        2'b00: begin if(in) state<=2'b01;
          else state<=2'b00;
        end
        2'b01:begin if(in) state<=2'b01;
          else state<=2'b10;
        end
        2'b10:begin if(in) state<=2'b11;
          else state<=2'b00;
        end
        2'b11:begin if(in) state<=2'b01;
          else state<=2'b10;
        end
      endcase
    end
  end
  always @(posedge clk) begin
    if(state == 2'b11)
      out<=1;
    else
      out<=0;
  end
  
  
  
  //assign out = (state == 2'b11) ? 1 :0;
endmodule

          
