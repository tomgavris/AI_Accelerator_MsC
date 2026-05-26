import pe_pkg::*;

module SA_top_tb ();
    
logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                top_a_i;
logic signed [M-1:0][N-1:0][2*DATA_WIDTH-1:0]                      top_p_i;
logic                                                              top_clk, top_rst, top_wr_e, top_comp_e;
logic signed [M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]         top_w_i;
logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                top_a_o;
logic signed [M-1:0][N-1:0][2*DATA_WIDTH-1:0]                      top_parsum_o; 


SA_top SA_top_i (
    .top_a_i(top_a_i),
    .top_p_i(top_p_i),
    .top_clk(top_clk), 
    .top_rst(top_rst), 
    .top_wr_e(top_wr_e), 
    .top_comp_e(top_comp_e),
    .top_w_i(top_w_i),
    .top_a_o(top_a_o),
    .top_parsum_o(top_parsum_o)
);

initial begin
    top_clk = 0;
    forever #5 top_clk = ~top_clk;  
end

initial begin
    
    static int weight_val = 1;
    for (int i = 0; i < M; i++) begin
        for (int j = 0; j < N ; j++ ) begin
            for (int k = 0; k < OP; k++) begin
                top_a_i[i][j][k] =  i + j + k;
            end
        end
    end
    

    for (int i = 0; i < M ; i++ ) begin
        for (int j = 0; j < N; j++) begin
            top_p_i[i][j] = 1;
        end
    end
    
    top_rst = 1;
    top_wr_e = 0;
    top_comp_e = 0;
    @(posedge top_clk);

    for (int i = 0; i < M ; i++) begin
        for (int j = 0; j < N; j++) begin
            for (int k = 0; k < N; k++) begin
                for (int l = 0; l < OP ; l++) begin
                    top_w_i[i][j][k][l] = weight_val;
                end
            end
        end
    end
    weight_val = weight_val + 1;
    top_rst = 0;
    top_wr_e = 1;
    top_comp_e = 0;


    repeat(9) @(posedge top_clk);
    top_rst = 0;
    top_wr_e = 0;
    top_comp_e = 1;

    repeat(9) @(posedge top_clk);
    top_rst = 1;
    top_wr_e = 0;
    top_comp_e = 0;

    @(posedge top_clk);
    top_rst = 0;
    top_wr_e = 0;
    top_comp_e = 0;

    repeat(4) @(posedge top_clk);
    $finish;


end

endmodule