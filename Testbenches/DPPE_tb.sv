import pe_pkg::*;
module DPPE_tb ();


logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_i; 
logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  mid_w_i; 
logic signed [N-1:0][P_DATA_WIDTH-1:0]               mid_p_i; 
logic                                                clk, rst, mid_wr_e, comp_e; 
logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         mid_a_o; 
logic signed [N-1:0][P_DATA_WIDTH-1:0]               mid_parsum_o;

generate
    DPPE DPPE_I (
        .dppe_a_i(mid_a_i),
        .dppe_w_i(mid_w_i),
        .dppe_p_i(mid_p_i),
        .clk(clk),
        .rst(rst),
        .dppe_wr_e(mid_wr_e),
        .comp_e_i(comp_e),
        .dppe_a_o(mid_a_o),
        .dppe_parsum_o(mid_parsum_o),
        .dppe_w_o()
    );
endgenerate

initial begin
    clk = 0;
    forever #5 clk = ~ clk;
end

initial begin
    
    $display("This is the start");
    rst = 1;
    mid_wr_e = 0;
    comp_e = 0;

    // loading weights
    @(posedge clk);
    $display("================ Loading weights/activations ==================");
    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < N; j++) begin
            for (int k = 0; k < OP; k++) begin
                mid_w_i[i][j][k] = 4*i + 2*j + k;
            end
        end
    end



    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < OP; j++) begin
            mid_a_i[i][j] = i + 1;
        end
    end

    for (int i = 0; i < N; i++) begin
        mid_p_i[i] = 16'd0;
    end
    rst = 0;
    mid_wr_e = 1;
    comp_e = 0;

    repeat(N) @(posedge clk);

    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < N; j++) begin
            for (int k = 0; k < OP; k++) begin
                $display("DPPE_I.dppe_w_i[%0d][%0d][%0d] = %0d", i, j, k, DPPE_I.dppe_w_i[i][j][k]);
            end
        end
    end

    rst = 0;
    mid_wr_e = 0;
    comp_e = 1;
    
    
    @(posedge clk);
    #1

    rst = 0;
    mid_wr_e = 0;
    comp_e = 1;
    $display("psum0 = %0d and psum1 = %0d", 
        DPPE_I.dppe_parsum_o[0],
        DPPE_I.dppe_parsum_o[1]
    );

    if((mid_parsum_o[0] != 19) || (mid_parsum_o[1] != 31)) $display("ERROR IN FIRST TRY!");
    else $display("SUCCES FIRST TRY!");

    

    @(posedge clk);
    #1
    
    for (int i = 0; i < N ; i++ ) begin
        for (int j = 0; j < OP; j++) begin
            mid_a_i[i][j] = 1;
        end
    end
    for (int i = 0; i < N; i++) begin
        mid_p_i[i] = 16'd1;
    end

    $display("psum0 = %0d and psum1 = %0d", 
        mid_parsum_o[0],
        mid_parsum_o[1]
    );

    if((mid_parsum_o[0] != 11) || (mid_parsum_o[1] != 19)) $display("ERROR IN SECOND TRY!");
    else $display("SUCCESS SECOND TRY!");
    rst = 1;
    mid_wr_e = 0;
    comp_e = 0;

    repeat(4) @(posedge clk);
    $finish;
end

endmodule