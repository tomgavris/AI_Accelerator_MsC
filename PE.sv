localparam DATA_WIDTH = 8;

module pe_ws(
    input logic [DATA_WIDTH-1:0]  a_i,
    input logic [DATA_WIDTH-1:0]  w_i, parsum_i, //parsum_i = partial sum output
    input logic                   clk, wr_e, comp_e, rst, //wr_e = write enable, comp_e = compute enable
    output logic [DATA_WIDTH-1:0] a_o, w_o, parsum_o, //a_o = activation output, parsum_o = partial sum output 
    output logic                  valid_wr // valid_wr = valid write 
);

logic [2*DATA_WIDTH-1:0] acc_next;
logic [DATA_WIDTH-1:0] weight;


always_ff @( posedge clk ) begin 
    if(rst) begin
        weight <= '0;
        valid_wr <= 0;
        parsum_o <= '0;
        a_o <= '0;
    end
    else if(comp_e) begin
       parsum_o <= acc_next >> 8;
       a_o <= a_i; 
       valid_wr <= 0;
    end else if(wr_e) begin
        w_o <= weight;
        weight <= w_i;
        valid_wr <= 1;
    end
end 

assign acc_next = parsum_i + a_i*weight;

endmodule