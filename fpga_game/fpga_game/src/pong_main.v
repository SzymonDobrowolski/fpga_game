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
  
  // NAPRAWA B£ÊDU: OpóŸniamy V_CNT o 1 takt zegara
  reg [10:0] V_CNT_fixed;
  always @(posedge CLK or posedge RST) begin
      if (RST) V_CNT_fixed <= 0;
      else     V_CNT_fixed <= V_CNT;
  end
  
  // Wymiary czo³gu
  localparam TANK_W = 5;
  localparam TANK_H = 5;
  reg [10:0] tank_x = SCR_W / 2;
  reg [10:0] tank_y = SCR_H / 2;

  // LOGIKA RYSOWANIA (U¿ywa V_CNT_fixed!)
  wire is_tank = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && 
                 (V_CNT_fixed >= tank_y) && (V_CNT_fixed < tank_y + TANK_H);
  
  localparam PIPE_W = 1;
  localparam PIPE_H = 2;
  wire [10:0] pipe_x = tank_x + 2; 
  wire [10:0] pipe_y = tank_y - PIPE_H; 

  wire is_pipe = (H_CNT >= pipe_x) && (H_CNT < pipe_x + PIPE_W) && 
                 (V_CNT_fixed >= pipe_y) && (V_CNT_fixed < pipe_y + PIPE_H);
  
// T³o to wszystko od 1 do maksymalnej rozdzielczoœci
  wire is_bg     = (H_CNT >= 1 && H_CNT <= SCR_W) && (V_CNT >= 1 && V_CNT <= SCR_H);
  
  // Gruba ramka (po 2 piksele), œciœle przylegaj¹ca do krawêdzi 1-based
  wire is_top    = (H_CNT >= 0 && H_CNT <= SCR_W) && (V_CNT >= 0 && V_CNT < 1);
  wire is_down   = (H_CNT >= 0 && H_CNT <= SCR_W) && (V_CNT >= SCR_H - 1 && V_CNT <= SCR_H);
  wire is_left   = (H_CNT >= 0 && H_CNT < 1)     && (V_CNT >= 0 && V_CNT <= SCR_H);
  wire is_right  = (H_CNT >= SCR_W - 1 && H_CNT <= SCR_W) && (V_CNT >= 0 && V_CNT <= SCR_H);
  

  // 2. Ustalamy kolor na podstawie tego, w której strefie jesteœmy
  // U¿ywamy operatora warunkowego przypisania: warunek ? wartoœæ_jeœli_prawda : wartoœæ_jeœli_fa³sz
  
  wire [7:0] final_R, final_G, final_B;

  assign final_R = (is_top || is_left || is_right || is_down) ? 8'hFF : 
                   (is_tank)                                  ? 8'h00 : 
                   (is_pipe)								  ? 8'h00 :
				   (is_bg)                                    ? 8'h00 : 8'h00;
                   
  assign final_G = (is_top || is_left || is_right || is_down) ? 8'hFF : 
                   (is_tank)                                  ? 8'hFF : // 8'hFF dla zielonego czo³gu
                   (is_pipe)								  ? 8'hFF :
				   (is_bg)                                    ? 8'h00 : 8'h00;

  assign final_B = (is_top || is_left || is_right || is_down) ? 8'hFF : 
                   (is_tank)                                  ? 8'h00 : 
                   (is_pipe)								  ? 8'h00 :
				   (is_bg)                                    ? 8'h00 : 8'h00;

  // 3. Wyprowadzenie na zewn¹trz
  // Wewnêtrzne rejestry do opóŸnienia sygna³u o 1 takt
  reg [7:0] r_red, r_green, r_blue;

  always @(posedge CLK or posedge RST) begin
      if (RST) begin
          r_red   <= 8'h00;
          r_green <= 8'h00;
          r_blue  <= 8'h00;
      end else begin
          r_red   <= final_R;
          r_green <= final_G;
          r_blue  <= final_B;
      end
  end

  // Wyprowadzenie opóŸnionych sygna³ów na zewn¹trz modu³u
  assign RED   = r_red;
  assign GREEN = r_green;
  assign BLUE  = r_blue;

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