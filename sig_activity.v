// Detects transitions on an asynchronous signal and stretches the indication
// long enough to be clearly visible on an LED.
module sig_activity (
    input  wire clk,
    input  wire sig,
    output reg  alive = 1'b0
);
    reg [2:0] sync = 3'b000;
    reg [22:0] hold = 23'd0; // ~0.17 s at 50 MHz

    always @(posedge clk) begin
        sync <= {sync[1:0], sig};
        if (sync[2] ^ sync[1]) begin
            hold  <= {23{1'b1}};
            alive <= 1'b1;
        end else if (hold != 0) begin
            hold  <= hold - 1'b1;
            alive <= 1'b1;
        end else begin
            alive <= 1'b0;
        end
    end
endmodule
