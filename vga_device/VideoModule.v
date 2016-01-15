`timescale 1ns / 1ps
`include "SVGA_DEFINES.v"

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Pirmin Schmid
// 
// Create Date:    21:43:52 05/15/2014 
// Design Name: 
// Module Name:    VideoModule 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
// 
// Dependencies:
// - SVGA_DEFINES.v
// - SVGA_TIMING_GENERATION.v
// - VIDEO_OUT.v
// - vram.v
//
// Revision: 
// Revision 0.01 - File Created
//
// Additional Comments: 
// opcode: 01 - X position
//         10 - Y position
//         11 - bitmap pixel in [1:0]
//         00 - nothing
//
// bitmap pixels are converted into RGB as defined with the constants below
//
// max calculations interface:
// 320: 9 bits   240:  9 bits  => 76'800: 17 bits
//
// vga output:
// 640: 10 bits   480:  9 bits  => 307'200: 19 bits
//////////////////////////////////////////////////////////////////////////////////

// This module is the actual video card.
// Due to memory restrictions on the Spartan 3 board, it offers a 320x240 bitmap
// with depth 2 bits (4 colors) to the software. It automatically upscales this
// bitmap to 640x480 of depth 3 (8 colors) available on the Spartan 3 VGA output.
// The I/O interface kept identical to all RAM access within the motherboard (including
// reading and writing). See top.v.
// CLK_50MHz     clock @ 50 MHz
// CLK_mips      clock @ either 12.5 MHz or 1 Hz as defined (see clockdiv.v)
// RST           resets the device
// opcode        defines the type of data
//               01 - X position
//               10 - Y position
//               11 - bitmap pixel in [1:0]
//               00 - nothing
//               see tron.asm for details how to used these opcodes
// WE            write enable (writes data in write data according to opcode)
// write_data    32 bit bus data connection, data is written if WE is 1
// read_data     32 bit bus data connection, read data based on opcode
// VGA_HSYNC,
// VGA_VSYNC,
// VGA_RED,
// VGA_GREEN,
// and VGA_BLUE  connected to hardware pins of the Spartan 3 FPGA board


module VideoModule(
    input CLK_50MHz,
    input CLK_mips,
    input RST,
    input [1:0] opcode,
    input WE,
    input [31:0] write_data,
    output [31:0] read_data,
    output VGA_HSYNC,
    output VGA_VSYNC,
    output VGA_RED,
    output VGA_GREEN,
    output VGA_BLUE
    );

//////////////////////////////////////////////////////////////////////////////////
// constants
//////////////////////////////////////////////////////////////////////////////////

    localparam [8:0] IN_WIDTH  = 320;
    localparam [8:0] IN_HEIGHT = 240;

    localparam [1:0] VGA_OPCODE_NONE  = 2'b00;
    localparam [1:0] VGA_OPCODE_X     = 2'b01;
    localparam [1:0] VGA_OPCODE_Y     = 2'b10;
    localparam [1:0] VGA_OPCODE_PIXEL = 2'b11;

    // rgb definitions of the 4 colors stored in the bitmap
    localparam [2:0] COLOR_00 = 3'b000; // black
    localparam [2:0] COLOR_01 = 3'b100; // red
    localparam [2:0] COLOR_10 = 3'b110; // yellow
    localparam [2:0] COLOR_11 = 3'b111; // white
    
    localparam ZERO1 = 1'b0;
    localparam ZERO2 = 2'b00;

//////////////////////////////////////////////////////////////////////////////////
// INTERFACE TOWARDS MIPS
//////////////////////////////////////////////////////////////////////////////////

    // position
    reg [8:0] x;
    reg [8:0] y;
    wire [16:0] address;
    
    wire [1:0] pixel_in;    // input from MIPS interface
    wire [1:0] pixel_out;   // output to MIPS interface
    wire [1:0] pixel_vga;   // output to VGA signal generation
    
    wire vram_access;
    wire vram_we;

    // address calculation
    assign address = (y * IN_WIDTH) + x;
    
    // access
    assign vram_access = (opcode === VGA_OPCODE_PIXEL) ? 1'b1 : 1'b0;
    assign vram_we     = WE & vram_access;
    
    // read (only one important case: read the pixel from VRAM)
    assign read_data = (opcode === VGA_OPCODE_PIXEL) ? {30'h0, pixel_out} :
                       (opcode === VGA_OPCODE_X) ? {23'h0, x} :
                       (opcode === VGA_OPCODE_Y) ? {23'h0, y} :
                       32'h0;

    // debug
    //assign read_data = 32'h0;
    //assign read_data = {30'h0, pixel_out};
    
    // write
    assign pixel_in = write_data[1:0];
    
    always @ ( posedge CLK_mips, posedge RST )  // At rising edge of MIPS CLK
        begin
            if ( RST ) begin
                x <= 9'h0;
                y <= 9'h0;
            end
            else if ( WE ) begin
                case ( opcode )
                    VGA_OPCODE_X :  x <= write_data[8:0];
                    VGA_OPCODE_Y :  y <= write_data[8:0];
                endcase
            end
        end

//////////////////////////////////////////////////////////////////////////////////
// OUTPUT: VGA signal generation
//////////////////////////////////////////////////////////////////////////////////
    
    //wire system_clock_buffered;
    reg pixel_clock;
    
    wire h_sync;
    wire v_sync;
    wire blank;
    
    wire [10:0] pixel_count;
    wire [9:0] line_count;

    wire [8:0] pixel_count2; // = pixel_count / 2
    wire [8:0] line_count2;  // = line_count / 2
    
    wire [16:0] readout_address;
    wire red;
    wire green;
    wire blue;

// video clock generation: 25 MHz for 640x480 VGA (it would need 25.175 MHz)

    always @ (posedge CLK_50MHz, posedge RST)
        begin
            if (RST) pixel_clock <= 1'b0;
            else pixel_clock <= ~pixel_clock;
        end
    
// SVGA timing generation

SVGA_TIMING_GENERATION svga_timing(
    .pixel_clock(pixel_clock),
    .reset(RST),
    .h_synch(h_sync),
    .v_synch(v_sync),
    .blank(blank),
    .pixel_count(pixel_count),
    .line_count(line_count)
    );

// read out the RAM

    assign pixel_count2 = pixel_count[9:1]; // shift right equals division by 2
    assign line_count2 = line_count[9:1];
    
    assign readout_address = (line_count2 * IN_WIDTH) + pixel_count2;

    assign {red, green, blue} = (pixel_vga == 2'b01) ? COLOR_01 :
                                (pixel_vga == 2'b10) ? COLOR_10 :
                                (pixel_vga == 2'b11) ? COLOR_11 :
                                COLOR_00;

    // debug: ok!
    // assign {red, green, blue} = readout_address[2:0]; // vertical stripes: ok
    // assign {red, green, blue} = readout_address[8:6]; // together with multiplication only: ok
    // assign {red, green, blue} = line_count[4:2];      // horizontal stripes: ok

// video out

VIDEO_OUT video_connector(
    .pixel_clock(pixel_clock),
    .reset(vga_reset),
    .vga_red_data(red),
    .vga_green_data(green),
    .vga_blue_data(blue),
    .h_synch(h_sync),
    .v_synch(v_sync),
    .blank(blank),
    .VGA_HSYNCH(VGA_HSYNC),
    .VGA_VSYNCH(VGA_VSYNC),
    .VGA_OUT_RED(VGA_RED),
    .VGA_OUT_GREEN(VGA_GREEN),
    .VGA_OUT_BLUE(VGA_BLUE)
    );

//////////////////////////////////////////////////////////////////////////////////
// RAM: storage
//////////////////////////////////////////////////////////////////////////////////  

vram VRAM(
  .clka(CLK_mips),
  .wea(vram_we),
  .addra(address),
  .dina(pixel_in),
  .douta(pixel_out),
  .clkb(pixel_clock),
  .web(ZERO1),
  .addrb(readout_address),
  .dinb(ZERO2),
  .doutb(pixel_vga)
);
        
endmodule
