// =============================================================================
// MODU£ DEKODERA ENKODERA KWADRATUROWEGO
// =============================================================================
module quad_decoder(
    input wire clk,
    input wire a,
    input wire b,
    output reg step_up,
    output reg step_down
);
    reg a_delayed, b_delayed;
    always @(posedge clk) begin
        a_delayed <= a;
        b_delayed <= b;
        step_up   <= (a ^ b_delayed) && (a != a_delayed);   
        step_down <= (a ^ b_delayed) == 0 && (a != a_delayed); 
    end
endmodule

// =============================================================================
// G£ÓWNY MODU£ GRY - PONG TANK
// =============================================================================
module pong_main
#(
    parameter SCR_W = 60,
    parameter SCR_H = 40
)
(
    input wire        CLK,
    input wire        RST,
  
    input wire [10:0] H_CNT,
    input wire [10:0] V_CNT,
    
    input wire        EncA_QA,
    input wire        EncA_QB,
    input wire        EncB_QA,
    input wire        EncB_QB,
    
    output wire [7:0] RED,
    output wire [7:0] GREEN,
    output wire [7:0] BLUE,
    
    output wire [3:0] LED
);

    // --- PARAMETRY ---
    localparam TANK_W = 3;
    localparam TANK_H = 3;
    localparam TIME_LIMIT = 5000; 

    // --- REJESTRY POZYCJI (SHADOW REGISTERS) ---
    reg [10:0] next_tank_x, next_tank_y;
    reg [1:0]  next_direction;
    reg [3:0]  auto_step;

    reg [10:0] tank_x, tank_y;
    reg [1:0]  direction;

    // --- LOGIKA CZASU (ANIMACJA) ---
    reg [26:0] timer;
    wire tick_sec = (timer == TIME_LIMIT);

    always @(posedge CLK or posedge RST) begin
        if (RST) timer <= 0;
        else if (tick_sec) timer <= 0;
        else timer <= timer + 1;
    end

    // --- OBLICZANIE RUCHU ---
    wire rotate_cw, rotate_ccw;
    quad_decoder dec_rot (.clk(CLK), .a(EncA_QA), .b(EncA_QB), .step_up(rotate_cw), .step_down(rotate_ccw));

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            next_tank_x <= SCR_W / 2;
            next_tank_y <= SCR_H / 2;
            next_direction <= 0;
            auto_step <= 0;
        end else begin
            if (rotate_cw)  next_direction <= next_direction + 1;
            if (rotate_ccw) next_direction <= next_direction - 1;

            if (tick_sec) begin
                auto_step <= auto_step + 1;
                case (auto_step)
                    0, 1, 2: begin next_direction <= 0; next_tank_y <= next_tank_y - 1; end 
                    3      : begin next_direction <= 1; end                                 
                    4, 5, 6: begin next_direction <= 1; next_tank_x <= next_tank_x + 1; end 
                    7      : begin next_direction <= 2; end                                 
                    8, 9, 10: begin next_direction <= 2; next_tank_y <= next_tank_y + 1; end 
                    default: auto_step <= 0;
                endcase
            end
        end
    end

    // --- SYNCHRONIZACJA KLATKI (Shadow Copy) ---
    wire start_of_frame = (H_CNT == 0 && V_CNT == 0);

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            tank_x    <= SCR_W / 2;
            tank_y    <= SCR_H / 2;
            direction <= 0;
        end else if (start_of_frame) begin
            tank_x    <= next_tank_x;
            tank_y    <= next_tank_y;
            direction <= next_direction;
        end
    end

    // --- LOGIKA RYSOWANIA (KOMBINACYJNA - BEZ OPÓNIEÑ) ---
    // Obliczamy wszystko bezpoœrednio na podstawie H_CNT i V_CNT
    
    wire is_bg    = (H_CNT >= 0 && H_CNT < SCR_W) && (V_CNT >= 0 && V_CNT < SCR_H);
    wire is_frame = is_bg && (V_CNT == 0 || V_CNT == SCR_H-1 || H_CNT == 0 || H_CNT == SCR_W-1);

    wire is_tank  = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && 
                    (V_CNT >= tank_y) && (V_CNT < tank_y + TANK_H);

    reg is_pipe;
    always @(*) begin
        case (direction)
            0: is_pipe = (H_CNT == tank_x+1 && V_CNT == tank_y-1);
            1: is_pipe = (H_CNT == tank_x+3 && V_CNT == tank_y+1);
            2: is_pipe = (H_CNT == tank_x+1 && V_CNT == tank_y+3);
            3: is_pipe = (H_CNT == tank_x-1 && V_CNT == tank_y+1);
            default: is_pipe = 1'b0;
        endcase
    end

    // --- KOLORY (TYLKO JEDEN REJESTR WYJŒCIOWY) ---
    // Ten blok wprowadza tylko 1 takt opóŸnienia, co jest akceptowalne dla SimVid
    reg [7:0] r_red, r_green, r_blue;
    always @(posedge CLK) begin
        if (is_frame) begin
            r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF;
        end else if (is_tank || is_pipe) begin
            r_red <= 8'h00; r_green <= 8'hFF; r_blue <= 8'h00;
        end else if (is_bg) begin
            r_red <= 8'h00; r_green <= 8'h00; r_blue <= 8'h00;
        end else begin
            r_red <= 8'h00; r_green <= 8'h00; r_blue <= 8'h00;
        end
    end

    assign RED   = r_red;
    assign GREEN = r_green;
    assign BLUE  = r_blue;

    // --- HEARTBEAT ---
    reg [31:0] heartbeat;
    always @(posedge CLK) heartbeat <= heartbeat + 1;
    assign LED = heartbeat[26:23];

endmodule