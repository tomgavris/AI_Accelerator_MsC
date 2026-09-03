//import pe_pkg::*;

module DPPE #(
    parameter FIRST_ROW = 0,
    parameter IS_LAST_X = 0, 
    parameter IS_LAST_Y = 0, 
    parameter IS_LAST_ALL = 0,
    parameter int N = 4,
    parameter int OP = 2,
    parameter int DATA_WIDTH = 8,
    parameter int P_DATA_WIDTH = 16    
) ( 
    
    input  logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         dppe_a_i, //dppe_a_i = activaiton inputs
    input  logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  dppe_w_i, //dppe_w_i = weight inputs
    input  logic signed [N-1:0][P_DATA_WIDTH-1:0]               dppe_p_i, //dppe_p_i = partial sum inputs
    input  logic                                                clk, rst, dppe_wr_e, comp_e_i, //dppe_we_i = write enable, comp_e = compute enable
    output logic                                                dppe_wr_e_o, comp_e_o, // dppe_wr_e_o = write enable out
    output logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  dppe_w_o,  //dppe_w_i = weight outputs
    output logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         dppe_a_o, // activation output
    output logic signed [N-1:0][P_DATA_WIDTH-1:0]               dppe_parsum_o // parsum_o = partial sum output 
);

    logic signed [N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  weight_reg;
    logic signed [N:0][N-1:0][P_DATA_WIDTH-1:0]          p_wires; 
    logic signed [N-1:0][N:0][OP-1:0][DATA_WIDTH-1:0]    a_wires;
    logic        [N-1:0][N-1:0]                          en_wires;
    logic        [N-1:0][N-1:0]                          comp_wire;
    logic signed [N-1:0][OP-1:0][DATA_WIDTH-1:0]         act_reg;
    logic signed [N-1:0][P_DATA_WIDTH-1:0]               p_reg;

    always_ff @( posedge clk ) begin 
        if (rst) begin
            dppe_wr_e_o <= 0;
            comp_e_o    <= 0;
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
        end else if (dppe_wr_e) begin
            dppe_wr_e_o <= 1;
            for (int i = 0 ; i < N ; i++) begin
                for (int j = 0; j < N ; j++) begin
                    for (int k = 0; k < OP; k++) begin
                        weight_reg[i][j][k] <= dppe_w_i[i][j][k];
                        dppe_w_o[i][j][k] <= weight_reg[i][j][k];
                    end
                end
            end
        end else if(comp_e_i) begin
            dppe_wr_e_o   <= 0;
            comp_e_o <= 1;
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
        if(IS_LAST_X || IS_LAST_ALL) begin // on the last module of the grid don't use boundary registers
            for (i = 0; i< N ; i++) begin
                for (j = 0; j< OP; j++) begin
                    
                    assign a_wires[i][0][j] = dppe_a_i[i][j];
                    assign dppe_a_o[i][j]   = a_wires[i][N][j];
                end
            end
        end else begin
            for (i = 0; i< N ; i++) begin
                for (j = 0; j< OP; j++) begin
                    
                    assign a_wires[i][0][j] = dppe_a_i[i][j];
                    assign dppe_a_o[i][j]   = act_reg[i][j];
                end
            end
        end
        
    endgenerate

    generate
        if(IS_LAST_Y || IS_LAST_ALL) begin // on the last module of the grid don't use boundary registers
            for (i = 0; i< N ; i++) begin
                    assign p_wires[0][i] = FIRST_ROW ? '0 : dppe_p_i[i]; // driving the psum_i of the first row DPPEs to 0 
                    assign dppe_parsum_o[i] = p_wires[N][i];
            end
        end else begin
            for (i = 0; i< N ; i++) begin
                assign p_wires[0][i] = dppe_p_i[i];
                assign dppe_parsum_o[i] = p_reg[i];
            end
        end 
    endgenerate

    generate
            for (i = 0; i< N ; i++) begin
                for (j = 0; j< N; j++) begin
                    assign en_wires[i][j] = dppe_wr_e;
                    assign comp_wire[i][j] = comp_e_i; 
                end
            end
    endgenerate

    generate
        for(i=0; i< N; i=i+1) begin : row_loop
            for(j=0; j< N; j=j+1) begin : col_loop
                DP #(.OP(OP), .DATA_WIDTH(DATA_WIDTH), .P_DATA_WIDTH(P_DATA_WIDTH)) DP_I (
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