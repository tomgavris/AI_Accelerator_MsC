import pe_pkg::*;

module dp_fsm (
    input  logic                               clk, rst, 
    input  logic                               stop_comp_i, cu_hold_i,            // RoCC Tran. signals
    input  logic                               start_w_load_i, start_comp_i,      // Mem FSM signal
    input  logic                               sa_valid_i, 

    output logic                               results_ready_o, no_skew, dp_busy_o, 
    output logic                               w_sp_rd_o, a_sp_rd_o,              // SP signals
    output logic                               acc_op_o, acc_hold_o, acc_state_o, // Accumulator signals
    output logic                               sa_wr_o, sa_comp_e_o,              // SA signals
    output logic [$clog2(BATCH_SIZE)-1:0]      out_count                          // Accumulator addressing
);

    typedef enum logic [1:0] { 
        IDLE    = 2'd0,
        W_LOAD  = 2'd1,
        COMP    = 2'd2
    } state_t;

    state_t next_state, curr_state;
    
    logic [$clog2(M)-1:0]          sp_count;
    logic [$clog2(BATCH_SIZE)-1:0] in_count;
    logic                          out_cnt_clr; 
    logic                          count_en, cnt_clr, k_increase, in_count_en, k_clear;
    logic                          acc_state_flip;
    logic [$clog2(K_TILE)-1:0]     k_tile_count;
    logic                          w_ready_flag, reg_clr;
    logic                          in_cnt_clr_o; 
    logic                          reading_done;      

    always_ff @(posedge clk) begin
        if (rst || in_cnt_clr_o) reading_done <= 1'b0;
        else if (in_count == BATCH_SIZE-1) reading_done <= 1'b1;
    end    

    always_ff @(posedge clk) begin
        if(rst || cu_hold_i) begin
            curr_state <= IDLE;
        end    
        else curr_state <= next_state;
    end

    // Acc. flipping state logic
    always_ff @(posedge clk) begin
        if(rst) begin
            acc_state_o <= 1'b0; 
        end
        else if(acc_state_flip) begin 
            acc_state_o <= ~acc_state_o;
        end
    end

    // SP counter during LOAD
    always_ff @(posedge clk) begin
        if(rst || cnt_clr) begin
            sp_count <= '0;
        end    
        else if(count_en) begin
            if (sp_count == (M-1)) begin
                sp_count <= '0;
            end 
            else sp_count <= sp_count + 1;
        end 
    end

    // Hold logic
    always_ff @(posedge clk) begin
        if(rst) begin
            acc_hold_o <= 0;
        end
        else if(cu_hold_i) begin
            acc_hold_o <= 1;
        end
        else acc_hold_o <= 0;
    end    

    // K_tile count determines acc_op 
    always_ff @(posedge clk) begin
        if(rst || k_clear) begin
            k_tile_count <= '0;
        end
        else if(k_increase) begin
            k_tile_count <= k_tile_count + 1;
        end
    end 

    always_ff @(posedge clk) begin
        if (rst || reg_clr) begin 
            w_ready_flag <= 1'b0;
        end
        else if (start_w_load_i) begin
            w_ready_flag <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst || in_cnt_clr_o) begin
            in_count <= '0;
        end
        else if(in_count_en) begin
            in_count <= in_count + 1;
        end 
    end 
    
    always_ff @(posedge clk) begin
        if(rst || out_cnt_clr || !sa_valid_i)       out_count <= '0;
        else if(sa_valid_i && (curr_state == COMP)) out_count <= out_count + 1; 
    end 

    always_comb begin

        dp_busy_o = (curr_state != IDLE);
        
        in_cnt_clr_o = 0;
        out_cnt_clr  = 0;
        in_count_en  = 0;

        no_skew = 0; 
        w_sp_rd_o = 0;
        a_sp_rd_o = 0;
        acc_op_o = 0; 
        acc_state_flip = 0;
        sa_wr_o = 0; 
        sa_comp_e_o = 0;
        results_ready_o = 0;
        count_en      = 0;
        cnt_clr       = 0;
        k_increase    = 0;
        k_clear       = 0;
        reg_clr       = 0;

        acc_op_o = (k_tile_count == 0) ? 1'b0 : 1'b1;

        case (curr_state)
            IDLE : begin 
                if(w_ready_flag) begin
                    reg_clr    = 1;
                    next_state = W_LOAD;
                end
                else if (start_comp_i) begin
                    next_state = COMP;
                end
                else next_state = IDLE;
            end

            W_LOAD : begin 
                no_skew     = 1;
                w_sp_rd_o   = 1; 
                sa_wr_o     = 1;
                count_en    = 1;

                if(sp_count == (M-1)) begin
                    next_state = IDLE;
                    cnt_clr  = 1;
                end 
                else begin
                    next_state = W_LOAD;
                end
            end
            
            COMP : begin
                // Keep compute enable high during normal run and drain phase
                sa_comp_e_o = 1;

                if (!reading_done) begin
                    a_sp_rd_o   = 1'b1;
                    in_count_en = 1'b1;
                end          

                // Allow out_count to finish completely before shutting down
                if(sa_valid_i && (out_count == (BATCH_SIZE-1))) begin
                    acc_state_flip = 1;
                    if(k_tile_count == (K_TILE-1)) begin
                        results_ready_o = 1;
                        k_clear = 1;
                    end 
                    else begin
                        k_increase = 1;
                    end
                    next_state  = IDLE;
                    in_cnt_clr_o  = 1;
                    out_cnt_clr   = 1;
                end 
                else if(stop_comp_i) next_state = IDLE;
                else next_state = COMP;
            end

            default : begin
                next_state = IDLE;
            end
        endcase
    end
endmodule