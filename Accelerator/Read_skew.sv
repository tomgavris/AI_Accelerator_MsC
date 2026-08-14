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
                .clk(clk), .rst(rst || clear_i), .sp_rd_i(sp_rd_i),
                .sp_rd_o(sp_rd_o[part]), .sp_rd_add_o(sp_rd_add_o[part])
            );
        end
    endgenerate
endmodule

module Weight_sp_rd (
    input  logic                                clk, rst,
    input  logic                                sp_rd_i,     // from mem_fsm
    input  logic                                clear_i,
    output logic                                sp_rd_o,
    output logic [$clog2(WEIGHT_SP_SIZE)-1:0]   sp_rd_add_o
);

    logic [$clog2(WEIGHT_SP_SIZE)-1:0] count;
    always_ff @(posedge clk) begin
        if (rst) begin
            count <= '0;
        end 
        else if (sp_rd_i) begin
            if (count == WEIGHT_SP_SIZE - 1) begin
                count <= '0;
            end 
            else begin
                count <= count + 1'b1;
            end
        end
    end

    assign sp_rd_add_o = count;
    assign sp_rd_o  = sp_rd_i;
endmodule


    

module part_rd_gen #(
    parameter int PART_ID = 0
)(
    input  logic                          clk, rst,
    input  logic                          sp_rd_i,      
    output logic                          sp_rd_o,      
    output logic [$clog2(SRAM_SIZE)-1:0]  sp_rd_add_o   
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