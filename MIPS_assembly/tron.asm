################################################################################
#
# TRON
#
# A hardware / software project on Xilinx Spartan 3 boards
# by Sandro Meier and Pirmin Schmid
# v1.0 May 2014
#
################################################################################
#
# this source code: v1.05 (2014-05-17, Pirmin Schmid)
# implementation of the classic light cycle race for a simple MIPS 32 bit processor
# with limited op code set (e.g. no shift, no multiplication, no subroutine calls)
#
# concept
# -------
# Due to memory restrictions of the board, a 320x240 2bit bitmap is used as
# video ram that is translated into RBG colors as defined in a custom "video
# graphics card" written in Verilog. This card is designed to additionally
# translate x and y positions into proper RAM addresses.
# background: black  = (00) = 0
# player 1: color 1  = (01) = 1
# player 2: color 2  = (10) = 2
# frame: white       = (11) = 3
#
# collision detection with any color except black = (00)
#
# registry usage
# --------------
# - player 1:
#      $s0  x
#      $s1  y
#      $s2 score    
# - player 2:
#      $s4  x
#      $s5  y
#      $s6  score
#
# - $s7 wait loop max count
# - $s3 wait loop speed (currently inreased after each round/level); may be made adjustable
#
# - $t registers only temporarily used, e.g.
#   for both players: $t0 delta-x read from HW, $t1 delta-y read from HW, $t2 = color
#
# Hardware requirements
# ---------------------
# all values are at the lsb end of the 32 bit words used for lw and sw to these
# mapped hardware I/O addresses
#
# *** assumes GFX engine with
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
#
# *** assumes input device that provides delta x and delta y values at addresses
#     0x7ff3 player 1 delta x
#     0x7ff4          delta y
#     0x7ff5 player 2 delta x
#     0x7ff6          delta y
# read/write access to provide starting delta directions
#
# *** assumes output device that handles the LED digits
#     0x7ff7 score player 1 (0 to 9; or 99 if supported)
#     0x7ff8 score player 2
# --> write the score with sw
################################################################################

.data
max_x: .word 319
max_y: .word 239

loopcount: .word 0x0003d090
speed: .word 1
speed_delta: .word 1
speed_max: .word 4

waitcount_after_finished: .word 0x00f42420 # 64 x loopcount

p1_x: .word 50
p1_y: .word 119
p1_dx: .word 1
p1_dy: .word 0

p2_x: .word 269
p2_y: .word 119
p2_dx: .word -1
p2_dy: .word 0

.text
initialize: 
	addi $s2, $0, 0
	addi $s6, $0, 0
	lw $s7, loopcount
	lw $s3, speed

new_round:
	lw $s0, p1_x
	lw $s1, p1_y
	lw $t0, p1_dx
	sw $t0, 0x7ff3($0)
	lw $t1, p1_dy
	sw $t1, 0x7ff4($0)

	lw $s4, p2_x
	lw $s5, p2_y
	lw $t0, p2_dx
	sw $t0, 0x7ff5($0)
	lw $t1, p2_dy
	sw $t1, 0x7ff6($0)

# clear screen
	addi $t0, $0, 0
	lw $t1, max_y
cs_outer_loop:
	sw $t0, 0x7ff1($0)	# y
	addi $t2, $0, 0
	lw $t3, max_x
cs_inner_loop:
	sw $t2, 0x7ff0($0)	# x
	sw $0, 0x7ff2($0)	# black
	beq $t2, $t3, cs_inner_end
	addi $t2, $t2, 1
	j cs_inner_loop
cs_inner_end:
	beq $t0, $t1, cs_outer_end
	addi $t0, $t0, 1
	j cs_outer_loop
cs_outer_end:

# frame: horizontal lines
# use $t0 as i=0..max_x; $t1 as loop_max = max_x; $t2 max_y
	addi $t7, $0, 3		# bitmap color 3 (11) = white	
	addi $t0, $0, 0
	lw $t1, max_x
	lw $t2, max_y
hf_loop:
	sw $t0, 0x7ff0($0)
	sw $0, 0x7ff1($0)	# top
	sw $t7, 0x7ff2($0)
	sw $t2, 0x7ff1($0)	# bottom
	sw $t7, 0x7ff2($0)
	beq $t0, $t1, hf_end
	addi $t0, $t0, 1
	j hf_loop
hf_end:

# frame: vertical lines
# use $t0 as i=0..max_y; $t1 as loop_max = max_y; $t2 max_x
	addi $t0, $0, 0
	lw $t1, max_y
	lw $t2, max_x
vf_loop:
	sw $0, 0x7ff0($0)	# left
	sw $t0, 0x7ff1($0)
	sw $t7, 0x7ff2($0)
	sw $t2, 0x7ff0($0)	# right
	sw $t7, 0x7ff2($0)
	beq $t0, $t1, vf_end
	addi $t0, $t0, 1
	j vf_loop
vf_end:

# the race basically consists of
# 1) move the player positions by delta values
# 2) collision detection
# 3) draw positions if no collision
# note: to be fair to both players, collision detection
# always tests for both players, of course. A draw is possible
# with 1 point for each player

race_loop:
# move player 1 to next position
	lw $t0, 0x7ff3($0)
	lw $t1, 0x7ff4($0)
	add $s0, $s0, $t0
	add $s1, $s1, $t1
		
# move player 2 to next position
	lw $t0, 0x7ff5($0)
	lw $t1, 0x7ff6($0)
	add $s4, $s4, $t0
	add $s5, $s5, $t1
		
# collision detection player 1
	sw $s0, 0x7ff0($0)
	sw $s1, 0x7ff1($0)
	add $0, $0, $0     # actually a nop wait to compensate for vram delay
	lw $t7, 0x7ff2($0)
	beq $t7, $0, p1_no_coll
	addi $s6, $s6, 1  #  player 2 gets a point
p1_no_coll:

# collision detection player 2
	sw $s4, 0x7ff0($0)
	sw $s5, 0x7ff1($0)
	add $0, $0, $0     # actually a nop wait to compensate for vram delay
	lw $t6, 0x7ff2($0)
	beq $t6, $0, p2_no_coll
	addi $s2, $s2, 1  #  player 1 gets a point
p2_no_coll:

# any collision?
	or $t7, $t7, $t6
	beq $t7, $0, no_coll
# yes, there was a collision, adjust score display
	sw $s2, 0x7ff7($0)
	sw $s6, 0x7ff8($0)
# future option: add any show effect (LEDs / screen) to show it
# currently: wait, increase speed, and start a new round
	addi $t0, $0, 0
	lw $t1, waitcount_after_finished
finished_wait_loop:
	beq $t0, $t1, finished_wait_end
	addi $t0, $t0, 1
	j finished_wait_loop
finished_wait_end:

# increase speed by speed_delta up to speed_max
	lw $t7, speed_max
	slt $t6, $s3, $t7
	beq $t6, $0, speed_ok	
	lw $t5, speed_delta
	add $s3, $s3, $t5
	slt $t6, $t7, $s3		# boundary check
	beq $t6, $0, speed_ok
	addi $s3, $t7, 0	 	
speed_ok:	
	j new_round

no_coll:
# draw player 1
	addi $t2, $0, 1  	# bitmap color 1 (01)
	sw $s0, 0x7ff0($0)
	sw $s1, 0x7ff1($0)
	sw $t2, 0x7ff2($0)

# draw player 2
	addi $t2, $0, 2  	# bitmap color 2 (10)
	sw $s4, 0x7ff0($0)
	sw $s5, 0x7ff1($0)
	sw $t2, 0x7ff2($0)

# wait a bit (increase counter by speed up to loopcount)
	addi $t0, $0, 0
wait_loop:
	add $t0, $t0, $s3
	slt $t1, $t0, $s7
	beq $t1, $0, wait_end	
	j wait_loop
wait_end:
	j race_loop

################################################################################
