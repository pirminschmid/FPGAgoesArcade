`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Pirmin Schmid and Sandro Meier
// 
// Create Date:    05/09/2014 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: this file implements the "motherboard" and organizes all
// I/O access connected to the MIPS processor.
//
// Dependencies (provided here):
// - clockdiv (clock rate divider) -> see helpers
// - Input (key board, i.e 4 input buttons) -> see input_device
// - SimpleOutput (output of the score on the LEDs in binary) -> see helpers
// - VideoModule (the video card) -> see vga_device
//
// Dependencies (not provided here):
// - MIPS (actual MIPS CPU) -> see description in referenced book
// 
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: There is some redundancy, which is kept to have
// better readability of the code.
//
//////////////////////////////////////////////////////////////////////////////////
module top(
    input FPGACLK,
    input RESET,
  
    input player1_LeftButton,
    input player1_RightButton,
    input player2_LeftButton,
    input player2_RightButton,        
  
    output VGA_HSYNC,
    output VGA_VSYNC,
    output VGA_RED,
    output VGA_GREEN,
    output VGA_BLUE,
          
    output [7:0] STATUS_LED
    );

// Define internal signals
    wire CLK;                 // The output of the clock divider 12.5 MHz Clock

// MIPS interface
    wire [31:0] IOWriteData;
    wire  [3:0] IOAddr;
    wire        IOWriteEn;
    wire [31:0] IOReadData;
    wire IsIO; // new added for better IO device management.
    
//////////////////////////////////////////////////////////////////////////////////
// video
    wire [1:0] vga_opcode;
    wire vga_access;
    wire vga_we;
    wire [31:0] vga_write_data;
    wire [31:0] vga_read_data;

//////////////////////////////////////////////////////////////////////////////////
// input devices
    wire [1:0] input1_opcode;
    wire input1_access;
    wire input1_we;
    wire [31:0] input1_write_data;
    wire [31:0] input1_read_data;
    
    wire [1:0] input2_opcode;
    wire input2_access;
    wire input2_we;
    wire [31:0] input2_write_data;
    wire [31:0] input2_read_data;

//////////////////////////////////////////////////////////////////////////////////
// output devices
    wire output1_access;
    wire output1_we;
    wire [31:0] output1_write_data;
    wire [31:0] output1_read_data;

    wire output2_access;
    wire output2_we;
    wire [31:0] output2_write_data;
    wire [31:0] output2_read_data;
    
//////////////////////////////////////////////////////////////////////////////////
// DEFINE SOME CONSTANTS to make life easier

    // for debugging
    localparam DEBUG_SPEED = 1'b0; // flag for debug speed, which is 1 Hz

    // for VGA output
    localparam [3:0] IO_VGA_X     = 4'h0;
    localparam [3:0] IO_VGA_Y     = 4'h1;
    localparam [3:0] IO_VGA_PIXEL = 4'h2;
    
    localparam [1:0] VGA_OPCODE_NONE  = 2'b00;
    localparam [1:0] VGA_OPCODE_X     = 2'b01;
    localparam [1:0] VGA_OPCODE_Y     = 2'b10;
    localparam [1:0] VGA_OPCODE_PIXEL = 2'b11;
    
    // for input devices
    localparam [3:0] IO_INPUT1_DX = 4'h3;
    localparam [3:0] IO_INPUT1_DY = 4'h4;
    localparam [3:0] IO_INPUT2_DX = 4'h5;
    localparam [3:0] IO_INPUT2_DY = 4'h6;
    
    localparam [1:0] INPUT_OPCODE_NONE = 2'b00;
    localparam [1:0] INPUT_OPCODE_DX   = 2'b01;
    localparam [1:0] INPUT_OPCODE_DY   = 2'b10;
    
    // for score LED output: currently simple output in binary mode on status LEDs
    localparam [3:0] IO_OUTPUT1 = 4'h7;
    localparam [3:0] IO_OUTPUT2 = 4'h8; 
    
//////////////////////////////////////////////////////////////////////////////////

// Instantiate an internal clock divider that will 
// take the 50 MHz FPGA clock and divide it by 5 so that
// We will have a simple 12.5 MHz clock internally
//
// or 1 Hz in debug mode
clockdiv ClockDiv (
    .clk(FPGACLK), 
    .rst(RESET),
    .debugMode(DEBUG_SPEED),
    .clk_en(CLK)
    );

//////////////////////////////////////////////////////////////////////////////////
// opcodes

    assign vga_opcode = (~IsIO) ? VGA_OPCODE_NONE :
                        (IOAddr[3:0] === IO_VGA_X) ? VGA_OPCODE_X :
                        (IOAddr[3:0] === IO_VGA_Y) ? VGA_OPCODE_Y :
                        (IOAddr[3:0] === IO_VGA_PIXEL) ? VGA_OPCODE_PIXEL :
                        VGA_OPCODE_NONE; 

    assign input1_opcode = (~IsIO) ? INPUT_OPCODE_NONE :
                           (IOAddr[3:0] === IO_INPUT1_DX) ? INPUT_OPCODE_DX :
                           (IOAddr[3:0] === IO_INPUT1_DY) ? INPUT_OPCODE_DY :
                           INPUT_OPCODE_NONE;

    assign input2_opcode =  (~IsIO) ? INPUT_OPCODE_NONE :
                            (IOAddr[3:0] === IO_INPUT2_DX) ? INPUT_OPCODE_DX :
                            (IOAddr[3:0] === IO_INPUT2_DY) ? INPUT_OPCODE_DY :
                            INPUT_OPCODE_NONE;

// access

    assign vga_access = |vga_opcode; // any opcode indicates access;

    assign input1_access = |input1_opcode;
    assign input2_access = |input2_opcode;

    assign output1_access = (~IsIO) ? 1'b0 :
                            (IOAddr[3:0] === IO_OUTPUT1) ? 1'b1 :
                            1'b0;

    assign output2_access = (~IsIO) ? 1'b0 :
                            (IOAddr[3:0] === IO_OUTPUT2) ? 1'b1 :
                            1'b0;

// read

    assign IOReadData = vga_access ? vga_read_data :
                        input1_access ? input1_read_data :
                        input2_access ? input2_read_data :
                        output1_access ? output1_read_data :
                        output2_access ? output2_read_data :
                        32'h0;

// write

    assign vga_we = IOWriteEn & vga_access;
    assign vga_write_data = IOWriteData;
    
    assign input1_we = IOWriteEn & input1_access;
    assign input1_write_data = IOWriteData;
    
    assign input2_we = IOWriteEn & input2_access;
    assign input2_write_data = IOWriteData;
    
    assign output1_we = IOWriteEn & output1_access;
    assign output1_write_data = IOWriteData;
    
    assign output2_we = IOWriteEn & output2_access;
    assign output2_write_data = IOWriteData;

//////////////////////////////////////////////////////////////////////////////////

// Instantiate the processor
MIPS processor (
    .CLK(CLK),
    .RESET(RESET), 
    .IOWriteData(IOWriteData),
    .IOAddr(IOAddr), 
    .IOWriteEn(IOWriteEn), 
    .IOReadData(IOReadData),
    .IsIO(IsIO)
    );

//////////////////////////////////////////////////////////////////////////////////

VideoModule video (
    .CLK_50MHz(FPGACLK),
    .CLK_mips(CLK),
    .RST(RESET),
    .opcode(vga_opcode),
    .WE(vga_we),
    .write_data(vga_write_data),
    .read_data(vga_read_data),
    .VGA_HSYNC(VGA_HSYNC),
    .VGA_VSYNC(VGA_VSYNC),
    .VGA_RED(VGA_RED),
    .VGA_GREEN(VGA_GREEN),
    .VGA_BLUE(VGA_BLUE)
    );

//////////////////////////////////////////////////////////////////////////////////

Input input_player1 (
    .CLK(FPGACLK),
    .RST(RESET),
    .opCode(input1_opcode),
    .leftButton(player1_LeftButton),
    .rightButton(player1_RightButton),
    .writeEnable(input1_we),
    .data(input1_write_data),
    .delta(input1_read_data)
    );

Input input_player2 (
    .CLK(FPGACLK),   
    .RST(RESET),
    .opCode(input2_opcode),
    .leftButton(player2_LeftButton),
    .rightButton(player2_RightButton),
    .writeEnable(input2_we),
    .data(input2_write_data),
    .delta(input2_read_data)
    );

//////////////////////////////////////////////////////////////////////////////////
// output points as binary numbers on the leds
// left 4: player 1
// right 4: player 2
// deactivate this in case status output is desired in debugging mode (see below)

SimpleOutput output_player1 (
    .CLK_mips(CLK),
    .RST(RESET),
    .WE(output1_we),
    .write_data(output1_write_data),
    .read_data(output1_read_data),
    .LED(STATUS_LED[7:4])
    );

SimpleOutput output_player2 (
    .CLK_mips(CLK),
    .RST(RESET),
    .WE(output2_we),
    .write_data(output2_write_data),
    .read_data(output2_read_data),
    .LED(STATUS_LED[3:0])
    );

//////////////////////////////////////////////////////////////////////////////////
// status codes (for debugging)
// only useful if debugging MIPS frequency of 1 Hz is activated
// note: deactivate simple output on the LEDs while debugging.

/*
    assign STATUS_LED[7] = input1_access;
    assign STATUS_LED[6] = input2_access;
    assign STATUS_LED[5] = vga_access;
    assign STATUS_LED[4] = vga_we | input1_we | input2_we;
    assign STATUS_LED[3:2] = vga_opcode | input1_opcode | input2_opcode;
    assign STATUS_LED[1:0] = IOReadData[1:0];
*/

endmodule
