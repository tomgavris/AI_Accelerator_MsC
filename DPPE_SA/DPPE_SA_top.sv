localparam N = 2;
localparam OP = 2;
localparam DATA_WIDTH = 8;

module SA_top #(
    parameter M = 2 // M defines the number of DPPEs inside the top level module
)(
    input  logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]         top_a_i,
    input  logic signed [M-1:0][N-1:0][2*DATA_WIDTH-1:0]               top_p_i,
    input  logic                                                       top_clk, top_rst, top_wr_e, top_comp_e,
    input  logic signed [M-1:0][M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  top_w_i,
    output logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]         top_a_o,
    output logic signed [M-1:0][N-1:0][DATA_WIDTH-1:0]                 top_parsum_o // logic around the output has to be defined
);
    
    logic signed [M:0][M:0][N-1:0][2*DATA_WIDTH-1:0]        p_wires; 
    logic signed [M:0][M:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  a_wires; 
    logic        [M-1:0][M-1:0]                             en_wires, comp_wire; 


genvar i,j,k;
generate //done
    for (i = 0; i < M ; i++) begin
        for (j = 0; j < N ; j++) begin
            for (k = 0; k < OP; k++) begin
                //assigning inputs
                assign a_wires[i][0][j][k] = top_a_i[i][j][k];
                assign top_a_o[i][j][k]    = a_wires[i][N][j][k];
            end
        end
    end
endgenerate

generate // done
    for (i = 0; i < M; i++) begin
        for (j = 0; j < N ; j++) begin
            assign p_wires[0][i][j]   = top_p_i[i][j];
            assign top_parsum_o[i][j] = p_wires[N][i][j];
        end
    end
endgenerate

generate // done
        for (i = 0; i < M ; i++) begin
            for (j = 0; j < M; j++) begin
                assign en_wires[i][j] = top_wr_e;
                assign comp_wire[i][j] = top_comp_e; 
            end
        end
endgenerate

generate
    for (i = 0; i < M; i++) begin
        for (j = 0; j < M ; j++) begin
            DPPE DPPE_inst (
            .mid_a_i(a_wires[i][j]),
            .mid_w_i(top_w_i[i][j]),
            .mid_p_i(p_wires[i][j]),
            .clk(top_clk), 
            .rst(top_rst), 
            .mid_wr_e(en_wires[i][j]), 
            .comp_e(comp_wire[i][j]),
            .mid_a_o(top_a_o[i][j+1]),
            .mid_parsum_o(top_parsum_o[i+1][j])
    );
        end
    end
endgenerate
    

endmodule