// =============================================================================
// MODU� DEKODERA ENKODERA KWADRATUROWEGO
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
        a_delayed <= a; b_delayed <= b;
        step_up   <= (a ^ b_delayed) && (a != a_delayed);   
        step_down <= (a ^ b_delayed) == 0 && (a != a_delayed); 
    end
endmodule

// =============================================================================
// G��WNY MODU� GRY - PONG TANK (FPGA LITE VERSION)
// =============================================================================
module pong_main
#(
    parameter SCR_W = 60,
    parameter SCR_H = 40,
    parameter SIM_MODE = 0  // 0 = SPRZ�T
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

    localparam TANK_W = 3, TANK_H = 3; 
    localparam TIME_LIMIT = SIM_MODE ? 5000 : 1250000; 
    localparam DEMO_WAIT  = SIM_MODE ? 150000 : 750000000; 
    
    localparam STATE_START       = 3'd0;
    localparam STATE_LOAD_LEVEL  = 3'd1;
    localparam STATE_PLAY        = 3'd2;
    localparam STATE_LEVEL_CLEAR = 3'd3;
    localparam STATE_GAMEOVER    = 3'd4;
    localparam STATE_GAME_CLEAR  = 3'd5;

    reg [2:0]  state;
    reg [1:0]  lives;
    reg [3:0]  score_tens, score_ones;
    reg [1:0]  current_level;
    reg [2:0]  current_wave;
    reg [2:0]  enemies_killed;
    
    reg        demo_mode;
    reg [31:0] idle_timer;

    reg [10:0] tank_x, tank_y, next_tank_x, next_tank_y;
    reg [1:0]  direction, next_direction;
    reg [3:0]  p_step; 

    // Ograniczenie do 2 wrog�w na ekranie dla FPGA
    reg [10:0] enemy_x [0:1], next_enemy_x [0:1], enemy_y [0:1], next_enemy_y [0:1];
    reg [1:0]  enemy_dir [0:1], next_enemy_dir [0:1];
    reg [3:0]  enemy_step [0:1];
    reg [1:0]  enemy_alive;
    
    reg [10:0] bullet_x, bullet_y, next_bullet_x, next_bullet_y;
    reg [1:0]  next_bullet_dir;
    reg        bullet_act, next_bullet_act;
    
    reg [10:0] e_bullet_x, e_bullet_y, next_e_bullet_x, next_e_bullet_y;
    reg [1:0]  next_e_bullet_dir;
    reg        e_bullet_act, next_e_bullet_act;
    
    reg [15:0] lfsr; 
    reg trigger_p_respawn, trigger_wave_spawn;
    integer i;

    reg [26:0] timer, bullet_timer;
    reg [31:0] heartbeat; 
    
    wire tick_sec = (timer >= TIME_LIMIT);
    wire tick_bullet = (bullet_timer >= (TIME_LIMIT / 10)); 
    wire start_of_frame = (H_CNT == 0 && V_CNT == 0);

    always @(posedge CLK) begin
        if (RST) begin
            lfsr <= 16'hACE1; heartbeat <= 0; timer <= 0; bullet_timer <= 0;
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            heartbeat <= heartbeat + 1;
            timer <= tick_sec ? 0 : timer + 1;
            bullet_timer <= tick_bullet ? 0 : bullet_timer + 1;
        end
    end

    // --- WIRTUALNA MAPA ---
    function is_wall_func;
        input [1:0] lvl; input [10:0] x; input [10:0] y;
        begin
            is_wall_func = 1'b0;
            if (y >= 9 && y < SCR_H && x < SCR_W) begin
                case (lvl)
                    1: begin
                        if ((y >= 10 && y <= 38) && (x == 29 || x == 30) && (y < 18 || y > 28)) is_wall_func = 1'b1;
                        if ((y >= 16 && y <= 24) && (x == 16 || x == 43)) is_wall_func = 1'b1;
                        if ((x >= 16 && x <= 21) && (y == 16 || y == 24)) is_wall_func = 1'b1;
                        if ((x >= 39 && x <= 44) && (y == 16 || y == 24)) is_wall_func = 1'b1;
                    end
                    2: begin
                        if ((x >= 15 && x <= 45) && y == 20 && (x < 25 || x > 35)) is_wall_func = 1'b1;
                        if ((y >= 10 && y <= 35) && x == 30 && (y < 18 || y > 22)) is_wall_func = 1'b1;
                    end
                    3: begin
                        if ((y >= 12 && y <= 28) && (x == 20 || x == 40)) is_wall_func = 1'b1;
                        if ((x >= 20 && x <= 40) && (y == 12 || y == 27)) is_wall_func = 1'b1;
                    end
                endcase
            end
        end
    endfunction

    reg [10:0] b_look_x, b_look_y, eb_look_x, eb_look_y;
    always @(*) begin
        case (next_bullet_dir)
            0: begin b_look_x = next_bullet_x; b_look_y = next_bullet_y - 1; end
            1: begin b_look_x = next_bullet_x + 1; b_look_y = next_bullet_y; end
            2: begin b_look_x = next_bullet_x; b_look_y = next_bullet_y + 1; end
            3: begin b_look_x = next_bullet_x - 1; b_look_y = next_bullet_y; end
        endcase
        case (next_e_bullet_dir)
            0: begin eb_look_x = next_e_bullet_x; eb_look_y = next_e_bullet_y - 1; end
            1: begin eb_look_x = next_e_bullet_x + 1; eb_look_y = next_e_bullet_y; end
            2: begin eb_look_x = next_e_bullet_x; eb_look_y = next_e_bullet_y + 1; end
            3: begin eb_look_x = next_e_bullet_x - 1; eb_look_y = next_e_bullet_y; end
        endcase
    end

    wire rotate_cw, rotate_ccw;
    quad_decoder dec_rot (.clk(CLK), .a(EncA_QA), .b(EncA_QB), .step_up(rotate_cw), .step_down(rotate_ccw));
    wire fire_cmd = demo_mode ? (tick_sec && (lfsr[11:9] == 3'b111)) : BTN_SHOOT;

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
    wire p_col_frame = (p_pipe_x < 1 || p_pipe_x >= SCR_W-1 || p_pipe_y < 9 || p_pipe_y >= SCR_H-1);
    wire col_wall = is_wall_func(current_level, next_tank_x, next_tank_y) | is_wall_func(current_level, next_tank_x+2, next_tank_y) |
                    is_wall_func(current_level, next_tank_x, next_tank_y+2) | is_wall_func(current_level, next_tank_x+2, next_tank_y+2);
    wire p_col_wall = is_wall_func(current_level, p_pipe_x, p_pipe_y);
    wire collision = col_frame || col_wall || p_col_frame || p_col_wall;

    reg enemy_collision [0:1];
    reg [10:0] ex, ey, epx, epy;
    reg ec_f, ec_w, epc_f, epc_w, ec_p;
    integer e_i;
    
    always @(*) begin
        for (e_i=0; e_i<2; e_i=e_i+1) begin
            enemy_collision[e_i] = 0;
            if (enemy_alive[e_i]) begin
                ex = next_enemy_x[e_i]; ey = next_enemy_y[e_i];
                case (next_enemy_dir[e_i])
                    0: begin epx = ex + 11'd1; epy = ey - 11'd1; end
                    1: begin epx = ex + 11'd3; epy = ey + 11'd1; end
                    2: begin epx = ex + 11'd1; epy = ey + 11'd3; end
                    3: begin epx = ex - 11'd1; epy = ey + 11'd1; end
                    default: begin epx = ex; epy = ey; end
                endcase
                
                ec_f = (ex < 1 || ex + TANK_W > SCR_W-1 || ey < 9 || ey + TANK_H > SCR_H-1);
                epc_f = (epx < 1 || epx >= SCR_W-1 || epy < 9 || epy >= SCR_H-1);
                ec_p = (ex + TANK_W > next_tank_x && ex < next_tank_x + TANK_W && ey + TANK_H > next_tank_y && ey < next_tank_y + TANK_H);
                ec_w = is_wall_func(current_level, ex, ey) | is_wall_func(current_level, ex+2, ey) |
                       is_wall_func(current_level, ex, ey+2) | is_wall_func(current_level, ex+2, ey+2);
                epc_w = is_wall_func(current_level, epx, epy);
                
                enemy_collision[e_i] = ec_f | epc_f | ec_w | epc_w | ec_p;
            end
        end
    end

    reg [1:0] enemy_hit_flag;
    reg enemy_fired;
    
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            state <= STATE_START; lives <= 3; score_tens <= 0; score_ones <= 0;
            current_level <= 1; current_wave <= 1; enemies_killed <= 0;
            enemy_alive <= 0; next_bullet_act <= 0; next_e_bullet_act <= 0;
            trigger_p_respawn <= 0; trigger_wave_spawn <= 0; idle_timer <= 0; demo_mode <= 0;
        end else begin
            trigger_p_respawn <= 0; trigger_wave_spawn <= 0;

            if (demo_mode && (BTN_SHOOT || rotate_cw || rotate_ccw)) begin
                demo_mode <= 0; state <= STATE_START;
            end

            case (state)
                STATE_START: begin
                    lives <= 3; score_tens <= 0; score_ones <= 0; current_level <= 1; demo_mode <= 0;
                    if (BTN_SHOOT || rotate_cw || rotate_ccw) begin
                        state <= STATE_LOAD_LEVEL; idle_timer <= 0;
                    end else begin
                        idle_timer <= idle_timer + 1;
                        if (idle_timer >= DEMO_WAIT) begin demo_mode <= 1; state <= STATE_LOAD_LEVEL; idle_timer <= 0; end
                    end
                end
                
                STATE_GAMEOVER, STATE_GAME_CLEAR: begin
                    if (demo_mode) begin state <= STATE_START; end else if (BTN_SHOOT) state <= STATE_START;
                end
                
                STATE_LEVEL_CLEAR: begin
                    if (demo_mode || BTN_SHOOT) begin
                        if (current_level == 3) state <= STATE_GAME_CLEAR;
                        else begin current_level <= current_level + 1; state <= STATE_LOAD_LEVEL; end
                    end
                end

                STATE_LOAD_LEVEL: begin
                    current_wave <= 1; enemies_killed <= 0; enemy_alive <= 2'b01;
                    trigger_wave_spawn <= 1; state <= STATE_PLAY;
                end
                
                STATE_PLAY: begin
                    if (enemies_killed >= current_wave) begin
                        if (current_wave == 4) state <= STATE_LEVEL_CLEAR;
                        else begin
                            current_wave <= current_wave + 1; enemies_killed <= 0; trigger_wave_spawn <= 1;
                            enemy_alive <= 2'b11; 
                        end
                    end

                    if (fire_cmd && !next_bullet_act) begin
                        next_bullet_act <= 1; next_bullet_dir <= direction;
                        case (direction)
                            0: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y-2; end
                            1: begin next_bullet_x <= tank_x+4; next_bullet_y <= tank_y+1; end
                            2: begin next_bullet_x <= tank_x+1; next_bullet_y <= tank_y+4; end
                            3: begin next_bullet_x <= tank_x-2; next_bullet_y <= tank_y+1; end
                        endcase
                    end else if (next_bullet_act && tick_bullet) begin
                        if (b_look_x <= 0 || b_look_x >= SCR_W-1 || b_look_y <= 8 || b_look_y >= SCR_H-1) next_bullet_act <= 0;
                        else if (is_wall_func(current_level, b_look_x, b_look_y)) next_bullet_act <= 0; 
                        else begin
                            enemy_hit_flag = 2'b00;
                            for (i=0; i<2; i=i+1) begin
                                if (enemy_alive[i] && b_look_x >= enemy_x[i] && b_look_x < enemy_x[i]+TANK_W && b_look_y >= enemy_y[i] && b_look_y < enemy_y[i]+TANK_H)
                                    enemy_hit_flag[i] = 1;
                            end
                            if (enemy_hit_flag != 0) begin
                                next_bullet_act <= 0; enemies_killed <= enemies_killed + 1;
                                if (score_ones == 9) begin score_ones <= 0; score_tens <= score_tens + 1; end else score_ones <= score_ones + 1;
                                if (enemy_hit_flag[0]) enemy_alive[0] <= 0; else if (enemy_hit_flag[1]) enemy_alive[1] <= 0;
                            end else begin next_bullet_x <= b_look_x; next_bullet_y <= b_look_y; end
                        end
                    end

                    enemy_fired = 0;
                    if (!next_e_bullet_act && tick_sec) begin
                        for (i=0; i<2; i=i+1) begin
                            if (enemy_alive[i] && !enemy_fired && ((lfsr[4:2] ^ i[1:0]) == 3'b111)) begin
                                next_e_bullet_act <= 1; next_e_bullet_dir <= enemy_dir[i]; enemy_fired = 1;
                                case (enemy_dir[i])
                                    0: begin next_e_bullet_x <= enemy_x[i]+1; next_e_bullet_y <= enemy_y[i]-2; end
                                    1: begin next_e_bullet_x <= enemy_x[i]+4; next_e_bullet_y <= enemy_y[i]+1; end
                                    2: begin next_e_bullet_x <= enemy_x[i]+1; next_e_bullet_y <= enemy_y[i]+4; end
                                    3: begin next_e_bullet_x <= enemy_x[i]-2; next_e_bullet_y <= enemy_y[i]+1; end
                                endcase
                            end
                        end
                    end else if (next_e_bullet_act && tick_bullet) begin
                        if (eb_look_x <= 0 || eb_look_x >= SCR_W-1 || eb_look_y <= 8 || eb_look_y >= SCR_H-1) next_e_bullet_act <= 0;
                        else if (is_wall_func(current_level, eb_look_x, eb_look_y)) next_e_bullet_act <= 0; 
                        else if (eb_look_x >= tank_x && eb_look_x < tank_x+TANK_W && eb_look_y >= tank_y && eb_look_y < tank_y+TANK_H) begin
                            next_e_bullet_act <= 0; trigger_p_respawn <= 1; 
                            if (lives > 1) lives <= lives - 1; else begin lives <= 0; state <= STATE_GAMEOVER; end
                        end else begin next_e_bullet_x <= eb_look_x; next_e_bullet_y <= eb_look_y; end
                    end
                end
            endcase
        end
    end

    always @(posedge CLK) begin
        if (state == STATE_START || trigger_p_respawn || trigger_wave_spawn) begin
            tank_x <= 10; next_tank_x <= 10; tank_y <= 20; next_tank_y <= 20; direction <= 1; next_direction <= 1; p_step <= 0;
        end else if (state == STATE_PLAY) begin
            if (demo_mode) begin
                if (tick_sec) begin
                    if (p_step == 0) begin next_direction <= lfsr[7:6]; p_step <= lfsr[12:10] + 2; end 
                    else begin
                        case (next_direction)
                            0: next_tank_y <= next_tank_y - 1; 1: next_tank_x <= next_tank_x + 1;
                            2: next_tank_y <= next_tank_y + 1; 3: next_tank_x <= next_tank_x - 1;
                        endcase
                        p_step <= p_step - 1;
                    end
                end
            end else begin
                if (rotate_cw)  next_direction <= next_direction + 1;
                if (rotate_ccw) next_direction <= next_direction - 1;
                if (tick_sec) begin
                    case (direction)
                        0: next_tank_y <= next_tank_y - 1; 1: next_tank_x <= next_tank_x + 1;
                        2: next_tank_y <= next_tank_y + 1; 3: next_tank_x <= next_tank_x - 1;
                    endcase
                end
            end
            if (start_of_frame) begin
                if (collision) begin 
                    next_tank_x <= tank_x; next_tank_y <= tank_y; next_direction <= direction; 
                    if (demo_mode) p_step <= 0; 
                end else begin tank_x <= next_tank_x; tank_y <= next_tank_y; direction <= next_direction; end
            end
        end
    end

    always @(posedge CLK) begin
        if (state == STATE_START || trigger_wave_spawn) begin
            for (i=0; i<2; i=i+1) begin
                enemy_x[i] <= 48; next_enemy_x[i] <= 48; enemy_y[i] <= 12+(i*10); next_enemy_y[i] <= 12+(i*10); 
                enemy_dir[i] <= 3; next_enemy_dir[i] <= 3; enemy_step[i] <= 0;
            end
        end else if (state == STATE_PLAY) begin
            if (tick_sec) begin
                for (i=0; i<2; i=i+1) begin
                    if (enemy_alive[i]) begin
                        if (enemy_step[i] == 0) begin next_enemy_dir[i] <= lfsr[1:0] ^ i[1:0]; enemy_step[i] <= lfsr[4:2] + 3; end 
                        else begin
                            case (next_enemy_dir[i])
                                0: next_enemy_y[i] <= next_enemy_y[i] - 1; 1: next_enemy_x[i] <= next_enemy_x[i] + 1;
                                2: next_enemy_y[i] <= next_enemy_y[i] + 1; 3: next_enemy_x[i] <= next_enemy_x[i] - 1;
                            endcase
                            enemy_step[i] <= enemy_step[i] - 1;
                        end
                    end
                end
            end
            if (start_of_frame) begin
                for (i=0; i<2; i=i+1) begin
                    if (enemy_collision[i]) begin 
                        next_enemy_x[i] <= enemy_x[i]; next_enemy_y[i] <= enemy_y[i]; 
                        next_enemy_dir[i] <= enemy_dir[i]; enemy_step[i] <= 0; 
                    end else begin 
                        enemy_x[i] <= next_enemy_x[i]; enemy_y[i] <= next_enemy_y[i]; enemy_dir[i] <= next_enemy_dir[i]; 
                    end
                end
            end
        end
    end

    reg [1:0] enemy_act;
    always @(posedge CLK) begin
        if (start_of_frame) begin
            bullet_act <= next_bullet_act; bullet_x <= next_bullet_x; bullet_y <= next_bullet_y;
            e_bullet_act <= next_e_bullet_act; e_bullet_x <= next_e_bullet_x; e_bullet_y <= next_e_bullet_y;
            enemy_act <= enemy_alive;
        end
    end

    function get_font_pixel;
        input [7:0] char; input [10:0] cx; input [10:0] cy; reg [14:0] bitmap;
        begin
            case (char)
                "0": bitmap = 15'b111_101_101_101_111; "1": bitmap = 15'b010_110_010_010_111;
                "2": bitmap = 15'b111_001_111_100_111; "3": bitmap = 15'b111_001_111_001_111;
                "4": bitmap = 15'b101_101_111_001_001; "5": bitmap = 15'b111_100_111_001_111;
                "6": bitmap = 15'b111_100_111_101_111; "7": bitmap = 15'b111_001_001_010_010;
                "8": bitmap = 15'b111_101_111_101_111; "9": bitmap = 15'b111_101_111_001_111;
                "A": bitmap = 15'b010_101_111_101_101; "C": bitmap = 15'b011_100_100_100_011;
                "D": bitmap = 15'b110_101_101_101_110; "E": bitmap = 15'b111_100_110_100_111; 
                "G": bitmap = 15'b011_100_101_101_011; "H": bitmap = 15'b101_101_111_101_101; 
                "I": bitmap = 15'b111_010_010_010_111; "K": bitmap = 15'b101_110_100_110_101; 
                "L": bitmap = 15'b100_100_100_100_111; "M": bitmap = 15'b101_111_101_101_101; 
                "N": bitmap = 15'b111_101_101_101_101; "O": bitmap = 15'b010_101_101_101_010; 
                "P": bitmap = 15'b110_101_110_100_100; "R": bitmap = 15'b110_101_110_101_101; 
                "S": bitmap = 15'b011_100_010_001_110; "T": bitmap = 15'b111_010_010_010_010; 
                "V": bitmap = 15'b101_101_101_101_010; "X": bitmap = 15'b101_101_010_101_101; 
                "Y": bitmap = 15'b101_101_010_010_010;
                default: bitmap = 15'b0;
            endcase
            get_font_pixel = (bitmap >> (14 - (cy * 3 + cx))) & 1'b1;
        end
    endfunction

    wire [10:0] cx_t = (H_CNT - 4) & 3; wire [10:0] ch_t = (H_CNT - 4) >> 2;
    wire [7:0] t_title = (ch_t==1)? "T": (ch_t==2)? "H": (ch_t==3)? "E": (ch_t==5)? "T": (ch_t==6)? "A": (ch_t==7)? "N": (ch_t==8)? "K": (ch_t==10)? "G": (ch_t==11)? "A": (ch_t==12)? "M": (ch_t==13)? "E": " ";
    wire is_title = (state == STATE_START) && (V_CNT >= 10 && V_CNT <= 14) && (H_CNT >= 4 && H_CNT <= 55) && (cx_t < 3) ? get_font_pixel(t_title, cx_t, V_CNT-10) : 0;
    
    wire [10:0] cx_p = (H_CNT - 8) & 3; wire [10:0] ch_p = (H_CNT - 8) >> 2;
    wire [7:0] t_press = (ch_p==2)? "P": (ch_p==3)? "R": (ch_p==4)? "E": (ch_p==5)? "S": (ch_p==6)? "S": (ch_p==8)? "S": (ch_p==9)? "H": (ch_p==10)? "O": (ch_p==11)? "O": (ch_p==12)? "T": " ";
    wire is_press = (state != STATE_PLAY && state != STATE_LOAD_LEVEL) && (V_CNT >= 25 && V_CNT <= 29) && (H_CNT >= 8 && H_CNT <= 51) && heartbeat[24] && (cx_p < 3) ? get_font_pixel(t_press, cx_p, V_CNT-25) : 0;

    wire [10:0] cx_o = (H_CNT - 12) & 3; wire [10:0] ch_o = (H_CNT - 12) >> 2;
    wire [7:0] t_over = (ch_o==3)? "G": (ch_o==4)? "A": (ch_o==5)? "M": (ch_o==6)? "E": (ch_o==8)? "O": (ch_o==9)? "V": (ch_o==10)? "E": (ch_o==11)? "R": " ";
    wire is_gameover = (state == STATE_GAMEOVER) && (V_CNT >= 15 && V_CNT <= 19) && (H_CNT >= 12 && H_CNT <= 47) && (cx_o < 3) ? get_font_pixel(t_over, cx_o, V_CNT-15) : 0;

    wire [10:0] cx_v = (H_CNT - 16) & 3; wire [10:0] ch_v = (H_CNT - 16) >> 2;
    wire [7:0] t_vic = (ch_v==4)? "V": (ch_v==5)? "I": (ch_v==6)? "C": (ch_v==7)? "T": (ch_v==8)? "O": (ch_v==9)? "R": (ch_v==10)? "Y": " ";
    wire is_victory = (state == STATE_LEVEL_CLEAR || state == STATE_GAME_CLEAR) && (V_CNT >= 15 && V_CNT <= 19) && (H_CNT >= 16 && H_CNT <= 43) && (cx_v < 3) ? get_font_pixel(t_vic, cx_v, V_CNT-15) : 0;

    wire [10:0] cx_d = (H_CNT - 4) & 3; wire [10:0] ch_d = (H_CNT - 4) >> 2;
    wire [7:0] t_demo = (ch_d==1)? "D": (ch_d==2)? "E": (ch_d==3)? "M": (ch_d==4)? "O": " ";
    wire is_demo_text = demo_mode && (state == STATE_PLAY) && (V_CNT >= 34 && V_CNT <= 38) && (H_CNT >= 4 && H_CNT <= 19) && heartbeat[23] && (cx_d < 3) ? get_font_pixel(t_demo, cx_d, V_CNT-34) : 0;

    wire is_score = (H_CNT >= 50 && H_CNT <= 52 && V_CNT >= 2 && V_CNT <= 6) ? get_font_pixel("0"+score_tens, H_CNT-50, V_CNT-2) : (H_CNT >= 54 && H_CNT <= 56 && V_CNT >= 2 && V_CNT <= 6) ? get_font_pixel("0"+score_ones, H_CNT-54, V_CNT-2) : 1'b0;
    
    wire is_h1 = (lives >= 1) && ((V_CNT == 2 && (H_CNT == 3 || H_CNT == 5)) || (V_CNT == 3 && (H_CNT >= 3 && H_CNT <= 5)) || (V_CNT == 4 && H_CNT == 4));
    wire is_h2 = (lives >= 2) && ((V_CNT == 2 && (H_CNT == 7 || H_CNT == 9)) || (V_CNT == 3 && (H_CNT >= 7 && H_CNT <= 9)) || (V_CNT == 4 && H_CNT == 8));
    wire is_h3 = (lives >= 3) && ((V_CNT == 2 && (H_CNT == 11|| H_CNT == 13))|| (V_CNT == 3 && (H_CNT >= 11&& H_CNT <= 13))|| (V_CNT == 4 && H_CNT == 12));
    wire is_hearts = (state != STATE_START) && (is_h1 || is_h2 || is_h3);

    wire is_bg    = (H_CNT >= 0 && H_CNT < SCR_W) && (V_CNT >= 0 && V_CNT < SCR_H);
    wire is_frame = is_bg && (V_CNT == 8 || V_CNT == SCR_H-1 || H_CNT == 0 || H_CNT == SCR_W-1);
    wire is_tank  = (H_CNT >= tank_x) && (H_CNT < tank_x + TANK_W) && (V_CNT >= tank_y) && (V_CNT < tank_y + TANK_H);
    
    reg is_pipe;
    always @(*) begin
        is_pipe = 1'b0;
        case (direction)
            0: if ((H_CNT == tank_x + 11'd1) && (V_CNT + 11'd1 == tank_y)) is_pipe = 1'b1;
            1: if ((H_CNT == tank_x + 11'd3) && (V_CNT == tank_y + 11'd1)) is_pipe = 1'b1;
            2: if ((H_CNT == tank_x + 11'd1) && (V_CNT == tank_y + 11'd3)) is_pipe = 1'b1;
            3: if ((H_CNT + 11'd1 == tank_x) && (V_CNT == tank_y + 11'd1)) is_pipe = 1'b1;
        endcase
    end

    wire is_bullet = bullet_act && (H_CNT == bullet_x && V_CNT == bullet_y);
    wire is_e_bullet = e_bullet_act && (H_CNT == e_bullet_x && V_CNT == e_bullet_y);
    wire is_wall = is_wall_func(current_level, H_CNT, V_CNT);

    reg is_enemy;
    integer draw_i;
    always @(*) begin
        is_enemy = 1'b0;
        for (draw_i=0; draw_i<2; draw_i=draw_i+1) begin
            if (enemy_act[draw_i]) begin
                if ((H_CNT >= enemy_x[draw_i]) && (H_CNT < enemy_x[draw_i]+TANK_W) && (V_CNT >= enemy_y[draw_i]) && (V_CNT < enemy_y[draw_i]+TANK_H)) 
                    is_enemy = 1'b1;
                case (enemy_dir[draw_i])
                    0: if ((H_CNT == enemy_x[draw_i] + 11'd1) && (V_CNT + 11'd1 == enemy_y[draw_i])) is_enemy = 1'b1;
                    1: if ((H_CNT == enemy_x[draw_i] + 11'd3) && (V_CNT == enemy_y[draw_i] + 11'd1)) is_enemy = 1'b1;
                    2: if ((H_CNT == enemy_x[draw_i] + 11'd1) && (V_CNT == enemy_y[draw_i] + 11'd3)) is_enemy = 1'b1;
                    3: if ((H_CNT + 11'd1 == enemy_x[draw_i]) && (V_CNT == enemy_y[draw_i] + 11'd1)) is_enemy = 1'b1;
                endcase
            end
        end
    end

    reg [7:0] r_red, r_green, r_blue;
    always @(posedge CLK) begin
        if (state == STATE_START) begin
            if (is_title || is_press) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF; end else begin r_red<=0; r_green<=0; r_blue<=0; end
        end else if (state == STATE_GAMEOVER) begin
            if (is_gameover || is_press) begin r_red <= 8'hFF; r_green <= 8'h00; r_blue <= 8'h00; end else begin r_red<=8'h20; r_green<=0; r_blue<=0; end
        end else if (state == STATE_LEVEL_CLEAR || state == STATE_GAME_CLEAR) begin
            if (is_victory || is_press) begin r_red <= 8'h00; r_green <= 8'hFF; r_blue <= 8'h00; end else begin r_red<=0; r_green<=8'h20; r_blue<=0; end
        end else begin 
            if (is_frame) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF; end
            else if (is_score) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'h00; end 
            else if (is_demo_text) begin r_red <= 8'hFF; r_green <= 8'hFF; r_blue <= 8'hFF; end 
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
    assign LED = (lives == 3) ? 4'b0111 : (lives == 2) ? 4'b0011 : (lives == 1) ? 4'b0001 : 4'b0000;

endmodule