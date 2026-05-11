localparam DATA_WIDTH = 8;

module pe_tb();

logic [DATA_WIDTH-1:0]  a_i;
logic [DATA_WIDTH-1:0]  w_i, parsum_i; //parsum_i = partial sum output
logic                   clk, wr_e, comp_e, rst; //wr_e = write enable, comp_e = compute enable
logic [DATA_WIDTH-1:0]  a_o, parsum_o; //a_o = activation output, parsum_o = partial sum output 
logic                   valid_wr;


pe_ws pe_ws_i (
    .clk(clk),
    .a_i(a_i),
    .a_o(a_o),
    .w_i(w_i),
    .parsum_i(parsum_i),
    .parsum_o(parsum_o),
    .wr_e(wr_e),
    .comp_e(comp_e),
    .rst(rst),
    .valid_wr(valid_wr)
    );

initial begin
    clk = 0;
    forever #5 clk = ~clk; // Toggles every 5 time units (Period = 10)
end

initial begin
    $monitor("Time: %0t | rst: %b | wr_e: %b | comp_e: %b || w_i: %d | a_i: %d | parsum_o: %d", 
             $time, rst, wr_e, comp_e, w_i, a_i, parsum_o);

    parsum_i = 8'd0;
    rst      = 1;
    wr_e     = 0;
    comp_e   = 0;
    w_i      = 8'd0;
    a_i      = 8'd0;

    repeat(2) @(negedge clk); 
    rst  = 0;
    wr_e = 1;
    w_i  = 8'd2;

    
    @(negedge clk);
    wr_e   = 0;
    comp_e = 1;
    a_i    = 8'd2;

    
    repeat(4) @(negedge clk);
    $finish;
end



endmodule