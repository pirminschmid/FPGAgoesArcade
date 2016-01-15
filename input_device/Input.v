`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:        Sandro Meier
// 
// Create Date:    12:56:27 05/16/2014 
// Design Name: 
// Module Name:    Input 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

// Input device.
// Uses 2 of the 4 buttons on the board to steer the bike to left or right.
// This device was built to have as simple a MIPS assembly program as possible.
// Thus lots of needed calculation is done within this hardware device,
// which returns direclty delta x and delta y values of {-1, 0, 1}.
// -1 is encoded in two's complement
// interface kept identical to all RAM access within the motherboard (including
// reading and writing)
// CLK         Clock -> will be divided to sample the buttons at a reasonable interval
// RST         reset
// opcode      selects which direction is returned as result, or written as a start value
//             01 = x
//             10 = y
//             00 = nothing
// leftButton  connected with hardware button
// rightButton connected with hardware button
// writeEnable data is written if this is 1
// data        32 bit bus with input data (set start value) if writeEnable
// delta       32 bit bus with output data

module Input(
    input CLK,  
    input RST,
    input [1:0] opCode,
    input leftButton,
    input rightButton,
    input writeEnable,
    input [31:0] data,
    output [31:0] delta
    );

//////////////////////////////////////////////////////////////////////////////////
// opcodes for the IO interface
    localparam [1:0] INPUT_OPCODE_NONE = 2'b00;
    localparam [1:0] INPUT_OPCODE_DX   = 2'b01;
    localparam [1:0] INPUT_OPCODE_DY   = 2'b10;
    
//////////////////////////////////////////////////////////////////////////////////
// Registers for the values of x and y values
// These registers can contain the values -1, 0 and 1
// The resulting directions will then look like this:
//
//   x       y      direction
//---------------------------
//   1       0      right
//   0       1      down
//  -1       0      left
//   0      -1      up
//
//
    reg [31:0] xDelta;
    reg [31:0] yDelta;

//////////////////////////////////////////////////////////////////////////////////  
// The internal clock which is around 6 Hz

    wire internal_clock;
    
    // Clock divider which divides the clock by a factor 8.4 million
    reg [22:0] clk_count;
    always @ (posedge CLK, posedge RST)
    begin
        if (RST) clk_count <= 0;
        else
            clk_count <= clk_count+1'b1;
    end
    
    // Assign the internal clock
    assign internal_clock = &clk_count;

//////////////////////////////////////////////////////////////////////////////////  
// State machine to switch between the buttons

    always @ (posedge CLK, posedge RST)
    begin
        // only check for user input if ther is no setup by the software
        if ( RST ) begin
            xDelta <= 32'h0;
            yDelta <= 32'h0;
        end
        else if ( writeEnable ) begin
            case ( opCode )
                INPUT_OPCODE_DX : xDelta <= data;
                INPUT_OPCODE_DY : yDelta <= data;
            endcase
        end
        else if ( internal_clock ) begin
            // Check the buttons
            if (leftButton) begin 
                if (xDelta[1:0] === 2'b01) begin
                    // right to up
                    xDelta <= 32'h0;
                    yDelta <= 32'hffffffff;
                end
                else if (xDelta[1:0] === 2'b11) begin
                    // left to down
                    xDelta <= 32'h0;
                    yDelta <= 32'h1;
                end
                else if (yDelta[1:0] === 2'b01) begin
                    // Down to right
                    xDelta <= 32'h1;
                    yDelta <= 32'h0;
                end
                else if (yDelta[1:0] === 2'b11) begin
                    // Up to left
                    xDelta <= 32'hffffffff;
                    yDelta <= 32'h0;
                end
            end
            else if (rightButton) begin
                // else was chosen to exclude handling both buttons pressed
                
                if (xDelta[1:0] === 2'b11) begin
                    // left to up
                    xDelta <= 32'h0;
                    yDelta <= 32'hffffffff;
                end
                else if (xDelta[1:0] === 2'b01) begin
                    // right to down
                    xDelta <= 32'h0;
                    yDelta <= 32'h1;
                end
                else if (yDelta[1:0] === 2'b11) begin
                    // up to right
                    xDelta <= 32'h1;
                    yDelta <= 32'h0;
                end
                else if (yDelta[1:0] === 2'b01) begin
                    // down to left
                    xDelta <= 32'hffffffff;
                    yDelta <= 32'h0;
                end
            end
        end
    end


//////////////////////////////////////////////////////////////////////////////////
// return desired delta value

    assign delta = (opCode === INPUT_OPCODE_DX) ? xDelta :
                        (opCode === INPUT_OPCODE_DY) ? yDelta :
                       32'h0;

    // debug
    //assign delta = 32'b1;
    //assign delta = 32'hffffffff;

endmodule
