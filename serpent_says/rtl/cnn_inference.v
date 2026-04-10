// ============================================================================
// CNN Inference Engine
// ============================================================================
// Implements the quantized CNN for keyword spotting:
//
//   Input (256 x int8) -> Reshape(16,16,1)
//   -> Conv1(3x3, 1->16, ReLU) -> MaxPool(2x2) -> [8x8x16]
//   -> Conv2(3x3, 16->32, ReLU) -> MaxPool(2x2) -> [4x4x32]
//   -> Flatten(512) -> Dense(32, ReLU) -> Dense(3, argmax)
//
// Interface matches kws_inference.v / bnn_inference.v (drop-in replacement):
//   - Reads 256 int8 features from external buffer via feat_addr/feat_data
//   - Outputs kws_class[1:0], kws_conf[7:0], kws_second[7:0], kws_valid
//
// Internal feature map buffers:
//   - fmap_a: 4096 bytes (conv1 output, then reused for conv2 output)
//   - fmap_b: 2048 bytes (pool1 output, read by conv2)
//   - fmap_c:  512 bytes (pool2 output, read by dense hidden)
//
// Each buffer has exactly one write port (muxed) and one read port
// to ensure clean BRAM inference.
// ============================================================================

module cnn_inference #(
    parameter FEAT_DIM    = 256,
    parameter NUM_CLASSES = 3,
    // Accumulator shifts per layer
    parameter SHIFT_C1 = 7,
    parameter SHIFT_C2 = 10,
    parameter SHIFT_H  = 7,
    parameter SHIFT_O  = 7,
    // Weight/bias ROM files
    parameter C1_W_FILE = "conv1_weights.mem",
    parameter C1_B_FILE = "conv1_bias.mem",
    parameter C2_W_FILE = "conv2_weights.mem",
    parameter C2_B_FILE = "conv2_bias.mem",
    parameter H_W_FILE  = "cnn_hidden_weights.mem",
    parameter H_B_FILE  = "cnn_hidden_bias.mem",
    parameter O_W_FILE  = "cnn_output_weights.mem",
    parameter O_B_FILE  = "cnn_output_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Control
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input feature vector (256 x int8, read port)
    output wire [7:0]  feat_addr,
    input  wire signed [7:0] feat_data,
    // Classification output
    output reg  [1:0]  kws_class,
    output reg  signed [7:0] kws_conf,
    output reg  signed [7:0] kws_second,   // Second-highest logit (for margin)
    output reg         kws_valid
);

    // ════════════════════════════════════════════════════════════════
    // Feature map buffer A (4096 bytes)
    // Written by: conv1 OR conv2 (muxed, never simultaneous)
    // Read by:    pool1 OR pool2 (muxed, never simultaneous)
    // Async read (distributed RAM) — avoids 1-cycle BRAM read latency
    // that would cause pipeline misalignment in conv2d/maxpool modules.
    // ════════════════════════════════════════════════════════════════
    reg signed [7:0] fmap_a [0:4095];
    reg [11:0] fmap_a_raddr;
    wire signed [7:0] fmap_a_rdata = fmap_a[fmap_a_raddr];
    reg [11:0] fmap_a_waddr;
    reg signed [7:0] fmap_a_wdata;
    reg        fmap_a_we;

    always @(posedge clk) begin
        if (fmap_a_we)
            fmap_a[fmap_a_waddr] <= fmap_a_wdata;
    end

    // ════════════════════════════════════════════════════════════════
    // Feature map buffer B (2048 bytes)
    // Written by: pool1 (only)
    // Read by:    conv2 (only)
    // ════════════════════════════════════════════════════════════════
    reg signed [7:0] fmap_b [0:2047];
    reg [10:0] fmap_b_raddr;
    wire signed [7:0] fmap_b_rdata = fmap_b[fmap_b_raddr];

    always @(posedge clk) begin
        if (p1_out_we)
            fmap_b[p1_out_addr[10:0]] <= p1_out_data;
    end

    // ════════════════════════════════════════════════════════════════
    // Feature map buffer C (512 bytes)
    // Written by: pool2 (only)
    // Read by:    dense_hidden (only)
    // ════════════════════════════════════════════════════════════════
    reg signed [7:0] fmap_c [0:511];
    reg [8:0] fmap_c_raddr;
    wire signed [7:0] fmap_c_rdata = fmap_c[fmap_c_raddr];

    always @(posedge clk) begin
        if (p2_out_we)
            fmap_c[p2_out_addr[8:0]] <= p2_out_data;
    end

    // ════════════════════════════════════════════════════════════════
    // Small buffers (distributed RAM / registers — no BRAM needed)
    // ════════════════════════════════════════════════════════════════
    // hidden buffer (32 x int8) — async read is fine for distributed RAM
    reg signed [7:0] hidden_buf [0:31];

    // logit buffer (3 x int8) — registers
    reg signed [7:0] logit_buf [0:2];

    // ════════════════════════════════════════════════════════════════
    // Conv1: 16x16x1 -> 16x16x16
    // ════════════════════════════════════════════════════════════════
    wire        c1_busy, c1_done;
    wire [15:0] c1_in_addr;
    wire signed [7:0] c1_out_data;
    wire [15:0] c1_out_addr;
    wire        c1_out_we;
    reg         c1_start;

    assign feat_addr = c1_in_addr[7:0];

    conv2d_layer #(
        .IN_H(16), .IN_W(16), .C_IN(1), .C_OUT(16),
        .KH(3), .KW(3), .SHIFT(SHIFT_C1),
        .W_FILE(C1_W_FILE), .B_FILE(C1_B_FILE)
    ) u_conv1 (
        .clk(clk), .rst_n(rst_n),
        .start(c1_start), .busy(c1_busy), .done(c1_done),
        .in_addr(c1_in_addr), .in_data(feat_data),
        .out_data(c1_out_data), .out_addr(c1_out_addr), .out_we(c1_out_we)
    );

    // ════════════════════════════════════════════════════════════════
    // MaxPool1: 16x16x16 -> 8x8x16
    // ════════════════════════════════════════════════════════════════
    wire        p1_busy, p1_done;
    wire [15:0] p1_in_addr;
    wire signed [7:0] p1_out_data;
    wire [15:0] p1_out_addr;
    wire        p1_out_we;
    reg         p1_start;

    maxpool2d #(
        .IN_H(16), .IN_W(16), .CHANNELS(16)
    ) u_pool1 (
        .clk(clk), .rst_n(rst_n),
        .start(p1_start), .busy(p1_busy), .done(p1_done),
        .in_addr(p1_in_addr), .in_data(fmap_a_rdata),
        .out_data(p1_out_data), .out_addr(p1_out_addr), .out_we(p1_out_we)
    );

    // ════════════════════════════════════════════════════════════════
    // Conv2: 8x8x16 -> 8x8x32
    // ════════════════════════════════════════════════════════════════
    wire        c2_busy, c2_done;
    wire [15:0] c2_in_addr;
    wire signed [7:0] c2_out_data;
    wire [15:0] c2_out_addr;
    wire        c2_out_we;
    reg         c2_start;

    conv2d_layer #(
        .IN_H(8), .IN_W(8), .C_IN(16), .C_OUT(32),
        .KH(3), .KW(3), .SHIFT(SHIFT_C2),
        .W_FILE(C2_W_FILE), .B_FILE(C2_B_FILE)
    ) u_conv2 (
        .clk(clk), .rst_n(rst_n),
        .start(c2_start), .busy(c2_busy), .done(c2_done),
        .in_addr(c2_in_addr), .in_data(fmap_b_rdata),
        .out_data(c2_out_data), .out_addr(c2_out_addr), .out_we(c2_out_we)
    );

    // ════════════════════════════════════════════════════════════════
    // MaxPool2: 8x8x32 -> 4x4x32
    // ════════════════════════════════════════════════════════════════
    wire        p2_busy, p2_done;
    wire [15:0] p2_in_addr;
    wire signed [7:0] p2_out_data;
    wire [15:0] p2_out_addr;
    wire        p2_out_we;
    reg         p2_start;

    maxpool2d #(
        .IN_H(8), .IN_W(8), .CHANNELS(32)
    ) u_pool2 (
        .clk(clk), .rst_n(rst_n),
        .start(p2_start), .busy(p2_busy), .done(p2_done),
        .in_addr(p2_in_addr), .in_data(fmap_a_rdata),
        .out_data(p2_out_data), .out_addr(p2_out_addr), .out_we(p2_out_we)
    );

    // ════════════════════════════════════════════════════════════════
    // Dense Hidden: 512 -> 32, ReLU
    // ════════════════════════════════════════════════════════════════
    wire        dh_busy, dh_done;
    wire signed [7:0] dh_in_data;
    wire signed [7:0] dh_out_data;
    wire [7:0]  dh_out_addr;
    wire        dh_out_we;
    reg         dh_start;

    assign dh_in_data = fmap_c_rdata;

    wire [15:0] dh_in_addr_wide;

    dense_layer_wide #(
        .IN_N(512), .OUT_N(32),
        .ACTIVATION(1), .SHIFT(SHIFT_H),
        .W_FILE(H_W_FILE), .B_FILE(H_B_FILE)
    ) u_dense_hidden (
        .clk(clk), .rst_n(rst_n),
        .start(dh_start), .busy(dh_busy), .done(dh_done),
        .in_addr(dh_in_addr_wide), .in_data(dh_in_data),
        .out_data(dh_out_data), .out_addr(dh_out_addr), .out_we(dh_out_we)
    );

    // Store hidden output (small — distributed RAM)
    always @(posedge clk) begin
        if (dh_out_we)
            hidden_buf[dh_out_addr[4:0]] <= dh_out_data;
    end

    // ════════════════════════════════════════════════════════════════
    // Dense Output: 32 -> 3, no activation
    // ════════════════════════════════════════════════════════════════
    wire        do_busy, do_done;
    wire [7:0]  do_in_addr;
    wire signed [7:0] do_in_data;
    wire signed [7:0] do_out_data;
    wire [7:0]  do_out_addr;
    wire        do_out_we;
    reg         do_start;

    assign do_in_data = hidden_buf[do_in_addr[4:0]];

    dense_layer #(
        .IN_N(32), .OUT_N(NUM_CLASSES),
        .ACTIVATION(0), .SHIFT(SHIFT_O),
        .W_FILE(O_W_FILE), .B_FILE(O_B_FILE)
    ) u_dense_output (
        .clk(clk), .rst_n(rst_n),
        .start(do_start), .busy(do_busy), .done(do_done),
        .in_addr(do_in_addr), .in_data(do_in_data),
        .out_data(do_out_data), .out_addr(do_out_addr), .out_we(do_out_we)
    );

    // Store logits (3 registers)
    always @(posedge clk) begin
        if (do_out_we)
            logit_buf[do_out_addr[1:0]] <= do_out_data;
    end

    // ════════════════════════════════════════════════════════════════
    // MUX: fmap_a write port (conv1 or conv2, never simultaneous)
    // ════════════════════════════════════════════════════════════════
    always @(*) begin
        if (c1_out_we) begin
            fmap_a_we    = 1'b1;
            fmap_a_waddr = c1_out_addr[11:0];
            fmap_a_wdata = c1_out_data;
        end else if (c2_out_we) begin
            fmap_a_we    = 1'b1;
            fmap_a_waddr = c2_out_addr[11:0];
            fmap_a_wdata = c2_out_data;
        end else begin
            fmap_a_we    = 1'b0;
            fmap_a_waddr = 12'd0;
            fmap_a_wdata = 8'sd0;
        end
    end

    // ════════════════════════════════════════════════════════════════
    // MUX: fmap_a read address (pool1 or pool2, never simultaneous)
    // ════════════════════════════════════════════════════════════════
    always @(*) begin
        if (p1_busy)
            fmap_a_raddr = p1_in_addr[11:0];
        else
            fmap_a_raddr = p2_in_addr[11:0];
    end

    // fmap_b read address (conv2 only)
    always @(*) begin
        fmap_b_raddr = c2_in_addr[10:0];
    end

    // fmap_c read address (dense_hidden only)
    always @(*) begin
        fmap_c_raddr = dh_in_addr_wide[8:0];
    end

    // ════════════════════════════════════════════════════════════════
    // Sequencer FSM
    // ════════════════════════════════════════════════════════════════
    localparam SEQ_IDLE   = 4'd0;
    localparam SEQ_CONV1  = 4'd1;
    localparam SEQ_POOL1  = 4'd2;
    localparam SEQ_CONV2  = 4'd3;
    localparam SEQ_POOL2  = 4'd4;
    localparam SEQ_DENSE1 = 4'd5;
    localparam SEQ_DENSE2 = 4'd6;
    localparam SEQ_ARGMAX = 4'd7;

    reg [3:0] seq_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_state  <= SEQ_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            c1_start   <= 1'b0;
            p1_start   <= 1'b0;
            c2_start   <= 1'b0;
            p2_start   <= 1'b0;
            dh_start   <= 1'b0;
            do_start   <= 1'b0;
            kws_class  <= 2'd0;
            kws_conf   <= 8'sd0;
            kws_second <= 8'sd0;
            kws_valid  <= 1'b0;
        end else begin
            done      <= 1'b0;
            c1_start  <= 1'b0;
            p1_start  <= 1'b0;
            c2_start  <= 1'b0;
            p2_start  <= 1'b0;
            dh_start  <= 1'b0;
            do_start  <= 1'b0;
            kws_valid <= 1'b0;

            case (seq_state)
                SEQ_IDLE: begin
                    if (start) begin
                        seq_state <= SEQ_CONV1;
                        c1_start  <= 1'b1;
                        busy      <= 1'b1;
                    end
                end

                SEQ_CONV1: begin
                    if (c1_done) begin
                        seq_state <= SEQ_POOL1;
                        p1_start  <= 1'b1;
                    end
                end

                SEQ_POOL1: begin
                    if (p1_done) begin
                        seq_state <= SEQ_CONV2;
                        c2_start  <= 1'b1;
                    end
                end

                SEQ_CONV2: begin
                    if (c2_done) begin
                        seq_state <= SEQ_POOL2;
                        p2_start  <= 1'b1;
                    end
                end

                SEQ_POOL2: begin
                    if (p2_done) begin
                        seq_state <= SEQ_DENSE1;
                        dh_start  <= 1'b1;
                    end
                end

                SEQ_DENSE1: begin
                    if (dh_done) begin
                        seq_state <= SEQ_DENSE2;
                        do_start  <= 1'b1;
                    end
                end

                SEQ_DENSE2: begin
                    if (do_done) begin
                        seq_state <= SEQ_ARGMAX;
                    end
                end

                SEQ_ARGMAX: begin
                    // Argmax over 3 logits + second-best for margin
                    if (logit_buf[0] >= logit_buf[1] && logit_buf[0] >= logit_buf[2]) begin
                        kws_class  <= 2'd0;
                        kws_conf   <= logit_buf[0];
                        kws_second <= (logit_buf[1] >= logit_buf[2]) ? logit_buf[1] : logit_buf[2];
                    end else if (logit_buf[1] >= logit_buf[0] && logit_buf[1] >= logit_buf[2]) begin
                        kws_class  <= 2'd1;
                        kws_conf   <= logit_buf[1];
                        kws_second <= (logit_buf[0] >= logit_buf[2]) ? logit_buf[0] : logit_buf[2];
                    end else begin
                        kws_class  <= 2'd2;
                        kws_conf   <= logit_buf[2];
                        kws_second <= (logit_buf[0] >= logit_buf[1]) ? logit_buf[0] : logit_buf[1];
                    end

                    kws_valid <= 1'b1;
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    seq_state <= SEQ_IDLE;
                end

                default: seq_state <= SEQ_IDLE;
            endcase
        end
    end

endmodule
