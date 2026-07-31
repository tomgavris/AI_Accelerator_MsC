import pe_pkg::*;

module ff_pyramid (
    input  logic [CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0] ff_p_i,
    input  logic                                               clk, rst, 
    output logic [CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0] ff_p_o
);
    
    genvar rows;
    generate
        for (rows = 0; rows < CONC_ADD ; rows++) begin
            FF_chain  #(.WIDTH(), .DELAY(rows)) FF_chain_inst(
                .ffc_in(ff_p_i[rows]),
                .clk(clk),
                .rst(rst),
                .ffc_out(ff_p_o[rows])
            );
        end
    endgenerate
endmodule


module FF_chain #(
    parameter WIDTH = N*OP*DATA_WIDTH, 
    parameter DELAY = 2
)(
    input  logic [N-1:0][OP-1:0][DATA_WIDTH-1:0] ffc_in,
    input  logic                                 clk, rst,
    output logic [N-1:0][OP-1:0][DATA_WIDTH-1:0] ffc_out
);
    
    logic [DELAY:0][WIDTH-1:0] ff_wires;

    assign ff_wires[0] = ffc_in; 
    assign ffc_out = ff_wires[DELAY];

    genvar i;
    // for DELAY = 0 the chain is turned into a simple wire
    generate
        for (i = 0; i < DELAY; i++) begin
                FF  #(.WIDTH(WIDTH)) FF_I(
                    .ff_in(ff_wires[i]),
                    .clk(clk),
                    .rst(rst),
                    .ff_out(ff_wires[i+1])
                );    
            end  
    endgenerate
        
endmodule

module FF #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] ff_in,
    input  logic                  clk, rst,
    output logic [WIDTH-1:0] ff_out
);

  always_ff @(posedge clk) begin
    if(rst) begin
        ff_out <= '0;
    end
    else begin
        ff_out <= ff_in;
    end
  end  
endmodule