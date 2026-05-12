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
    input wire        EncA_QA, EncA_QB,
    input wire        EncB_QA, EncB_QB,
    input wire        BTN_SHOOT, 
    
    output wire [7:0] RED, GREEN, BLUE,
    output wire [3:0] LED
);

    localparam TANK_W = 3;
    localparam TANK_H = 3;
    localparam TIME_LIMIT = 5000; 
    
    localparam STATE_START    = 2'b00;
    localparam STATE_PLAY     = 2'b01;
    localparam STATE_GAMEOVER = 2'b10;

    // --- REJESTRY GRY ---
    reg [1:0]  state;
    reg [1:0]  lives;
    reg [3:0]  score_tens, score_ones;

    reg [10:0] tank_x, tank_y, next_tank_x, next_tank_y;
    reg [1:0]  direction, next_direction;
    reg [3:0]  auto_step;

    reg [10:0] enemy_x, enemy_y, next_enemy_x, next_enemy_y;
    reg [1:0]  enemy_dir, next_enemy_dir;
    reg [3:0]  enemy_step;
    
    reg [10:0] bullet_x, bullet_y, next_bullet_x, next_bullet_y;
    reg [1:0]  next_bullet_dir;
    reg        bullet_act, next_bullet_act;
    
    reg [10:0] e_bullet_x, e_bullet_y, next_e_bullet_x, next_e_bullet_y;
    reg [1:0]  next_e_bullet_dir;
    reg        e_bullet_act, next_e_bullet_act;
    
    reg        wall_active;
    reg        enemy_alive; // Flaga ¿ycia wroga (1 = ¿yje, 0 = permanentna œmieræ)
    reg [15:0] lfsr; 

    // Sygna³ komunikacyjny dla respawnu gracza
    reg trigger_p_respawn;

    // --- ZEGARY ---
    reg [26:0] timer, bullet_timer;
    wire tick_sec = (timer == TIME_LIMIT);
    wire tick_bullet = (bullet_timer == TIME_LIMIT / 10); 
    wire start_of_frame = (H_CNT == 0 && V_CNT == 0);

    always @(posedge CLK) begin
        if (RST) lfsr <= 16'hACE1;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin timer <= 0; bullet_timer <= 0; end 
        else if (state == STATE_PLAY) begin
            timer <= tick_sec ? 0 : timer + 1;
            bullet_timer <= tick_bullet ? 0 : bullet_timer + 1;
        end
    end

    // --- SYSTEM KOLIZJI ---
    // Gracz
    reg [10:0] p_pipe_x, p_pipe_y;
    always @(*) begin
        case (next_direction)
            0: begin p_pipe_x = next_tank_x + 11'd1; p_pipe_y = next_tank_y - 11'd1; end
            1: begin p_pipe_x = next_tank_x + 11'd3; p_pipe_y = next_tank_y + 11'd1; end
            2: begin p_pipe_x = next_tank_x + 11'd1; p_pipe_y = next_tank_y + 11'd3; end
            3: begin p_pipe_x = next_tank_x - 11'd1; p_pipe_y = next_tank_y + 11'd1; end
            default: begin p_pipe_x = next_tank_x; p_pipe_y = next_tank_y; end
        endcase
    end
    
    wire col_frame = (next_tank_x < 1 || next_tank_x + TANK_W > SCR_W-1 || next_tank_y < 9 || next_tank_y + TANK_H > SCR_H-1);
    wire col_wall  = wall_active && (next_tank_x + TANK_W - 1 >= 40 && next_tank_x <= 44 && next_tank_y + TANK_H - 1 >= 10 && next_tank_y <= 29);
    wire col_enemy = enemy_alive && (next_tank_x + TANK_W > next_enemy_x && next_tank_x < next_enemy_x + TANK_W && next_tank_y + TANK_H > next_enemy_y && next_tank_y < next_enemy_y + TANK_H);
    
    wire p_col_frame = (p_pipe_x < 1 || p_pipe_x >= SCR_W-1 || p_pipe_y < 9 || p_pipe_y >= SCR_H-1);
    wire p_col_wall  = wall_active && (p_pipe_x >= 40 && p_pipe_x <= 44 && p_pipe_y >= 10 && p_pipe_y <= 29);
    
    wire collision = col_frame || col_wall || col_enemy || p_col_frame || p_col_wall;

    // Wróg
    reg [10:0] e_pipe_x, e_pipe_y;
    always @(*) begin
        case (next_enemy_dir)
            0: begin e_pipe_x = next_enemy_x + 11'd1; e_pipe_y = next_enemy_y - 11'd1; end
            1: begin e_pipe_x = next_enemy_x + 11'd3; e_pipe_y = next_enemy_y + 11'd1; end
            2: begin e_pipe_x = next_enemy_x + 11'd1; e_pipe_y = next_enemy_y + 11'd3; end
            3: begin e_pipe_x = next_enemy_x - 11'd1; e_pipe_y = next_enemy_y + 11'd1; end
            default: begin e_pipe_x = next_enemy_x; e_pipe_y = next_enemy_y; end
        endcase
    end
    
    wire e_col_frame = (next_enemy_x < 1 || next_enemy_x + TANK_W > SCR_W-1 || next_enemy_y < 9 || next_enemy_y + TANK_H > SCR_H-1);
    wire e_col_wall  = wall_active && (next_enemy_x + TANK_W - 1 >= 40 && next_enemy_x <= 44 && next_enemy_y + TANK_H - 1 >= 10 && next_enemy_y <= 29);
    wire ep_col_frame = (e_pipe_x < 1 || e_pipe_x >= SCR_W-1 || e_pipe_y < 9 || e_pipe_y >= SCR_H-1);
    wire ep_col_wall  = wall_active && (e_pipe_x >= 40 && e_pipe_x <= 44 && e_pipe_y >= 10 && e_pipe_y <= 29);
    
    wire enemy_collision = e_col_frame || e_col_wall || col_enemy || ep_col_frame || ep_col_wall;

    // --- STEROWANIE ---
    wire rotate_cw, rotate_ccw;
    quad_decoder dec_rot (.clk(CLK), .a(EncA_QA), .b(EncA_QB), .step_up(rotate_cw), .step_down(rotate_ccw));
    wire auto_shoot_trigger = (tick_sec && auto_step == 11);
    wire fire_cmd = (BTN_SHOOT || auto_shoot_trigger);
    wire enemy_fire_cmd = (tick_sec && enemy_alive && (lfsr[4:2] == 3'b111)); 

    // --- FSM & POCISKI ---
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            state <= STATE_START; lives <= 3; score_tens <= 0; score_ones <= 0;
            wall_active <= 1; enemy_alive <= 1; next_bullet_act <= 0; next_e_bullet_act <= 0;
            trigger_p_respawn <= 0;
        end else begin
            trigger_p_respawn <= 0;

            case (state)
                STATE_START: begin
                    lives <= 3; score_tens <= 0; score_ones <= 0; 
                    wall_active <= 1; enemy_alive <= 1;
                    if (BTN_SHOOT) state <= STATE_PLAY;
                end
                STATE_GAMEOVER: begin
                    if (BTN_SHOOT) state <= STATE_START;
                end
                STATE_PLAY: begin
                    // Pocisk Gracza
                    if (fire_cmd && !next_bullet_act) begin
                        next_bullet_act <= 1; next_bullet_dir <= direction;
                        case (direction)
                            0: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y-2; end
                            1: begin next_bullet_x <= tank_x+4; next_bullet_y <= tank_y+1; end
                            2: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y+4; end
                            3: begin next_bullet_x <= tank_x-2; next_bullet_y <= tank_y+1; end
                        endcase
                    end else if (next_bullet_act && tick_bullet) begin
                        case (next_bullet_dir)
                            0: next_bullet_y <= next_bullet_y - 1; 1: next_bullet_x <= next_bullet_x + 1;
                            2: next_bullet_y <= next_bullet_y + 1; 3: next_bullet_x <= next_bullet_x - 1;
                        endcase

                        if (next_bullet_x <= 0 || next_bullet_x >= SCR_W-1 || next_bullet_y <= 8 || next_bullet_y >= SCR_H-1) 
                            next_bullet_act <= 0;
                        else if (wall_active && next_bullet_x >= 40 && next_bullet_x <= 44 && next_bullet_y >= 10 && next_bullet_y <= 29) begin
                            next_bullet_act <= 0; wall_active <= 0; 
                        end else if (enemy_alive && next_bullet_x >= next_enemy_x && next_bullet_x < next_enemy_x + TANK_W &&
                                     next_bullet_y >= next_enemy_y && next_bullet_y < next_enemy_y + TANK_H) begin
                            // TRAFIENIE WROGA -> PERMANENTNA ŒMIERÆ + PUNKTY
                            next_bullet_act <= 0; 
                            enemy_alive <= 0; 
                            if (score_ones == 9) begin score_ones <= 0; score_tens <= score_tens + 1; end 
                            else score_ones <= score_ones + 1;
                        end
                    end

                    // Pocisk Wroga
                    if (enemy_fire_cmd && !next_e_bullet_act) begin
                        next_e_bullet_act <= 1; next_e_bullet_dir <= enemy_dir;
                        case (enemy_dir)
                            0: begin next_e_bullet_x <= enemy_x+1; next_e_bullet_y <= enemy_y-2; end
                            1: begin next_e_bullet_x <= enemy_x+4; next_e_bullet_y <= enemy_y+1; end
                            2: begin next_e_bullet_x <= enemy_x+1; next_e_bullet_y <= enemy_y+4; end
                            3: begin next_e_bullet_x <= enemy_x-2; next_e_bullet_y <= enemy_y+1; end
                        endcase
                    end else if (next_e_bullet_act && tick_bullet) begin
                        case (next_e_bullet_dir)
                            0: next_e_bullet_y <= next_e_bullet_y - 1; 1: next_e_bullet_x <= next_e_bullet_x + 1;
                            2: next_e_bullet_y <= next_e_bullet_y + 1; 3: next_e_bullet_x <= next_e_bullet_x - 1;
                        endcase

                        if (next_e_bullet_x <= 0 || next_e_bullet_x >= SCR_W-1 || next_e_bullet_y <= 8 || next_e_bullet_y >= SCR_H-1) 
                            next_e_bullet_act <= 0;
                        else if (wall_active && next_e_bullet_x >= 40 && next_e_bullet_x <= 44 && next_e_bullet_y >= 10 && next_e_bullet_y <= 29) begin
                            next_e_bullet_act <= 0; wall_active <= 0; 
                        end else if (next_e_bullet_x >= next_tank_x && next_e_bullet_x < next_tank_x + TANK_W &&
                                     next_e_bullet_y >= next_tank_y && next_e_bullet_y < next_tank_y + TANK_H) begin
                            // TRAFIENIE GRACZA -> UTRATA ¯YCIA + RESPAWN GRACZA
                            next_e_bullet_act <= 0; 
                            trigger_p_respawn <= 1; 
                            if (lives > 1) lives <= lives - 1;
                            else begin lives <= 0; state <= STATE_GAMEOVER; end
                        end
                    end
                end
            endcase
        end
    end

    // --- RUCH GRACZA ---
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            tank_x <= 10; next_tank_x <= 10; tank_y <= 20; next_tank_y <= 20; direction <= 1; next_direction <= 1; auto_step <= 0;
        end else if (state == STATE_START || trigger_p_respawn) begin
            tank_x <= 10; next_tank_x <= 10; tank_y <= 20; next_tank_y <= 20; direction <= 1; next_direction <= 1; auto_step <= 0;
        end else if (state == STATE_PLAY) begin
            if (rotate_cw)  next_direction <= next_direction + 1;
            if (rotate_ccw) next_direction <= next_direction - 1;
            
            if (tick_sec) begin
                auto_step <= auto_step + 1;
                case (auto_step)
                    // Zabezpieczenie z przywróceniem prawid³owych kierunków dla lufy!
                    0, 1, 2: begin next_tank_y <= next_tank_y - 1; next_direction <= 0; end
                    3      : begin next_direction <= 1; end
                    4, 5, 6: begin next_tank_x <= next_tank_x + 1; next_direction <= 1; end
                    7      : begin next_direction <= 2; end
                    8, 9, 10: begin next_tank_y <= next_tank_y + 1; next_direction <= 2; end
                    11     : begin next_direction <= 1; end
                    default: auto_step <= 0;
                endcase
            end
            
            if (start_of_frame) begin
                if (collision) begin next_tank_x <= tank_x; next_tank_y <= tank_y; next_direction <= direction; end
                else begin tank_x <= next_tank_x; tank_y <= next_tank_y; direction <= next_direction; end
            end
        end
    end

    // --- RUCH WROGA ---
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            enemy_x <= 48; next_enemy_x <= 48; enemy_y <= 20; next_enemy_y <= 20; enemy_dir <= 3; next_enemy_dir <= 3; enemy_step <= 0;
        end else if (state == STATE_START) begin
            enemy_x <= 48; next_enemy_x <= 48; enemy_y <= 20; next_enemy_y <= 20; enemy_dir <= 3; next_enemy_dir <= 3; enemy_step <= 0;
        end else if (state == STATE_PLAY && enemy_alive) begin
            if (tick_sec) begin
                if (enemy_step == 0) begin
                    next_enemy_dir <= lfsr[1:0]; enemy_step <= lfsr[4:2] + 4'd3;
                end else begin
                    case (next_enemy_dir)
                        0: next_enemy_y <= next_enemy_y - 1; 1: next_enemy_x <= next_enemy_x + 1;
                        2: next_enemy_y <= next_enemy_y + 1; 3: next_enemy_x <= next_enemy_x - 1;
                    endcase
                    enemy_step <= enemy_step - 1;
                end
            end
            if (start_of_frame) begin
                if (enemy_collision) begin next_enemy_x <= enemy_x; next_enemy_y <= enemy_y; next_enemy_dir <= enemy_dir; enemy_step <= 0; end
                else begin enemy_x <= next_enemy_x; enemy_y <= next_enemy_y; enemy_dir <= next_enemy_dir; end
            end
        end
    end

    // --- SHADOW REGISTERS POCISKÓW I STANÓW RYSOWANIA ---
    reg enemy_act;
    always @(posedge CLK) begin
        if (start_of_frame) begin
            bullet_act <= next_bullet_act; bullet_x <= next_bullet_x; bullet_y <= next_bullet_y;
            e_bullet_act <= next_e_bullet_act; e_bullet_x <= next_e_bullet_x; e_bullet_y <= next_e_bullet_y;
            enemy_act <= enemy_alive;
        end
    end

    // --- CZYTANIE CZCIONKI ---
    function get_font_pixel;
        input [3:0] digit;
        input [10:0] cx;
        input [10:0] cy;
        reg [14:0] bitmap;
        begin
            case (digit)
                0: bitmap = 15'b111_101_101_101_111;
                1: bitmap = 15'b010_110_010_010_111;
                2: bitmap = 15'b111_001_111_100_111;
                3: bitmap = 15'b111_001_111_001_111;
                4: bitmap = 15'b101_101_111_001_001;
                5: bitmap = 15'b111_100_111_001_111;
                6: bitmap = 15'b111_100_111_101_111;
                7: bitmap = 15'b111_001_001_010_010;
                8: bitmap = 15'b111_101_111_101_111;
                9: bitmap = 15'b111_101_111_001_111;
                default: bitmap = 15'b0;
            endcase
            get_font_pixel = (bitmap >> (14 - (cy * 3 + cx))) & 1'b1;
        end
    endfunction

    // --- RYSOWANIE HUD ---
    wire is_score_tens = (H_CNT >= 50 && H_CNT <= 52 && V_CNT >= 2 && V_CNT <= 6) ? get_font_pixel(score_tens, H_CNT - 50, V_CNT - 2) : 1'b0;
    wire is_score_ones = (H_CNT >= 54 && H_CNT <= 56 && V_CNT >= 2 && V_CNT <= 6) ? get_font_pixel(score_ones, H_CNT - 54, V_CNT - 2) : 1'b0;
    wire is_score = is_score_tens || is_score_ones;

    wire is_h1 = (lives >= 1) && ((V_CNT == 2 && (H_CNT == 3 || H_CNT == 5)) || (V_CNT == 3 && (H_CNT >= 3 && H_CNT <= 5)) || (V_CNT == 4 && H_CNT == 4));
    wire is_h2 = (lives >= 2) && ((V_CNT == 2 && (H_CNT == 7 || H_CNT == 9)) || (V_CNT == 3 && (H_CNT >= 7 && H_CNT <= 9)) || (V_CNT == 4 && H_CNT == 8));
    wire is_h3 = (lives >= 3) && ((V_CNT == 2 && (H_CNT == 11|| H_CNT == 13))|| (V_CNT == 3 && (H_CNT >= 11&& H_CNT <= 13))|| (V_CNT == 4 && H_CNT == 12));
    wire is_hearts = is_h1 || is_h2 || is_h3;

    // --- LOGIKA RYSOWANIA OBIEKTÓW ---
    wire is_bg    = (H_CNT >= 0 && H_CNT < SCR_W) && (V_CNT >= 0 && V_CNT < SCR_H);
    wire is_frame = is_bg && (V_CNT == 8 || V_CNT == SCR_H-1 || H_CNT == 0 || H_CNT == SCR_W-1);

    wire is_tank  = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && (V_CNT >= tank_y) && (V_CNT < tank_y + TANK_H);
    reg is_pipe;
    always @(*) begin
        case (direction)
            0: is_pipe = (H_CNT == tank_x + 11'd1) && (V_CNT + 11'd1 == tank_y);
            1: is_pipe = (H_CNT == tank_x + 11'd3) && (V_CNT == tank_y + 11'd1);
            2: is_pipe = (H_CNT == tank_x + 11'd1) && (V_CNT == tank_y + 11'd3);
            3: is_pipe = (H_CNT + 11'd1 == tank_x) && (V_CNT == tank_y + 11'd1);
        endcase
    end

    wire is_enemy_body = enemy_act && (H_CNT >= enemy_x) && (H_CNT < enemy_x + TANK_W) && (V_CNT >= enemy_y) && (V_CNT < enemy_y + TANK_H);
    reg is_enemy_pipe;
    always @(*) begin
        if (enemy_act) begin
            case (enemy_dir)
                0: is_enemy_pipe = (H_CNT == enemy_x + 11'd1) && (V_CNT + 11'd1 == enemy_y);
                1: is_enemy_pipe = (H_CNT == enemy_x + 11'd3) && (V_CNT == enemy_y + 11'd1);
                2: is_enemy_pipe = (H_CNT == enemy_x + 11'd1) && (V_CNT == enemy_y + 11'd3);
                3: is_enemy_pipe = (H_CNT + 11'd1 == enemy_x) && (V_CNT == enemy_y + 11'd1);
            endcase
        end else is_enemy_pipe = 1'b0;
    end
    wire is_enemy = is_enemy_body || is_enemy_pipe;

    wire is_wall   = wall_active && (H_CNT >= 40 && H_CNT <= 44 && V_CNT >= 10 && V_CNT <= 29);
    wire is_bullet = bullet_act && (H_CNT == bullet_x && V_CNT == bullet_y);
    wire is_e_bullet = e_bullet_act && (H_CNT == e_bullet_x && V_CNT == e_bullet_y);

    // --- KOLORY ---
    reg [7:0] r_red, r_green, r_blue;
    always @(posedge CLK) begin
        if (state == STATE_GAMEOVER) begin
            if (is_frame) begin r_red <= 8'hFF; r_green <= 8'h00; r_blue <= 8'h00; end
            else if (is_score) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF; end 
            else begin r_red <= 8'h40; r_green <= 8'h00; r_blue <= 8'h00; end 
        end 
        else if (state == STATE_START) begin
            if (is_frame) begin 
                r_red <= timer[24] ? 8'hFF : 8'h00; 
                r_green <= timer[24] ? 8'hFF : 8'h00; 
                r_blue <= timer[24] ? 8'hFF : 8'h00; 
            end
            else begin r_red <= 8'h00; r_green <= 8'h00; r_blue <= 8'h00; end
        end
        else begin 
            if (is_frame) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF; end
            else if (is_score) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'h00; end 
            else if (is_hearts) begin r_red <= 8'hFF; r_green <= 8'h00; r_blue <= 8'h00; end 
            else if (is_wall) begin r_red <= 8'h00; r_green <= 8'hA0; r_blue <= 8'hFF; end 
            else if (is_bullet) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'h00; end 
            else if (is_e_bullet) begin r_red <= 8'hFF; r_green <= 8'h80; r_blue <= 8'h00; end 
            else if (is_enemy) begin r_red <= 8'hFF; r_green <= 8'h00; r_blue <= 8'h00; end 
            else if (is_tank || is_pipe) begin r_red <= 8'h00; r_green <= 8'hFF; r_blue <= 8'h00; end 
            else if (is_bg) begin r_red <= 8'h00; r_green <= 8'h00; r_blue <= 8'h00; end
            else begin r_red <= 8'h00; r_green <= 8'h00; r_blue <= 8'h00; end
        end
    end

    assign RED = r_red; assign GREEN = r_green; assign BLUE = r_blue;

    assign LED = (lives == 3) ? 4'b0111 :
                 (lives == 2) ? 4'b0011 :
                 (lives == 1) ? 4'b0001 : 4'b0000;

endmodule