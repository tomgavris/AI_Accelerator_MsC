localparam DATA_WIDTH = 8;
localparam GRID_LEN = 4;

module SPE_SA (
    input logic  [GRID_LEN-1:0][DATA_WIDTH-1:0]  top_w_i, top_a_i, top_p_i,
    input logic                                  top_clk, top_rst, comp_top, top_wr,
    input logic  [GRID_LEN-1:0]                  top_e_i,
    output logic [GRID_LEN-1:0][DATA_WIDTH-1:0]  result
);

logic [GRID_LEN:0][GRID_LEN:0][DATA_WIDTH-1:0] w_wires, a_wires, p_wires;
logic [GRID_LEN:0][GRID_LEN:0]                 en_wires;


genvar i, j, k;
generate 
    for (k = 0; k < GRID_LEN; k++) begin 
        // assigning imputs
        assign w_wires[0][k]  = top_w_i[k];
        assign en_wires[0][k] = top_e_i[k];
        assign a_wires[k][0]  = top_a_i[k];
        assign p_wires[0][k]  = top_p_i[k];

        // assigning outputs
        assign result[k] = p_wires[GRID_LEN][k];
        
    end
endgenerate



generate
    for(i=0; i<GRID_LEN; i=i+1) begin : row_loop
        for(j=0; j<GRID_LEN; j=j+1) begin : col_loop
            pe_ws PE_I (
                .clk (top_clk),
                .rst (top_rst),
                .wr_e (en_wires[i][j]),
                .valid_wr(en_wires[i+1][j]),
                .comp_e(comp_top),
                .w_i(w_wires[i][j]),
                .a_i(a_wires[i][j]),
                .parsum_i(p_wires[i][j]),
                .w_o(w_wires[i+1][j]),
                .a_o(a_wires[i][j+1]),
                .parsum_o(p_wires[i+1][j])
            );
        end
    end
endgenerate
    
endmodule

