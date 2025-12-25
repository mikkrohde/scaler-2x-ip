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
        parameter MAX_WIDTH   = 1920,
        parameter MAX_HEIGHT  = 1080,
        parameter PIXEL_WIDTH = 24
    )(
        input wire                   clk,
        input wire                   rst_n,
        input wire [15:0]            cfg_width,
        input wire [15:0]            cfg_height,

        // VideoBuffer read side
        output reg                                      VPU_rd_en,
        output reg [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0]   VPU_rd_addr,
        input  wire [PIXEL_WIDTH-1:0]                   VPU_rd_data,

        // Output 2x-upscaled stream
        output reg                    VPU_out_valid,
        input wire                    VPU_out_ready,
        output reg [PIXEL_WIDTH-1:0]  VPU_out_pixel,
        output reg                    VPU_out_line_start,
        output reg                    VPU_out_frame_start
    );
        
    //Vertical buffer variables:
    reg [$clog2(MAX_WIDTH)-1:0]  src_col;   // Current column in source frame
    reg [$clog2(MAX_HEIGHT)-1:0] src_row;
    
    // Horizontal repeat flag: 0 = first copy, 1 = second copy of same input pixel
    // Vertical repeat flag: 0 = first output line for this input line, 1 = second output line for this input line
    // Latches to remember frame/line start for the second vertical pass
    reg horizontal_repitition;
    reg vertical_repitition;
    reg [PIXEL_WIDTH-1:0] latched_pixel;
    
    // State machine
    localparam IDLE         = 3'b000;
    localparam FETCH_PIXEL  = 3'b001;
    localparam WAIT_READ    = 3'b010;
    localparam OUTPUT_FIRST = 3'b011;
    localparam OUTPUT_SECOND= 3'b100;
    
    reg [2:0] state, next_state;
    
    // State transition logic (combinational)
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                next_state = FETCH_PIXEL;  // Auto-start
            end
            
            FETCH_PIXEL: begin
                next_state = WAIT_READ;  // Next source line
            end
            
            WAIT_READ: begin
                next_state = OUTPUT_FIRST; // Data ready
            end
            
            OUTPUT_FIRST: begin
                if (VPU_out_ready) 
                    next_state = OUTPUT_SECOND;
                else
                    next_state = OUTPUT_FIRST;
            end
            
            OUTPUT_SECOND: begin
                if (VPU_out_ready) begin
                    next_state = FETCH_PIXEL;
                end else begin
                    next_state = OUTPUT_SECOND;  // Wait
                end
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src_col                 <= 0;
            src_row                 <= 0;
            horizontal_repitition   <= 1'b0;
            vertical_repitition     <= 1'b0;
            VPU_out_valid           <= 1'b0;
            VPU_out_pixel           <= {PIXEL_WIDTH{1'b0}};
            VPU_out_line_start      <= 1'b0;
            VPU_out_frame_start     <= 1'b0;
            latched_pixel           <= {PIXEL_WIDTH{1'b0}};
            VPU_rd_en               <= 0;
            VPU_rd_addr             <= 0;
            state                   <= IDLE;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    src_row <= 0;
                    src_col <= 0;
                    vertical_repitition <= 0;
                    VPU_out_valid <= 1'b0;
                end
                
                FETCH_PIXEL: begin
                    VPU_out_valid <= 1'b0;
                    if (src_col >= cfg_width) begin
                        // Line complete - wrap to next line
                        src_col <= 0;
                        VPU_rd_en <= 1'b0;  // Don't read during wrap
        
                        if (vertical_repitition == 0) begin
                            // First pass done, do second pass of same line
                            vertical_repitition <= 1;
                        end else begin
                            // Second pass done, move to next source row
                            vertical_repitition <= 0;
                            if (src_row >= cfg_height - 1)
                                src_row <= 0;  // Wrap frame
                            else
                                src_row <= src_row + 1;
                        end
                    end else begin
                        // Normal pixel fetch
                        VPU_rd_en   <= 1'b1;
                        VPU_rd_addr <= src_row * cfg_width + src_col;
                    end
                end
                
                WAIT_READ: begin
                    VPU_rd_en     <= 1'b0;
                    latched_pixel <= VPU_rd_data;
                end
                
                OUTPUT_FIRST: begin
                    VPU_out_valid       <= 1'b1;
                    VPU_out_pixel       <= latched_pixel;
                    VPU_out_line_start  <= (src_col == 0);
                    VPU_out_frame_start <= (src_row == 0 && src_col == 0 && vertical_repitition == 0);
                end
                
                OUTPUT_SECOND: begin
                    VPU_out_valid       <= 1'b1;
                    VPU_out_pixel       <= latched_pixel;
                    VPU_out_line_start  <= 1'b0;
                    VPU_out_frame_start <= 1'b0;
                    if (VPU_out_ready) begin
                        src_col <= src_col + 1;
                    end
                end
            endcase
        end
    end 
endmodule
