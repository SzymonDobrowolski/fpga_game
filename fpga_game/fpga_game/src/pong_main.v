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
// G£ÓWNY MODU£ GRY - PONG TANK (Test Zniszczenia Wroga)
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
    input wire        BTN_SHOOT, 
    
    output wire [7:0] RED,
    output wire [7:0] GREEN,
    output wire [7:0] BLUE,
    
    output wire [3:0] LED
);

    // --- PARAMETRY ---
    localparam TANK_W = 3;
    localparam TANK_H = 3;
    localparam TIME_LIMIT = 5000; 

    // --- REJESTRY GRACZA ---
    reg [10:0] next_tank_x, next_tank_y, tank_x, tank_y;
    reg [1:0]  next_direction, direction;
    reg [3:0]  auto_step;

    // --- REJESTRY WROGA ---
    reg [10:0] next_enemy_x, next_enemy_y, enemy_x, enemy_y;
    reg [1:0]  next_enemy_dir, enemy_dir;
    reg        next_enemy_active, enemy_act;
    reg        enemy_moving_down;

    // --- REJESTRY POCISKU I OTOCZENIA ---
    reg [10:0] next_bullet_x, next_bullet_y, bullet_x, bullet_y;
    reg [1:0]  next_bullet_dir;
    reg        next_bullet_act, bullet_act;
    reg        wall_active;

    // --- LOGIKA CZASU ---
    reg [26:0] timer, bullet_timer;
    wire tick_sec = (timer == TIME_LIMIT);
    wire tick_bullet = (bullet_timer == TIME_LIMIT / 10); 

    always @(posedge CLK or posedge RST) begin
        if (RST) begin timer <= 0; bullet_timer <= 0; end 
        else begin
            timer <= tick_sec ? 0 : timer + 1;
            bullet_timer <= tick_bullet ? 0 : bullet_timer + 1;
        end
    end

    // --- OBLICZANIE RUCHU GRACZA ---
    wire rotate_cw, rotate_ccw;
    quad_decoder dec_rot (.clk(CLK), .a(EncA_QA), .b(EncA_QB), .step_up(rotate_cw), .step_down(rotate_ccw));

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            next_tank_x <= SCR_W / 4;
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
                    11     : begin next_direction <= 1; end 
                    default: auto_step <= 0;
                endcase
            end
        end
    end

    // --- OBLICZANIE RUCHU WROGA (ZAMRO¯ONY DLA TESTU) ---
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            next_enemy_x <= 48; // Ustawiony zaraz za murem (X: 48)
            next_enemy_y <= 20; // Idealnie w linii ognia (Y: 20)
            next_enemy_dir <= 3; // Patrzy w lewo na gracza
            enemy_moving_down <= 1;
            next_enemy_active <= 1;
        end else if (tick_sec && next_enemy_active) begin
            // Logika ruchu zakomentowana/usuniêta - czo³g stoi w miejscu!
            next_enemy_x <= next_enemy_x;
            next_enemy_y <= next_enemy_y;
        end
    end

    // --- OBLICZANIE RUCHU POCISKU I ZNISZCZEÑ ---
    wire auto_shoot_trigger = (tick_sec && auto_step == 11);
    wire fire_cmd = BTN_SHOOT || auto_shoot_trigger;

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            next_bullet_act <= 0;
            wall_active <= 1;
        end else begin
            if (fire_cmd && !next_bullet_act) begin
                next_bullet_act <= 1;
                next_bullet_dir <= direction;
                case (direction)
                    0: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y-2; end
                    1: begin next_bullet_x <= tank_x+4; next_bullet_y <= tank_y+1; end
                    2: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y+4; end
                    3: begin next_bullet_x <= tank_x-2; next_bullet_y <= tank_y+1; end
                endcase
            end 
            else if (next_bullet_act && tick_bullet) begin
                case (next_bullet_dir)
                    0: next_bullet_y <= next_bullet_y - 1;
                    1: next_bullet_x <= next_bullet_x + 1;
                    2: next_bullet_y <= next_bullet_y + 1;
                    3: next_bullet_x <= next_bullet_x - 1;
                endcase

                if (next_bullet_x <= 0 || next_bullet_x >= SCR_W-1 || next_bullet_y <= 0 || next_bullet_y >= SCR_H-1) begin
                    next_bullet_act <= 0;
                end
                else if (wall_active && next_bullet_x >= 40 && next_bullet_x <= 44 && next_bullet_y >= 10 && next_bullet_y <= 29) begin
                    next_bullet_act <= 0;
                    wall_active <= 0; 
                end
                else if (next_enemy_active && next_bullet_x >= next_enemy_x && next_bullet_x < next_enemy_x + TANK_W &&
                         next_bullet_y >= next_enemy_y && next_bullet_y < next_enemy_y + TANK_H) begin
                    next_bullet_act <= 0;
                    next_enemy_active <= 0; // Strza³ w dziesi¹tkê! Wróg zniszczony.
                end
            end
        end
    end

    // --- SYSTEM KOLIZJI GRACZA (Korpus + Lufa) ---
    reg [10:0] next_pipe_x, next_pipe_y;
    always @(*) begin
        case (next_direction)
            0: begin next_pipe_x = next_tank_x + 1; next_pipe_y = next_tank_y - 1; end
            1: begin next_pipe_x = next_tank_x + 3; next_pipe_y = next_tank_y + 1; end
            2: begin next_pipe_x = next_tank_x + 1; next_pipe_y = next_tank_y + 3; end
            3: begin next_pipe_x = next_tank_x - 1; next_pipe_y = next_tank_y + 1; end
            default: begin next_pipe_x = next_tank_x; next_pipe_y = next_tank_y; end
        endcase
    end

    wire col_frame = (next_tank_x < 1 || next_tank_x + TANK_W > SCR_W-1 || next_tank_y < 1 || next_tank_y + TANK_H > SCR_H-1);
    wire col_wall  = wall_active && (next_tank_x + TANK_W - 1 >= 40 && next_tank_x <= 44 && next_tank_y + TANK_H - 1 >= 10 && next_tank_y <= 29);
    wire col_enemy = next_enemy_active && (next_tank_x + TANK_W > next_enemy_x && next_tank_x < next_enemy_x + TANK_W &&
                                           next_tank_y + TANK_H > next_enemy_y && next_tank_y < next_enemy_y + TANK_H);

    wire pipe_col_frame = (next_pipe_x < 1 || next_pipe_x >= SCR_W-1 || next_pipe_y < 1 || next_pipe_y >= SCR_H-1);
    wire pipe_col_wall  = wall_active && (next_pipe_x >= 40 && next_pipe_x <= 44 && next_pipe_y >= 10 && next_pipe_y <= 29);
    wire pipe_col_enemy = next_enemy_active && (next_pipe_x >= next_enemy_x && next_pipe_x < next_enemy_x + TANK_W &&
                                                next_pipe_y >= next_enemy_y && next_pipe_y < next_enemy_y + TANK_H);

    wire collision = col_frame || col_wall || col_enemy || pipe_col_frame || pipe_col_wall || pipe_col_enemy;

    // --- SYNCHRONIZACJA KLATKI ---
    wire start_of_frame = (H_CNT == 0 && V_CNT == 0);

    always @(posedge CLK or posedge RST) begin
        if (start_of_frame) begin
            if (collision) begin
                next_tank_x <= tank_x;
                next_tank_y <= tank_y;
                next_direction <= direction; 
            end else begin
                tank_x <= next_tank_x;
                tank_y <= next_tank_y;
                direction <= next_direction;
            end
            
            bullet_act <= next_bullet_act; bullet_x <= next_bullet_x; bullet_y <= next_bullet_y;
            enemy_act <= next_enemy_active; enemy_x <= next_enemy_x; enemy_y <= next_enemy_y; enemy_dir <= next_enemy_dir;
        end
    end

    // --- LOGIKA RYSOWANIA (BEZ OPÓNIEÑ) ---
    wire is_bg    = (H_CNT >= 0 && H_CNT < SCR_W) && (V_CNT >= 0 && V_CNT < SCR_H);
    wire is_frame = is_bg && (V_CNT == 0 || V_CNT == SCR_H-1 || H_CNT == 0 || H_CNT == SCR_W-1);

    wire is_tank  = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && (V_CNT >= tank_y) && (V_CNT < tank_y + TANK_H);
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

    wire is_enemy_body = enemy_act && (H_CNT >= enemy_x) && (H_CNT < enemy_x + TANK_W) && (V_CNT >= enemy_y) && (V_CNT < enemy_y + TANK_H);
    reg is_enemy_pipe;
    always @(*) begin
        if (enemy_act) begin
            case (enemy_dir)
                0: is_enemy_pipe = (H_CNT == enemy_x+1 && V_CNT == enemy_y-1);
                1: is_enemy_pipe = (H_CNT == enemy_x+3 && V_CNT == enemy_y+1);
                2: is_enemy_pipe = (H_CNT == enemy_x+1 && V_CNT == enemy_y+3);
                3: is_enemy_pipe = (H_CNT == enemy_x-1 && V_CNT == enemy_y+1);
            endcase
        end else is_enemy_pipe = 1'b0;
    end
    wire is_enemy = is_enemy_body || is_enemy_pipe;

    wire is_wall   = wall_active && (H_CNT >= 40 && H_CNT <= 44 && V_CNT >= 10 && V_CNT <= 29);
    wire is_bullet = bullet_act && (H_CNT == bullet_x && V_CNT == bullet_y);

    // --- KOLORY ---
    reg [7:0] r_red, r_green, r_blue;
    always @(posedge CLK) begin
        if (is_frame) begin
            r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF;
        end else if (is_wall) begin
            r_red <= 8'h00; r_green <= 8'hA0; r_blue <= 8'hFF; 
        end else if (is_bullet) begin
            r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'h00; 
        end else if (is_enemy) begin
            r_red <= 8'hFF; r_green <= 8'h00; r_blue <= 8'h00; 
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

    reg [31:0] heartbeat;
    always @(posedge CLK) heartbeat <= heartbeat + 1;
    assign LED = heartbeat[26:23];

endmodule