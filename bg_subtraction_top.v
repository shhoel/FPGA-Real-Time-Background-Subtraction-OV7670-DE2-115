module bg_subtraction_top (
    input  wire        CLOCK_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [8:0]  LEDG,

    input  wire [7:0]  CAM_D,
    input  wire        CAM_PCLK,
    input  wire        CAM_HREF,
    input  wire        CAM_VSYNC,
    output wire        CAM_XCLK,
    output wire        CAM_SIOC,
    inout  wire        CAM_SIOD,
    output wire        CAM_RESET_N,
    output wire        CAM_PWDN,

    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        VGA_HS,
    output wire        VGA_VS
);
    // 25 MHz VGA clock from board 50 MHz clock
    reg clk25 = 1'b0;
    always @(posedge CLOCK_50)
        clk25 <= ~clk25;

    // KEY0: reset/re-send camera configuration (active low)
    reg [2:0] key0_sync = 3'b111;
    always @(posedge CLOCK_50)
        key0_sync <= {key0_sync[1:0], KEY[0]};
    wire key0_press = key0_sync[2] & ~key0_sync[1];
    wire sys_reset_n = key0_sync[1];

    wire cfg_done;
    ov7670_controller u_cam_ctrl (
        .clk             (CLOCK_50),
        .resend          (key0_press),
        .config_finished (cfg_done),
        .sioc            (CAM_SIOC),
        .siod            (CAM_SIOD),
        .reset           (CAM_RESET_N),
        .pwdn            (CAM_PWDN),
        .xclk            (CAM_XCLK)
    );

    // KEY1: request capture of the next complete frame as background
    reg [2:0] key1_sync = 3'b111;
    reg       bg_req_toggle = 1'b0;
    always @(posedge CLOCK_50) begin
        key1_sync <= {key1_sync[1:0], KEY[1]};
        if (!sys_reset_n)
            bg_req_toggle <= 1'b0;
        else if (key1_sync[2] & ~key1_sync[1])
            bg_req_toggle <= ~bg_req_toggle;
    end

    wire [16:0] cam_wr_addr;
    wire [11:0] cam_wr_data;
    wire live_we, bg_we, bg_busy_cam, bg_valid_cam;

    ov7670_capture_bg u_capture (
        .pclk                (CAM_PCLK),
        .reset_n             (sys_reset_n),
        .vsync               (CAM_VSYNC),
        .href                (CAM_HREF),
        .d                   (CAM_D),
        .bg_req_toggle_async (bg_req_toggle),
        .byte_swap_async     (SW[9]),
        .wr_addr             (cam_wr_addr),
        .wr_data             (cam_wr_data),
        .live_we             (live_we),
        .bg_we               (bg_we),
        .bg_busy             (bg_busy_cam),
        .bg_valid            (bg_valid_cam)
    );

    // Two RGB444 320x240 frame buffers
    wire [16:0] rd_addr;
    wire [11:0] live_pix;
    wire [11:0] bg_pix;

    frame_buffer u_live_fb (
        .wclk(CAM_PCLK), .we(live_we), .waddr(cam_wr_addr), .wdata(cam_wr_data),
        .rclk(clk25), .raddr(rd_addr), .rdata(live_pix)
    );

    frame_buffer u_bg_fb (
        .wclk(CAM_PCLK), .we(bg_we), .waddr(cam_wr_addr), .wdata(cam_wr_data),
        .rclk(clk25), .raddr(rd_addr), .rdata(bg_pix)
    );

    // VGA timing and test pattern
    wire vga_hs, vga_vs, vga_active;
    wire [11:0] test_pix;
    wire [8:0] src_x;
    wire [7:0] src_y;
    wire src_sample;
    vga_timing u_vga (
        .clk(clk25), .raddr(rd_addr), .hs(vga_hs), .vs(vga_vs),
        .active(vga_active), .test_pix(test_pix),
        .src_x(src_x), .src_y(src_y), .src_sample(src_sample)
    );

    // Synchronize display controls into VGA domain
    reg [1:0] sw0_s = 2'b00, sw1_s = 2'b00, sw2_s = 2'b00;
    reg [5:0] thr_s1 = 6'd0, thr_s2 = 6'd0;
    reg [1:0] bgv_s = 2'b00;
    always @(posedge clk25) begin
        sw0_s <= {sw0_s[0], SW[0]};  // subtraction enable
        sw1_s <= {sw1_s[0], SW[1]};  // white mask mode
        sw2_s <= {sw2_s[0], SW[2]};  // VGA colour bars
        thr_s1 <= SW[8:3];
        thr_s2 <= thr_s1;
        bgv_s <= {bgv_s[0], bg_valid_cam};
    end

    // ------------------------------------------------------------------
    // Improved foreground detector.
    // Luma ~= (R + 2G + B)/4.  Score gives luma twice the weight of
    // the largest channel difference, making it less sensitive to AWB noise
    // while still detecting coloured objects of similar brightness.
    // ------------------------------------------------------------------
    wire [3:0] lr = live_pix[11:8];
    wire [3:0] lg = live_pix[7:4];
    wire [3:0] lb = live_pix[3:0];
    wire [3:0] br = bg_pix[11:8];
    wire [3:0] bg = bg_pix[7:4];
    wire [3:0] bb = bg_pix[3:0];

    wire [5:0] live_y_sum = {2'b00,lr} + {1'b0,lg,1'b0} + {2'b00,lb};
    wire [5:0] bg_y_sum   = {2'b00,br} + {1'b0,bg,1'b0} + {2'b00,bb};
    wire [3:0] live_y = live_y_sum[5:2];
    wire [3:0] back_y = bg_y_sum[5:2];

    wire [4:0] dy = (live_y >= back_y) ? (live_y - back_y) : (back_y - live_y);
    wire [4:0] dr = (lr >= br) ? (lr - br) : (br - lr);
    wire [4:0] dg = (lg >= bg) ? (lg - bg) : (bg - lg);
    wire [4:0] db = (lb >= bb) ? (lb - bb) : (bb - lb);
    wire [4:0] max_rg = (dr >= dg) ? dr : dg;
    wire [4:0] max_rgb = (max_rg >= db) ? max_rg : db;
    wire [6:0] fg_score = {1'b0,dy,1'b0} + {2'b00,max_rgb};

    // SW8:SW3 = threshold. All zero selects default threshold = 4.
    wire [5:0] threshold = (thr_s2 == 6'd0) ? 6'd3 : thr_s2;
    wire foreground_raw = (fg_score > {1'b0,threshold});

    // Synchronize the background-capture request into the VGA domain so a
    // newly captured background starts a fresh filtered-mask frame.
    reg [2:0] bg_req_vga = 3'b000;
    always @(posedge clk25)
        bg_req_vga <= {bg_req_vga[1:0], bg_req_toggle};
    wire new_bg_request_vga = bg_req_vga[2] ^ bg_req_vga[1];

    // True 3x3 source-pixel majority filter. It generates a filtered mask
    // into a small 1-bit frame buffer; the completed mask is displayed on
    // the following VGA frame (about 16.7 ms latency).
    wire mask_we;
    wire [16:0] mask_waddr;
    wire mask_wdata;
    wire mask_ready;
    wire filtered_mask_pix;

    mask_filter_3x3 u_mask_filter (
        .clk       (clk25),
        .clear     (new_bg_request_vga || !bgv_s[1]),
        .sample_en (src_sample),
        .src_x     (src_x),
        .src_y     (src_y),
        .raw_mask  (foreground_raw),
        .out_we    (mask_we),
        .out_addr  (mask_waddr),
        .out_mask  (mask_wdata),
        .mask_ready(mask_ready)
    );

    mask_buffer u_mask_fb (
        .clk   (clk25),
        .we    (mask_we),
        .waddr (mask_waddr),
        .wdata (mask_wdata),
        .raddr (rd_addr),
        .rdata (filtered_mask_pix)
    );

    wire source_border = (src_x == 9'd0) || (src_x == 9'd319) ||
                         (src_y == 8'd0) || (src_y == 8'd239);

    // Before the first complete filtered mask exists, use raw subtraction.
    // Afterwards, use the 3x3-cleaned mask. Border pixels are forced black.
    wire foreground_clean = mask_ready ?
                            (source_border ? 1'b0 : filtered_mask_pix) :
                            foreground_raw;

    wire subtract_active = sw0_s[1] && bgv_s[1];
    wire [11:0] sub_pix = subtract_active ?
                          (foreground_clean ? (sw1_s[1] ? 12'hFFF : live_pix) : 12'h000) :
                          live_pix;
    wire [11:0] final_pix = sw2_s[1] ? test_pix : sub_pix;

    RGB u_rgb (
        .Din(final_pix), .Nblank(vga_active),
        .R(VGA_R), .G(VGA_G), .B(VGA_B)
    );

    assign VGA_CLK     = clk25;
    assign VGA_HS      = vga_hs;
    assign VGA_VS      = vga_vs;
    assign VGA_BLANK_N = vga_active;
    assign VGA_SYNC_N  = 1'b0;

    // Debug LEDs
    wire pclk_alive, href_alive, vsync_alive, data_alive;
    sig_activity u_a0 (.clk(CLOCK_50), .sig(CAM_PCLK),  .alive(pclk_alive));
    sig_activity u_a1 (.clk(CLOCK_50), .sig(CAM_HREF),  .alive(href_alive));
    sig_activity u_a2 (.clk(CLOCK_50), .sig(CAM_VSYNC), .alive(vsync_alive));
    sig_activity u_a3 (.clk(CLOCK_50), .sig(^CAM_D),    .alive(data_alive));

    reg [1:0] bgvalid_sync = 2'b00, bgbusy_sync = 2'b00;
    always @(posedge CLOCK_50) begin
        bgvalid_sync <= {bgvalid_sync[0], bg_valid_cam};
        bgbusy_sync  <= {bgbusy_sync[0], bg_busy_cam};
    end

    assign LEDG[0] = cfg_done;
    assign LEDG[1] = bgvalid_sync[1];
    assign LEDG[2] = pclk_alive;
    assign LEDG[3] = href_alive;
    assign LEDG[4] = vsync_alive;
    assign LEDG[5] = data_alive;
    assign LEDG[6] = bgbusy_sync[1];
    assign LEDG[7] = subtract_active;
    assign LEDG[8] = SW[9]; // ON = alternate RGB565 byte order selected
endmodule
