// Divides input clock frequency (clk) to desired clock frequency (clk_en)
// either 12.5 MHz or 1 Hz
// rst        resets the module
// debugMode  sets clock frequency to 1 Hz
// May 2014 Pirmin Schmid and Sandro Meier

module clockdiv(
    input clk,
    input rst,
    input debugMode,
    output clk_en
    );

// standard for 12.5 MHz
    reg [1:0] clk_count;
    always @ (posedge clk, posedge rst)
    begin
        if (rst) clk_count <= 0;
        else
            clk_count <= clk_count+1'b1;
    end
    
// for debug purpose: 1 Hz
    localparam [26:0] debug_clk_start = 27'b101_0000_0101_0000_1111_0111_1111;
    
    reg [26:0] debug_clk_count;
    
    always @ (posedge clk, posedge rst)
    begin
        if (rst) debug_clk_count <= debug_clk_start;
        else begin
            debug_clk_count <= debug_clk_count + 1'b1;
            if ( ~(|debug_clk_count) )
                debug_clk_count <= debug_clk_start;
        end
    end
    
    assign clk_en = debugMode ? &debug_clk_count : &clk_count;
endmodule
