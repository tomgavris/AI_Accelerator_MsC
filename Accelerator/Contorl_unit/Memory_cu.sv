import pe_pkg::*;


module memory_unit (
    input  logic clk, rst, 
    input  logic start_w, start_a,                  // RoCC Tran. signals
    input  logic results_ready,                     // DP FSM signal
    input  logic dma_load_finish,                   // DMA signal
    
    output logic start_w_load, start_comp,          // DP FSM signal
    output logic acc_rd,                            // Accumulator signal
    output logic dma_go_pulse,                      // DMA signal
    output logic busy                               // RoCC translator
);

    typedef enum logic [2:0] { 
        IDLE         = 3'd0,
        W_FETCH_REQ  = 3'd1,
        W_FETCH_WAIT = 3'd2,
        A_FETCH_REQ  = 3'd3,
        A_FETCH_WAIT = 3'd4, 
        STORE_REQ    = 3'd5,
        STORE_WAIT   = 3'd6
    } state_t;

    state_t                        curr_state, next_state;
    logic                          cnt_clr;
    logic [$clog2(BATCH_SIZE)-1:0] batch_count;
    logic                          w_req_flag, a_req_flag, store_req_flag;
    logic                          w_req_clr, a_req_clr, store_req_clr;

    always_ff @(posedge clk) begin
        if(rst) begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end 
    end

    always_ff @(posedge clk) begin
        if(rst ) begin
            w_req_flag     = 0; 
            a_req_flag     = 0;
            store_req_flag = 0;
        end
        else begin
            if (start_w)            w_req_flag  <= 1'b1;
            else if (w_req_clr)     w_req_flag <= 1'b0;

            if (start_a)            a_req_flag <= 1'b1;
            else if (a_req_clr)     a_req_flag <= 1'b0;

            if (results_ready)      store_req_flag <= 1'b1;
            else if (store_req_clr) store_req_flag <= 1'b0; 
        end
    end

    
    always_comb begin

        busy      = 1;

        acc_rd    = 0;

        dma_go_pulse = 0;

        start_w_load = 0;

        cnt_clr = 0;     

        w_req_clr     = 0;
        a_req_clr     = 0;
        store_req_clr = 0;
                
        case (curr_state)
            IDLE : begin // done

                busy = 0;

                if(w_req_flag) begin
                    w_req_clr  = 1;
                    next_state = W_FETCH_REQ;
                end
                else if(a_req_flag) begin
                    a_req_clr  = 1;
                    next_state = A_FETCH_REQ;
                end
                else if(store_req_flag) begin
                    store_req_clr  = 1;
                    next_state = STORE_REQ;
                end
                else next_state = IDLE;
            end

            W_FETCH_REQ : begin // done
                dma_go_pulse = '1; // 1 clock cycle
                next_state = W_FETCH_WAIT;
            end 

            W_FETCH_WAIT : begin // done
                
                if (dma_load_finish) begin
                    start_w_load = 1;
                    next_state = IDLE;
                end
                else begin
                    next_state = W_FETCH_WAIT;
                end
            end 

            A_FETCH_REQ : begin // done
                dma_go_pulse = 1; // 1 clock cycle
                next_state = A_FETCH_WAIT;
            end 

            A_FETCH_WAIT : begin // done

                if(dma_load_finish) begin
                    start_comp = 1;
                    next_state = IDLE;
                end
                else next_state = A_FETCH_WAIT;
            end

            STORE_REQ : begin
                dma_go_pulse = 1'b1; 
                next_state   = STORE_WAIT;
            end

            STORE_WAIT : begin
                acc_rd = 1'b1; 

                if(dma_load_finish) begin
                    next_state = IDLE;
                end
                else begin 
                    next_state = STORE_WAIT;
                end
            end 
            
            default: begin
                next_state = IDLE;
            end 
        endcase
    end
    
endmodule