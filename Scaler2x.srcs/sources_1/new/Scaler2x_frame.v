`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.12.2025 20:18:50
// Design Name: 
// Module Name: Scaler2x_frame
// Project Name: Scaler2x 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


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
