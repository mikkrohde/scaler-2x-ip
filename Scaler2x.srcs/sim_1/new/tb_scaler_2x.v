`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for 2x video upscaler (Horizontal + Vertical)
//////////////////////////////////////////////////////////////////////////////////

module tb_Scaler2x;
    // Parameters
    localparam PIXEL_WIDTH = 24;
    localparam MAX_WIDTH   = 1024;
    localparam MAX_HEIGHT  = 960;
    
    // Clock / reset
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;  // 100 MHz

    // DUT signals
    reg         VPU_use_frame_mode;
    reg [15:0]  VPU_cfg_width;
    reg [15:0]  VPU_cfg_height;

    reg                     VPU_in_valid;
    wire                    VPU_in_ready;
    reg [PIXEL_WIDTH-1:0]   VPU_in_pixel;
    reg                     VPU_in_line_start;
    reg                     VPU_in_frame_start;

    wire                                    VPU_rd_en;
    wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] VPU_rd_addr;
    wire [PIXEL_WIDTH-1:0]                  VPU_rd_data;

    wire                    VPU_out_valid;
    reg                     VPU_out_ready;
    wire [PIXEL_WIDTH-1:0]  VPU_out_pixel;
    wire                    VPU_out_line_start;
    wire                    VPU_out_frame_start;

    // Dummy VideoBuffer read data (unused in stream mode)
    assign VPU_rd_data = {PIXEL_WIDTH{1'b0}};
    
    // Instantiate DUT
    Scaler2x #(
        .MAX_WIDTH  (MAX_WIDTH),
        .MAX_HEIGHT (MAX_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .VPU_use_stream_mode(1'b1),
        .VPU_cfg_width     (VPU_cfg_width),
        .VPU_cfg_height    (VPU_cfg_height),
        .VPU_in_valid      (VPU_in_valid),
        .VPU_in_ready      (VPU_in_ready),
        .VPU_in_pixel      (VPU_in_pixel),
        .VPU_in_line_start (VPU_in_line_start),
        .VPU_in_frame_start(VPU_in_frame_start),
        .VPU_rd_en         (VPU_rd_en),
        .VPU_rd_addr       (VPU_rd_addr),
        .VPU_rd_data       (VPU_rd_data),
        .VPU_out_valid     (VPU_out_valid),
        .VPU_out_ready     (VPU_out_ready),
        .VPU_out_pixel     (VPU_out_pixel),
        .VPU_out_line_start(VPU_out_line_start),
        .VPU_out_frame_start(VPU_out_frame_start)
    );

    // Test pattern: 6x4 frame
    // Pixel value = {row[7:0], col[7:0], 8'h00} for easy identification
    localparam IN_W = 6;
    localparam IN_H = 4;

    integer x, y;

    // Task: drive one input line
    task drive_line(input integer row);
    begin
        for (x = 0; x < IN_W; x = x + 1) begin
            VPU_in_valid       <= 1'b1;
            VPU_in_pixel       <= {row[7:0], x[7:0], 8'h00};
            VPU_in_line_start  <= (x == 0);
            VPU_in_frame_start <= (row == 0 && x == 0);
            
            @(posedge clk);
            while (!VPU_in_ready) @(posedge clk);
        end
        
        // Deassert valid after the line is complete
        VPU_in_valid       <= 1'b0;
        VPU_in_line_start  <= 1'b0;
        VPU_in_frame_start <= 1'b0;
        @(posedge clk);
    end
    endtask

    // Monitor output with better formatting
    integer out_count;
    integer out_line_count;
    integer pixels_this_line;
    
    initial begin
        out_count = 0;
        out_line_count = 0;
        pixels_this_line = 0;
        
        $display("========================================");
        $display("2x Scaler Testbench - Horizontal + Vertical");
        $display("========================================");
        
        forever begin
            @(posedge clk);
            if (VPU_out_valid && VPU_out_ready) begin
                // Track line starts
                if (VPU_out_line_start) begin
                    if (out_line_count > 0) begin
                        $display("  [Line %0d complete: %0d pixels]", out_line_count - 1, pixels_this_line);
                    end
                    $display("Line %0d (frame_start=%b):", out_line_count, VPU_out_frame_start);
                    pixels_this_line = 0;
                    out_line_count = out_line_count + 1;
                end
                
                // Display pixel (compact format)
                $write(" %02h:%02h", VPU_out_pixel[23:16], VPU_out_pixel[15:8]);
                
                pixels_this_line = pixels_this_line + 1;
                out_count = out_count + 1;
                
                // Line break every 12 pixels for readability
                if (pixels_this_line % 12 == 0) begin
                    $display("");
                end
            end
        end
    end

    // Main stimulus
    initial begin
        // Init
        VPU_cfg_width      = IN_W;
        VPU_cfg_height     = IN_H;
        VPU_in_valid       = 0;
        VPU_in_pixel       = 0;
        VPU_in_line_start  = 0;
        VPU_in_frame_start = 0;
        VPU_out_ready      = 1;

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("\n=== Driving %0dx%0d test frame into Scaler2x ===\n", IN_W, IN_H);

        // Drive all input lines
        for (y = 0; y < IN_H; y = y + 1) begin
            $display(">>> Sending input line %0d", y);
            drive_line(y);
            repeat (2) @(posedge clk);
        end

        // Wait for all outputs (vertical scaling means more output)
        repeat (200) @(posedge clk);

        // Final report
        $display("\n========================================");
        $display("Test Complete");
        $display("========================================");
        $display("Input:  %0d x %0d = %0d pixels", IN_W, IN_H, IN_W * IN_H);
        $display("Output: %0d pixels received", out_count);
        $display("Expected (2x H + V): %0d x %0d = %0d pixels", IN_W * 2, IN_H * 2, IN_W * 2 * IN_H * 2);
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