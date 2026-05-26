import pe_pkg::*;

module SA_top (
    input  logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                top_a_i,
    input  logic signed [M-1:0][N-1:0][2*DATA_WIDTH-1:0]                      top_p_i,
    input  logic                                                              top_clk, top_rst, top_wr_e, top_comp_e,
    input  logic signed [M-1:0][DATA_WIDTH-1:0]                               top_w_i,
    output logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                top_a_o,
    output logic signed [M-1:0][N-1:0][2*DATA_WIDTH-1:0]                      top_parsum_o // logic around the output has to be defined
);
    
    logic signed [M:0][M:0][N-1:0][2*DATA_WIDTH-1:0]        p_wires; 
    logic signed [M:0][M:0][DATA_WIDTH-1:0]                 w_wires; 
    logic signed [M:0][M:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  a_wires; 
    logic        [M:0][M:0]                                 comp_en_wire, wr_en_wires; 


genvar i,j,k;
generate 
    for (i = 0; i < M ; i++) begin
        for (j = 0; j < N ; j++) begin
            for (k = 0; k < OP; k++) begin
                //assigning inputs
                assign a_wires[i][0][j][k] = top_a_i[i][j][k];
                assign top_a_o[i][j][k]    = a_wires[i][M][j][k];
            end
        end
    end
endgenerate

generate
    for (i = 0; i < M; i++) begin
        assign w_wires[0][i]      = top_w_i[i];
        assign wr_en_wires[0][i]  = top_wr_e;
        assign comp_en_wire[0][i] = top_comp_e;
    end
endgenerate

generate 
    for (i = 0; i < M; i++) begin
        for (j = 0; j < N ; j++) begin
            assign p_wires[0][i][j]   = top_p_i[i][j];
            assign top_parsum_o[i][j] = p_wires[M][i][j];
        end
    end
endgenerate

generate 
        for (i = 0; i < M ; i++) begin
            for (j = 0; j < M; j++) begin
                assign wr_en_wires[i][j] = top_wr_e;
                assign comp_wire[i][j] = top_comp_e; 
            end
        end
endgenerate

generate
    for (i = 0; i < M; i++) begin
        for (j = 0; j < M ; j++) begin
            DPPE #(
                .IS_LAST_X(j == M-1),
                .IS_LAST_Y(i == M-1),
                .IS_LAST_ALL(i == M-1 && j == M-1)
            ) DPPE_inst (
            .mid_a_i(a_wires[i][j]),
            .mid_w_i(w_wires[i][j]),
            .mid_p_i(p_wires[i][j]),
            .clk(top_clk), 
            .rst(top_rst), 
            .mid_wr_e(wr_en_wires[i][j]), 
            .comp_e_i(comp_en_wire[i][j]),
            .comp_e_o(comp_en_wire[i+1][j]),
            .wr_e_o(wr_en_wires[i+1][j]), 
            .mid_w_o(w_wires[i+1][j]),
            .mid_a_o(a_wires[i][j+1]),
            .mid_parsum_o(p_wires[i+1][j])
            );
        end
    end
endgenerate
    

endmodule