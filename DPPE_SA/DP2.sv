localparam DATA_WIDTH = 8;
localparam OP = 2; // OP = operands

module DP(
    input  logic signed [OP-1:0][DATA_WIDTH-1:0]  a_i,
    input  logic signed [OP-1:0][DATA_WIDTH-1:0]  w_i, 
    input  logic signed [2*DATA_WIDTH-1:0]        parsum_i, //parsum_i = partial sum output
    input  logic                                  comp_e, //wr_e = write enable, comp_e = compute enable
    output logic signed [OP-1:0][DATA_WIDTH-1:0]  a_o, 
    output logic signed [2*DATA_WIDTH-1:0]        parsum_o //a_o = activation output, parsum_o = partial sum output 
);

logic signed [2*DATA_WIDTH-1:0] temp;

always_comb begin 
    if (comp_e == 1) begin
        temp = parsum_i;
        for (int i = 0; i < OP ; i++) begin
            a_o[i] = a_i[i];
            temp   = temp + a_i[i]*w_i[i];
        end 
        parsum_o = temp;
    end else begin
        a_o      = '0;
        parsum_o = '0;
        temp     = '0;
    end
end
endmodule