`timescale 1ns / 1ps

module sprite_rom #(
    parameter SPRITE_FILE   = "apple.mem",
    parameter DEPTH         = 256,
    parameter WIDTH         = 16,
    parameter DATA_WIDTH    = 12,
    parameter USE_BLOCK_ROM = 0
)(
    input  wire                         clk,
    input  wire [$clog2(DEPTH)-1:0]     addr,
    output wire [DATA_WIDTH-1:0]        data
);

    generate
        if (USE_BLOCK_ROM) begin : blk_rom
            (* rom_style = "block" *)
            reg [DATA_WIDTH-1:0] rom [0:DEPTH-1];
            initial $readmemh(SPRITE_FILE, rom);
            reg [DATA_WIDTH-1:0] data_reg;
            always @(posedge clk)
                data_reg <= rom[addr];
            assign data = data_reg;
        end else begin : dist_rom
            (* rom_style = "distributed" *)
            reg [DATA_WIDTH-1:0] rom [0:DEPTH-1];
            initial $readmemh(SPRITE_FILE, rom);
            assign data = rom[addr];
        end
    endgenerate

endmodule
