// grass_map.vh -- Static decorative grass tile placements.
// Mirrors arena_map.vh in style. The set is hand-picked so it does NOT
// overlap any of:
//   * obstacle tiles (see arena_map.vh)
//   * food candidate tiles
//       (14,10) (25,5) (8,15) (30,3) (18,18) (32,11) (6,3) (28,19)
//   * snake spawn tiles
//       player primary  : (5,5)  (4,5)
//       player alternate: (5,17) (4,17)
//       rival primary   : (34,17) (35,17)
//       rival alternate : (34,5)  (35,5)
//
// Tile grid is 40 wide x 23 tall. The list below is sparse (~25 tiles)
// scattered around the perimeter and edges, away from the central corridor
// where snakes spend most of the action.

function grass_at;
    input [5:0] tx;
    input [5:0] ty;
    grass_at =
        // Top row band
        (tx == 6'd2  && ty == 6'd2)  ||
        (tx == 6'd9  && ty == 6'd2)  ||
        (tx == 6'd15 && ty == 6'd2)  ||
        (tx == 6'd22 && ty == 6'd2)  ||
        (tx == 6'd29 && ty == 6'd2)  ||
        (tx == 6'd37 && ty == 6'd2)  ||
        // Upper-mid band
        (tx == 6'd2  && ty == 6'd8)  ||
        (tx == 6'd37 && ty == 6'd8)  ||
        // Mid-left edge
        (tx == 6'd0  && ty == 6'd7)  ||
        (tx == 6'd0  && ty == 6'd13) ||
        (tx == 6'd0  && ty == 6'd17) ||
        // Mid-right edge
        (tx == 6'd39 && ty == 6'd7)  ||
        (tx == 6'd39 && ty == 6'd13) ||
        // Lower band
        (tx == 6'd2  && ty == 6'd14) ||
        (tx == 6'd38 && ty == 6'd14) ||
        (tx == 6'd7  && ty == 6'd12) ||
        (tx == 6'd33 && ty == 6'd12) ||
        // Bottom row band
        (tx == 6'd2  && ty == 6'd20) ||
        (tx == 6'd10 && ty == 6'd20) ||
        (tx == 6'd16 && ty == 6'd20) ||
        (tx == 6'd24 && ty == 6'd20) ||
        (tx == 6'd30 && ty == 6'd20) ||
        (tx == 6'd38 && ty == 6'd20) ||
        // Corner-ish accents
        (tx == 6'd20 && ty == 6'd0)  ||
        (tx == 6'd20 && ty == 6'd22);
endfunction
