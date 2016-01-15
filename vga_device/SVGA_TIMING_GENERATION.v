`include "SVGA_DEFINES.v"

// from project bitvga-s3 by E. Gallimore and N. Smith on embedded.olin.edu
// modified 2014-05-15 Pirmin Schmid

module SVGA_TIMING_GENERATION(
    input pixel_clock,
    input reset,
    output reg h_synch,
    output reg v_synch,
    output reg blank,
    output reg [10:0] pixel_count,  // pixels in a line
    output reg [9:0] line_count);       // number of lines

    reg h_blank;                // horizontal blanking
    reg v_blank;                // vertical blanking

// CREATE THE HORIZONTAL LINE PIXEL COUNTER
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset set pixel counter to 0
        pixel_count <= 11'h000;
    
    else if (pixel_count == (`H_TOTAL - 1))
        // last pixel in the line, so reset pixel counter
        pixel_count <= 11'h000;
    
    else
        pixel_count <= pixel_count +1;      
end

// CREATE THE HORIZONTAL SYNCH PULSE
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset remove h_synch
        h_synch <= 1'b0;
    
    else if (pixel_count == (`H_ACTIVE + `H_FRONT_PORCH -1))
        // start of h_synch
        h_synch <= 1'b1;
    
    else if (pixel_count == (`H_TOTAL - `H_BACK_PORCH -1))
        // end of h_synch
        h_synch <= 1'b0;
end


// CREATE THE VERTICAL FRAME LINE COUNTER
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset set line counter to 0
        line_count <= 10'h000;
    
    else if ((line_count == (`V_TOTAL - 1)) && (pixel_count == (`H_TOTAL - 1)))
        // last pixel in last line of frame, so reset line counter
        line_count <= 10'h000;
    
    else if ((pixel_count == (`H_TOTAL - 1)))
        // last pixel but not last line, so increment line counter
        line_count <= line_count + 1;
end

// CREATE THE VERTICAL SYNCH PULSE
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset remove v_synch
        v_synch = 1'b0;

    else if ((line_count == (`V_ACTIVE + `V_FRONT_PORCH -1) &&
           (pixel_count == `H_TOTAL - 1))) 
        // start of v_synch
        v_synch = 1'b1;
    
    else if ((line_count == (`V_TOTAL - `V_BACK_PORCH - 1)) &&
           (pixel_count == (`H_TOTAL - 1)))
        // end of v_synch
        v_synch = 1'b0;
end


// CREATE THE HORIZONTAL BLANKING SIGNAL
// the "-2" is used instead of "-1" because of the extra register delay
// for the composite blanking signal 
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset remove the h_blank
        h_blank <= 1'b0;

    else if (pixel_count == (`H_ACTIVE - 2)) 
        // start of HBI
        h_blank <= 1'b1;
    
    else if (pixel_count == (`H_TOTAL - 2))
        // end of HBI
        h_blank <= 1'b0;
end

// CREATE THE VERTICAL BLANKING SIGNAL
// the "-2" is used instead of "-1"  in the horizontal factor because of the extra
// register delay for the composite blanking signal
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset remove v_blank
        v_blank <= 1'b0;

    else if ((line_count == (`V_ACTIVE - 1) &&
           (pixel_count == `H_TOTAL - 2))) 
        // start of VBI
        v_blank <= 1'b1;
    
    else if ((line_count == (`V_TOTAL - 1)) &&
           (pixel_count == (`H_TOTAL - 2)))
        // end of VBI
        v_blank <= 1'b0;
end

// CREATE THE COMPOSITE BLANKING SIGNAL
always @ (posedge pixel_clock or posedge reset) begin
    if (reset)
        // on reset remove blank
        blank <= 1'b0;

    // blank during HBI or VBI
    else if (h_blank || v_blank)
        blank <= 1'b1;
        
    else
        // active video do not blank
        blank <= 1'b0;
end

endmodule //SVGA_TIMING_GENERATION
