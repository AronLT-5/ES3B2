// arena_map.vh -- Single source of truth for static obstacle layout.
// Included by snake_game_core.v, rival_ai_simple.v, and pixel_renderer.v.
//
// "Offset Gates" map: 5 segments, 27 tiles total.
//
//   Seg 1: Left vertical gate      x=12, y=6..10   (5 tiles)
//   Seg 2: Center horizontal gate   x=18..24, y=11  (7 tiles)
//   Seg 3: Right vertical gate      x=28, y=12..16  (5 tiles)
//   Seg 4: Upper-center horizontal  x=16..20, y=5   (5 tiles)
//   Seg 5: Lower-center horizontal  x=22..26, y=17  (5 tiles)

// --- Segment 1: Left vertical gate ---
localparam [5:0] OBS0_X  = 6'd12, OBS0_Y  = 6'd6;
localparam [5:0] OBS1_X  = 6'd12, OBS1_Y  = 6'd7;
localparam [5:0] OBS2_X  = 6'd12, OBS2_Y  = 6'd8;
localparam [5:0] OBS3_X  = 6'd12, OBS3_Y  = 6'd9;
localparam [5:0] OBS4_X  = 6'd12, OBS4_Y  = 6'd10;

// --- Segment 2: Center horizontal gate ---
localparam [5:0] OBS5_X  = 6'd18, OBS5_Y  = 6'd11;
localparam [5:0] OBS6_X  = 6'd19, OBS6_Y  = 6'd11;
localparam [5:0] OBS7_X  = 6'd20, OBS7_Y  = 6'd11;
localparam [5:0] OBS8_X  = 6'd21, OBS8_Y  = 6'd11;
localparam [5:0] OBS9_X  = 6'd22, OBS9_Y  = 6'd11;
localparam [5:0] OBS10_X = 6'd23, OBS10_Y = 6'd11;
localparam [5:0] OBS11_X = 6'd24, OBS11_Y = 6'd11;

// --- Segment 3: Right vertical gate ---
localparam [5:0] OBS12_X = 6'd28, OBS12_Y = 6'd12;
localparam [5:0] OBS13_X = 6'd28, OBS13_Y = 6'd13;
localparam [5:0] OBS14_X = 6'd28, OBS14_Y = 6'd14;
localparam [5:0] OBS15_X = 6'd28, OBS15_Y = 6'd15;
localparam [5:0] OBS16_X = 6'd28, OBS16_Y = 6'd16;

// --- Segment 4: Upper-center horizontal ---
localparam [5:0] OBS17_X = 6'd16, OBS17_Y = 6'd5;
localparam [5:0] OBS18_X = 6'd17, OBS18_Y = 6'd5;
localparam [5:0] OBS19_X = 6'd18, OBS19_Y = 6'd5;
localparam [5:0] OBS20_X = 6'd19, OBS20_Y = 6'd5;
localparam [5:0] OBS21_X = 6'd20, OBS21_Y = 6'd5;

// --- Segment 5: Lower-center horizontal ---
localparam [5:0] OBS22_X = 6'd22, OBS22_Y = 6'd17;
localparam [5:0] OBS23_X = 6'd23, OBS23_Y = 6'd17;
localparam [5:0] OBS24_X = 6'd24, OBS24_Y = 6'd17;
localparam [5:0] OBS25_X = 6'd25, OBS25_Y = 6'd17;
localparam [5:0] OBS26_X = 6'd26, OBS26_Y = 6'd17;

// --- Shared obstacle-hit function ---
function obstacle_at;
    input [5:0] tx;
    input [5:0] ty;
    obstacle_at =
        // Segment 1
        (tx == OBS0_X  && ty == OBS0_Y)  ||
        (tx == OBS1_X  && ty == OBS1_Y)  ||
        (tx == OBS2_X  && ty == OBS2_Y)  ||
        (tx == OBS3_X  && ty == OBS3_Y)  ||
        (tx == OBS4_X  && ty == OBS4_Y)  ||
        // Segment 2
        (tx == OBS5_X  && ty == OBS5_Y)  ||
        (tx == OBS6_X  && ty == OBS6_Y)  ||
        (tx == OBS7_X  && ty == OBS7_Y)  ||
        (tx == OBS8_X  && ty == OBS8_Y)  ||
        (tx == OBS9_X  && ty == OBS9_Y)  ||
        (tx == OBS10_X && ty == OBS10_Y) ||
        (tx == OBS11_X && ty == OBS11_Y) ||
        // Segment 3
        (tx == OBS12_X && ty == OBS12_Y) ||
        (tx == OBS13_X && ty == OBS13_Y) ||
        (tx == OBS14_X && ty == OBS14_Y) ||
        (tx == OBS15_X && ty == OBS15_Y) ||
        (tx == OBS16_X && ty == OBS16_Y) ||
        // Segment 4
        (tx == OBS17_X && ty == OBS17_Y) ||
        (tx == OBS18_X && ty == OBS18_Y) ||
        (tx == OBS19_X && ty == OBS19_Y) ||
        (tx == OBS20_X && ty == OBS20_Y) ||
        (tx == OBS21_X && ty == OBS21_Y) ||
        // Segment 5
        (tx == OBS22_X && ty == OBS22_Y) ||
        (tx == OBS23_X && ty == OBS23_Y) ||
        (tx == OBS24_X && ty == OBS24_Y) ||
        (tx == OBS25_X && ty == OBS25_Y) ||
        (tx == OBS26_X && ty == OBS26_Y);
endfunction
