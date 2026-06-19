import pe_pkg::*;

module FF_chain #( 
    parameter DELAY = 0
)(
    input  logic [N-1:0][OP-1:0][DATA_WIDTH-1:0] ffc_in,
    input  logic                                 clk, rst,
    output logic [N-1:0][OP-1:0][DATA_WIDTH-1:0] ffc_out
);
    
    localparam WIDTH = N * OP * DATA_WIDTH;
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
    input  logic [DATA_WIDTH-1:0] ff_in,
    input  logic                  clk, rst,
    output logic [DATA_WIDTH-1:0] ff_out
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