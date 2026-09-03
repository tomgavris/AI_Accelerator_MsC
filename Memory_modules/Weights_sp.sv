// import pe_pkg::*;

module weights_sp #(
    parameter int N = 4,
    parameter int M = 8,
    parameter int OP = 2,
    parameter int DATA_WIDTH = 8,
    parameter int WEIGHT_SP_SIZE = M,
    parameter int PARTITIONS = 4    
)(
    input  logic signed [M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]        sp_i,
    input  logic                                                             clk, rst,
    input  logic                                                             sp_rd_i, 
    input  logic                                                             sp_wr_i, 
    input  logic                                                             sp_state_i,  
    input  logic        [$clog2(WEIGHT_SP_SIZE)-1:0]                         sp_wr_add, sp_rd_add, 
    output logic                                                             sp_ready_o, sp_valid_o,
    output logic signed [M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]        sp_o
);

    localparam WEIGHT_SP_WIDTH = M*N*N*OP*DATA_WIDTH;
    
    double_buffer #(.DB_WIDTH(WEIGHT_SP_WIDTH), .DB_SIZE(WEIGHT_SP_SIZE)) DB_inst (
        .db_i(sp_i),
        .clk(clk),
        .rst(rst),
        .state(sp_state_i),
        .db_wr(sp_wr_i), 
        .db_rd(sp_rd_i),
        .db_ready(sp_ready_o), 
        .db_valid(sp_valid_o),
        .db_wr_add(sp_wr_add),
        .db_rd_add(sp_rd_add),
         .db_o(sp_o)
    );
            

endmodule