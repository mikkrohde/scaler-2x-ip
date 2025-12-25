`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date: 23.12.2025 15:33:55
// Design Name: 
// Module Name: Scaler2x
// Project Name: 2x stream scaler
// Target Devices: 
// Tool Versions: 
// Description: 2x upscaler for video signals using hsync-based streamed upscaling and vsync-based frame-by-frame upscaling
// 
// Revision 1.0 - File Created
// 
//////////////////////////////////////////////////////////////////////////////////

module Scaler2x #(
        parameter MAX_WIDTH   = 1920,
        parameter MAX_HEIGHT  = 1080,
        parameter PIXEL_WIDTH = 24,
        parameter ENABLE_STREAM_SCALING = 1,
        parameter ENABLE_FRAME_SCALING = 1
    )(
        input wire  clk,
        input wire  rst_n,

        // Mode select: 1 = stream mode (line-based), 0 = frame mode (future feature)
        input wire                  VPU_use_stream_mode,

        // Config (for future frame mode)
        input wire [15:0]           VPU_cfg_width,
        input wire [15:0]           VPU_cfg_height,

        // Stream input (from sampler / line buffer)
        input wire                      VPU_in_valid,
        output wire                     VPU_in_ready,
        input wire [PIXEL_WIDTH-1:0]    VPU_in_pixel,
        input wire                      VPU_in_line_start,
        input wire                      VPU_in_frame_start,

        // VideoBuffer read side (used only in frame mode)
        output wire                                     VPU_rd_en,
        output wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0]  VPU_rd_addr,
        input  wire [PIXEL_WIDTH-1:0]                   VPU_rd_data,

        // Unified 2x output stream
        output wire                   VPU_out_valid,
        input  wire                   VPU_out_ready,
        output wire [PIXEL_WIDTH-1:0] VPU_out_pixel,
        output wire                   VPU_out_line_start,
        output wire                   VPU_out_frame_start
    );

        // Stream scaler instance
        wire s_out_valid;
        wire [PIXEL_WIDTH-1:0] s_out_pixel;
        wire s_out_line_start;
        wire s_out_frame_start;

        Scaler2x_stream #(
            .PIXEL_WIDTH(PIXEL_WIDTH),
            .MAX_WIDTH(MAX_WIDTH)
        ) u_scaler_stream (
            .clk                (clk),
            .rst_n              (rst_n),
            .cfg_width          (VPU_cfg_width),
            .VPU_in_valid       (VPU_in_valid),
            .VPU_in_ready       (VPU_in_ready),
            .VPU_in_pixel       (VPU_in_pixel),
            .VPU_in_line_start  (VPU_in_line_start),
            .VPU_in_frame_start (VPU_in_frame_start),
            .VPU_out_valid      (s_out_valid),
            .VPU_out_ready      (VPU_out_ready),
            .VPU_out_pixel      (s_out_pixel),
            .VPU_out_line_start (s_out_line_start),
            .VPU_out_frame_start(s_out_frame_start)
        );

        // Frame scaler instance (placeholder)
        wire f_out_valid;
        wire [PIXEL_WIDTH-1:0] f_out_pixel;
        wire f_out_line_start;
        wire f_out_frame_start;
        wire f_rd_en;
        wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] f_rd_addr;

        Scaler2x_frame #(
            .MAX_WIDTH  (MAX_WIDTH),
            .MAX_HEIGHT (MAX_HEIGHT),
            .PIXEL_WIDTH(PIXEL_WIDTH)
        ) u_scaler_frame (
            .clk               (clk),
            .rst_n             (rst_n),
            .cfg_width         (VPU_cfg_width),
            .cfg_height        (VPU_cfg_height),
            .VPU_rd_en         (f_rd_en),
            .VPU_rd_addr       (f_rd_addr),
            .VPU_rd_data       (VPU_rd_data),
            .VPU_out_valid     (f_out_valid),
            .VPU_out_ready     (VPU_out_ready), 
            .VPU_out_pixel     (f_out_pixel),
            .VPU_out_line_start(f_out_line_start),
            .VPU_out_frame_start(f_out_frame_start)
        );

        // Mode selection: for now only stream mode is really active;
        // frame mode outputs are all zeros from the placeholder.
        assign VPU_rd_en   = VPU_use_stream_mode  ? 1'b0 : f_rd_en;
        assign VPU_rd_addr = VPU_use_stream_mode  ? {($clog2(MAX_WIDTH*MAX_HEIGHT)){1'b0}} : f_rd_addr;

        assign VPU_out_valid       = VPU_use_stream_mode  ? s_out_valid : f_out_valid;
        assign VPU_out_pixel       = VPU_use_stream_mode  ? s_out_pixel : f_out_pixel;
        assign VPU_out_line_start  = VPU_use_stream_mode  ? s_out_line_start : f_out_line_start;
        assign VPU_out_frame_start = VPU_use_stream_mode  ? s_out_frame_start : f_out_frame_start; 
endmodule
