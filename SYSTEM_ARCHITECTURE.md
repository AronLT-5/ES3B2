# Serpent Says System Architecture

This document describes the Serpent Says FPGA system deeply enough that a reader can reconstruct the design, module boundaries, data flow, and implementation logic from the repository. It treats the checked-in Verilog and memory assets as the source of truth, not the shorter top-level `README.md`.

## System Overview

Serpent Says is a Vivado/Verilog design for an Artix-7 FPGA target (`xc7a100tcsg324-1`). The active top module is `top_serpent_says` in `serpent_says/rtl/top_serpent_says.v`. The design drives a 640x480 VGA output, implements a two-snake game, accepts player turns from either buttons or an onboard PDM microphone keyword-spotting pipeline, renders sprites, text, temperature-reactive grass, and HUD hearts, and exposes debug/status through LEDs and seven-segment displays.

At runtime the design has these major flows:

| Flow | Start | End | Main files |
| --- | --- | --- | --- |
| Video timing | 100 MHz board clock | VGA sync and pixel coordinates | `clk_divider.v`, `vga_controller.v` |
| Gameplay | start/pause/buttons/voice ticks | snake positions, lives, food, game state | `button_input_adapter.v`, `turn_request_mux.v`, `game_tick_gen.v`, `snake_game_core.v`, `rival_ai_simple.v`, `arena_map.vh` |
| Rendering | pixel coordinate plus game state | VGA RGB outputs | `info_bar_renderer.v`, `pixel_renderer.v`, `sprite_rom.v`, `text_glyph_rom.v` |
| Voice commands | PDM mic bitstream | left/right turn events | `ml_top_cnn.v`, `pdm_capture.v`, `cic_decimator.v`, `frame_buffer.v`, `feature_pipeline.v`, `context_buffer.v`, `normalizer.v`, `cnn_inference.v`, `command_filter.v` |
| Status outputs | game/debug/ML state | LEDs and seven-segment digits | `led_status_driver.v`, `seven_seg_driver.v` |

The player snake is controlled by relative turns: left means rotate counter-clockwise, right means rotate clockwise. The rival snake is controlled by an AI that outputs an absolute direction. The current top-level instantiates the CNN speech path (`ml_top_cnn`), while the BNN files remain present as an alternate or legacy inference path.

## Repository and Source-of-Truth Layout

```text
.
|-- README.md
|-- SYSTEM_ARCHITECTURE.md
|-- bitstreams/
|   `-- speech_kws_verify_top.bit
`-- serpent_says/
    |-- serpent_says.xpr
    |-- rtl/
    |   |-- top_serpent_says.v
    |   |-- snake_game_core.v
    |   |-- pixel_renderer.v
    |   |-- ml_top_cnn.v
    |   `-- ... remaining canonical RTL ...
    |-- tb/
    |   `-- ... Verilog testbenches ...
    |-- xdc/
    |   `-- top.xdc
    |-- scripts/
    |   |-- repair_vivado_project.tcl
    |   `-- waveforms/
    |       `-- waveform evidence capture scripts
    |-- Sprites/
    |   |-- mem/
    |   |   `-- sprite, ML weight, FFT, mel, and normalization ROM files
    |   |-- PNG/
    |   |   `-- source/preview bitmap assets
    |   |-- Sprites_README.md
    |   `-- ui_overlay_layout.txt
    `-- serpent_says.srcs/
        `-- sources_1/new/
            `-- older Vivado-created stubs, not the canonical source
```

Canonical source lives in `serpent_says/rtl/`. The Vivado project (`serpent_says.xpr`) lists those RTL files, the `.mem` ROM assets, `xdc/top.xdc`, and testbench files. The duplicate files under `serpent_says/serpent_says.srcs/sources_1/new/` are old generated stubs: one `top_serpent_says.v` only drives VGA outputs to inactive values, and one `clk_divider.v` is empty. Do not use those stubs to replicate the current system.

The `Sprites/mem/` directory contains these broad ROM data groups:

| Asset class | Examples | Consumers |
| --- | --- | --- |
| 16x16 12-bit color sprites | `apple.mem`, `Obstacle.mem`, `Snake_head_up.mem`, `Bot_Eat_right.mem`, `Grass_Normal.mem` | `sprite_rom`, selected by `top_serpent_says`, addressed by `pixel_renderer` |
| 13x13 HUD sprites | `Heart_Blue.mem`, `Heart_Red.mem` | `sprite_rom`, addressed by `info_bar_renderer` |
| Large active overlays | `Title.mem`, `victory.mem`, `gameOver.mem` | block-ROM `sprite_rom` instances, addressed by `pixel_renderer` |
| ML/support coefficients | `hann_window.mem`, `tw_cos.mem`, `tw_sin.mem`, `mel_coeffs.mem`, `norm_scale.mem`, `conv1_weights.mem`, etc. | feature extraction, normalization, CNN, and BNN modules |

`Sprites/PNG/` contains bitmap source/preview assets. `Sprites/Sprites_README.md` documents the active `.mem` encoding and dimensions for the current grass, heart, and title assets. There is no converter script in the current repo, so exact regeneration of `.mem` assets from PNGs would require recreating the conversion tool or preserving the checked-in `.mem` files. `Logo.mem`, `live.mem`, and `Sprites/ui_overlay_layout.txt` may still exist as legacy assets/layout notes, but they are not instantiated by the active top-level.

## Hardware Interface and Constraints

`serpent_says/xdc/top.xdc` maps the top-level ports to FPGA pins. The project target is `xc7a100tcsg324-1`, consistent with Nexys 4 DDR / Nexys A7-style peripherals and an Artix-7 XADC primitive.

Top-level hardware ports:

| Port | Direction | Purpose |
| --- | --- | --- |
| `CLK100MHZ` | input | 100 MHz board clock |
| `CPU_RESETN` | input | active-low reset |
| `BTNC`, `BTNL`, `BTNR` | input | start/restart, relative-left turn, relative-right turn |
| `SW[0]` | input | pause switch |
| `SW[1]` | input | LED debug mode |
| `SW[2]` | input | enable voice commands and slower voice tick cadence |
| `pdm_data_i` | input | microphone PDM data |
| `pdm_clk_o`, `pdm_lrsel_o` | output | microphone clock and LR select |
| `VGA_HS`, `VGA_VS`, `VGA_R/G/B[3:0]` | output | VGA sync and 12-bit RGB |
| `LED[12:0]` | output | game/debug/voice indicators |
| `CA..CG`, `DP`, `AN[7:0]` | output | seven-segment display |

Clocking is intentionally simple. `clk_divider.v` divides the 100 MHz board clock by four using a 2-bit counter and exposes `div_cnt[1]` as the 25 MHz pixel/system clock. `top.xdc` declares the 100 MHz input clock and a generated 25 MHz clock at the divider register. Almost all modules run on this 25 MHz clock. The PDM microphone clock is not a new clock domain; it is generated as a toggled output inside `pdm_capture.v`.

## Top-Level Architecture

`top_serpent_says.v` is the integration file. It creates and connects all user-visible behavior:

1. It divides `CLK100MHZ` to `clk_25mhz`.
2. It generates VGA coordinates and sync from `vga_controller`.
3. It synchronizes `SW[2:0]` into the 25 MHz domain and derives pause, debug, and voice-mode flags.
4. It creates `game_tick` using `game_tick_gen`, enabled only while `fsm_state == PLAYING`.
5. It converts raw buttons into one-cycle start and turn events through `button_input_adapter`.
6. It samples XADC temperature through `temp_background_ctrl` for background color selection.
7. It runs the CNN microphone pipeline through `ml_top_cnn`.
8. It stretches accepted voice commands for about 0.25 seconds so LEDs can show voice activity.
9. It combines button and voice turn requests through `turn_request_mux`, with button priority.
10. It computes rival turns using `rival_ai_simple`.
11. It advances game state through `snake_game_core`.
12. It instantiates all sprite ROMs, including directional/eating heads, food, obstacles, HUD hearts, temperature-selectable grass, victory/game-over banners, and the title splash.
13. It direction-selects player/rival head and eating sprites, muxes grass by `temp_state`, and renders the top info bar, playfield, overlays, and sprites.
14. It drives seven-segment and LED status outputs.

The current speech inference path is `ml_top_cnn`. `ml_top_bnn`, `bnn_inference`, and `binary_dense_layer` are included in the project as an alternate inference implementation, but they are not instantiated by the active top-level.

## Module Dependency Graph

```text
top_serpent_says
|-- clk_divider
|-- vga_controller
|-- game_tick_gen
|-- button_input_adapter
|-- temp_background_ctrl
|   `-- XADC primitive
|-- ml_top_cnn
|   |-- pdm_capture
|   |-- cic_decimator
|   |-- frame_buffer
|   |-- feature_pipeline
|   |   |-- fft_256
|   |   `-- mel_power
|   |-- context_buffer
|   |-- normalizer
|   |-- cnn_inference
|   |   |-- conv2d_layer
|   |   |-- maxpool2d
|   |   |-- conv2d_layer
|   |   |-- maxpool2d
|   |   |-- dense_layer_wide
|   |   `-- dense_layer
|   `-- command_filter
|-- turn_request_mux
|-- rival_ai_simple
|   `-- arena_map.vh
|-- snake_game_core
|   `-- arena_map.vh
|-- sprite_rom instances
|   `-- heads, eating heads, food, obstacles, hearts, grass, banners, title
|-- info_bar_renderer
|   `-- text_glyph_rom
|-- pixel_renderer
|   |-- arena_map.vh
|   `-- grass_map.vh
|-- seven_seg_driver
`-- led_status_driver

Optional alternate path:
ml_top_bnn
|-- same audio/feature/normalizer modules as ml_top_cnn
|-- bnn_inference
|   `-- binary_dense_layer instances
`-- command_filter
```

`arena_map.vh` is included in the game core, rival AI, and renderer so collision logic and obstacle drawing use one shared obstacle map. `grass_map.vh` is included only in the renderer because grass is decorative and does not affect gameplay collisions.

## Clocking, Reset, and Timing

The reset convention is active-low (`CPU_RESETN`, `reset_n`, or `rst_n`). Most sequential modules reset asynchronously on `negedge reset_n`. Some render counters, such as animation counters, are free-running after configuration and do not need gameplay reset for correctness.

Clock and rate generation:

| Logic | Rate/behavior | File |
| --- | --- | --- |
| Board clock | 100 MHz input | `top.xdc` |
| Pixel/system clock | `CLK100MHZ / 4 = 25 MHz` | `clk_divider.v` |
| VGA timing | 640 visible + front/sync/back porch, 480 visible + front/sync/back porch | `vga_controller.v` |
| Button game tick | default 12,500,000 cycles, about 0.5 s at 25 MHz | `game_tick_gen.v` |
| Voice game tick | default 18,750,000 cycles, about 0.75 s at 25 MHz | `game_tick_gen.v` |
| PDM mic clock | default `25 MHz / 10 = 2.5 MHz` | `pdm_capture.v` |
| CIC PCM output | `2.5 MHz / 156`, about 16 kHz | `cic_decimator.v` |
| Death respawn timer | 37,500,000 cycles, about 1.5 s | `snake_game_core.v` |
| Voice activity LED stretch | 6,250,000 cycles, about 0.25 s | `top_serpent_says.v` |
| Food/eating flash | 5,000,000 cycles, about 0.2 s | `top_serpent_says.v`, `pixel_renderer.v` |

The game state machine only advances on `game_tick`, not every pixel clock. Input events are latched between ticks so a one-cycle button or voice event can affect the next movement step.

## Gameplay Architecture

### State Machine

`snake_game_core.v` owns the game FSM:

| State | Encoding | Meaning |
| --- | --- | --- |
| `IDLE` | `3'd0` | Reset/default state. Center button advances to title screen. |
| `PLAYING` | `3'd1` | Movement ticks are active; pause and restart are accepted. |
| `PAUSED` | `3'd2` | Movement stops while `SW[0]` is high. |
| `VICTORY` | `3'd3` | Player wins. Center button returns to title screen. |
| `GAME_OVER` | `3'd4` | Player loses. Center button returns to title screen. |
| `RESPAWNING` | `3'd5` | Non-terminal collision freeze/death animation before respawn. |
| `TITLE_SCREEN` | `3'd6` | Single centered 300x300 title splash over a black game area. Center button initializes a new game and enters playing. |

State changes are synchronized to the 25 MHz clock. Movement and collision resolution happen only in `PLAYING` when `game_tick` pulses. Center button can reset from playing, paused, respawning, victory, or game-over back to `TITLE_SCREEN`.

### Coordinate System and Direction Encoding

The arena is 40 tiles wide by 23 tiles high:

| Field | Value |
| --- | --- |
| `ARENA_X_MAX` | 39 |
| `ARENA_Y_MAX` | 22 |
| tile size | 16x16 pixels |
| playfield x pixels | 0..639 |
| playfield y pixels | 106..473 |

Direction encoding is shared by game, renderer, and AI:

| Direction | Encoding |
| --- | --- |
| up | `2'b00` |
| right | `2'b01` |
| down | `2'b10` |
| left | `2'b11` |

Player input is relative:

| Turn request | Meaning |
| --- | --- |
| `2'b01` | rotate left: `p_direction - 1` |
| `2'b10` | rotate right: `p_direction + 1` |
| `2'b00` | no turn |

Rival AI output is absolute and directly becomes `next_r_dir`.

### Spawns, Lengths, Lives, and Food

Both snakes start at length 2 and can grow to length 8. Each snake has one head register plus seven body segment register pairs. `p_length` and `r_length` decide how many body registers are active.

Default spawns:

| Entity | Head | Body0 | Direction |
| --- | --- | --- | --- |
| Player primary | `(5,5)` | `(4,5)` | right |
| Player alternate | `(5,17)` | `(4,17)` | right |
| Rival primary | `(34,17)` | `(35,17)` | left |
| Rival alternate | `(34,5)` | `(35,5)` | left |

`INITIAL_LIVES` defaults to 3. Seven-segment score is derived from `length - 2`, because length 2 is the initial state. Food uses a deterministic ring of eight candidate positions:

```text
(14,10), (25,5), (8,15), (30,3),
(18,18), (32,11), (6,3), (28,19)
```

When food is eaten, `snake_game_core` searches forward from the current `food_idx` and chooses the first candidate that is not an obstacle and not occupied by either snake's post-move body/head. This deterministic approach avoids random-number hardware while still moving food around the board.

### Obstacles

`arena_map.vh` defines 27 obstacle tiles in five "offset gate" segments and exposes a shared `obstacle_at(tx, ty)` function:

| Segment | Tiles |
| --- | --- |
| Left vertical gate | x=12, y=6..10 |
| Center horizontal gate | x=18..24, y=11 |
| Right vertical gate | x=28, y=12..16 |
| Upper-center horizontal | x=16..20, y=5 |
| Lower-center horizontal | x=22..26, y=17 |

Because this include is used by `snake_game_core`, `rival_ai_simple`, and `pixel_renderer`, gameplay collisions, AI avoidance, and visual obstacle placement stay consistent.

### Collision and Movement Logic

On a movement tick, `snake_game_core` computes the next directions, next head positions, collision flags, food flags, and terminal state before committing movement.

Collision sources:

| Collision | Logic |
| --- | --- |
| Wall | moving beyond x=0, x=39, y=0, or y=22 |
| Obstacle | `obstacle_at(next_x, next_y)` |
| Self body | next head hits own active body segment |
| Other body | next head hits the other snake's active body segment |
| Head-to-head | both next heads land on the same tile |
| Head-swap | both snakes swap current head tiles |
| Head-into-head | one next head enters the other current head tile |

The body collision logic handles tail-vacate correctly. Moving into a tail tile is allowed only when the snake owning that tail is not eating on the same tick. If the owner eats, the tail does not vacate and the tile remains occupied.

Movement commitment:

1. If a snake collided, it loses one life and its body registers do not advance on that tick.
2. If it did not collide, its direction and head update to the computed next values.
3. Body segments shift: old head becomes body0, body0 becomes body1, and so on.
4. If it eats and is below max length, length increments.
5. If either snake eats, food relocates using the safe-candidate scan.

Terminal precedence:

1. If the player collision consumes the last life, state becomes `GAME_OVER`.
2. Else if the rival collision consumes the last life, state becomes `VICTORY`.
3. Else if player eats and reaches max length, state becomes `VICTORY`.
4. Else if rival eats and reaches max length, state becomes `GAME_OVER`.
5. Else any non-terminal collision enters `RESPAWNING`.

During `RESPAWNING`, the dead snake(s) freeze for about 1.5 seconds. When the timer expires, each dead snake respawns at its primary spawn if safe relative to the surviving snake, otherwise its alternate spawn. Respawn resets that snake's body registers, direction, and length, but keeps its reduced lives.

### Input Flow

`button_input_adapter.v` synchronizes `BTNL`, `BTNR`, and `BTNC` through two flip-flops and edge-detects rising edges. `BTNL` and `BTNR` produce one-cycle turn events, with left priority if both rise together. `BTNC` produces `start_btn`.

`ml_top_cnn.v` produces voice turn events with the same `2'b01` left and `2'b10` right encoding. `turn_request_mux.v` merges button and voice events. If both are valid at once, the button event wins and `turn_source` is `2'b01`; voice-only events set `turn_source` to `2'b10`.

`snake_game_core.v` latches one player turn between movement ticks. It ignores additional turn events while `pending_valid` is already set, preventing multiple turns from accumulating before the next movement step.

### Rival AI

`rival_ai_simple.v` is purely combinational. It evaluates three possible directions from the rival's current direction: forward, relative-left, and relative-right. It never intentionally reverses.

For each candidate it:

1. Computes the next tile.
2. Rejects walls, obstacles, rival body tiles, and player head/body tiles.
3. Computes Manhattan distance to food.
4. Chooses the safe candidate with the shortest distance to food.
5. Uses tie-break order forward, then left, then right.
6. If no candidate is safe, it continues forward and will likely collide.

## Rendering and VGA Pipeline

### VGA Timing

`vga_controller.v` implements standard 640x480-style timing using the 25 MHz pixel clock:

| Horizontal | Pixels |
| --- | --- |
| visible | 640 |
| front porch | 16 |
| sync | 96 |
| back porch | 48 |
| total | 800 |

| Vertical | Lines |
| --- | --- |
| visible | 480 |
| front porch | 10 |
| sync | 2 |
| back porch | 33 |
| total | 525 |

`video_active` is true only inside 640x480. HSYNC and VSYNC are active-low during their sync intervals. `pixel_x` and `pixel_y` are exposed to both renderers.

### Info Bar

`info_bar_renderer.v` owns the top 100 pixels (`pixel_y < 100`). It renders:

| Row | Content |
| --- | --- |
| y=4 | student IDs `U5560656   U5552548` |
| y=16 | left-aligned `PLAYER SCORE : N` and right-aligned `N : SCORE RIVAL` |
| y=28..40 | blue player hearts on the left and red rival hearts on the right |
| y=46 | mode, command source, last command |
| y=60 | state text |

Text uses 6x8 cells backed by `text_glyph_rom.v`, which is a combinational 5x7 bitmap font with spacing in column 5 and row 7. The font covers uppercase letters, digits, space, colon, equals, slash, pipe, dash, period, and the punctuation used by the HUD state strings. Scores are derived as `length - 2`, matching `seven_seg_driver.v`. Life icons are fetched from `Heart_Blue.mem` and `Heart_Red.mem` through top-level `sprite_rom` instances. Heart pixels have priority over text within their region and disappear as the corresponding life count decreases.

### Playfield Renderer

`pixel_renderer.v` owns the remaining visible image. It treats the playfield as a 40x23 tile grid of 16x16 sprites:

```text
tile_x = pixel_x[9:4]
tile_y = (pixel_y - playfield_y_start)[9:4]
tile_sprite_addr = {tile_py, tile_px}
```

The playfield normally starts at y=106 and ends at y=473. In `RESPAWNING`, the renderer applies a small +/-2 pixel shake to the playfield y range.

The renderer computes hit flags for player head, rival head, every active body segment, food, obstacles, decorative grass, playfield border, lower background, the title overlay, and terminal overlays. Body segments are not sprites; they are colored rectangles with a gradient based on segment index. Heads, eating heads, food, obstacles, grass, title, victory, and game-over graphics are sprite ROM data.

Priority from highest to lowest:

1. inactive video -> black
2. info bar passthrough
3. title-screen `Title.mem` splash
4. victory banner sprite
5. game-over banner sprite
6. playfield border
7. player head sprite
8. rival head sprite
9. player body gradient/death flash
10. rival body gradient/death flash
11. food sprite or food flash
12. obstacle sprite
13. decorative grass sprite
14. playfield background
15. title-screen black background
16. lower background
17. black fallback

Sprite color `12'h000` is treated as transparent for the overlay/head/food/obstacle cases. Large overlays use block ROM and therefore have one-cycle latency; the renderer delays their region flags by one clock to match returned sprite data.

Visual effects:

| Effect | Implementation |
| --- | --- |
| death flash | `anim_p_dying`/`anim_r_dying` cause white/red blinking on heads and bodies |
| screen shake | y offset toggles during `RESPAWNING` |
| food flash | `anim_food_eaten` starts a 5,000,000-cycle flash timer |
| body gradient | segment index darkens base RGB channels |
| game-over background | red tint derived from animation counter |
| victory background | gold tint derived from animation counter |
| terminal border | border flashes red or gold |
| temperature background | `temp_state` selects cool, neutral, or hot playfield color |
| decorative grass | `grass_map.vh` selects sparse tiles and `temp_state` muxes cold/normal/hot grass sprite data |

### Sprite ROMs

`sprite_rom.v` is parameterized by file, depth, width, data width, and block-vs-distributed style. Small sprites use distributed ROM and effectively combinational reads. Large overlays use block ROM with a registered output. `top_serpent_says.v` instantiates separate ROMs for directional player heads, player eating heads, rival heads, rival eating heads, food, obstacles, blue/red HUD hearts, cold/normal/hot grass, victory, game-over, and title.

`top_serpent_says.v` selects direction-specific head sprites based on `p_direction` and `r_direction`. Eating sprites override normal head sprites while `p_eat_cnt` or `r_eat_cnt` is nonzero. Those counters are started from `dbg_p_ate` and `dbg_r_ate`. Grass ROMs are read in parallel and muxed by `temp_state` before being passed to `pixel_renderer.v`.

## Sprite and Memory Assets

The design relies on `$readmemh` ROM initialization for both graphics and ML constants. In Vivado, the `.mem` files must be present in the project or available in the simulation/synthesis working directory so each ROM can initialize correctly.

Sprite memory conventions:

| Asset group | Files | Format and use |
| --- | --- | --- |
| Food and obstacles | `apple.mem`, `Obstacle.mem` | 16x16, 256 entries, 12-bit RGB, `12'h000` transparent in renderer |
| Player heads | `Snake_head_up.mem`, `Snake_head_right.mem`, `Snake_head_down.mem`, `Snake_head_left.mem` | direction-specific normal player head sprites |
| Player eating heads | `Player_Eating_up.mem`, `Player_Eating_right.mem`, `Player_Eating_down.mem`, `Player_Eating_left.mem` | direction-specific eating animation heads |
| Rival heads | `Bot_Snake_head_up.mem`, `Bot_Snake_head_right.mem`, `Bot_Snake_head_down.mem`, `Bot_Snake_head_left.mem` | direction-specific rival head sprites |
| Rival eating heads | `Bot_Eat_up.mem`, `Bot_Eat_right.mem`, `Bot_Eat_down.mem`, `Bot_Eat_left.mem` | direction-specific rival eating animation heads |
| HUD hearts | `Heart_Blue.mem`, `Heart_Red.mem` | 13x13 life icons used in the info bar |
| Decorative grass | `Grass_Cold.mem`, `Grass_Normal.mem`, `Grass_Hot.mem` | 16x16 playfield decoration sprites muxed by temperature state |
| Terminal/title overlays | `victory.mem`, `gameOver.mem`, `Title.mem` | larger block-ROM sprites with explicit width/depth and registered output |
| Legacy/unused graphics | `Logo.mem`, `live.mem` | retained assets, not instantiated by the current top-level |

Large overlay dimensions are hard-coded in `top_serpent_says.v` and `pixel_renderer.v`:

| File | Width x height | ROM depth | Screen position |
| --- | --- | --- | --- |
| `victory.mem` | 312x40 | 12,480 | x=164, y=270 |
| `gameOver.mem` | 368x40 | 14,720 | x=136, y=270 |
| `Title.mem` | 300x300 | 90,000 | x=170, y=140 |

ML/support memory conventions:

| File group | Consumer | Purpose |
| --- | --- | --- |
| `hann_window.mem` | `feature_pipeline.v` | 256-entry Q1.15 Hann window |
| `tw_cos.mem`, `tw_sin.mem` | `fft_256.v` | 128-entry Q1.15 FFT twiddle tables |
| `mel_coeffs.mem` | `mel_power.v` | 129-entry packed mel coefficient table, up to two mel contributions per FFT bin |
| `norm_scale.mem`, `norm_offset.mem` | `normalizer.v` | 256-entry per-feature normalization parameters |
| `conv1_*`, `conv2_*`, `cnn_hidden_*`, `cnn_output_*` | `cnn_inference.v` and layer modules | CNN int8 weights and int32 biases |
| `hidden_weights_bin.mem`, `output_weights_bin.mem`, `hidden_scale.mem`, `output_scale.mem`, `hidden_bias.mem`, `output_bias.mem` | BNN modules | optional packed binary weights plus scale/bias terms |

The `.PNG` files are useful visual references, but the RTL consumes `.mem` files. If sprites are replaced, dimensions, transparency behavior, ROM depth, and address formulas must remain consistent or the top-level sprite instances and renderer address calculations must be updated together.

## Voice/ML Command Pipeline

The active voice path is:

```text
pdm_data_i
-> pdm_capture
-> cic_decimator
-> frame_buffer
-> feature_pipeline
   -> fft_256
   -> mel_power
-> context_buffer
-> normalizer
-> cnn_inference
   -> conv2d_layer
   -> maxpool2d
   -> conv2d_layer
   -> maxpool2d
   -> dense_layer_wide
   -> dense_layer
-> command_filter
-> voice_turn_req / voice_turn_valid
```

### Capture and PCM Conversion

`pdm_capture.v` generates a 2.5 MHz microphone clock from the 25 MHz system clock when `CLK_DIV=10`. It synchronizes `pdm_data_i`, captures the synchronized bit on generated PDM rising edges, and emits a one-cycle `pdm_valid_o` strobe.

`cic_decimator.v` converts PDM bits into signed 16-bit PCM. It uses a fourth-order CIC structure:

1. Convert PDM bit to `+1` or `-1`.
2. Run four integrator stages at PDM sample rate.
3. Every 156 PDM samples, run four comb stages.
4. Output the upper 16 bits of the 32-bit final comb result and pulse `pcm_valid`.

The default sample rate is approximately `2.5 MHz / 156`, close to 16 kHz.

### Frame, FFT, Mel, and Context Features

`frame_buffer.v` collects 256 PCM samples per frame with a 128-sample hop. It uses two banks so one bank can be read while the other is filled. After a frame is consumed, it copies the 128-sample overlap into the next active bank and resumes writing from index 128.

`feature_pipeline.v` waits for `frame_ready`, then:

1. Reads 256 samples from the frame buffer.
2. Multiplies each sample by `hann_window.mem` Q1.15 coefficients.
3. Writes windowed samples into `fft_256`.
4. Starts the FFT.
5. Starts `mel_power`.
6. Writes 16 raw log-mel values into the context buffer and pulses `ctx_frame_done`.

The feature pipeline includes a delayed `fb_addr_d` register because `fb_data` corresponds to the address set the previous cycle. The `tb_feature_pipeline_addr.v` testbench exists specifically to guard this alignment.

`fft_256.v` is a sequential 256-point radix-2 DIT FFT. It loads real samples in bit-reversed address order, initializes imaginary samples to zero, and runs eight stages of 128 butterflies. Twiddle factors come from `tw_cos.mem` and `tw_sin.mem`, with Q1.15 fixed-point multiply and per-stage right-shift scaling to prevent overflow. Output is a readable complex buffer after `done`.

`mel_power.v` consumes FFT bins 0..128. For each bin it computes `re^2 + im^2`, decodes up to two mel filter contributions from `mel_coeffs.mem`, accumulates into 16 mel bins, then applies a log2 approximation. The log approximation uses leading-one detection and a 16-entry fractional LUT, outputting signed Q8.8-style log values.

`context_buffer.v` keeps a rolling set of 16 mel frames, each with 16 bins. It writes new mel values by physical frame slot and exposes a flattened 256-feature vector in mel-major order: upper address nibble is mel bin, lower address nibble is frame index. `feat_ready` becomes high after 16 frames have been collected.

### Normalization

`normalizer.v` performs two passes over the 256 raw features:

1. Pass 1 scans for the maximum feature value.
2. Pass 2 computes `round((feature - max) * scale + offset)`, clamps to `[-127, 127]`, and writes an int8 feature.

The max subtraction makes the hardware convention match a `power_to_db(..., ref=max)` style pipeline. Scale and offset coefficients come from `norm_scale.mem` and `norm_offset.mem`.

`ml_top_cnn.v` stores normalized outputs in `norm_feat_buf[0:255]` and starts CNN inference only after normalization is complete.

### CNN Inference

`cnn_inference.v` implements this quantized CNN:

```text
256 int8 features -> reshape 16x16x1
Conv1: 3x3, 1 -> 16, ReLU, same padding
MaxPool1: 2x2 -> 8x8x16
Conv2: 3x3, 16 -> 32, ReLU, same padding
MaxPool2: 2x2 -> 4x4x32
Flatten: 512
Dense hidden: 512 -> 32, ReLU
Dense output: 32 -> 3, no activation
Argmax plus second-best logit
```

It has three main feature-map buffers:

| Buffer | Size | Use |
| --- | --- | --- |
| `fmap_a` | 4096 bytes | conv1 output, later conv2 output |
| `fmap_b` | 2048 bytes | pool1 output, conv2 input |
| `fmap_c` | 512 bytes | pool2 output, dense hidden input |

`conv2d_layer.v` performs sequential same-padded convolution. For each output row, column, and channel, it loops through `KH * KW * C_IN` kernel elements, uses zero for out-of-bounds padding, accumulates int8 x int8 into int32, adds bias, right-shifts by a per-layer quantization amount, applies ReLU, and clamps to int8.

`maxpool2d.v` performs 2x2 stride-2 max pooling. It reads four addresses for each output spatial/channel position and writes the maximum. The write state computes the fourth value directly from `in_data` to avoid using stale `v3`.

`dense_layer.v` and `dense_layer_wide.v` implement sequential fully connected layers with output-major weight ROM layout. `dense_layer_wide` is identical in behavior but has a 16-bit input address for the 512-element flattened pool2 output. Both accumulate int8 x int8 products, add int32 bias, shift, optionally ReLU, clamp, and write each output.

The CNN sequencer runs `CONV1 -> POOL1 -> CONV2 -> POOL2 -> DENSE1 -> DENSE2 -> ARGMAX`. Argmax emits:

| Output | Meaning |
| --- | --- |
| `kws_class=0` | left |
| `kws_class=1` | right |
| `kws_class=2` | other |
| `kws_conf` | highest logit |
| `kws_second` | second-highest logit for margin filtering |

### Command Filtering

`command_filter.v` converts raw keyword classifications into game turn pulses. It always exposes raw mapped class/confidence through `voice_kws_*`, but it only generates `voice_turn_valid` when all of these are true:

1. `voice_mode_en` is high.
2. Cooldown is inactive.
3. `kws_conf_i >= CONF_THRESH`.
4. `kws_conf_i - kws_second_i >= MARGIN_THRESH`.
5. Class is left or right, not other.

Accepted class 0 maps to `voice_turn_req=2'b01`; class 1 maps to `2'b10`. After an accepted command the cooldown counter suppresses detections for `COOLDOWN_TICKS`, defaulting to 1.5 seconds in the CNN top. `ml_alive` toggles on raw valid inference outputs for debug/status.

### Optional BNN Path

`ml_top_bnn.v`, `bnn_inference.v`, and `binary_dense_layer.v` provide an alternate binary neural network path:

```text
256 int8 features -> binary dense hidden 128 bits -> binary dense output 3 logits
```

Layer 1 uses int8 inputs and binary weights, adding or subtracting each input based on a packed weight bit. Layer 2 uses binary inputs and binary weights with XNOR plus byte popcount. Scale and bias ROMs implement folded batch normalization. The active top-level does not instantiate this path. If swapping it into the design, verify the `command_filter` interface because the current filter expects a second-best logit input for margin thresholding.

## Debug and Status Outputs

### LEDs

`led_status_driver.v` has normal and debug modes selected by `SW[1]`.

Normal mode:

| LED bits | Meaning |
| --- | --- |
| `[12:10]` | zero |
| `[9]` | stretched accepted voice command activity |
| `[8]` | voice mode enabled (`SW[2]`) |
| `[7]` | terminal state |
| `[6]` | paused |
| `[5:3]` | rival lives bitmap |
| `[2:0]` | player lives bitmap |

Debug mode:

| LED bits | Meaning |
| --- | --- |
| `[12:10]` | FSM state |
| `[9]` | rival ate |
| `[8]` | player ate |
| `[7]` | rival collision |
| `[6]` | player collision |
| `[5]` | rival direction changed |
| `[4]` | player turn accepted |
| `[3:2]` | rival direction |
| `[1:0]` | player direction |

### Seven-Segment Display

`seven_seg_driver.v` multiplexes all eight digits using `refresh_cnt[16:14]`. It displays player score/lives on the left bank and rival score/lives on the right bank:

```text
AN[7] player score tens
AN[6] player score ones
AN[5] blank
AN[4] player lives
AN[3] rival score tens
AN[2] rival score ones
AN[1] blank
AN[0] rival lives
```

Score is `length - 2`. Segments and anodes are active-low. Decimal point is always off.

## Vivado Scripts and Evidence

`serpent_says/scripts/repair_vivado_project.tcl` is the current project-repair entry point. It opens `serpent_says.xpr` if needed, removes stale generated top/clock stubs and stale incremental checkpoints from the Vivado project database, re-adds canonical `rtl/*.v`, `rtl/*.vh`, `Sprites/mem/*.mem`, and `xdc/top.xdc`, sets the include directory to `serpent_says/rtl`, sets `top_serpent_says` as the synthesis top, updates compile order, and resets synthesis/implementation runs.

`serpent_says/scripts/waveforms/` contains named waveform-capture Tcl scripts for the W1-W11 evidence cases, with `common_wave_setup.tcl` shared across them. The top-level `Waveforms/` directory contains captured PNG waveform evidence for VGA timing, clocking, turn muxing, game FSM/tick behavior, collision/respawn, food growth, renderer priority, info bar rendering, feature pipeline address alignment, command filtering, and top integration.

## Testbench Coverage

The repository contains focused Verilog testbenches under `serpent_says/tb/`:

| Testbench | Coverage |
| --- | --- |
| `tb_vga_controller.v` | visible area, horizontal porch/sync/back-porch timing, vertical sync/back-porch timing, and frame wrap |
| `tb_clk_divider.v` | basic divide-by-4 clock behavior |
| `tb_turn_request_mux.v` | no-input, button-only, voice-only, simultaneous input, and button-priority cases |
| `tb_snake_game_core.v` | FSM transitions, player movement, turn latch, wall collision/life loss/respawn, food collection, restart from terminal |
| `tb_pixel_renderer_priority.v` | inactive-video black, info bar priority, sprite transparency, head/body priority, food, obstacles, grass, background, border, game-over banner, title splash geometry, and lower background |
| `tb_info_bar_renderer.v` | current HUD row positions, score digits, mode/source/command text, state text, blue/red heart priority, and hidden hearts when lives are zero |
| `tb_feature_pipeline_addr.v` | feature pipeline frame-buffer address delay alignment and non-X windowing path |
| `tb_command_filter.v` | disabled-mode raw output visibility, accepted left/right commands, cooldown suppression, class/confidence/margin rejection, and `ml_alive` knownness |
| `tb_top_serpent_says.v` | integration smoke: reset/IDLE, start to playing, LED/seven-seg no-X checks, pause/resume, basic button movement/VGA no-X, voice mode sanity, debug LED mode |

These testbenches are simulation evidence for several important integration assumptions, but they do not fully verify the CNN math, all collision combinations, all sprite overlays, or the Vivado implementation result.

## Replication Checklist

To recreate this system:

1. Create a Vivado RTL project targeting `xc7a100tcsg324-1`.
2. Add every file in `serpent_says/rtl/` as design source, including `arena_map.vh` and `grass_map.vh`.
3. Set `top_serpent_says` as the synthesis top.
4. Add every required `.mem` file under `serpent_says/Sprites/mem/` so `$readmemh` calls can resolve during simulation/synthesis.
5. Add `serpent_says/xdc/top.xdc` as the active constraints file.
6. Keep the top-level port names unchanged unless constraints are updated to match.
7. Ensure the Verilog include path allows `` `include "arena_map.vh" `` and `` `include "grass_map.vh" `` from modules that include them.
8. Preserve the 25 MHz system/pixel-clock assumption unless VGA timing, PDM settings, game tick counts, animation counts, and XADC timings are recalculated.
9. Preserve sprite dimensions and ROM depths unless `top_serpent_says.v` and `pixel_renderer.v` address calculations are updated.
10. Preserve ML feature vector order: 16 mel bins by 16 frames, flattened in mel-major order.
11. Run the included testbenches, especially `tb_top_serpent_says`, `tb_snake_game_core`, `tb_pixel_renderer_priority`, and `tb_feature_pipeline_addr`.
12. If Vivado has stale generated sources or incremental checkpoints in the project database, run `serpent_says/scripts/repair_vivado_project.tcl` before rebuilding.
13. Generate bitstream from the current top, not the non-canonical stubs under `serpent_says.srcs/sources_1/new/`.

## File-by-File RTL Reference

### `arena_map.vh`

Defines the shared obstacle layout and the `obstacle_at(tx, ty)` function. It is an include file, not a module. Keep this file consistent because it is compiled into collision detection, rival AI safety checks, and rendering.

### `grass_map.vh`

Defines the sparse decorative grass tile layout and the `grass_at(tx, ty)` function. It is included by `pixel_renderer.v`. The selected tiles avoid static obstacles, food candidates, and primary/alternate snake spawn positions.

### `binary_dense_layer.v`

Reusable BNN dense layer. It reads packed binary weights, scale, and bias ROMs. In int8-input mode it iterates each input and adds or subtracts the signed input based on the weight bit. In binary-input mode it processes 8-bit chunks, XNORs input bits with weight bits, popcounts matches, and accumulates `2*popcount - 8`. It then applies `(acc * scale + bias) >>> FRAC_BITS`. With sign activation it writes packed output bits; without activation it writes clamped int8 outputs.

### `bnn_inference.v`

Optional two-layer BNN inference engine. Layer 1 maps 256 int8 features to 128 binary hidden bits using `binary_dense_layer`. Layer 2 maps those bits to three int8 logits. Its FSM runs layer 1, then layer 2, then argmax.

### `button_input_adapter.v`

Synchronizes raw button inputs with two flip-flops, detects rising edges, maps left/right buttons to one-cycle relative-turn requests, and maps center button to a one-cycle start/restart pulse. Left has priority if both turn buttons rise together.

### `cic_decimator.v`

Fourth-order CIC decimator for PDM-to-PCM conversion. Integrator stages run at PDM strobe rate; comb stages run once per decimation period. Produces signed 16-bit PCM and a one-cycle valid strobe.

### `clk_divider.v`

2-bit counter clock divider. `clk_out = div_cnt[1]`, so 100 MHz becomes 25 MHz.

### `cnn_inference.v`

Quantized CNN inference engine. Owns intermediate feature-map buffers, controls convolution/pooling/dense layers, and emits class, confidence, second-best confidence, and valid. The sequencer is strictly serial: each layer starts after the previous layer's `done`.

### `command_filter.v`

Post-processes CNN/BNN class outputs. It maps raw classes to game command encodings, applies voice enable, confidence threshold, margin threshold, left/right class filtering, and cooldown suppression. It also keeps last accepted voice command and toggles an ML-alive debug bit on raw inference.

### `context_buffer.v`

Rolling 16-frame by 16-mel-bin feature buffer. Writes raw log-mel values into a circular frame slot. Reads out a 256-element feature vector in mel-major order to match the training/export pipeline.

### `conv2d_layer.v`

Sequential same-padded convolution layer. Addressing is row-major/channel-last. Weights are output-channel-major. It prefetches the next input while accumulating the previous product, handles out-of-bounds kernel positions as zero, adds bias, shifts, applies ReLU, clamps, and writes one int8 output at a time.

### `dense_layer.v`

Sequential fully connected layer for input vectors up to 256 entries. It uses output-major int8 weights and int32 biases, accumulates one output neuron at a time, shifts and optionally ReLUs, then clamps to int8.

### `dense_layer_wide.v`

Same behavior as `dense_layer.v`, but with a 16-bit input address for wider inputs such as the CNN's 512-element flattened pool2 output.

### `feature_pipeline.v`

Controls per-frame feature extraction. It reads a PCM frame, applies the Hann window, loads the FFT, runs FFT, runs mel/log processing, then writes 16 raw log-mel values to the context buffer. It owns the important one-cycle delayed frame-buffer address alignment.

### `fft_256.v`

Sequential fixed-point FFT. Loads samples into bit-reversed addresses, runs eight radix-2 stages, uses external Q1.15 twiddle ROMs, scales butterflies by one bit per stage, and exposes complex FFT bins.

### `frame_buffer.v`

Double-buffered PCM frame collector. Uses 256-sample frames and 128-sample hop by default. A completed read bank stays available while the next active bank is filled. After consumption it copies overlap samples into the new active bank.

### `game_tick_gen.v`

Programmable tick counter. It emits `game_tick` only while enabled, selects button or voice tick period based on `voice_mode_en`, and resets its counter when disabled, when mode changes, or when a tick fires.

### `info_bar_renderer.v`

Renders the top 100 pixels. It computes the current HUD text rows, split score display, blue/red heart positions, dynamic command/state strings, glyph addresses, blinking paused/respawn text, and final `info_rgb`. It has priority over the main pixel renderer.

### `led_status_driver.v`

Maps game/debug/voice state into 13 LEDs. Normal mode shows lives, pause, terminal, voice mode, and accepted voice activity. Debug mode shows FSM, pulses, collisions, eating events, and directions.

### `maxpool2d.v`

Sequential 2x2 stride-2 max-pooling layer. It reads four source values per output position/channel and writes the signed maximum.

### `mel_power.v`

Computes FFT power, applies a 16-bin mel filterbank, and converts accumulators to approximate log2 values. Filter coefficients come from `mel_coeffs.mem`; log approximation uses leading-one detection and a small fractional LUT.

### `ml_top_bnn.v`

Optional alternate audio-to-command top using BNN inference. It shares PDM, CIC, frame, feature, context, and normalization logic with the CNN path, but swaps `bnn_inference` in place of `cnn_inference`. It is not instantiated by `top_serpent_says.v`.

### `ml_top_cnn.v`

Active audio-to-command top. It connects microphone capture through feature extraction, context buffering, normalization, CNN inference, and command filtering. Its FSM waits for a completed context frame, starts normalization, then starts inference, and returns idle when inference completes.

### `normalizer.v`

Two-pass feature normalizer and quantizer. It first finds the max feature, then subtracts that max from every feature, applies per-feature Q8.8 scale/offset, rounds, and clamps to int8.

### `pdm_capture.v`

Generates the PDM clock output and captures synchronized microphone data on generated rising edges. Emits a valid pulse without creating a second internal clock domain.

### `pixel_renderer.v`

Main VGA pixel compositor. Converts pixel coordinates to tile coordinates, addresses sprite ROMs, detects entity and grass-map hits, applies priority, handles overlays, transparent sprite pixels, animation effects, temperature backgrounds, borders, and final 4-bit RGB channels.

### `rival_ai_simple.v`

Combinational rival controller. It evaluates forward, left, and right candidate moves, filters unsafe tiles using walls/obstacles/snakes, ranks safe moves by Manhattan distance to food, and outputs the chosen absolute direction.

### `seven_seg_driver.v`

Eight-digit active-low seven-segment multiplexer. Displays player and rival score/lives with blank separators and turns the decimal point off.

### `snake_game_core.v`

Owns the game FSM, snake registers, food index, pending player turn latch, movement, collisions, lives, growth, death animation flags, respawn, terminal-state resolution, and debug pulses.

### `sprite_rom.v`

Generic `$readmemh` ROM wrapper. It can infer distributed ROM for small sprites or block ROM with registered output for large overlays.

### `temp_background_ctrl.v`

Reads the Artix-7 XADC temperature channel using the DRP interface. It filters readings, captures a baseline on first reading or game start, applies thresholds with hysteresis, and outputs cool/neutral/hot background state.

### `text_glyph_rom.v`

Combinational 5x7 bitmap font in a 6x8 character cell. Used by `info_bar_renderer` for all text rows.

### `top_serpent_says.v`

Active system top. Wires all subsystems, synchronizes switches, stretches voice activity, selects directional/eating sprites, muxes temperature grass, instantiates HUD/title/terminal ROMs, registers VGA outputs, and maps final subsystem outputs to external ports.

### `turn_request_mux.v`

Combines button and voice turn requests. Button events override simultaneous voice events and source encoding records button or voice.

### `vga_controller.v`

Pixel counter and sync generator for 640x480 VGA. Produces `pixel_x`, `pixel_y`, `video_active`, active-low `hsync`, and active-low `vsync`.

## Feature-to-File Traceability Matrix

| Feature | Primary implementation | Supporting files/assets |
| --- | --- | --- |
| 25 MHz system/pixel clock | `clk_divider.v` | `top.xdc`, `top_serpent_says.v` |
| VGA sync and coordinates | `vga_controller.v` | `pixel_renderer.v`, `info_bar_renderer.v` |
| Start/restart button | `button_input_adapter.v`, `snake_game_core.v` | `top_serpent_says.v` |
| Pause switch | `top_serpent_says.v`, `snake_game_core.v` | `info_bar_renderer.v`, `led_status_driver.v` |
| Button turning | `button_input_adapter.v`, `turn_request_mux.v`, `snake_game_core.v` | `tb_turn_request_mux.v` |
| Voice turning | `ml_top_cnn.v`, `command_filter.v`, `turn_request_mux.v` | ML `.mem` files |
| Different game speed for voice mode | `game_tick_gen.v` | `top_serpent_says.v` |
| Player/rival movement | `snake_game_core.v` | `rival_ai_simple.v` |
| Rival food-seeking AI | `rival_ai_simple.v` | `arena_map.vh` |
| Obstacle map | `arena_map.vh` | `snake_game_core.v`, `rival_ai_simple.v`, `pixel_renderer.v`, `Obstacle.mem` |
| Collision rules | `snake_game_core.v` | `arena_map.vh`, `tb_snake_game_core.v` |
| Food placement/growth | `snake_game_core.v` | `apple.mem`, `pixel_renderer.v` |
| Lives and respawn | `snake_game_core.v` | `led_status_driver.v`, `seven_seg_driver.v`, `info_bar_renderer.v` |
| Victory and game-over | `snake_game_core.v`, `pixel_renderer.v` | `victory.mem`, `gameOver.mem` |
| Title screen | `snake_game_core.v`, `pixel_renderer.v` | `Title.mem` |
| Info bar text | `info_bar_renderer.v` | `text_glyph_rom.v` |
| Life icons | `info_bar_renderer.v` | `Heart_Blue.mem`, `Heart_Red.mem`, `sprite_rom.v` |
| Head and eating sprites | `top_serpent_says.v`, `pixel_renderer.v` | directional snake `.mem` files |
| Temperature background and grass | `temp_background_ctrl.v`, `pixel_renderer.v` | XADC primitive, `grass_map.vh`, `Grass_Cold.mem`, `Grass_Normal.mem`, `Grass_Hot.mem` |
| LED status/debug | `led_status_driver.v` | `top_serpent_says.v` |
| Seven-segment score/lives | `seven_seg_driver.v` | `top_serpent_says.v` |
| PDM microphone clock/data | `pdm_capture.v` | `top.xdc` |
| PCM conversion | `cic_decimator.v` | `pdm_capture.v` |
| Audio frame buffering | `frame_buffer.v` | `feature_pipeline.v` |
| Hann window and FFT | `feature_pipeline.v`, `fft_256.v` | `hann_window.mem`, `tw_cos.mem`, `tw_sin.mem` |
| Mel/log features | `mel_power.v` | `mel_coeffs.mem` |
| Rolling ML context | `context_buffer.v` | `ml_top_cnn.v` |
| Feature quantization | `normalizer.v` | `norm_scale.mem`, `norm_offset.mem` |
| CNN keyword spotting | `cnn_inference.v` | conv/dense weight and bias `.mem` files |
| Optional BNN keyword spotting | `ml_top_bnn.v`, `bnn_inference.v`, `binary_dense_layer.v` | binary weights, scale, bias `.mem` files |
| Integration smoke coverage | `tb_top_serpent_says.v` | all active subsystems |
