`timescale 1ns / 1ps

// Temperature-controlled background state using the Artix-7 XADC on-die sensor.
// Outputs a discrete 3-state signal: COOL / NEUTRAL / HOT.
// Fully isolated from game logic and voice/ML path.

module temp_background_ctrl (
    input  wire       clk,              // 25 MHz system clock
    input  wire       reset_n,
    input  wire       capture_baseline, // pulse to (re)set baseline (game start)
    output reg  [1:0] temp_state        // 00=COOL, 01=NEUTRAL, 10=HOT
);

    localparam [1:0] COOL    = 2'b00;
    localparam [1:0] NEUTRAL = 2'b01;
    localparam [1:0] HOT     = 2'b10;

    // Temperature thresholds in ADC LSBs (1 LSB ≈ 0.123 °C)
    localparam [11:0] THRESHOLD  = 12'd4;  // ~0.5 °C
    localparam [11:0] HYSTERESIS = 12'd2;  // ~0.25 °C

    // --- XADC wires ---
    wire [15:0] xadc_do;
    wire        xadc_drdy;
    wire        xadc_eoc;
    wire        xadc_eos;
    wire  [4:0] xadc_channel;
    wire        xadc_busy;
    wire  [7:0] xadc_alm;
    wire        xadc_ot;

    reg  [6:0]  drp_addr;
    reg         drp_den;
    reg         drp_dwe;
    reg  [15:0] drp_di;

    // --- DRP read state machine ---
    localparam S_WAIT  = 2'd0;
    localparam S_READ  = 2'd1;
    localparam S_DRDY  = 2'd2;

    reg [1:0]  drp_state;
    reg [14:0] wait_cnt;        // ~1 ms at 25 MHz = 25000 cycles
    reg [11:0] raw_temp;        // 12-bit ADC value (DO[15:4])
    reg [11:0] filtered;        // IIR-filtered temperature
    reg [11:0] baseline;
    reg        baseline_valid;
    reg        first_reading;

    // XADC primitive instantiation (no IP catalog)
    XADC #(
        // Configuration registers
        .INIT_40(16'h1000),     // Config reg 0: averaging 16, cont sequence mode
        .INIT_41(16'h2EF0),     // Config reg 1: enable calibration, internal ref
        .INIT_42(16'h0800),     // Config reg 2: ADCCLK = DCLK/8 => 3.125 MHz
        // Sequence registers
        .INIT_48(16'h0100),     // Seq reg: enable temperature channel in sequence
        .INIT_49(16'h0000),     // No aux channels
        .INIT_4A(16'h0000),     // Seq averaging: default
        .INIT_4B(16'h0000),
        .INIT_4C(16'h0000),
        .INIT_4D(16'h0000),
        .INIT_4E(16'h0000),
        .INIT_4F(16'h0000),
        // Alarm thresholds (disabled/benign)
        .INIT_50(16'hB5ED),     // OT upper
        .INIT_51(16'h57E4),     // Vccint upper
        .INIT_52(16'hA147),     // Vccaux upper
        .INIT_53(16'hCA33),     // OT reset
        .INIT_54(16'hA93A),     // Temp upper
        .INIT_55(16'h52C6),     // Vccint lower
        .INIT_56(16'h9555),     // Vccaux lower
        .INIT_57(16'hAE4E),     // Temp lower
        .INIT_58(16'h0000),
        .INIT_59(16'h0000),
        .INIT_5A(16'h0000),
        .INIT_5B(16'h0000),
        .INIT_5C(16'h0000),
        .INIT_5D(16'h0000),
        .INIT_5E(16'h0000),
        .INIT_5F(16'h0000),
        .SIM_MONITOR_FILE(""),
        .IS_CONVSTCLK_INVERTED(1'b0),
        .IS_DCLK_INVERTED(1'b0)
    ) u_xadc (
        // DRP interface
        .DCLK       (clk),
        .DEN        (drp_den),
        .DADDR      (drp_addr),
        .DWE        (drp_dwe),
        .DI         (drp_di),
        .DO         (xadc_do),
        .DRDY       (xadc_drdy),
        // Status
        .EOC        (xadc_eoc),
        .EOS        (xadc_eos),
        .CHANNEL    (xadc_channel),
        .BUSY       (xadc_busy),
        .ALM        (xadc_alm),
        .OT         (xadc_ot),
        // Unused inputs
        .RESET      (1'b0),
        .CONVST     (1'b0),
        .CONVSTCLK  (1'b0),
        .VP         (1'b0),
        .VN         (1'b0),
        .VAUXP      (16'h0000),
        .VAUXN      (16'h0000),
        .MUXADDR    ()
    );

    // --- DRP state machine: read temperature register every ~1 ms ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            drp_state     <= S_WAIT;
            wait_cnt      <= 15'd0;
            drp_den       <= 1'b0;
            drp_dwe       <= 1'b0;
            drp_addr      <= 7'h00;
            drp_di        <= 16'h0000;
            raw_temp      <= 12'd0;
            filtered      <= 12'd0;
            baseline      <= 12'd0;
            baseline_valid <= 1'b0;
            first_reading <= 1'b1;
            temp_state    <= NEUTRAL;
        end else begin
            drp_den <= 1'b0;  // default: deassert

            case (drp_state)
                S_WAIT: begin
                    if (wait_cnt >= 15'd24999) begin
                        wait_cnt  <= 15'd0;
                        drp_state <= S_READ;
                    end else begin
                        wait_cnt <= wait_cnt + 15'd1;
                    end
                end

                S_READ: begin
                    drp_addr  <= 7'h00;    // Temperature status register
                    drp_den   <= 1'b1;
                    drp_dwe   <= 1'b0;
                    drp_state <= S_DRDY;
                end

                S_DRDY: begin
                    if (xadc_drdy) begin
                        raw_temp <= xadc_do[15:4];  // 12-bit value

                        // IIR filter: filtered = filtered - (filtered>>4) + (raw>>4)
                        if (first_reading) begin
                            filtered      <= xadc_do[15:4];
                            first_reading <= 1'b0;
                        end else begin
                            filtered <= filtered - (filtered >> 4) + (xadc_do[15:4] >> 4);
                        end

                        drp_state <= S_WAIT;
                    end
                end

                default: drp_state <= S_WAIT;
            endcase

            // --- Baseline capture ---
            if (capture_baseline || (!baseline_valid && !first_reading)) begin
                baseline       <= filtered;
                baseline_valid <= 1'b1;
                temp_state     <= NEUTRAL;
            end

            // --- Temperature state comparison with hysteresis ---
            if (baseline_valid && !first_reading) begin
                if (filtered > baseline + THRESHOLD + (temp_state != HOT ? HYSTERESIS : 12'd0))
                    temp_state <= HOT;
                else if (filtered + THRESHOLD + (temp_state != COOL ? HYSTERESIS : 12'd0) < baseline)
                    temp_state <= COOL;
                else if (filtered <= baseline + THRESHOLD - HYSTERESIS &&
                         filtered + THRESHOLD - HYSTERESIS >= baseline)
                    temp_state <= NEUTRAL;
                // else: maintain current state (hysteresis band)
            end
        end
    end

endmodule
