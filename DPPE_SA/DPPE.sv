module DPPE #(
    parameter DATA_WIDTH = 8,
    parameter OP = 2,
    parameter N = 2 // Number of DP2s NxN
) ( 
    // mid refers to the middle level the module sits at
    input  logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_i, //mid_a_i = activaiton inputs
    input  logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  mid_w_i, //mid_w_i = weight inputs
    input  logic signed [N-1:0][2*DATA_WIDTH-1:0]               mid_p_i, //mid_p_i = partial sum inputs
    input  logic                                                clk, rst, mid_wr_e, comp_e, //mid_we_i = write enable, comp_e = compute enable
    output logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_o, // activation output
    output logic signed [N-1:0][2*DATA_WIDTH-1:0]               mid_parsum_o // parsum_o = partial sum output 
);

logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  weight_reg;
logic signed [N:0][N:0][2*DATA_WIDTH-1:0]            p_wires; 
logic signed [N:0][N:0][OP-1:0][DATA_WIDTH-1:0]      a_wires;
logic        [N-1:0][N-1:0]                          en_wires;
logic        [N-1:0][N-1:0]                          comp_wire;
logic        [N-1:0][OP-1:0]                         act_reg;
logic        [N-1:0]                                 p_reg;

always_ff @( posedge clk ) begin 
    if (rst) begin
        for (int i = 0 ; i < N ; i++) begin
            for (int j = 0; j < N ; j++) begin
                weight_reg[i][j] <= '0; 
            end
        end
        for (int i = 0 ; i < N ; i++) begin
            for (int j = 0; j < OP ; j++) begin
                act_reg[i][j] <= '0; 
            end
        end
        for (int i = 0 ; i < N ; i++) begin
                p_reg[i] <= '0; 
        end
    end else if (mid_wr_e) begin
        for (int i = 0 ; i < N ; i++) begin
            for (int j = 0; j < N ; j++) begin
                weight_reg[i][j] <= mid_w_i[i][j];
            end
        end
    end else if(comp_e) begin
        for (int i = 0 ; i < N ; i++) begin
            for (int j = 0; j < OP ; j++) begin
                act_reg[i][j] <= a_wires[i][N][j]; 
            end
        end
        for (int i = 0 ; i < N ; i++) begin
                p_reg[i] <= p_wires[N][i]; 
        end
    end
end


genvar i, j, k;
generate
    for (i = 0; i< N ; i++) begin
        for (j = 0; j< OP; j++) begin
            //assigning inputs
            assign a_wires[i][0][j] = mid_a_i[i][j];
            assign mid_a_o[i][j] = act_reg[i][j];
        end
    end
endgenerate

generate
        for (i = 0; i< N ; i++) begin
            assign p_wires[0][i] = mid_p_i[i];
            assign mid_parsum_o[i] = p_reg[i];
        end
endgenerate

generate
        for (i = 0; i< N ; i++) begin
            for (j = 0; j< N; j++) begin
                assign en_wires[i][j] = mid_wr_e;
                assign comp_wire[i][j] = comp_e; 
            end
        end
endgenerate

generate
    for(i=0; i< N; i=i+1) begin : row_loop
        for(j=0; j< N; j=j+1) begin : col_loop
            DP DP_I (
                .comp_e(comp_wire[i][j]),
                .w_i(weight_reg[i][j]),
                .a_i(a_wires[i][j]),
                .parsum_i(p_wires[i][j]),
                .a_o(a_wires[i][j+1]),
                .parsum_o(p_wires[i+1][j])
            );
        end
    end
endgenerate

endmodule