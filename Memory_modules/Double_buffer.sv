// import pe_pkg::*;

module double_buffer # (
   parameter DB_WIDTH = 8,
   parameter DB_SIZE =  512
)(
    input  logic signed [DB_WIDTH-1:0]   db_i,
    input  logic [$clog2(DB_SIZE)-1:0]   db_wr_add, db_rd_add, 
    input  logic                         clk, rst, state, 
    input  logic                         db_wr, db_rd,
    output logic                         db_ready, db_valid,
    output logic signed [DB_WIDTH-1:0]   db_o
);
   
    logic [1:0][$clog2(DB_SIZE)-1:0]   add_wire ;
    logic signed [1:0][DB_WIDTH-1:0]   temp;
    logic [1:0]                        rd_wire, wr_wire;

    
    assign db_ready = 1'b1;
    assign db_valid = 1'b1;

    genvar i;
    generate
        for (i = 0; i < 2; i++) begin
            single_port_ram #(.WIDTH(DB_WIDTH), .RAM_SIZE(DB_SIZE)) SPRAM_I (
                .clk(clk), 
                .rst(rst),
                .addr(add_wire[i]),
                .sram_i(db_i),
                .wr(wr_wire[i]),
                .rd(rd_wire[i]), 
                .sram_o(temp[i])
            );
        end
    endgenerate
    
    assign db_o = state ? temp[0] : temp[1];

    // state0 -> write in bank0, read bank1
    // state1 -> write in bank1, read bank0
    always_comb begin 
        
        add_wire[0] = state ? db_rd_add : db_wr_add;
        add_wire[1] = state ? db_wr_add : db_rd_add;

        wr_wire[0]  = state ? 1'b0 : db_wr;
        wr_wire[1]  = state ? db_wr : 1'b0;

        rd_wire[0]  = state ? db_rd : 1'b0;
        rd_wire[1]  = state ? 1'b0 : db_rd;
    end
    
endmodule