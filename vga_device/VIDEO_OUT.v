// from project bitvga-s3 by E. Gallimore and N. Smith on embedded.olin.edu
// modified 2014-05-15 Pirmin Schmid

module VIDEO_OUT(
    input pixel_clock,
    input reset,
    input vga_red_data,
    input vga_green_data,
    input vga_blue_data,
    input h_synch,
    input v_synch,
    input blank,
    output reg VGA_HSYNCH,
    output reg VGA_VSYNCH,
    output reg VGA_OUT_RED,
    output reg VGA_OUT_GREEN,
    output reg VGA_OUT_BLUE
    );

// make the external video connections
always @ (posedge pixel_clock or posedge reset) begin
    if (reset) begin
        // shut down the video output during reset
        VGA_HSYNCH              <= 1'b1;
        VGA_VSYNCH              <= 1'b1;
        VGA_OUT_RED             <= 1'b0;
        VGA_OUT_GREEN           <= 1'b0;
        VGA_OUT_BLUE            <= 1'b0;
    end
    
    else if (blank) begin
        // output black during the blank signal
        VGA_HSYNCH              <= h_synch;
        VGA_VSYNCH              <= v_synch;
        VGA_OUT_RED             <= 1'b0;
        VGA_OUT_GREEN           <= 1'b0;
        VGA_OUT_BLUE            <= 1'b0;
    end
    
    else begin
        // output color data otherwise
        VGA_HSYNCH              <= h_synch;
        VGA_VSYNCH              <= v_synch;
        VGA_OUT_RED             <= vga_red_data;
        VGA_OUT_GREEN           <= vga_green_data;
        VGA_OUT_BLUE            <= vga_blue_data;
    end
end

endmodule // VIDEO_OUT