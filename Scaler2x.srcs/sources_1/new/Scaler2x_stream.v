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
// Revision 1.0 - Initial 2x scaler for hsync-based video stream
// 
//////////////////////////////////////////////////////////////////////////////////

module Scaler2x_stream #(
    parameter                       PIXEL_WIDTH = 24,
    parameter                       MAX_WIDTH = 1920
)(
    input wire                      clk,
    input wire                      rst_n,
    input wire [15:0]               cfg_width,
    
    input wire                      VPU_in_valid,
    output wire                     VPU_in_ready,
    input wire [PIXEL_WIDTH-1:0]    VPU_in_pixel,
    input wire                      VPU_in_line_start,
    input wire                      VPU_in_frame_start,
    
    output reg                      VPU_out_valid,
    input wire                      VPU_out_ready,
    output reg [PIXEL_WIDTH-1:0]    VPU_out_pixel,
    output reg                      VPU_out_line_start,
    output reg                      VPU_out_frame_start
);
    
    //Vertical buffer variables:
    reg [PIXEL_WIDTH-1:0]       line_ram [0:MAX_WIDTH-1];
    reg [$clog2(MAX_WIDTH)-1:0] line_addr;
    
    // Horizontal repeat flag: 0 = first copy, 1 = second copy of same input pixel
    // Vertical repeat flag: 0 = first output line for this input line, 1 = second output line for this input line
    // Latches to remember frame/line start for the second vertical pass
    reg horizontal_repitition;
    reg vertical_repitition;
    reg [PIXEL_WIDTH-1:0] latched_pixel;
    reg latched_frame_start;
    reg latched_line_start;
    
    localparam IDLE         = 2'b00;
    localparam FIRST_VPASS  = 2'b01;
    localparam SECOND_VPASS = 2'b10;
    
    reg [1:0] state, next_state;
    
    //Handshake signals
    wire handshake_in  = VPU_in_valid && VPU_in_ready;
    wire handshake_out = VPU_out_valid && VPU_out_ready;
    
    // State transition logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (VPU_in_valid && VPU_in_frame_start)
                    next_state = FIRST_VPASS;
            end
            
            FIRST_VPASS: begin
                if (line_addr >= cfg_width)
                    next_state = SECOND_VPASS;
            end
            
            SECOND_VPASS: begin
                if (line_addr >= cfg_width)
                    next_state = FIRST_VPASS;
            end
        endcase
    end


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                   <= IDLE;
            horizontal_repitition   <= 1'b0;
            vertical_repitition     <= 1'b0;
            VPU_out_valid           <= 1'b0;
            VPU_out_pixel           <= {PIXEL_WIDTH{1'b0}};
            VPU_out_line_start      <= 1'b0;
            VPU_out_frame_start     <= 1'b0;
            latched_pixel           <= {PIXEL_WIDTH{1'b0}};
            latched_line_start      <= 1'b0;
            latched_frame_start     <= 1'b0;
            line_addr               <= 0;
        end else begin
            state <= next_state;

            if (state != next_state) begin
                line_addr <= 0;
                horizontal_repitition <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        // Do nothing until new line starts
                    end
                    
                    FIRST_VPASS: begin
                        if (!VPU_out_valid || handshake_out) begin
                            if (horizontal_repitition) begin
                                VPU_out_valid           <= 1'b1;
                                VPU_out_pixel           <= latched_pixel;
                                VPU_out_line_start      <= 1'b0;
                                VPU_out_frame_start     <= 1'b0;
                                horizontal_repitition   <= 1'b0;

                            end else if(handshake_in) begin
                                VPU_out_valid           <= 1'b1;
                                latched_pixel           <= VPU_in_pixel;
                                latched_line_start      <= VPU_in_line_start;
                                latched_frame_start     <= VPU_in_frame_start;
                                
                                VPU_out_pixel           <= VPU_in_pixel;
                                VPU_out_line_start      <= VPU_in_line_start;
                                VPU_out_frame_start     <= VPU_in_frame_start;

                                line_ram[line_addr]     <= VPU_in_pixel;
                                line_addr               <= line_addr + 1;
                                
                                horizontal_repitition   <= 1'b1;
                            end else begin
                                VPU_out_valid <= 1'b0; // No input available
                            end
                        end
                    end
                    
                    SECOND_VPASS: begin
                        if (!VPU_out_valid || handshake_out) begin
                            if (horizontal_repitition) begin
                                VPU_out_valid           <= 1'b1;
                                VPU_out_pixel           <= latched_pixel;
                                VPU_out_line_start      <= 1'b0;
                                VPU_out_frame_start     <= 1'b0;
                                horizontal_repitition   <= 1'b0;
                                
                            end else begin
                                VPU_out_valid           <= 1'b1;
                                VPU_out_pixel           <= line_ram[line_addr];
                                latched_pixel           <= line_ram[line_addr];
                                VPU_out_line_start      <= (line_addr == 0);
                                VPU_out_frame_start     <= 1'b0;
                                
                                horizontal_repitition   <= 1'b1;
                                line_addr               <= line_addr + 1;
                            end
                        end else begin
                            VPU_out_valid <= 1'b0;  // Deassert when line complete
                        end
                    end
                endcase
            end
        end
    end
    
    assign VPU_in_ready = (state == FIRST_VPASS) && (!VPU_out_valid || handshake_out) && !horizontal_repitition;

endmodule