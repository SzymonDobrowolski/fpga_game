module clk_divider(
input wire clock_in,
output wire clock_out,
input wire [31:0] n
);
reg clk_out_reg;
reg [31:0] cnt;

initial begin
	cnt = 0;
	clk_out_reg = 0;
end

always @(posedge clock_in)
	begin
		if(cnt == 32'd0) //gdy zliczyliœmy do 0
			begin
				cnt <= n - 32'd1; //dajemy na nowo wartoœæ
				clk_out_reg <= ~clk_out_reg;
			end
		else
			begin
				cnt <= cnt - 32'd1; //odejmujemy 1 i kontynuujemy
			end
	end
	assign clock_out = clk_out_reg;
endmodule