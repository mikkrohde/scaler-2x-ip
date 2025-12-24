`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.12.2025 16:08:17
// Design Name: 
// Module Name: tb_scaler_2x_continuous
// Project Name: scaler2x
// Target Devices: 
// Tool Versions: 
// Description: Testbench for 2x video upscaler
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
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
    reg [PIXEL_WIDTH-1:0]   VPU_in_pixel;
    reg                     VPU_in_line_start;
    reg                     VPU_in_frame_start;

    wire                                    VPU_rd_en;
    wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] VPU_rd_addr;
    wire [PIXEL_WIDTH-1:0]                  VPU_rd_data;

    wire                    VPU_out_valid;
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
        .VPU_use_stream_mode(1'b1),        // 0 = use stream scaler
        .VPU_cfg_width     (VPU_cfg_width),
        .VPU_cfg_height    (VPU_cfg_height),
        .VPU_in_valid      (VPU_in_valid),
        .VPU_in_pixel      (VPU_in_pixel),
        .VPU_in_line_start (VPU_in_line_start),
        .VPU_in_frame_start(VPU_in_frame_start),
        .VPU_rd_en         (VPU_rd_en),
        .VPU_rd_addr       (VPU_rd_addr),
        .VPU_rd_data       (VPU_rd_data),
        .VPU_out_valid     (VPU_out_valid),
        .VPU_out_pixel     (VPU_out_pixel),
        .VPU_out_line_start(VPU_out_line_start),
        .VPU_out_frame_start(VPU_out_frame_start)
    );

    // Test pattern: 6x4 frame
    // Pixel value = {row[7:0], col[7:0], 8'h00} for easy identification
    localparam IN_W = 6;
    localparam IN_H = 4;

    integer x, y;

    // Task: drive one 6-pixel line
    task drive_line(input integer row);
    begin
        // First pixel in line
        VPU_in_line_start  = 1'b1;
        VPU_in_frame_start = (row == 0) ? 1'b1 : 1'b0;
        VPU_in_valid       = 1'b1;
        VPU_in_pixel       = {row[7:0], 8'd0, 8'h00};
        @(posedge clk);
    
        VPU_in_line_start  = 1'b0;
        VPU_in_frame_start = 1'b0;
    
        // Remaining pixels in the line
        for (x = 1; x < IN_W; x = x + 1) begin
            VPU_in_valid <= 1'b1;
            VPU_in_pixel <= {row[7:0], x[7:0], 8'h00};
            @(posedge clk);
        end
    
        // End of line: deassert valid AFTER last pixel
        VPU_in_valid <= 1'b0;
        @(posedge clk);
    end
    endtask

    // Monitor output
    integer out_count;
    initial begin
        out_count = 0;
        $display("Time  | out_valid out_line_start out_frame_start  out_pixel");
        forever begin
            @(posedge clk);
            if (VPU_out_valid) begin
                $display("%5t |    %b         %b              %b        0x%06h",
                         $time, VPU_out_valid, VPU_out_line_start,
                         VPU_out_frame_start, VPU_out_pixel);
                out_count = out_count + 1;
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

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("=== Driving 6x4 test frame into Scaler2x (stream mode) ===");

        // Drive 4 lines
        for (y = 0; y < IN_H; y = y + 1) begin
            $display("--- Driving line %0d ---", y);
            drive_line(y);
            repeat (2) @(posedge clk);
        end

        // Allow some time for remaining outputs
        repeat (50) @(posedge clk);

        $display("Total output pixels seen (valid): %0d", out_count);
        $display("Expected with 2x horizontal (only): %0d", IN_W * 2 * IN_H);
        $display("NOTE: Current Scaler2x_stream only doubles horizontally; vertical 2x to 8 lines is a later step.");
        $finish;
    end

endmodule
