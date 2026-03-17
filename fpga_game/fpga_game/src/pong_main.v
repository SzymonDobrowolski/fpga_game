module pong_main
#(
  parameter SCR_W = 1280,
  parameter SCR_H = 720
)
(
	input wire        CLK, // CLK 75MHz
	input wire        RST, // Active high reset
  
	input wire [10:0] H_CNT, // horizontal pixel pointer
	input wire [10:0] V_CNT, // vertical   pixel pointer
	
	input wire        EncA_QA, 
	input wire        EncA_QB,
	input wire        EncB_QA,
	input wire        EncB_QB,
	
	output wire [7:0] RED,
	output wire [7:0] GREEN,
	output wire [7:0] BLUE,
	
	output wire [3:0] LED
  );	   
  
  wire [7:0] loc_RED;
  wire [7:0] loc_GREEN;
  wire [7:0] loc_BLUE;
  
  rect_painter 	   //zielony
  #( 
  .R_VAL(8'h00), .G_VAL(8'hFF), .B_VAL(8'h00)
  )
  rect1
  (
  .clk(CLK), .rst(RST), .h_cnt(H_CNT), .v_cnt(V_CNT),
  .x0(10), .y0(10), .x1(15), .y1(16),
  .red_i(8'hFF), .green_i(8'h00), .blue_i(8'h00),
  .red_o(loc_RED), .green_o(loc_GREEN), .blue_o(loc_BLUE)
  );  
  
  
  rect_painter   
  #( 
  .R_VAL(8'h00), .G_VAL(8'h00), .B_VAL(8'hFF)
  )
  rect2
  (
  .clk(CLK), .rst(RST), .h_cnt(H_CNT), .v_cnt(V_CNT),
  .x0(0), .y0(0), .x1(5), .y1(5),
  .red_i(loc_RED), .green_i(loc_GREEN), .blue_i(loc_BLUE),
  .red_o(RED), .green_o(GREEN), .blue_o(BLUE)
  );
  

  // Constant output 
  //assign RED   = 8'hFF;
  //assign GREEN = 8'h67;
  //assign BLUE  = 8'hDF;
  
  //-----------------------------------------
  // assign LED to counter bits to indicate FPGA is working
  reg [31:0] heartbeat;
  always@(posedge CLK or posedge RST)
  if(RST) heartbeat <=             32'd0;
  else    heartbeat <= heartbeat + 32'd1;
  
  assign LED[3:0] = heartbeat[26:23];
  //-----------------------------------------
endmodule