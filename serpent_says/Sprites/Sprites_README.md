# Sprite Tile `.mem` Files

Image assets for the VGA renderer, stored as flat hex-text ROMs that can be loaded with Verilog `$readmemh`.

## Common format

Every sprite `.mem` file in this folder uses the same encoding:

- **Color:** 3 hex digits per line = 12-bit RGB444 (`RGB`, 4 bits per channel, range `0`-`F`)
- **One pixel per line**, row-major, top-left to bottom-right
- **File length = width * height** (no header, no padding)
- **Encoding:** ASCII, LF line endings
- `000` is used as the transparent / background color in sprites that need a key color
- Compatible with Verilog `$readmemh`; expand the 12-bit value directly onto the 4-4-4 VGA DAC pins

Generic load pattern:

```verilog
reg [11:0] sprite_rom [0:N-1];      // N = width * height
initial $readmemh("Sprite.mem", sprite_rom);
// per-pixel: addr = py * WIDTH + px;
```

## Files

| File | Dimensions | Lines | Notes |
| --- | --- | --- | --- |
| `Grass_Cold.mem` | 16 x 16 | 256 | Cool / frosty teal-tinted green |
| `Grass_Normal.mem` | 16 x 16 | 256 | Standard forest green |
| `Grass_Hot.mem` | 16 x 16 | 256 | Warm / sun-bleached yellow-green |
| `Heart_Blue.mem` | 13 x 13 | 169 | Blue heart icon (HUD life indicator) |
| `Heart_Red.mem` | 13 x 13 | 169 | Red heart icon (HUD life indicator) |
| `Title.mem` | 300 x 300 | 90000 | Title-screen splash image |

---

## Grass tiles (`Grass_Cold` / `Grass_Normal` / `Grass_Hot`)

Three 16x16 grass tile variants for use as a playfield background. All three share the same pixel pattern; only the 5-color palette is shifted, so they tile identically and can be swapped at runtime.

Palette (darkest -> highlight; index 0 is reserved / unused by the current pattern):

| Index | Cold | Normal | Hot |
| --- | --- | --- | --- |
| 0 (reserved) | `021` | `020` | `130` |
| 1 (dark) | `032` | `030` | `240` |
| 2 (mid) | `043` | `040` | `350` |
| 3 (bright) | `154` | `150` | `460` |
| 4 (highlight / blade tip) | `165` | `161` | `571` |

Per-pixel address for a tile placed at screen origin `(tile_x*16, tile_y*16)`:

```
addr = (py & 4'hF) * 16 + (px & 4'hF);   // 0..255
```

```verilog
reg [11:0] grass_rom [0:255];
initial $readmemh("Grass_Normal.mem", grass_rom);
```

---

## Heart icons (`Heart_Blue` / `Heart_Red`)

13 x 13 HUD sprites used as life / status indicators.

- 169 lines per file
- `000` = transparent (skip when blitting; do not write to the framebuffer)
- `111` = dark outline
- `fff` = white specular highlight
- Body fill: `00f` / `008` (blue variant) or analogous reds (red variant)

Per-pixel address for a heart placed at screen origin `(x0, y0)`:

```
addr = (py - y0) * 13 + (px - x0);   // 0..168
```

```verilog
reg [11:0] heart_rom [0:168];
initial $readmemh("Heart_Blue.mem", heart_rom);
```

---

## Title splash (`Title.mem`)

Full-resolution title-screen image.

- **Dimensions:** 300 x 300 pixels
- **File length:** 90000 lines (~350 KB on disk)
- Same RGB444 row-major encoding as the other sprites

Per-pixel address for the splash placed at screen origin `(x0, y0)`:

```
addr = (py - y0) * 300 + (px - x0);   // 0..89999
```

Because of its size this ROM will not fit in LUT memory; instantiate it as a Block RAM (e.g. Vivado Block Memory Generator with a `.coe` or `.mem` init file, or `(* ram_style = "block" *)` on the inferred array):

```verilog
(* ram_style = "block" *)
reg [11:0] title_rom [0:89999];
initial $readmemh("Title.mem", title_rom);
```
