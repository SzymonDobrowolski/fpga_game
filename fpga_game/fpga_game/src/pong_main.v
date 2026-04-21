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
  
  // Wymiary czo³gu
  localparam TANK_W = 5;
  localparam TANK_H = 5;

  // Pozycja czo³gu (rejestry, bo bêd¹ siê zmieniaæ)
  // Inicjujemy go np. na œrodku ekranu
  reg [10:0] tank_x = SCR_W / 2;
  reg [10:0] tank_y = SCR_H / 2;

  // Logika rysowania: czy piksel nale¿y do czo³gu?
  wire is_tank = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && 
  (V_CNT >= tank_y) && (V_CNT < tank_y + TANK_H);
  
// Wymiary lufy (skierowanej w górê)
  localparam PIPE_W = 1;
  localparam PIPE_H = 2;
  
  // Pozycja lufy obliczana w locie!
  // X: œrodek czo³gu (tank_x + po³owa szerokoœci, czyli +2)
  // Y: nad czo³giem (tank_y minus wysokoœæ lufy)
  wire [10:0] pipe_x = tank_x + 2; 
  wire [10:0] pipe_y = tank_y - PIPE_H; 

  // Logika rysowania lufy
  wire is_pipe = (H_CNT >= pipe_x) && (H_CNT < pipe_x + PIPE_W) && 
                 (V_CNT >= pipe_y) && (V_CNT < pipe_y + PIPE_H);
  
  
 // 1. Definiujemy "strefy" jako sygna³y 1-bitowe (prawda/fa³sz)
  // Jeœli piksel jest w danym obszarze, sygna³ przyjmie wartoœæ 1.
  
  wire is_bg     = (H_CNT >= 0  && H_CNT < 30) && (V_CNT >= 0 && V_CNT < 20);
  wire is_top    = (H_CNT >= 0  && H_CNT < 30) && (V_CNT >= 0 && V_CNT <= 1);
  wire is_left   = (H_CNT >= 0  && H_CNT <= 1)  && (V_CNT >= 0 && V_CNT < 20);
  wire is_right  = (H_CNT >= 29 && H_CNT < 30) && (V_CNT >= 0 && V_CNT < 20); 
  wire is_down   = (H_CNT >= 0  && H_CNT < 30) && (V_CNT >= 19 && V_CNT < 20);
  

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
  assign RED   = final_R;
  assign GREEN = final_G;
  assign BLUE  = final_B;

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