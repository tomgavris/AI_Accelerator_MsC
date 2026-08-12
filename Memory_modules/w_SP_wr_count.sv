import pe_pkg::*;

module w_SP_wr_count (
    input  logic                                         clk, rst,
    // Control Signals
    input  logic                                         sp_wr_i, // From Concat/DMA
    input  logic                                         clear_i, // From FSM 
    
    // Outputs to Weight SP
    output logic [$clog2(WEIGHT_SP_SIZE)-1:0]            sp_wr_add_o,
    output logic                                         sp_wr_en_o   
);

    logic [$clog2(WEIGHT_SP_SIZE)-1:0]  count;

    always_ff @(posedge clk) begin
        if (rst || clear_i) begin
            count <= '0;
        end 
        else if (sp_wr_i) begin
            if (sp_wr_add_o == WEIGHT_SP_SIZE - 1) begin
                count <= '0;
            end 
            else begin
                count <= count + 1'b1;
            end
        end
    end

    assign sp_wr_add_o = count;
    assign sp_wr_en_o  = sp_wr_i;


endmodule