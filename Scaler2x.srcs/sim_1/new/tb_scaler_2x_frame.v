`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for Scaler2x - Frame Mode
//////////////////////////////////////////////////////////////////////////////////

module tb_Scaler2x_frame;
    // Parameters
    localparam PIXEL_WIDTH = 24;
    localparam MAX_WIDTH   = 1024;
    localparam MAX_HEIGHT  = 960;

    // Clock / reset
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;  // 100 MHz

    // Test dimensions
    localparam IN_W = 6;
    localparam IN_H = 4;

    // DUT signals
    reg [15:0]  VPU_cfg_width;
    reg [15:0]  VPU_cfg_height;

    wire                                    VPU_rd_en;
    wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] VPU_rd_addr;
    reg  [PIXEL_WIDTH-1:0]                  VPU_rd_data;

    wire                    VPU_out_valid;
    reg                     VPU_out_ready;
    wire [PIXEL_WIDTH-1:0]  VPU_out_pixel;
    wire                    VPU_out_line_start;
    wire                    VPU_out_frame_start;

    // Frame buffer: stores 6x4 test pattern
    reg [PIXEL_WIDTH-1:0] frame_buffer [0:MAX_WIDTH*MAX_HEIGHT-1];

    // Frame buffer read logic - combinational
    always @(*) begin
        if (VPU_rd_en && VPU_rd_addr < (IN_W * IN_H))
            VPU_rd_data = frame_buffer[VPU_rd_addr];
        else
            VPU_rd_data = {PIXEL_WIDTH{1'b0}};
    end

    // Instantiate DUT - FRAME MODE
    Scaler2x #(
        .MAX_WIDTH  (MAX_WIDTH),
        .MAX_HEIGHT (MAX_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .VPU_use_stream_mode(1'b0),        // ← FRAME MODE
        .VPU_cfg_width     (VPU_cfg_width),
        .VPU_cfg_height    (VPU_cfg_height),
        
        // Stream inputs unused in frame mode
        .VPU_in_valid      (1'b0),
        .VPU_in_ready      (),
        .VPU_in_pixel      ({PIXEL_WIDTH{1'b0}}),
        .VPU_in_line_start (1'b0),
        .VPU_in_frame_start(1'b0),
        
        // Frame buffer interface
        .VPU_rd_en         (VPU_rd_en),
        .VPU_rd_addr       (VPU_rd_addr),
        .VPU_rd_data       (VPU_rd_data),
        
        // Output stream
        .VPU_out_valid     (VPU_out_valid),
        .VPU_out_ready     (VPU_out_ready),
        .VPU_out_pixel     (VPU_out_pixel),
        .VPU_out_line_start(VPU_out_line_start),
        .VPU_out_frame_start(VPU_out_frame_start)
    );

    // Monitor output
    integer out_count;
    integer out_line_count;
    integer pixels_this_line;
    
    initial begin
        out_count = 0;
        out_line_count = 0;
        pixels_this_line = 0;
        
        $display("========================================");
        $display("2x Scaler Testbench - FRAME MODE");
        $display("========================================");
        
        forever begin
            @(posedge clk);
            if (VPU_out_valid && VPU_out_ready) begin
                if (VPU_out_line_start) begin
                    if (out_line_count > 0) begin
                        $display("  [Line %0d complete: %0d pixels]", out_line_count - 1, pixels_this_line);
                    end
                    $display("Line %0d (frame_start=%b):", out_line_count, VPU_out_frame_start);
                    pixels_this_line = 0;
                    out_line_count = out_line_count + 1;
                end
                
                $write(" %02h:%02h", VPU_out_pixel[23:16], VPU_out_pixel[15:8]);
                pixels_this_line = pixels_this_line + 1;
                out_count = out_count + 1;
                
                if (pixels_this_line % 12 == 0) begin
                    $display("");
                end
            end
        end
    end

    // Main test
    integer i, x, y;
    
    initial begin
        // Initialize frame buffer with test pattern
        // Pixel value = {row[7:0], col[7:0], 8'h00}
        for (i = 0; i < MAX_WIDTH*MAX_HEIGHT; i = i + 1) begin
            frame_buffer[i] = {PIXEL_WIDTH{1'b0}};
        end
        
        for (y = 0; y < IN_H; y = y + 1) begin
            for (x = 0; x < IN_W; x = x + 1) begin
                frame_buffer[y * IN_W + x] = {y[7:0], x[7:0], 8'h00};
            end
        end
        
        $display("\n=== Frame buffer loaded with %0dx%0d pattern ===", IN_W, IN_H);
        $display("\n=== Each pixel encoded as {row, col, 00} ===\n");

        // Configure and reset
        VPU_cfg_width  = IN_W;
        VPU_cfg_height = IN_H;
        VPU_out_ready  = 1;

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        $display("=== Scaler starting frame-based 2x upscale ===\n");

        // Wait for scaler to process entire frame
        wait(VPU_out_frame_start && VPU_out_valid && out_count > 0);
        repeat(10) @(posedge clk);

        // Final report
        $display("\n========================================");
        $display("Test Complete");
        $display("========================================");
        $display("Input:  %0d x %0d = %0d pixels", IN_W, IN_H, IN_W * IN_H);
        $display("Output: %0d pixels received", out_count);
        $display("Expected (2x H + 2*V): %0d x %0d = %0d pixels", IN_W * 2, IN_H * 2, IN_W * 2 * IN_H * 2);
        $display("Output lines detected: %0d (expected %0d)", out_line_count, IN_H * 2);
        
        if (out_count == (IN_W * 2 * IN_H * 2)) begin
            $display(">>> PASS: Correct pixel count!");
        end else begin
            $display(">>> FAIL: Pixel count mismatch!");
        end
        
        if (out_line_count == IN_H * 2) begin
            $display(">>> PASS: Correct line count!");
        end else begin
            $display(">>> FAIL: Line count mismatch!");
        end
        
        $display("========================================\n");
        $finish;
    end

endmodule
