
    localparam DATA_WIDTH = 8;
    localparam OP = 2;
    localparam N = 2; // Number of DP2s NxN

module DPPE_tb ();


logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_i; 
logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  mid_w_i; 
logic signed [N-1:0][2*DATA_WIDTH-1:0]               mid_p_i; 
logic                                                clk, rst, mid_wr_e, comp_e; 
logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_o; 
logic signed [N-1:0][2*DATA_WIDTH-1:0]               mid_parsum_o;

generate
    DPPE DPPE_I (
        .mid_a_i(mid_a_i),
        .mid_w_i(mid_w_i),
        .mid_p_i(mid_p_i),
        .clk(clk),
        .rst(rst),
        .mid_wr_e(mid_wr_e),
        .comp_e(comp_e),
        .mid_a_o(mid_a_o),
        .mid_parsum_o(mid_parsum_o)
    );
endgenerate

initial begin
    clk = 0;
    forever #5 clk = ~ clk;
end

initial begin
    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < OP; j++) begin
            mid_a_i[i][j] =  i;
        end
    end

    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < N; j++) begin
            for (int k = 0; k < OP; k++) begin
                mid_w_i[i][j][k] = i + j + k;
            end
        end
    end
    for (int i = 0; i < N; i++) begin
        mid_p_i[i] = 16'd0;
    end
    rst = 1;
    mid_wr_e = 0;
    comp_e = 0;

    @(posedge clk);
    rst = 0;
    mid_wr_e = 1;
    comp_e = 0;

    @(posedge clk);
    rst = 0;
    mid_wr_e = 0;
    comp_e = 1;
    
    @(posedge clk);
    rst = 0;
    mid_wr_e = 0;
    comp_e = 1;
    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < OP; j++) begin
            mid_a_i[i][j] =  2*i + j;
        end
    end
    for (int i = 0; i < N; i++) begin
        mid_p_i[i] = 16'd1;
    end

    @(posedge clk);
    rst = 1;
    mid_wr_e = 0;
    comp_e = 0;

    repeat(4) @(posedge clk);
    $finish;
end

endmodule