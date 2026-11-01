// VGA 640x480 @ 60 Hz timing generator (25 MHz pixel clock).
// Reads a 320x240 frame buffer, each source pixel shown 2x2.
// src_x/src_y/src_sample are delayed to align with frame-buffer pixel data.
module vga_timing (
    input  wire        clk,
    output reg  [16:0] raddr,
    output reg         hs,
    output reg         vs,
    output reg         active,
    output reg  [11:0] test_pix,
    output reg  [8:0]  src_x,
    output reg  [7:0]  src_y,
    output reg         src_sample
);
    localparam H_ACT = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOT = 800;
    localparam V_ACT = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOT = 525;

    reg [9:0] h = 10'd0;
    reg [9:0] v = 10'd0;

    always @(posedge clk) begin
        if (h == H_TOT - 1) begin
            h <= 10'd0;
            if (v == V_TOT - 1) v <= 10'd0;
            else                v <= v + 1'b1;
        end else begin
            h <= h + 1'b1;
        end
    end

    wire act0 = (h < H_ACT) && (v < V_ACT);
    wire hs0  = ~((h >= H_ACT + H_FP) && (h < H_ACT + H_FP + H_SYNC));
    wire vs0  = ~((v >= V_ACT + V_FP) && (v < V_ACT + V_FP + V_SYNC));

    wire [8:0] xs = h[9:1];
    wire [7:0] ys = v[8:1];
    wire source_sample0 = act0 && (h[0] == 1'b0) && (v[0] == 1'b0);

    wire [16:0] addr_calc =
        {1'b0, ys, 8'b0} + {3'b000, ys, 6'b0} + {8'b00000000, xs};

    reg [11:0] bars;
    always @(*) begin
        case (h[9:7])
            3'd0:    bars = 12'hFFF;
            3'd1:    bars = 12'hFF0;
            3'd2:    bars = 12'h0FF;
            3'd3:    bars = 12'h0F0;
            3'd4:    bars = 12'hF0F;
            3'd5:    bars = 12'hF00;
            3'd6:    bars = 12'h00F;
            default: bars = 12'h444;
        endcase
    end

    wire border = (h == 10'd0) || (h == H_ACT - 1) ||
                  (v == 10'd0) || (v == V_ACT - 1);
    wire [11:0] tp0 = border ? 12'hFFF : bars;

    reg [11:0] tp1 = 12'h000;
    reg act1 = 1'b0, hs1 = 1'b1, vs1 = 1'b1;
    reg [8:0] xs1 = 9'd0;
    reg [7:0] ys1 = 8'd0;
    reg sample1 = 1'b0;

    always @(posedge clk) begin
        tp1   <= tp0;
        raddr <= act0 ? addr_calc : 17'd0;
        act1  <= act0;
        hs1   <= hs0;
        vs1   <= vs0;
        xs1   <= xs;
        ys1   <= ys;
        sample1 <= source_sample0;

        test_pix <= tp1;
        active   <= act1;
        hs       <= hs1;
        vs       <= vs1;
        src_x    <= xs1;
        src_y    <= ys1;
        src_sample <= sample1;
    end
endmodule
