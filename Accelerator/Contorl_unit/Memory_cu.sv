import pe_pkg::*;

// TODO: add communication between the two FSMs
module memory_unit (
    input  logic clk, rst, start_w, start_a,
    input  logic results_ready,                     // comes from the DP FSM
    input  logic flush_flag, dma_load_finish,       // accumulator flush TODO: add this to accumulator
    output logic acc_rd,                            // accumulator SRAM signal
    output logic dma_go_pulse                       // dma signals
);

    typedef enum logic [2:0] { 
        IDLE         = 3'd0,
        W_FETCH_REQ  = 3'd1,
        W_FETCH_WAIT = 3'd2,
        A_FETCH_REQ  = 3'd3,
        A_FETCH_WAIT = 3'd4, 
        STORE        = 3'd5
    } state_t;

    state_t                       curr_state, next_state;
    logic                         count_max = M-1;

    always_ff @(posedge clk) begin
        if(rst) begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end 
    end

    
    always_comb begin

        acc_rd    = 0;

        dma_go_pulse = 0;
                
        case (curr_state)
            IDLE : begin // done
                if(start_w) begin
                    next_state = W_FETCH_REQ;
                end
                else if(start_a) begin
                    next_state = A_FETCH_REQ;
                end
                else next_state = IDLE;
            end

            W_FETCH_REQ : begin // done
                dma_go_pulse = '1; // 1 clock cycle
                next_state = W_FETCH_WAIT;
            end 

            W_FETCH_WAIT : begin // done
                
                if (dma_load_finish) begin
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
                    next_state = IDLE;
                end
                else next_state = A_FETCH_WAIT;
            end

            STORE : begin
                acc_rd = 1;

                if(results_ready) begin
                    next_state = IDLE;
                end
                else next_state = STORE;
            end
            
            default: begin
                next_state = IDLE;
            end 
        endcase
    end
    
endmodule