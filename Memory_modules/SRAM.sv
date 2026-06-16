import pe_pkg::*;

module sram (
    input  logic signed [SRAM_WIDTH-1:0] sram_i,
    input  logic                         clk, rst, sram_wr, sram_rd,
    output logic signed [SRAM_WIDTH-1:0] sram_o
);
    
    logic [SRAM_WIDTH-1:0] mem [0:SRAM_SIZE-1];
    logic [$clog2(SRAM_SIZE)-1:0]  wr_pointer ,rd_pointer;


    always_ff @(posedge clk) begin
            if(rst) begin
                rd_pointer <= '0;  
                wr_pointer <= '0;
            end 
            else if(sram_wr) begin
                mem[wr_pointer] <= sram_i; 
                if(wr_pointer == SRAM_SIZE-1) begin
                    wr_pointer <= '0;
                end 
                else begin
                    wr_pointer <= wr_pointer +1;
                end
            end 
            else if(sram_rd) begin
                sram_o <= mem[rd_pointer];
                if(rd_pointer == SRAM_SIZE-1) begin
                    rd_pointer <= '0;
                end
                else begin
                    rd_pointer <= rd_pointer + 1;
                end
            end
    end

endmodule