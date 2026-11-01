// 1-bit 320x240 foreground-mask frame buffer.
// The 3x3 filter writes one filtered source pixel; VGA reads the previous
// completed filtered mask.  Both ports use the 25 MHz VGA clock.
module mask_buffer (
    input  wire        clk,
    input  wire        we,
    input  wire [16:0] waddr,
    input  wire        wdata,
    input  wire [16:0] raddr,
    output reg         rdata
);
    (* ramstyle = "M9K, no_rw_check" *) reg mem [0:76799];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end
endmodule
