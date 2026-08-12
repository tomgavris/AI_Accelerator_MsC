import pe_pkg::*;

module accumulator(
      input  logic                                  clk, rst, 
      
      // Data Path FSM Interface
      input  logic   op, 
      input  logic   hold, 
      input  logic   state,

      // Memory FSM Interface
      input  logic   acc_rd,

      input  logic                                  valid_i, // SA
      input  logic                                  dma_ready_i, 
      input  logic        [$clog2(ACC_SIZE)-1:0]    acc_wr_addr, acc_rd_addr,
      input  logic signed [(M*N*P_DATA_WIDTH)-1:0]  acc_i,
      output logic                                  valid_o, acc_ready,
      output logic signed [(M*N*P_DATA_WIDTH)-1:0]  acc_o
  );
  localparam ACC_SIZE = 2*BATCH_SIZE;

  logic signed [(M*N*P_DATA_WIDTH)-1:0] acc_data_reg, acc_res_w, m_o_w;
  logic [$clog2(ACC_SIZE)-1:0]          wr_add_reg;
  logic                                 op_reg, valid_reg;

  logic [$clog2(ACC_SIZE)-1:0]  drain_addr;
  logic                         drain_active;

  assign acc_ready = 1'b1;

  always_ff @(posedge clk) begin
      if (rst || !acc_rd) begin
          drain_addr   <= '0;
          drain_active <= 1'b0;
          valid_o      <= 1'b0;
      end else begin
          if (dma_ready_i || !valid_o) begin
              drain_active <= 1'b1;
              valid_o      <= drain_active; 
              
              if (drain_active) begin
                  drain_addr <= drain_addr + 1'b1;
              end
          end
      end
  end

  double_buffer #(
    .DB_WIDTH(M*N*P_DATA_WIDTH),
    .DB_SIZE(ACC_SIZE)
  ) double_buffer_i(
        .clk(clk), 
        .rst(rst),
        .db_wr_add(wr_add_reg),
        
        .db_rd_add(acc_rd ? drain_addr : acc_rd_addr),
        
        .db_i(acc_res_w),
        .db_wr(valid_reg), 
        
        .db_rd(acc_rd | op), 
        
        .db_ready(), 
        .db_valid(),  
        .state(state),
        .db_o(acc_o)
    );

  assign m_o_w = op_reg ? acc_o : '0;

  always_ff @ (posedge clk) begin
    if (rst) begin
        acc_data_reg <= '0;
        op_reg       <= '0;
        wr_add_reg   <= '0;
        valid_reg    <= '0;
    end
    else if(!hold) begin 
      wr_add_reg   <= acc_wr_addr;
      op_reg       <= op;
      acc_data_reg <= acc_i;
      valid_reg    <= valid_i;
    end
  end

  assign acc_res_w = acc_data_reg + m_o_w;

endmodule