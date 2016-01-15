Walkthrough guide
=================
Top down may be the fastest way to understand this project, which is a very simple computer.

![Spartan3][spartan3_small]

([larger picture][spartan3_large])

Motherboard (top.v and top.ucf)
-------------------------------
top.v describes the "motherboard" of the specified hardware to be run on the FPGA. It connects all sub-modules and the actual hardware pins provided by the Spartan 3 board.
- MIPS processor (including instruction and data RAM)
- Input device (transforms button presses to delta position values for both players)
- VGA graphics card (renders the bitmap available at the software interface side into signals available at the VGA port of the board)
- Output device (binary representation of the score)

See top.ucf for the connection of the Verilog description with the actual hardware (buttons, VGA output, LED output).

The interfaces to the sub-modules should be quite clear. They will be described below. It may be of interest that the actual RAM of this computer (split into instruction RAM and data RAM) was part of the MIPS module. We used memory mapping to make the input/output areas of the described I/O devices here visible to the actual processor. Thus, the address space with prefix 0x00007f was not actually adressing RAM but accessing devices (see hardware registers).
```verilog
// in MIPS.v
assign IsIO = (ALUResult[31:8] == 24'h00007f) ? 1 : 0;
```
And to keep I/O very simple, the devices are accessed by the same pattern as RAM is accessed (using lw [load word]; sw [store word] MIPS instructions). If the flag/bit WE (write enabled) is 1, then data in write_data (32 bit bus) is written to the hardware register of the associated device, otherwise bits in write_data are ignored. The current data of the hardware registers is returned in read_data (32 bit bus). The logic in top.v has been built to mux/demux the proper I/O device signals to the MIPS module, and IsIO allows the MIPS module to mux/demux RAM access and I/O.

Of course, this simple hardware does not allow for interrupts. Thus only polling is available to the software. But as you can see e.g. in Input.v, the devices do already most of the work themselves and provide quite high-level access towards the running MIPS software.

Let's have a look at individual modules:

clockdiv.v (helpers)
--------------------
This module divides the 50 MHz clock of the board by 4 to provide a 12.5 MHz clock signal to the MIPS CPU and all devices. An additional debugging mode has been introduced to provide a clock signal of 1 Hz. If the additional debug connections of some internal wires to the LEDs are activated (see top.v lines 280-285), the LED status provides quite a good feedback in sync with the printed assembly source code, one line per second.

SimpleOutput.v (helpers)
------------------------
The LEDs are used as a binary output of the scores for each player (0-15 each). A more advanced output could display the values on the four 7-segment LED displays as digits (0-99), which is not yet implemented.
I/O mapped to address space.
```MIPS_assembly
#     0x7ff7 score player 1
#     0x7ff8 score player 2
```

Input.v (input_device)
----------------------
This device samples the input buttons at reasonable clock frequencies and calculates delta x and delta y values that are provided as actual I/O output. Thus, the software can read the deltas for each player and just add them to the current position values. An example how hardware can unload calculations from software. Start delta values are written to the registers accordingly during initialization.
```MIPS_assembly
#     0x7ff3 player 1 delta x
#     0x7ff4          delta y
#     0x7ff5 player 2 delta x
#     0x7ff6          delta y
```

VideoModule.v (vga_device)
--------------------------
This is the "graphics card" for the computer. The same simple read/write access pattern is used as for all the other modules.
```MIPS_assembly
#     0x7ff0  x position
#     0x7ff1  y position
# --> set x/y positions first for both, reading and writing
#     0x7ff2  2-bit bitmap color at the lsb end of the 32 bit word
# --> the engine draws this pixel as soon as it is set by sw
# --> read the current color at position x,y with lw
#     note: use a nop instruction (like add $0, $0, $0)
#     between setting the x/y position and reading the color with lw at 0x7ff2
#     to compensate for vram delay (1 cycle as documented).
#     writing does not need such a delay.
```

This device uses several sub-modules. Video RAM (vram.v) was built using builtin design tools in the Xilinx ISE software. Maximum available space was used. It is the buffer / connection between read/write access at MIPS clock speed triggered by the MIPS assembly software and the output at signal clock speed as specified by the VGA specifications, both running in parallel independently of each other. Due to memory restrictions, a 320x240 bitmap (depth 2 bits, 4 colors) on the software side is automatically upscaled to the 640x480 output (depth 3 bits, 8 colors). See "Interface towards MIPS" (VideoModule.v lines 101-150) and "Output VGA signal generation" (VideoModule.v lines 151-226) for details. Note the 1 cycle delay for reading color values at a specific position after setting the x and y coordinates.

The colors are hard wired.
```Verilog
// rgb definitions of the 4 colors stored in the bitmap
localparam [2:0] COLOR_00 = 3'b000; // black
localparam [2:0] COLOR_01 = 3'b100; // red
localparam [2:0] COLOR_10 = 3'b110; // yellow
localparam [2:0] COLOR_11 = 3'b111; // white
```

The software interface is straightforward.
```MIPS_assembly
# writing a pixel (x, y, color)
sw $s0, 0x7ff0($0)  # set x, no visible action
sw $s1, 0x7ff1($0)  # set y, no visible action
sw $t2, 0x7ff2($0)  # set color, pixel is drawn

# reading the 2 bit color of a pixel
sw $s4, 0x7ff0($0)  # set x, no visible action
sw $s5, 0x7ff1($0)  # set y, no visible action
add $0, $0, $0      # actually a nop wait to compensate for vram delay
lw $t6, 0x7ff2($0)  # read the pixel color to register $t6
```

Note: since coordinates do not need to be set freshly if they do not change, quite compact loops can be written for lines, rectangles and filled boxes (see clear screen). See MIPS [source code][source] for examples.

VideoModule.v uses modified versions of several sub-modules published in the project bitvga-s3 by E. Gallimore and N. Smith on embedded.olin.edu (itself based on XUP-V2P Built in Self Test source code provided by Xilinx, Inc.) to generate the VGA signals. However, the interface towards MIPS and the upscaling mechanism are new in VideoModule.v.
- SVGA_DEFINES.v constants for various output resolutions. 640 X 480 @ 60Hz with a 25.175MHz pixel clock has been used in this project
- SVGA_TIMING_GENERATION.v generates the parameters (including x and y coordinates) to read out the vram buffer based on pixel clock
- VIDEO_OUT.v transforms the read pixels from buffer into actual output signals (output is connected directly with hardware pins)

Note: The site of the bitvga-s3 project is not online available at the moment. Thus, here a [link][bitvga_s3] from the internet archive (Wayback Machine).


MIPS
----
We cannot upload the source code of the MIPS CPU itself. It was mostly provided to us. Its design is based on the descriptions in the textbook by Harris and Harris Digital Design and Computer Architecture, Section 7.3 (2nd ed. Morgan Kaufmann/Elsevier, 2012). Our task in the lab was mainly to implement a few things in the ALU and Control Unit, and to complete the motherboard.

But this is not such a severe limitation: if you are in the situation of working with such an FPGA board, you will most likely get lots of the MIPS CPU provided, too. Or it will be your task to build it.

A MIPS CPU as described in the book by Harris and Harris, and conforming to the interface described below should work well with this project.
```verilog
module MIPS(
    input CLK,                   // Clock signal
    input RESET,                 // Reset Active low will set back the Program counter
    output [31:0] IOWriteData,   // IO Data to be written to the interface
    output  [3:0] IOAddr,        // IO Address we use 4 bits, could also be more
    output        IOWriteEn,     // 1: There is a valid IO Write
    input  [31:0] IOReadData,    // 32bit input from the I/O interface
    output IsIO                  // modified: this wire has been moved to the interface
                                 // because it helps the IO managing hardware a lot
    );
```

Please note that you may have to add the IsIO pin yourself in MIPS modules. It must be 1 if the address space (in ALUResult[31:8] in our case) matches the mapped address space as defined in the MIPS assembly program. top.v uses this signal to e.g. set WE signals accordingly if needed. 


MIPS assembly program (tron.asm)
--------------------------------
The available MIPS CPU had only a limited instruction set: no shift operator, no multiplication, no division, no subroutine calls, etc. were available. This was an additional reason to solve any potentially complex operation directly in hardware and offer a very simple interface of the I/O devices towards the software. The hardware devices here were designed to bring most comfort to the software programmer. Thus, the entire MIPS program could fit into 104 instructions and 15 words of data only. 


Assembly / Compilation
----------------------
As you can see, here are no actual project files. You may copy the files provided here to your own project. Some adjustment may be needed. We used the provided Xilinx suite to compile the Verilog files. We used [MARS][mars] to assemble the MIPS assembly file to a binary text file that we copied as a hexdump into the instruction memory module of the MIPS processor (details vary of course on the settings of your MIPS processor module).


Binary file
-----------
If you happen to have a Xilinx Spartan 3 FPGA board around, you may be interested in loading the binary file tron.bit ([link][bit]) and have a run at the game. Please make sure to check the sha-256 hash code before loading the file to your device. Welcome to the grid.
```verilog
hash_code = 2174b05f10675037dabcce89aa54176fb580a930531b91067a56ab1f7b50a0da
```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND (see [LICENSE][license] for details).

[spartan3_small]:bin/spartan3_small.png
[spartan3_large]:bin/spartan3_large.png
[source]:MIPS_assembly/tron.asm
[bitvga_s3]:https://web.archive.org/web/20150615044743/http://embedded.olin.edu/xilinx_docs/projects/bitvga-s3.php
[mars]:http://courses.missouristate.edu/KenVollmar/MARS/
[bit]:bin/tron.bit
[license]:LICENSE
