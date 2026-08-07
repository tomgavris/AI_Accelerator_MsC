import pe_pkg::*;

module single_port_ram #(
    parameter WIDTH = DATA_WIDTH
)( 
    input  logic                                clk, 
    input  logic                                rst, 
    input  logic        [$clog2(SRAM_SIZE)-1:0] addr,
    input  logic signed [WIDTH-1:0]        sram_i,
    input  logic                                wr, 
    input  logic                                rd, 
    output logic signed [WIDTH-1:0]        sram_o
);

    
    logic signed [SRAM_SIZE-1:0][WIDTH-1:0] mem ;

    always_ff @ (posedge clk) begin
        if (rst) begin
            sram_o <= '0;
        end
        else begin
            if (wr) begin
                mem[addr] <= sram_i;  
            end
            if (rd) begin 
                sram_o <= mem[addr];
            end
        end
    end

endmodule