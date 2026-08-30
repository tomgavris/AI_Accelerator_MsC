import pe_pkg::*;

module DPPE_SA (
    input  logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                sa_a_i,
    input  logic                                                              clk, sa_rst, sa_wr_e, sa_comp_e, 
    input  logic signed [M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]         sa_w_i,
    output logic                                                              sa_valid_o,
    output logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                sa_a_o,
    output logic signed [M-1:0][N-1:0][P_DATA_WIDTH-1:0]                      sa_parsum_o // logic around the output has to be defined
);
    
    logic signed [M:0][M:0][N-1:0][P_DATA_WIDTH-1:0]                p_wires; 
    logic signed [M:0][M:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]   w_wires; 
    logic signed [M:0][M:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]          a_wires; 
    logic        [M:0][M:0]                                         comp_en_wire, wr_en_wires;
    logic        [$clog2(M)-1:0]                                    counter; 


    always_ff @(posedge clk) begin
        if(sa_rst) begin
            counter <= '0;
            sa_valid_o <= 0;
        end
        else if (sa_comp_e) begin
            if(counter == (M-1)) sa_valid_o <= 1;
            else begin counter <= counter + 1; sa_valid_o <= 0; end
        end
        else begin
            counter    <= '0;
            sa_valid_o <= 1'b0;
        end
    end

    genvar i,j,k;
    generate 
        for (i = 0; i < M ; i++) begin
            for (j = 0; j < N ; j++) begin
                for (k = 0; k < OP; k++) begin
                    //assigning inputs
                    assign a_wires[i][0][j][k] = sa_a_i[i][j][k];
                    assign sa_a_o[i][j][k]    = a_wires[i][M][j][k];
                end
            end
        end
    endgenerate

    generate
        for (j = 0; j < M; j++) begin
            assign p_wires[0][j] = '0;
        end
    endgenerate

    generate
        for (i = 0; i < M; i++) begin
            assign w_wires[0][i]      = sa_w_i[i];
            assign wr_en_wires[0][i]  = sa_wr_e;
            assign comp_en_wire[0][i] = sa_comp_e;
        end
    endgenerate

    generate 
        for (i = 0; i < M; i++) begin
            for (j = 0; j < N ; j++) begin
                assign sa_parsum_o[i][j] = p_wires[M][i][j];
            end
        end
    endgenerate

    generate
        for (i = 0; i < M; i++) begin : row
            for (j = 0; j < M ; j++) begin : col
                DPPE #(
                    .FIRST_ROW(i == 0),
                    .IS_LAST_X(j == M-1),
                    .IS_LAST_Y(i == M-1),
                    .IS_LAST_ALL(i == M-1 && j == M-1)
                ) DPPE_inst (
                .dppe_a_i(a_wires[i][j]),
                .dppe_w_i(w_wires[i][j]),
                .dppe_p_i(p_wires[i][j]),
                .clk(clk), 
                .rst(sa_rst), 
                .dppe_wr_e(wr_en_wires[i][j]), 
                .comp_e_i(comp_en_wire[i][j]),

                // inter-DPPE connections
                .comp_e_o(comp_en_wire[i+1][j]),
                .dppe_wr_e_o(wr_en_wires[i+1][j]), 
                .dppe_w_o(w_wires[i+1][j]),
                .dppe_a_o(a_wires[i][j+1]),
                .dppe_parsum_o(p_wires[i+1][j])
                );
            end
        end
    endgenerate
    

endmodule