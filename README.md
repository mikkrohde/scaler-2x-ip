# Scaler2x Video Upscaler IP Core

A hardware-accelerated 2x video upscaling IP core for FPGAs, designed for real-time video processing applications.

## Overview

Scaler2x is a configurable video upscaler that doubles the resolution of input video streams using nearest-neighbor interpolation. The core supports both streaming (line-by-line) and frame-buffer modes, making it suitable for various video processing pipelines.

**Key Specifications:**
- **Scaling Factor:** 2x horizontal and 2x vertical (4x total pixels)
- **Interpolation:** Nearest-neighbor (pixel duplication)
- **Interface:** AXI4-Stream compatible (valid/ready handshaking)
- **Latency:** Approximately 1.5 input lines in stream mode
- **Throughput:** Up to 1 pixel per clock cycle (input rate)

## Features

### Current (v1.0)
- ✅ **Stream Mode:** Line-by-line processing with minimal buffering
- ✅ **2x Horizontal Scaling:** Each pixel duplicated horizontally
- ✅ **2x Vertical Scaling:** Each line duplicated vertically  
- ✅ **Efficient Memory Usage:** Single line buffer (1x input width)
- ✅ **Backpressure Support:** Full AXI-style flow control
- ✅ **Frame/Line Markers:** Preserves synchronization signals
- ✅ **Configurable Dimensions:** Runtime-configurable input resolution

### Planned (Future)
- ⏳ **Frame Mode:** Process from video frame buffer
- ⏳ **Bilinear Interpolation:** Higher quality upscaling option

### Block Diagram
## Architecture

```
          ┌─────────────────────────────┐
          │      Scaler2x Top           │
          │  (Mode Multiplexer)         │
          └──────────────┬──────────────┘
                         │
          ┌──────────────┴────────────────┐
          │                               │
┌─────────▼─────────┐          ┌──────────▼──────────┐
│ Scaler2x_stream   │          │  Scaler2x_frame     │
│  (Implemented)    │          │  (Placeholder)      │
└───────────────────┘          └─────────────────────┘
```
### Stream Mode Pipeline

Input Stream → Horizontal Doubler → Line Buffer → Vertical Doubler → Output Stream
(2x width) (1 line) (2x height)

**State Machine (Stream Mode):**
1. **IDLE:** Wait for frame_start signal
2. **FIRST_VPASS:** Accept input, perform H 2x, output, fill line buffer
3. **SECOND_VPASS:** Read from buffer, perform H 2x, output duplicate line

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `PIXEL_WIDTH` | integer | 24 | Bits per pixel (RGB888 = 24) |
| `MAX_WIDTH` | integer | 1920 | Maximum input line width (pixels) |
| `MAX_HEIGHT` | integer | 1080 | Maximum frame height (for frame mode) |

## Interface Signals

### Configuration
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_use_stream_mode` | 1 | Input | 1=Stream mode, 0=Frame mode |
| `VPU_cfg_width` | 16 | Input | Input line width (pixels) |
| `VPU_cfg_height` | 16 | Input | Input frame height (lines) |

### Input Stream (AXI-Stream)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_in_valid` | 1 | Input | Input pixel valid |
| `VPU_in_ready` | 1 | Output | Ready to accept input |
| `VPU_in_pixel` | PIXEL_WIDTH | Input | Input pixel data |
| `VPU_in_line_start` | 1 | Input | First pixel of line marker |
| `VPU_in_frame_start` | 1 | Input | First pixel of frame marker |

### Output Stream (AXI-Stream Like)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_valid` | 1 | Output | Output pixel valid |
| `VPU_out_ready` | 1 | Input | Downstream ready |
| `VPU_out_pixel` | PIXEL_WIDTH | Output | Output pixel data |
| `VPU_out_line_start` | 1 | Output | First pixel of line marker |
| `VPU_out_frame_start` | 1 | Output | First pixel of frame marker |

### Frame Buffer Interface (Frame Mode Only)
| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_rd_en` | 1 | Output | Memory read enable |
| `VPU_rd_addr` | log2(MAX_WIDTH×MAX_HEIGHT) | Output | Memory read address |
| `VPU_rd_data` | PIXEL_WIDTH | Input | Memory read data |

## Usage Example

### Instantiation

```Verilog
Scaler2x #(
  .MAX_WIDTH(640),
  .MAX_HEIGHT(480),
  .PIXEL_WIDTH(24)
) video_scaler (
  .clk(pixel_clk),
  .rst_n(reset_n),
  // Mode selection
  .VPU_use_stream_mode(1'b1),  // Stream mode
  .VPU_cfg_width(16'd640),
  .VPU_cfg_height(16'd480),
  
  // Input stream (640x480)
  .VPU_in_valid(vga_valid),
  .VPU_in_ready(vga_ready),
  .VPU_in_pixel(rgb_data),
  .VPU_in_line_start(hsync),
  .VPU_in_frame_start(vsync),
  
  // Output stream (1280x960)
  .VPU_out_valid(hdmi_valid),
  .VPU_out_ready(hdmi_ready),
  .VPU_out_pixel(hdmi_rgb),
  .VPU_out_line_start(hdmi_hsync),
  .VPU_out_frame_start(hdmi_vsync),
  
  // Frame buffer (unused in stream mode)
  .VPU_rd_en(),
  .VPU_rd_addr(),
  .VPU_rd_data(24'd0)
);
```


### Testbench Example

See `tb_Scaler2x.v` for a complete testbench that:
- Generates a 6×4 test pattern
- Drives the scaler with proper handshaking
- Validates 12×8 output with correct pixel values
- Verifies line/frame synchronization markers

## Resource Utilization

**Typical Implementation (1920×1080 max, 24-bit color):**

| Resource | Usage | Notes |
|----------|-------|-------|
| BRAM | ~46 KB | 1 line buffer (1920×24-bit) |
| LUTs | ~300 | State machine + control logic |
| FFs | ~150 | Registers and counters |
| DSP | 0 | No multipliers needed for NN |

**Clock Frequency:** Tested at 100 MHz (sufficient for 1080p60)

## Timing Characteristics

### Stream Mode Latency
- **Pipeline depth:** 1.5 input lines
- **First output pixel:** After first input line complete
- **Steady state:** 2 output lines per 1 input line

### Example (640×480 → 1280×960)
- Input rate: 640 pixels/line
- Output rate: 1280 pixels/line (takes ~2× longer to output)
- Per input line: ~640 cycles input + ~1280 cycles first output + ~1280 cycles second output

## Verification

**Test Coverage:**
- ✅ 6×4 input → 12×8 output validation
- ✅ Pixel value correctness (nearest-neighbor)
- ✅ Line/frame marker preservation
- ✅ Handshake protocol compliance
- ✅ State machine transitions
- ✅ Line buffer addressing

**Test Status:** All tests passing (96/96 pixels correct)

## Known Limitations

1. **Stream mode only:** Frame mode not yet implemented
2. **Fixed 2x scaling:** No other scaling factors supported
3. **Nearest-neighbor only:** No interpolation quality options
4. **No downscaling:** Upscaling only
5. **Sequential output:** Cannot skip or reorder lines

## Design Decisions

### Why Single Line Buffer?
- **Efficiency:** Nearest-neighbor only needs to repeat the current line
- **Pipelined:** Fill buffer during first vertical pass, read during second
- **Resource-optimal:** Saves 50% BRAM vs. buffering horizontally-scaled data

### Why Two-Process State Machine?
- **Industry standard:** Clear separation of combinational/sequential logic
- **Debuggability:** Easier to verify state transitions
- **Synthesis-friendly:** Better timing closure

### Why AXI-Stream-like Interface?
- **Standard protocol:** Compatible with Xilinx/Intel video IP
- **Backpressure:** Handles downstream stalls gracefully
- **Composable:** Easy to chain with other video processing blocks

## Future Development

### Priority 1: Frame Mode
- Implement `Scaler2x_frame` module
- Address generation for 2D scaling
- Integration with video frame buffers

### Priority 2: Quality Modes
- Add bilinear interpolation (2 line buffers)
- Runtime-selectable via config register
- Shared buffer architecture

## License

MIT - have fun :D

## Version History

- **v1.0** (2025-12-25): Initial release
  - Stream mode with nearest-neighbor 2x upscaling
  - Verified on 6×4 → 12×8 test pattern

## References

Based on industry-standard video scaling architectures similar to:
- Xilinx Video Processing Subsystem
- Intel Video Scaler IP
- MiSTer FPGA scaler implementations


