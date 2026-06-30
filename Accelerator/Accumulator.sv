import pe_pkg::*;

module accumulator(
     	input  logic					                      clk, rst, op, hold, state,
   		input  logic        [$clog2(ACC_SIZE)-1:0]	acc_wr_addr, acc_rd_addr,
   		input  logic signed [M*DATA_WIDTH-1:0]	    acc_i,
      output logic signed [M*DATA_WIDTH-1:0]      acc_o
  );

  logic signed [M*DATA_WIDTH-1:0] acc_reg, acc_res_w, m_o_w;
  logic [$clog2(ACC_SIZE)-1:0]    wr_add_reg;
  logic                           op_reg;

  double_buffer double_buffer_i(
        .clk(clk), 
        .rst(rst),
        .db_wr_add(wr_add_reg),
        .db_rd_add(acc_rd_addr),
        .db_i(acc_res_w),
        .state(state),
        .db_o(acc_o)
    );

  mux mux_i (
    .m_a(acc_o),
    .m_b('0),
    .m_cont(op_reg),
    .m_o(m_o_w)
  );

  // op = 0 -> storing
  // op = 1 ->  accumulating

  always_ff @ (posedge clk) begin
    if (rst) begin
        acc_reg <= '0;
        op_reg <= '0;
        wr_add_reg <= '0;
    end
    else if(!hold) begin 
      wr_add_reg <= acc_wr_addr;
      op_reg <= op;
      acc_reg <= acc_i;
    end

  end

  assign acc_res_w = acc_reg + m_o_w;

endmodule

module mux (
  input  logic signed [M*DATA_WIDTH-1:0] m_a, m_b,
  input  logic                           cont,
  output logic signed [M*DATA_WIDTH-1:0] m_o
);
  
  always_comb begin
    m_o = cont ? m_a : m_b; // 1 -> a , 0 -> b
  end
endmodule