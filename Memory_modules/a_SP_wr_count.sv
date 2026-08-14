import pe_pkg::*;

module a_SP_wr_count (
    input  logic                                         clk, rst,
    // Control Signals
    input  logic                                         sp_wr_i, // From Concat/DMA
    input  logic                                         clear_i, // From FSM 
    
    // Outputs to BANKED_SP
    output logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_wr_add_o,
    output logic [PARTITIONS-1:0]                        sp_wr_en_o   
);

    logic [$clog2(SRAM_SIZE)-1:0]  word_count;
    logic [$clog2(PARTITIONS)-1:0] bank_count;

    always_ff @(posedge clk) begin
        if (rst || clear_i) begin
            word_count <= '0;
            bank_count <= '0;
        end 
        else if (sp_wr_i) begin
                if (bank_count == PARTITIONS - 1) begin
                    bank_count <= '0;
                    if (word_count == SRAM_SIZE - 1) word_count <= '0;
                    else                             word_count <= word_count + 1'b1;
                end
                else begin
                    bank_count <= bank_count + 1'b1;
                end
            end
        end

    genvar i;
    generate
        for (i = 0; i < PARTITIONS; i++) begin : gen_steering
            assign sp_wr_add_o[i] = word_count;
            assign sp_wr_en_o[i]  = (bank_count == i) ? sp_wr_i : 1'b0;
            
        end
    endgenerate

endmodule