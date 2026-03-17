`timescale 1ns / 100ps
`default_nettype none

module tb();
  //---------------------------------------
  // Generacja sygna³u resetu
  //---------------------------------------
  reg RST;
  initial
    begin   
      RST = 1'b1; 
      #10 
      RST = 1'b0;
    end 
  //---------------------------------------
  // Generacja potrzebnych sygnalow zegarowych
  //---------------------------------------
  reg CLK75_0;
  initial CLK75_0 <= 0;
  always #6.6 CLK75_0<=~CLK75_0; // P = 13.2ns, f = 75.75MHz
   
  //---------------------------------------
  
  reg        EncA_QA;
  reg        EncA_QB;
  reg        EncB_QA;
  reg        EncB_QB;
  
  wire       VID_HSYNC;
  wire       VID_VSYNC;
  wire       VID_DE;
  wire [7:0] VID_RED;
  wire [7:0] VID_GREEN;
  wire [7:0] VID_BLUE; 
  wire       VID_HSYNC_d;
  wire       VID_VSYNC_d;
  wire       VID_DE_d;
  
  wire [3:0] LED;
  //---------------------------------------
  // VESA signal generator
  //---------------------------------------
  localparam [10:0] SCR_W = 30;
  localparam [10:0] SCR_H = 20;
  
  wire [10:0] x_hcnt;
  wire [10:0] x_vcnt;
  wire [10:0] x_hcnt_d;
  wire [10:0] x_vcnt_d;
  
  vga_sync_gen pong_vga_sync_gen (
    .CLK (CLK75_0),
    .RST (RST),
    
    // output ports
    .GEN_ACTIVE    (VID_DE),        // [ 0:0]
    .GEN_RGB       (),              // [23:0] TEST PATERN OUTPUT
                           
    .GEN_HSYNC     (),              // [ 0:0] HORIZONTAL SYNCHRONIZATION  
    .GEN_HSYNCP    (VID_HSYNC),     // [ 0:0] HORIZONTAL SYNCHRONIZATION (POLARITY)
    .GEN_HCNT      (x_hcnt),        // [10:0] PIXEL IN LINE ID

    .GEN_VSYNC     (),              // [ 0:0] VERTICAL SYNCHRONIZATION
    .GEN_VSYNCP    (VID_VSYNC),     // [ 0:0] VERTICAL SYNCHRONIZATION (POLARITY)
    .GEN_VCNT      (x_vcnt),        // [10:0] LINE IN FRAME ID

    // Parametry H
    .H_ACTIVE      (SCR_W),         // [10:0] FRAME WIDTH
    .H_FRONT_PORCH (11'd3),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .H_BACK_PORCH  (11'd1),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .H_SYNC        (11'd1),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .H_SYNC_POL    (1'd0),          // [ 0:0] SYNCHRONIZATION SIGNAL POLARIZATION 0(-), 1(+)

    // Parametry V
    .V_ACTIVE      (SCR_H),         // [10:0] FRAME HEIGHT
    .V_FRONT_PORCH (11'd1),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .V_BACK_PORCH  (11'd1),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .V_SYNC        (11'd1),         // [10:0] VESA BLANKING PERIOD PARAMETER
    .V_SYNC_POL    (1'd0)           // [ 0:0] SYNCHRONIZATION SIGNAL POLARIZATION 0(-), 1(+)
  );
  //---------------------------------------
  // Delay HSYNC, VSYNC, DE and H/V counters
  //---------------------------------------
  parameter CTRL_DELAY = 1;
  delay #(.D(CTRL_DELAY))        del1 (.CLK(CLK75_0), .I(   VID_DE), .O(   VID_DE_d));
  delay #(.D(CTRL_DELAY))        del2 (.CLK(CLK75_0), .I(VID_HSYNC), .O(VID_HSYNC_d));
  delay #(.D(CTRL_DELAY))        del3 (.CLK(CLK75_0), .I(VID_VSYNC), .O(VID_VSYNC_d));
  delay #(.D(CTRL_DELAY),.w(11)) del4 (.CLK(CLK75_0), .I(   x_hcnt), .O(   x_hcnt_d));
  delay #(.D(CTRL_DELAY),.w(11)) del5 (.CLK(CLK75_0), .I(   x_vcnt), .O(   x_vcnt_d));
  //---------------------------------------
  // PONG game
  //---------------------------------------
  pong_main 
  #(
    .SCR_W  (SCR_W),
    .SCR_H  (SCR_H)
  )
  my_pong_inst
  (
    .CLK    (CLK75_0),   // 75 MHz clock signal
    .RST    (RST),       // active high reset

    .H_CNT  (x_hcnt),    // input horizontal pixel pointer 
    .V_CNT  (x_vcnt),    // input vertical   pixel pointer

    .RED    (VID_RED),   // generated value for pixel (x_hcnt, x_vcnt)
    .GREEN  (VID_GREEN), // generated value for pixel (x_hcnt, x_vcnt)
    .BLUE   (VID_BLUE),  // generated value for pixel (x_hcnt, x_vcnt)

    .EncA_QA(EncA_QA),   // encoder A input
    .EncA_QB(EncA_QB),   // encoder A input
    .EncB_QA(EncB_QA),   // encoder B input
    .EncB_QB(EncB_QB),   // encoder B input

    .LED    (LED)        // general purpose LED output
    );   
  //---------------------------------------
  // encoders signals generation
  //---------------------------------------
  initial
    begin
      EncA_QA = 1;
      EncA_QB = 1;
      EncB_QA = 1;
      EncB_QB = 1;
      #100 
      EncA_QA = 0;
      // ... write more 
    end                               
             
  //---------------------------------------
  // screen memory
  //---------------------------------------
  reg[2:0] VIDMEM [0:SCR_W*SCR_H-1];   
  always@(posedge CLK75_0)
    if(VID_DE_d)
      VIDMEM[x_hcnt_d+x_vcnt_d*SCR_W] <= { &VID_RED, &VID_GREEN, &VID_BLUE};
  //---------------------------------------
endmodule
