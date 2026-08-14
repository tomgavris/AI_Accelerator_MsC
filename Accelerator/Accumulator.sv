import pe_pkg::*;

module accumulator(
      input  logic                                  clk, rst, 
      
      // Data Path FSM Interface
      input  logic                                  op, 
      input  logic                                  hold, 
      // input  logic                                  state,

      // Memory FSM Interface
      input  logic                                  acc_rd,

      input  logic                                  valid_i, // SA
      input  logic                                  dma_ready_i, 
      input  logic        [$clog2(ACC_SIZE)-1:0]    acc_wr_addr, acc_rd_addr_i,
      input  logic signed [(M*N*P_DATA_WIDTH)-1:0]  acc_i,
      output logic                                  valid_o, acc_ready,
      output logic signed [(M*N*P_DATA_WIDTH)-1:0]  acc_o
  );
  

  logic signed [(M*N*P_DATA_WIDTH)-1:0] acc_data_reg, acc_res_w, m_o_w;
  logic [$clog2(ACC_SIZE)-1:0]          wr_add_reg;
  logic                                 op_reg, valid_reg, state_reg;

  logic [$clog2(ACC_SIZE)-1:0]  drain_addr;
  logic                         drain_active;
  logic                         all_sent;
  logic                          rd_pending;

  assign acc_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (rst || !acc_rd) begin
            drain_addr   <= '0;
            rd_pending   <= 1'b0;
            drain_active <= 1'b0;
            all_sent     <= 1'b0;
            valid_o      <= 1'b0;
        end else if (!all_sent) begin
            if (!drain_active) begin
                drain_active <= 1'b1;
                rd_pending   <= 1'b1;
            end
            else if (rd_pending) begin
                rd_pending <= 1'b0;
                valid_o    <= 1'b1;
            end
            else if (valid_o && dma_ready_i) begin
                valid_o <= 1'b0;
                if (drain_addr == BATCH_SIZE-1) begin
                    all_sent <= 1'b1;
                end else begin
                    drain_addr <= drain_addr + 1'b1;
                    rd_pending <= 1'b1;
                end
            end
        end else begin
            valid_o <= 1'b0;
        end
    end

  double_buffer #(
    .DB_WIDTH(M*N*P_DATA_WIDTH),
    .DB_SIZE(ACC_SIZE)
  ) double_buffer_i(
        .clk(clk), 
        .rst(rst),
        .db_wr_add(wr_add_reg),
        
        .db_rd_add(acc_rd ? drain_addr : acc_rd_addr_i),
        
        .db_i(acc_res_w),
        .db_wr(valid_reg), 
        
        .db_rd(acc_rd | op), 
        
        .db_ready(), 
        .db_valid(),  
        .state(state_reg),
        .db_o(acc_o)
    );

  assign m_o_w = op_reg ? acc_o : '0;

  always_ff @ (posedge clk) begin
    if (rst) begin
        acc_data_reg <= '0;
        op_reg       <= '0;
        wr_add_reg   <= '0;
        valid_reg    <= '0;
        state_reg    <= '0;
    end
    else if(!hold) begin 
      wr_add_reg   <= acc_wr_addr;
      op_reg       <= op;
      acc_data_reg <= acc_i;
      valid_reg    <= valid_i;
      if (valid_reg && (wr_add_reg == BATCH_SIZE-1))
          state_reg <= ~state_reg;
    end
  end


  assign acc_res_w = acc_data_reg + m_o_w;

endmodule