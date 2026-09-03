// import pe_pkg::*;

module skewing_mod #(
    parameter int CONC_ADD = 2,
    parameter int N = 4,
    parameter int OP = 2,
    parameter int DATA_WIDTH = 8
)(
    input  logic signed [CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0] skew_mod_i,
    input  logic                                                      clk, rst, 
    output logic signed [CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0] skew_mod_o
);
    
    genvar rows;
    generate
        for (rows = 0; rows < CONC_ADD ; rows++) begin
            FF_chain  #(.DELAY(rows), .WIDTH(N * OP * DATA_WIDTH)) FF_chain_inst(
                .ffc_in(skew_mod_i[rows]),
                .clk(clk),
                .rst(rst),
                .ffc_out(skew_mod_o[rows])
            );
        end
    endgenerate
endmodule

module deskewing_mod #(
    parameter int M = 8,
    parameter int N = 4,
    parameter int P_DATA_WIDTH = 16
)(
    input  logic signed [M-1:0][N-1:0][P_DATA_WIDTH-1:0] deskew_mod_i,
    input  logic                                         clk, rst, 
    output logic signed [M-1:0][N-1:0][P_DATA_WIDTH-1:0] deskew_mod_o
);
    
    genvar columns;
    generate
        
        for (columns = 0; columns < M; columns++) begin
            FF_chain  #(
                .WIDTH(N*P_DATA_WIDTH),         
                .DELAY(M - columns - 1)       
            ) FF_chain_inst(
                .ffc_in(deskew_mod_i[columns]),
                .clk(clk),
                .rst(rst),
                .ffc_out(deskew_mod_o[columns])
            );
        end
        
    endgenerate
endmodule


module FF_chain #(
    parameter WIDTH = 8, 
    parameter DELAY = 2
)(
    input  logic [WIDTH-1:0] ffc_in,
    input  logic             clk, rst,
    output logic [WIDTH-1:0] ffc_out
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