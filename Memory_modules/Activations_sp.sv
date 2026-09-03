// import pe_pkg::*;

module activations_sp #(
    parameter int N = 4,
    parameter int M = 8,
    parameter int OP = 2,
    parameter int DATA_WIDTH = 8,
    parameter int PARTITIONS = 4,
    parameter int SP_SIZE = 2048,
    
    parameter int CONC_ADD = M / PARTITIONS,
    parameter int SRAM_SIZE = SP_SIZE / PARTITIONS  
)(
    input  logic signed [PARTITIONS-1:0][CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]        sp_i,
    input  logic                                                                             clk, rst,
    input  logic        [PARTITIONS-1:0]                                                     sp_rd_i, 
    input  logic        [PARTITIONS-1:0]                                                     sp_wr_i, 
    input  logic                                                                             sp_state_i,  
    input  logic        [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0]                              sp_wr_add, sp_rd_add, 
    output logic                                                                             sp_ready_o, sp_valid_o,
    output logic signed [PARTITIONS-1:0][CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]        sp_o
);

    logic [PARTITIONS-1:0] valid_wire, ready_wire, rd_wire, state_wire;

    assign sp_ready_o   = 1'b1; 
    assign sp_valid_o   = 1'b1; 

    assign rd_wire    = sp_rd_i;
    assign state_wire = {PARTITIONS{sp_state_i}};
    
    genvar i;
    generate
        for (i = 0; i < PARTITIONS; i++) begin : db_banks
            double_buffer #(.DB_WIDTH(CONC_ADD*N*OP*DATA_WIDTH)) DB_inst (
                .db_i(sp_i[i]),
                .clk(clk),
                .rst(rst),
                .state(state_wire[i]),
                .db_wr(sp_wr_i[i]), 
                .db_rd(sp_rd_i[i]),
                .db_ready(ready_wire[i]), 
                .db_valid(valid_wire[i]),
                .db_wr_add(sp_wr_add[i]),
                .db_rd_add(sp_rd_add[i]),
                .db_o(sp_o[i])
            );
        end
    endgenerate

endmodule