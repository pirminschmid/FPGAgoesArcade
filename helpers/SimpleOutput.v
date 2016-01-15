`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Pirmin Schmid
// 
// Create Date:    14:22:59 05/17/2014 
// Design Name: 
// Module Name:    SimpleOutput 
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

// interface kept identical to all RAM access within the motherboard (including
// reading and writing)
// CLK_mips    (either 12.5 MHz or 1 Hz signal based on clockdiv)
// RST         resets the device
// WE          write enabled (writes data)
// write_data  32 bit bus with data (only 4 lsb) to be written into the LED register if WE
// read_data   32 bit bus returning the data stored in LED register
// LED         4 bit register bus connected to the hardware LED pins

module SimpleOutput(
    input CLK_mips,
    input RST,
    input WE,
    input [31:0] write_data,
    output [31:0] read_data,
    output reg [3:0] LED
    );

// write data
    always @ ( posedge CLK_mips, posedge RST )
        begin
            if ( RST )
                LED <= 4'b0000;
            else
                if ( WE )
                    LED <= write_data[3:0];
        end

// read data
    assign read_data = {28'h0, LED};

endmodule
