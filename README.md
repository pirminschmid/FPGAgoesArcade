FPGA goes Arcade
================

A Tron like light cycle race implemented on a Xilinx Spartan 3 FPGA board (MIPS assembly, I/O devices, VGA output).

![Screenshot][screenshot_small]

Project description
-------------------
What do you need to play a classic arcade game with VGA graphics output on a Xilinx Spartan 3 FPGA board in a digital circuits class?

Simple: extend the provided MIPS processor by a few additional I/O devices, use a program of 104 MIPS assembly instructions, and you can enter the grid.

This project describes hardware modules for user input and VGA output on a Xilinx Spartan 3 FPGA. The modules are written in Verilog; the software in MIPS assembly. Combined with a MIPS processor module written in Verilog the game is ready for 2 players. The game implements a very simple version of the classic Tron lightcycle race.

We cannot upload the source code of the MIPS CPU itself since most of it was provided in class. Nevertheless, we think that some things from the provided source code here might be useful to other students as well. It took some time to get all information needed for the VGA output. Additionally, some neat tricks (as we think) have been used to design the hardware to keep the software as simple as possible. This reflects the old trade-off between software and hardware complexity. Additionally, some workarounds have been built to make it run on quite a low amount of video memory that could be assigned to this simple FPGA device.

We are aware that there are many much newer FPGA boards available with builtin ARM processors and much better graphics outputs. Some principles discussed here may still be useful.

Documentation
-------------
- very [high level description][pdf] of the project (PDF)
- [walkthrough guide][guide] for the project in detail (MD)
- larger [screenshot][screenshot_large] (PNG)
- a very short [video clip][clip] (MP4).

Current version v1.0 (May 2014) Pirmin Schmid and Sandro Meier ([link][fechu]).

[Feedback][feedback] welcome.


License 
-------
This license applies to our source code. Please check restrictions in the Xilinx library code.

Copyright (c) 2014 Pirmin Schmid and Sandro Meier, [MIT license][license].


Acknowledgments
---------------
- Tron, the grid and the light cycle race are (c) / TM from Walt Disney Productions. A first Tron arcade game was published by Midway Games in 1982. The present game was designed for educational in-class use without commercial interest. The source code here illustrates building of input and output devices for a simple MIPS computer on a Xilinx Spartan 3 FPGA board.
- VGA output is based on Xilinx library code and based on the project bitvga-s3 by E. Gallimore and N. Smith on embedded.olin.edu ([Internet Archive Link][bitvga_s3]; original site not online at the moment).
- MIPS code including ALU, control unit, registry file, instruction and data memory are based on the files provided in class. They were written by Frank K. Gürkaynak. We completed it as asked in the lab sheet, and introduced only few modifications like optional 1 Hz debug clock frequency (which allows tracking of the assembly program from the outside with some internal wires put on the status LEDs), wider instruction memory bus and memory size for max. 128 instructions. Additional output pin IsIO from MIPS to the motherboard top.v, which simplified the outside homebrew I/O controller.

[screenshot_small]:bin/screenshot_small.png
[screenshot_large]:bin/screenshot_large.png
[pdf]:bin/project_description.pdf
[guide]:GUIDE.md
[clip]:bin/clip.mp4
[fechu]:https://github.com/fechu
[feedback]:mailto:mailbox@pirmin-schmid.ch?subject=FPGAgoesArcade
[license]:LICENSE
[bitvga_s3]:https://web.archive.org/web/20150615044743/http://embedded.olin.edu/xilinx_docs/projects/bitvga-s3.php
