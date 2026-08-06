import pe_pkg::*;


module Read_skew (
    input  logic                                          clk, rst,
    input  logic                                          sp_rd_i,     // from mem_fsm
    output logic [PARTITIONS-1:0]                         sp_rd_o,
    output logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0]  sp_rd_add_o
);
    genvar part;
    generate
        for (part = 0; part < PARTITIONS; part++) begin : g_part
            part_rd_gen #(.PART_ID(part)) part_rd_gen_inst (
                .clk(clk), .rst(rst), .sp_rd_i(sp_rd_i),
                .sp_rd_o(sp_rd_o[part]), .sp_rd_add_o(sp_rd_add_o[part])
            );
        end
    endgenerate
endmodule

    

module part_rd_gen #(
    parameter int PART_ID = 0
)(
    input  logic                          clk, rst,
    input  logic                          sp_rd_i,      // from mem_fsm, shared
    output logic                          sp_rd_o,      // -> BANKED_SP.sp_rd_i[PART_ID]
    output logic [$clog2(SRAM_SIZE)-1:0]  sp_rd_add_o   // -> BANKED_SP.sp_rd_add[PART_ID]
);
    logic delayed_rd;
    logic [$clog2(SRAM_SIZE)-1:0] addr_cnt;

    FF_chain #(.WIDTH(1), .DELAY(PART_ID*CONC_ADD)) rd_delay (
        .ffc_in(sp_rd_i), .clk(clk), .rst(rst), .ffc_out(delayed_rd)
    );

    always_ff @(posedge clk) begin
        if (rst || !delayed_rd) addr_cnt <= '0;
        else                    addr_cnt <= addr_cnt + 1'b1;
    end

    assign sp_rd_o     = delayed_rd;
    assign sp_rd_add_o = addr_cnt;
endmodule