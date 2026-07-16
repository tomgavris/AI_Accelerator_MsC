import pe_pkg::*;

module control_unit (
    input  logic clk, rst, cu_hold,
    input  logic stop_comp, start_comp,             // stop computing signal comes from the translator
    input  logic start_w_load,                      // signals from mem_cu
    input  logic sa_valid,

    output logic results_ready,
    output logic sp_rd, sp_flush,                   // scratchpad signals
    output logic acc_op, acc_hold, acc_state,       // accumulator SRAM signals
    output logic sa_wr, sa_comp_e                   // systolic array signals
);

    typedef enum logic [1:0] { 
        IDLE    = 2'd0,
        W_LOAD  = 2'd1,
        COMP    = 2'd2
    } state_t;

    state_t next_state, curr_state;
    
    logic [$clog2(M)-1:0]          sp_count;
    logic [$clog2(BATCH_SIZE)-1:0] comp_count, in_count, out_count;
    logic                          in_cnt_clr, out_cnt_clr; 
    logic                          count_en, cnt_clr, comp_count_en, b_cnt_clr, k_increase, in_count_en, k_clear;
    logic                          acc_state_flip;
    logic [$clog2(K_TILE)-1:0]     k_tile_count;

    always_ff @(posedge clk) begin
        if(rst || cu_hold) begin
            curr_state <= IDLE;
        end    
        else curr_state <= next_state;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            acc_state <= 1'b0; 
        end
        else if(acc_state_flip) begin 
            acc_state <= ~acc_state;
        end
    end

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

    always_ff @(posedge clk) begin
        if(rst) begin
            acc_hold <= 0;
        end
        else if(cu_hold) begin
            acc_hold <= 1;
        end
        else acc_hold <= 0;
    end    

    always_ff @(posedge clk) begin
        if(rst) begin
            comp_count <= '0;
        end
        else if(sa_valid && comp_count_en) begin
            comp_count <= comp_count +1;
        end
    end 

    always_ff @(posedge clk) begin
        if(rst || k_clear) begin
            k_tile_count <= '0;
        end
        else if(k_increase) begin
            k_tile_count <= k_tile_count +1;
        end
    end 

    always_ff @(posedge clk) begin
        if(rst || in_cnt_clr) begin
            in_count <= '0;
        end
        else if(in_count_en) begin
            in_count <= in_count + 1;
        end 
    end 
    
    always_ff @(posedge clk) begin
        if(rst || out_cnt_clr) out_count <= '0;
        else if(sa_valid)      out_count <= out_count + 1; 
    end 

    always_comb begin

        // setting all signals to 0
        sp_rd = 0;
        sp_flush = 0;

        acc_op = 0; 
        acc_hold = 0; 
        acc_state = 0;

        acc_state_flip = 0;

        sa_wr = 0; 
        sa_comp_e = 0;

        results_ready = 0;
        comp_count_en = 0;

        count_en      = 0;
        cnt_clr       = 0;
        b_cnt_clr     = 0;

        k_increase = 0;
        k_clear = 0;

        acc_op = (k_tile_count == 0) ? 1'b0 : 1'b1;

        case (curr_state)
            IDLE : begin 
                if(start_w_load) begin
                    next_state = W_LOAD;
                end
                else if (start_comp) begin
                    next_state = COMP;
                end
                else next_state = IDLE;
            end


            W_LOAD : begin // done
                        sp_rd     = '1; 
                        
                        sa_wr     = '1;

                        count_en  = 1;
                        if(sp_count == (M-1)) begin
                            next_state = IDLE;
                            cnt_clr  = 1;
                            sp_flush = 1;
                        end 
                        else begin
                            next_state = W_LOAD;
                        end
                    end
            
            COMP : begin
                sa_comp_e = 1;

                comp_count_en = 1;
                
                if (in_count < BATCH_SIZE) begin
                    sp_rd       = 1'b1;
                    in_count_en = 1'b1;
                end
                

                if(sa_valid && (out_count == (BATCH_SIZE-1))) begin

                    if(k_tile_count == (K_TILE-1)) begin
                        acc_state_flip = 1;
                        results_ready = 1;
                        k_clear = 1;
                    end 
                    else begin
                        
                        k_increase = 1;
                        next_state = COMP;
                    end

                    in_cnt_clr  = 1;
                    out_cnt_clr = 1;
                    b_cnt_clr = 1;   
                end 
                else if(stop_comp) begin
                    next_state = IDLE;
                end
                else next_state = COMP;
            end

            default : begin
                next_state = IDLE;
            end
        endcase
    end
        


endmodule