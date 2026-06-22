import pe_pkg::*;

module single_port_ram
  ( 	input  logic					            clk, rst,
   		input  logic        [$clog2(SRAM_SIZE)-1:0]	addr,
   		input  logic signed [DATA_WIDTH-1:0]	    sram_i,
   		input  logic					            wr,
   		input  logic					            rd, 
        output logic signed [DATA_WIDTH-1:0]        sram_o
  );

  logic signed [DATA_WIDTH-1:0] mem [SRAM_SIZE-1:0];

  always_ff @ (posedge clk) begin
    if (rst) begin
        sram_o <= '0;
    end
    else if(wr) begin
      mem[addr] <= sram_i;
    end
    else if(rd) begin 
        sram_o <= mem[addr];
    end
  end

endmodule