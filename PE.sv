localparam DATA_WIDTH = 8;
localparam M_SIZE = 4;

module p_e(
    input logic [DATA_WIDTH-1:0] a_i,
    input logic [DATA_WIDTH-1:0] b_i, 
    input logic clk, enable, rst,
    output logic [DATA_WIDTH-1:0] a_o, b_o, res,
    output logic valid_output
);

logic [2*DATA_WIDTH-1:0] acc = '0;
logic [1:0] count = 0;

always_ff @(posedge clk) begin
    if(rst) begin 
        count <= '0;
        acc <= '0;
        res <= '0;
        valid_output <= 0;
    end else begin
    if(enable) begin
        if(count == (M_SIZE-1) )begin
            res <= (acc + a_i * b_i) >> 8;
            count <= '0;
            valid_output <= 1;
            acc <= '0;
        end else begin
            acc <= acc + a_i*b_i;
            count <= count +1;
            valid_output <= 0;
        end
        a_o <= a_i;
        b_o <= b_i;
        
    end
end
end 
    
endmodule