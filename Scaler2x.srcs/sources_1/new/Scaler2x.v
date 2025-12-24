`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date: 23.12.2025 15:33:55
// Design Name: 
// Module Name: Scaler2x
// Project Name: 2x stream scaler
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Scaler2x_stream #(
    parameter PIXEL_WIDTH = 24
)(
    input  wire                   clk,
    input  wire                   rst_n,
    // Input line stream
    input  wire                   VPU_in_valid,
    input  wire [PIXEL_WIDTH-1:0] VPU_in_pixel,
    input  wire                   VPU_in_line_start,
    input  wire                   VPU_in_frame_start,
    // Output 2x scaled stream
    output reg                    VPU_out_valid,
    output reg  [PIXEL_WIDTH-1:0] VPU_out_pixel,
    output reg                    VPU_out_line_start,
    output reg                    VPU_out_frame_start
);

    // Horizontal repeat flag: 0 = first copy, 1 = second copy of same input pixel
    reg h_rep;

    // Vertical repeat flag: 0 = first output line for this input line,
    //                       1 = second output line for this input line
    reg v_rep;

    // Latches to remember frame/line start for the second vertical pass
    reg [PIXEL_WIDTH-1:0] latched_pixel;
    reg latched_frame_start;
    reg latched_line_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_rep               <= 1'b0;
            v_rep               <= 1'b0;
            VPU_out_valid       <= 1'b0;
            VPU_out_pixel       <= {PIXEL_WIDTH{1'b0}};
            VPU_out_line_start  <= 1'b0;
            VPU_out_frame_start <= 1'b0;
            latched_pixel       <= {PIXEL_WIDTH{1'b0}};
            latched_line_start  <= 1'b0;
            latched_frame_start <= 1'b0;
        end else begin
            // Default outputs
            VPU_out_valid       <= 1'b0;
            VPU_out_line_start  <= 1'b0;
            VPU_out_frame_start <= 1'b0;

            if (VPU_in_valid) begin
                // Horizontal 2x: output each input pixel twice
                VPU_out_valid  <= 1'b1;
                VPU_out_pixel  <= VPU_in_pixel;
    
                // Propagate frame/line start on first copy
                if (h_rep) begin
                    // Second horizontal copy of same pixel
                    VPU_out_valid       <= 1'b1;
                    VPU_out_pixel       <= latched_pixel;
                    VPU_out_line_start  <= 1'b0;  // Start signals only on first copy
                    VPU_out_frame_start <= 1'b0;
                    h_rep               <= 1'b0;
                end else if(VPU_in_valid) begin
                    latched_pixel <= VPU_in_pixel;
                    latched_line_start <= VPU_in_line_start;
                    latched_frame_start <= VPU_in_frame_start;
                    
                    VPU_out_valid       <= 1'b1;
                    VPU_out_pixel       <= VPU_in_pixel;
                    VPU_out_line_start  <= VPU_in_line_start;  // Start signals only on first copy
                    VPU_out_frame_start <= VPU_in_frame_start;
                     
                    h_rep <= 1'b1;
                end
            end
            // Note: true vertical 2x requires either a second pass of the same
            // line (upstream sends it twice) or a line buffer feeding this module.
            // Here we just keep v_rep/pending_* as placeholders for when you
            // integrate with VideoBuffer and add a second-feed path.
        end
    end

endmodule

module Scaler2x_frame #(
    parameter MAX_WIDTH   = 1024,
    parameter MAX_HEIGHT  = 960,
    parameter PIXEL_WIDTH = 24
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [15:0]            cfg_width,
    input  wire [15:0]            cfg_height,

    // VideoBuffer read side
    output wire                                     VPU_rd_en,
    output wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0]  VPU_rd_addr,
    input  wire [PIXEL_WIDTH-1:0]                   VPU_rd_data,

    // Output 2x-upscaled stream
    output wire                   VPU_out_valid,
    output wire [PIXEL_WIDTH-1:0] VPU_out_pixel,
    output wire                   VPU_out_line_start,
    output wire                   VPU_out_frame_start
);
    // TODO: implement frame-based 2x scaler
    assign VPU_rd_en           = 1'b0;
    assign VPU_rd_addr         = {($clog2(MAX_WIDTH*MAX_HEIGHT)){1'b0}};
    assign VPU_out_valid       = 1'b0;
    assign VPU_out_pixel       = {PIXEL_WIDTH{1'b0}};
    assign VPU_out_line_start  = 1'b0;
    assign VPU_out_frame_start = 1'b0;
endmodule


module Scaler2x #(
    parameter MAX_WIDTH   = 1024,
    parameter MAX_HEIGHT  = 960,
    parameter PIXEL_WIDTH = 24
)(
    input wire  clk,
    input wire  rst_n,

    // Mode select: 1 = stream mode (line-based), 0 = frame mode (future)
    input wire  VPU_use_stream_mode,

    // Config (for future frame mode)
    input wire [15:0]            VPU_cfg_width,
    input wire [15:0]            VPU_cfg_height,

    // Stream input (from sampler / line buffer)
    input wire                   VPU_in_valid,
    input wire [PIXEL_WIDTH-1:0] VPU_in_pixel,
    input wire                   VPU_in_line_start,
    input wire                   VPU_in_frame_start,

    // VideoBuffer read side (used only in frame mode)
    output wire                                     VPU_rd_en,
    output wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0]  VPU_rd_addr,
    input  wire [PIXEL_WIDTH-1:0]                   VPU_rd_data,

    // Unified 2x output stream
    output wire                   VPU_out_valid,
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
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) u_scaler_stream (
        .clk               (clk),
        .rst_n             (rst_n),
        .VPU_in_valid      (VPU_in_valid),
        .VPU_in_pixel      (VPU_in_pixel),
        .VPU_in_line_start (VPU_in_line_start),
        .VPU_in_frame_start(VPU_in_frame_start),
        .VPU_out_valid     (s_out_valid),
        .VPU_out_pixel     (s_out_pixel),
        .VPU_out_line_start(s_out_line_start),
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
