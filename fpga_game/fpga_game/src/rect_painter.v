module rect_painter
	#(
	parameter R_VAL=8'hFF, G_VAL=8'hFF, B_VAL=8'hFF
	)	 
	( 
	input wire clk, rst,
	input wire [10:0] h_cnt, v_cnt,
	input wire [10:0] x0, y0, x1, y1,
	input wire [7:0] red_i, green_i, blue_i,
	output reg [7:0] red_o, green_o, blue_o
	);
	always@(posedge clk or rst)
		begin
			if(rst)
				begin
					red_o <= 8'h00; green_o <= 8'h00; blue_o <= 8'h00;
				end
			else if (h_cnt >= x0 && h_cnt < x1 && v_cnt >= y0 && v_cnt <y1 )
				begin
					red_o <= R_VAL; green_o <= G_VAL; blue_o <= B_VAL; //wszystko w obszarze
				end
			else
				begin
					red_o <= red_i; green_o <= green_i; blue_o <= blue_i;  //wszystko poza obszarem
				end
			end
endmodule