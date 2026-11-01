// Robust OV7670 VGA RGB565 -> 320x240 RGB444 capture.
// Camera bus/HREF/VSYNC are latched on the FALLING edge of PCLK and processed
// on the RISING edge. This mirrors the timing method used by the known-working
// reference project and gives the OV7670 outputs half a PCLK period to settle.
// Keeps every second RGB565 pixel and every second input line (640x480 -> 320x240).
module ov7670_capture_bg (
    input  wire        pclk,
    input  wire        reset_n,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    input  wire        bg_req_toggle_async,
    input  wire        byte_swap_async,

    output reg  [16:0] wr_addr,
    output reg  [11:0] wr_data,
    output reg         live_we,
    output reg         bg_we,
    output reg         bg_busy,
    output reg         bg_valid
);
    // Inputs sampled away from the processing edge.
    reg [7:0] d_neg;
    reg href_neg, vsync_neg;
    always @(negedge pclk) begin
        d_neg     <= d;
        href_neg  <= href;
        vsync_neg <= vsync;
    end

    reg [7:0] first_byte;
    reg byte_phase;
    reg [9:0] x_pixel;
    reg [9:0] y_line;
    reg href_q, vsync_q;
    reg [16:0] write_index;

    reg [2:0] bg_req_sync;
    reg bg_pending, bg_active;
    reg [1:0] byte_swap_sync;
    wire bg_req_event = bg_req_sync[2] ^ bg_req_sync[1];

    wire [15:0] pixel565_normal = {first_byte, d_neg};
    wire [15:0] pixel565_swap   = {d_neg, first_byte};
    wire [15:0] pixel565 = byte_swap_sync[1] ? pixel565_swap : pixel565_normal;
    wire [11:0] pixel444 = {pixel565[15:12], pixel565[10:7], pixel565[4:1]};

    always @(posedge pclk) begin
        if (!reset_n) begin
            first_byte     <= 8'h00;
            byte_phase     <= 1'b0;
            x_pixel        <= 10'd0;
            y_line         <= 10'd0;
            href_q         <= 1'b0;
            vsync_q        <= 1'b0;
            write_index    <= 17'd0;
            wr_addr        <= 17'd0;
            wr_data        <= 12'h000;
            live_we        <= 1'b0;
            bg_we          <= 1'b0;
            bg_req_sync    <= 3'b000;
            byte_swap_sync <= 2'b00;
            bg_pending     <= 1'b0;
            bg_active      <= 1'b0;
            bg_busy        <= 1'b0;
            bg_valid       <= 1'b0;
        end else begin
            bg_req_sync    <= {bg_req_sync[1:0], bg_req_toggle_async};
            byte_swap_sync <= {byte_swap_sync[0], byte_swap_async};
            href_q         <= href_neg;
            vsync_q        <= vsync_neg;
            live_we        <= 1'b0;
            bg_we          <= 1'b0;

            if (bg_req_event)
                bg_pending <= 1'b1;

            // Rising edge of VSYNC marks the frame boundary for this setup.
            if (vsync_neg && !vsync_q) begin
                x_pixel     <= 10'd0;
                y_line      <= 10'd0;
                byte_phase  <= 1'b0;
                write_index <= 17'd0;

                if (bg_active) begin
                    bg_active <= 1'b0;
                    bg_valid  <= 1'b1;
                end
                if (bg_pending || bg_req_event) begin
                    bg_active  <= 1'b1;
                    bg_pending <= 1'b0;
                    bg_valid   <= 1'b0;
                end
            end else if (!vsync_neg) begin
                // Start/end of an active camera line.
                if (href_neg && !href_q) begin
                    x_pixel    <= 10'd0;
                    byte_phase <= 1'b0;
                end
                if (!href_neg && href_q) begin
                    y_line     <= y_line + 1'b1;
                    byte_phase <= 1'b0;
                end

                if (href_neg) begin
                    if (!byte_phase) begin
                        first_byte <= d_neg;
                        byte_phase <= 1'b1;
                    end else begin
                        byte_phase <= 1'b0;

                        // One RGB565 pixel is now complete. Store every second
                        // pixel on every second input line.
                        if (!x_pixel[0] && !y_line[0] && write_index < 17'd76800) begin
                            // Registered write interface: wr_addr/wr_data/live_we
                            // remain stable for the complete following PCLK cycle,
                            // allowing the RAM to consume the correct address/data.
                            wr_addr <= write_index;
                            wr_data <= pixel444;
                            live_we <= 1'b1;
                            bg_we   <= bg_active;
                            write_index <= write_index + 1'b1;
                        end
                        x_pixel <= x_pixel + 1'b1;
                    end
                end
            end

            bg_busy <= bg_pending | bg_active | bg_req_event;
        end
    end
endmodule
