import pe_pkg::*;

module double_buffer # (
   parameter DB_WIDTH = DATA_WIDTH 
)(
    input  logic signed [DB_WIDTH-1:0]  db_i,
    input  logic [$clog2(SRAM_SIZE)-1:0]  db_wr_add, db_rd_add, 
    input  logic                          clk, rst, state,
    output logic signed [DB_WIDTH-1:0]  db_o
);

    logic [1:0][$clog2(SRAM_SIZE)-1:0] add_wire ;
    logic signed [1:0][DB_WIDTH-1:0] temp;
    logic [1:0]                        rd_wire, wr_wire;


    genvar i;
    generate
        for (i = 0; i < 2; i++) begin
            single_port_ram SPRAM_I (
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
    

    always_ff @(posedge clk) begin
        if(rst) begin
            db_o <= '0;
        end
        else begin
            if(!state) begin
                db_o <= temp[1];
            end
            else if(state) begin
                db_o <= temp[0];
            end
        end
    end

    // state0 -> write in bank0, read bank1
    // state1 -> write in bank1, read bank0
    always_comb begin 
        
        add_wire[0] = state ? db_rd_add : db_wr_add;
        add_wire[1] = state ? db_wr_add : db_rd_add;

        wr_wire[0]  = state ? 1'b0 : 1'b1;
        wr_wire[1]  = state ? 1'b1 : 1'b0;

        rd_wire[0]  = state ? 1'b1 : 1'b0;
        rd_wire[1]  = state ? 1'b0 : 1'b1;
    end
    
endmodule