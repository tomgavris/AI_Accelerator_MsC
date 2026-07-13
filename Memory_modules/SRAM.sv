import pe_pkg::*;

module single_port_ram
  ( 	input  logic					                      clk, rst,
   		input  logic        [$clog2(SRAM_SIZE)-1:0]	addr,
   		input  logic signed [DATA_WIDTH-1:0]	      sram_i,
   		input  logic					                      wr, rd, ram_flush,
      output logic                                ram_valid, ram_ready, 
      output logic signed [DATA_WIDTH-1:0]        sram_o
  );

  logic signed [DATA_WIDTH-1:0] mem [SRAM_SIZE-1:0];
  logic [$clog2(SRAM_SIZE)-1:0] counter = 0; 

  assign ram_ready = (counter < SRAM_SIZE);

  assign ram_valid = (counter > 0);

  always_ff @ (posedge clk) begin
    if (rst || ram_flush) begin
        sram_o <= '0;
        counter <= '0;
    end
    else begin
      if(wr && ram_ready) begin
        mem[addr] <= sram_i;  
        counter <= counter + 1;
      end
      else if(rd && ram_valid) begin 
        sram_o <= mem[addr];
        counter <= counter - 1;
      end
    end
  end
    

endmodule