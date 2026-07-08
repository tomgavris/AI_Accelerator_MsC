import pe_pkg::*;

module BANKED_SP (
    input  logic signed [PARTITIONS-1:0][DATA_WIDTH-1:0]        sp_i,
    input  logic                                                clk, rst, sp_rd, sp_wr, sp_state, 
    input  logic        [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_wr_add, sp_rd_add, 
    output logic                                                sp_ready, sp_valid,
    output logic signed [PARTITIONS-1:0][DATA_WIDTH-1:0]        sp_o
);

    logic [PARTITIONS-1:0] valid_wire, ready_wire, rd_wire, wr_wire, state_wire;


    assign sp_ready   = |ready_wire; // OR-ing all the ready wires
    assign sp_valid   = &valid_wire; // AND-ing all the valid wires

    assign rd_wire    = {PARTITIONS{sp_rd}};
    assign wr_wire    = {PARTITIONS{sp_wr}};
    assign state_wire = {PARTITIONS{sp_state}};
    
    genvar i;
    generate
        for (i = 0; i < PARTITIONS; i++) begin : db_banks
            double_buffer DB_inst (
                .db_i(sp_i[i]),
                .clk(clk),
                .rst(rst),
                .state(state_wire[i]),
                .db_wr(wr_wire[i]), 
                .db_rd(rd_wire[i]),
                .db_ready(ready_wire[i]), 
                .db_valid(valid_wire[i]),
                .db_wr_add(sp_wr_add[i]),
                .db_rd_add(sp_rd_add[i]),
                .db_o(sp_o[i])
            );
        end
    endgenerate

endmodule