module debouncer(
    input wire clk,
    input wire btn_in,
    output reg btn_out
);
    reg [15:0] counter;
    reg state;
    always @(posedge clk) begin
        if (btn_in != state) begin
            counter <= counter + 1;
            if (counter == 16'hFFFF) begin
                state <= btn_in;
                btn_out <= btn_in;
                counter <= 0;
            end
        end else begin
            counter <= 0;
        end
    end
endmodule

module top(
  input wire          CLK,  // CLK 50 MHz
  input wire          nRST, // Active low reset
  
  output wire [3:0]   LED,
  
  output wire         VID_DDR_PCLK,  
  output wire         VID_DDR_HSYNC, 
  output wire         VID_DDR_VSYNC, 
  output wire         VID_DDR_DE,    
  output wire  [11:0] VID_DDR_DAT,   
  
  inout wire          I2C_C,
  inout wire          I2C_D,
                      
  input wire          EncA_QA,
  input wire          EncA_QB,
  input wire          EncB_QA,
  input wire          EncB_QB,
  input wire          Button
  );

  // --- ODCZYT PRZYCISKÓW ---
  wire rst_clean, shoot_clean;
  debouncer deb_rst   (.clk(CLK), .btn_in(~nRST),   .btn_out(rst_clean));
  debouncer deb_shoot (.clk(CLK), .btn_in(Button),  .btn_out(shoot_clean));

  // --- ZEGARY (40 MHz dla qHD 960x540) ---
  wire CLK40_0;
  wire CLK40_90;
  wire CLK40_180;
  wire pll_lock;
  
  pll_50_to_40Mhz_0_90_180 pong_pll(
    .CLKI(CLK), 
    .CLKOP(CLK40_0), 
    .CLKOS(CLK40_90), 
    .CLKOS2(CLK40_180), 
    .LOCK(pll_lock)
  );

  wire       VID_HSYNC;
  wire       VID_VSYNC;
  wire       VID_DE;
  wire [7:0] VID_RED;
  wire [7:0] VID_GREEN;
  wire [7:0] VID_BLUE;
  
  wire       VID_HSYNC_d;
  wire       VID_VSYNC_d;
  wire       VID_DE_d;

  wire [10:0] x_hcnt;
  wire [10:0] x_vcnt;

  // --- GENERATOR WIDEO (960x540 @ 60Hz) ---
  vga_sync_gen pong_vga_sync_gen (
    .CLK           (CLK40_0),
    .RST           (rst_clean),
    .GEN_ACTIVE    (VID_DE),
    .GEN_RGB       (),
    .GEN_HSYNC     (),  
    .GEN_HSYNCP    (VID_HSYNC),
    .GEN_HCNT      (x_hcnt),
    .GEN_VSYNC     (),
    .GEN_VSYNCP    (VID_VSYNC),
    .GEN_VCNT      (x_vcnt),
    
    .H_ACTIVE      (11'd960),
    .H_FRONT_PORCH (11'd32),
    .H_BACK_PORCH  (11'd128),
    .H_SYNC        (11'd96),
    .H_SYNC_POL    (1'd0),
    
    .V_ACTIVE      (11'd540),
    .V_FRONT_PORCH (11'd3),
    .V_BACK_PORCH  (11'd14),
    .V_SYNC        (11'd5),
    .V_SYNC_POL    (1'd1)
  );

  // Opóźnienie dla silnika pong_main (zostało na 3)
  localparam CTRL_DELAY = 3; 
  delay #(.D(CTRL_DELAY)) del1 (.CLK(CLK40_0), .I(VID_DE),    .O(VID_DE_d));
  delay #(.D(CTRL_DELAY)) del2 (.CLK(CLK40_0), .I(VID_HSYNC), .O(VID_HSYNC_d));
  delay #(.D(CTRL_DELAY)) del3 (.CLK(CLK40_0), .I(VID_VSYNC), .O(VID_VSYNC_d));

  // --- SKALER I SILNIK GRY (Z 60x40 na środek 960x540, powiększenie 8x) ---
  // Obliczenia: szerokość 60*8=480, margines = (960-480)/2 = 240
  //             wysokość 40*8=320, margines = (540-320)/2 = 110
  wire [10:0] game_x = (x_hcnt >= 240 && x_hcnt < 720) ? (x_hcnt - 240) >> 3 : 11'h7FF;
  wire [10:0] game_y = (x_vcnt >= 110 && x_vcnt < 430) ? (x_vcnt - 110) >> 3 : 11'h7FF;
  
  pong_main #(
    .SCR_W  (60),
    .SCR_H  (40),
    .SIM_MODE(0)
  ) my_pong_inst (
    .CLK      (CLK40_0),
    .RST      (rst_clean),
    .H_CNT    (game_x),
    .V_CNT    (game_y),
    .RED      (VID_RED),
    .GREEN    (VID_GREEN),
    .BLUE     (VID_BLUE),
    .EncA_QA  (EncA_QA),
    .EncA_QB  (EncA_QB),
    .EncB_QA  (1'b0),
    .EncB_QB  (1'b0),
    .BTN_SHOOT(shoot_clean),
    .LED      (LED)
  );

  // --- BLOKI KONFIGURACJI I WYSYŁKI WIDEO ---
  vo_phy_ddr pong_vo_phy_ddr(
    .i_phy_clk0     (CLK40_0),
    .i_phy_clk90    (CLK40_90),
    .i_phy_clk180   (CLK40_180),
    .i_phy_rst0     (rst_clean),
    .i_phy_rst90    (rst_clean),
    .i_phy_hsync    (VID_HSYNC_d),
    .i_phy_vsync    (VID_VSYNC_d),
    .i_phy_de       (VID_DE_d),
    
    // Maskowanie czernią obszaru poza grą
    .i_phy_red      ((VID_DE && x_hcnt >= 240 && x_hcnt < 720 && x_vcnt >= 110 && x_vcnt < 430) ? VID_RED : 8'd0),
    .i_phy_green    ((VID_DE && x_hcnt >= 240 && x_hcnt < 720 && x_vcnt >= 110 && x_vcnt < 430) ? VID_GREEN : 8'd0),
    .i_phy_blue     ((VID_DE && x_hcnt >= 240 && x_hcnt < 720 && x_vcnt >= 110 && x_vcnt < 430) ? VID_BLUE : 8'd0),
    
    .o_pclk_pin     (VID_DDR_PCLK),
    .o_hsync_pin    (VID_DDR_HSYNC),
    .o_vsync_pin    (VID_DDR_VSYNC),
    .o_de_pin       (VID_DDR_DE),
    .o_data_pin     (VID_DDR_DAT)
  );

  hdmi_i2c_cfg pong_hdmi_i2c_cfg(
    .CLK            (CLK40_0),
    .RST            (rst_clean),       
    .I2C_C          (I2C_C),
    .I2C_D          (I2C_D)
  );

endmodule
