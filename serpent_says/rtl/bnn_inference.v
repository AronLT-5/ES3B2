// ============================================================================
// BNN Inference Engine
// ============================================================================
// Two-layer BNN matching the Python BNN model:
//   Layer 1 (hidden): 256 int8 inputs -> 128 binary outputs (sign activation)
//   Layer 2 (output):  128 binary inputs -> 3 int8 logits (no activation)
//
// Key differences from int8 MLP kws_inference.v:
//   - Weights are 1-bit packed (not int8), stored in far less memory
//   - Layer 1: int8 x binary = selective add/subtract (no DSP needed)
//   - Layer 2: binary x binary = XNOR + popcount (no DSP needed)
//   - BatchNorm folded into per-channel scale (Q8.8) + bias (Q16.8)
//   - 0 DSP blocks used
//
// Computes argmax over 3 output logits and reports:
//   - kws_class[1:0]: 00=left, 01=right, 10=other
//   - kws_conf[7:0]:  max logit value (raw, for thresholding)
//   - kws_valid:       classification valid strobe
// ============================================================================

module bnn_inference #(
    parameter FEAT_DIM    = 256,
    parameter HIDDEN_DIM  = 128,
    parameter NUM_CLASSES = 3,
    parameter L1_FRAC     = 8,    // Fractional bits for hidden layer scale
    parameter L2_FRAC     = 8,    // Fractional bits for output layer scale
    parameter L1_BYTES_PER = 32,  // ceil(FEAT_DIM / 8)
    parameter L2_BYTES_PER = 16,  // ceil(HIDDEN_DIM / 8)
    parameter W1_FILE     = "hidden_weights_bin.mem",
    parameter S1_FILE     = "hidden_scale.mem",
    parameter B1_FILE     = "hidden_bias.mem",
    parameter W2_FILE     = "output_weights_bin.mem",
    parameter S2_FILE     = "output_scale.mem",
    parameter B2_FILE     = "output_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Control
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input feature vector (read port — int8 from normalizer)
    output wire [7:0]  feat_addr,
    input  wire signed [7:0] feat_data,
    // Classification output
    output reg  [1:0]  kws_class,
    output reg  signed [7:0] kws_conf,
    output reg         kws_valid
);

    // ── Hidden layer binary output ──
    wire [HIDDEN_DIM-1:0] hidden_bits;

    // ── Output logits buffer (3 x 8 bits) ──
    reg signed [7:0] logit_buf [0:NUM_CLASSES-1];

    // ── Layer 1: 256 int8 -> 128 binary (sign activation) ──
    wire        l1_busy, l1_done;
    wire [7:0]  l1_in_addr;
    wire signed [7:0] l1_out_data;  // Not used (sign activation -> binary)
    wire [7:0]  l1_out_addr;
    wire        l1_out_we;
    reg         l1_start;

    binary_dense_layer #(
        .IN_N           (FEAT_DIM),
        .OUT_N          (HIDDEN_DIM),
        .ACTIVATION     (1),          // Sign activation -> binary output
        .FRAC_BITS      (L1_FRAC),
        .BYTES_PER_NEURON(L1_BYTES_PER),
        .W_FILE         (W1_FILE),
        .SCALE_FILE     (S1_FILE),
        .BIAS_FILE      (B1_FILE)
    ) u_layer1 (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (l1_start),
        .busy         (l1_busy),
        .done         (l1_done),
        .in_addr      (l1_in_addr),
        .in_data      (feat_data),
        .in_bits      ({FEAT_DIM{1'b0}}),     // Not used for layer 1
        .in_is_binary (1'b0),                 // Layer 1 takes int8 input
        .out_data     (l1_out_data),
        .out_addr     (l1_out_addr),
        .out_we       (l1_out_we),
        .out_bits     (hidden_bits)
    );

    // ── Layer 2: 128 binary -> 3 int8 logits (no activation) ──
    wire        l2_busy, l2_done;
    wire [7:0]  l2_in_addr;        // Not used for binary input
    wire signed [7:0] l2_out_data;
    wire [7:0]  l2_out_addr;
    wire        l2_out_we;
    reg         l2_start;

    binary_dense_layer #(
        .IN_N           (HIDDEN_DIM),
        .OUT_N          (NUM_CLASSES),
        .ACTIVATION     (0),          // No activation — output raw int8 logits
        .FRAC_BITS      (L2_FRAC),
        .BYTES_PER_NEURON(L2_BYTES_PER),
        .W_FILE         (W2_FILE),
        .SCALE_FILE     (S2_FILE),
        .BIAS_FILE      (B2_FILE)
    ) u_layer2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (l2_start),
        .busy         (l2_busy),
        .done         (l2_done),
        .in_addr      (l2_in_addr),
        .in_data      (8'sd0),              // Not used for binary input
        .in_bits      (hidden_bits),
        .in_is_binary (1'b1),               // Layer 2 takes binary input
        .out_data     (l2_out_data),
        .out_addr     (l2_out_addr),
        .out_we       (l2_out_we),
        .out_bits     ()                    // Not used (no sign activation)
    );

    // ── Layer 1 input comes from feature vector ──
    assign feat_addr = l1_in_addr;

    // ── Store layer 2 outputs ──
    always @(posedge clk) begin
        if (l2_out_we)
            logit_buf[l2_out_addr[1:0]] <= l2_out_data;
    end

    // ── FSM ──
    localparam S_IDLE    = 2'd0;
    localparam S_LAYER1  = 2'd1;
    localparam S_LAYER2  = 2'd2;
    localparam S_ARGMAX  = 2'd3;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            l1_start  <= 1'b0;
            l2_start  <= 1'b0;
            kws_class <= 2'd0;
            kws_conf  <= 8'sd0;
            kws_valid <= 1'b0;
        end else begin
            done      <= 1'b0;
            l1_start  <= 1'b0;
            l2_start  <= 1'b0;
            kws_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state    <= S_LAYER1;
                        l1_start <= 1'b1;
                        busy     <= 1'b1;
                    end
                end

                S_LAYER1: begin
                    if (l1_done) begin
                        state    <= S_LAYER2;
                        l2_start <= 1'b1;
                    end
                end

                S_LAYER2: begin
                    if (l2_done) begin
                        state <= S_ARGMAX;
                    end
                end

                S_ARGMAX: begin
                    // Find maximum logit — same as int8 version
                    if (logit_buf[0] >= logit_buf[1] && logit_buf[0] >= logit_buf[2]) begin
                        kws_class <= 2'd0; // left
                        kws_conf  <= logit_buf[0];
                    end else if (logit_buf[1] >= logit_buf[0] && logit_buf[1] >= logit_buf[2]) begin
                        kws_class <= 2'd1; // right
                        kws_conf  <= logit_buf[1];
                    end else begin
                        kws_class <= 2'd2; // other
                        kws_conf  <= logit_buf[2];
                    end

                    kws_valid <= 1'b1;
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
