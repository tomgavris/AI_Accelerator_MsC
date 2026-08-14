import pe_pkg::*;

module mem_fsm (
    input  logic clk, rst, 
    input  logic start_w_i, start_a_i,
    input  logic results_ready_i,
    input  logic dma_load_finish_i,
    input  logic dp_busy_i,                    

    // RoCC-captured request parameters 
    input  logic [31:0] rocc_src_addr_i,
    input  logic [31:0] rocc_length_i,
    input  logic [31:0] rocc_dst_addr_i,

    output logic a_sp_state_o, w_sp_state_o,
    output logic start_w_load_o, start_comp_o,
    output logic acc_rd,
    output logic dma_go_pulse, dma_mode_o,
    output logic dma_busy_o,
    output logic a_sp_wr_clr_o,

    // DMA parameters 
    output logic        weight_fetch_o,
    output logic [31:0] dma_src_addr_o,
    output logic [31:0] dma_length_o,
    output logic [31:0] dma_dst_addr_o
);

    localparam ACT_TILE_BYTES = (BATCH_SIZE * M * N * OP * DATA_WIDTH) / 8;
    
    localparam STORE_BYTES = (BATCH_SIZE * M * N * DATA_WIDTH) / 8;

    typedef enum logic [2:0] {
        IDLE            = 3'd0,
        W_FETCH_REQ     = 3'd1,
        W_FETCH_WAIT    = 3'd2,
        A_FETCH_REQ     = 3'd3,
        A_FETCH_WAIT    = 3'd4,
        A_FETCH_HANDOFF = 3'd5,
        STORE_REQ       = 3'd6,
        STORE_WAIT      = 3'd7
    } state_t;

    state_t curr_state, next_state;
    logic   a_sp_state_flip, w_sp_state_flip;
    logic   w_req_flag, a_req_flag, store_req_flag;
    logic   w_req_clr, a_req_clr, store_req_clr;

    // Tile sequencing for the autonomous activation loop
    logic [$clog2(K_TILE)-1:0] tile_idx;
    logic                      tile_idx_clr, tile_idx_inc;
    logic [31:0]               act_addr;
    logic                      act_addr_ld, act_addr_inc;

    logic comp_hold, comp_hold_set, comp_hold_clr;


    always_ff @(posedge clk) begin
        if (rst) curr_state <= IDLE;
        else     curr_state <= next_state;
    end

    always_ff @(posedge clk) begin
        if (rst) a_sp_state_o <= 1'b0;
        else if (a_sp_state_flip) a_sp_state_o <= ~a_sp_state_o;
    end

    always_ff @(posedge clk) begin
        if (rst) w_sp_state_o <= 1'b0;
        else if (w_sp_state_flip) w_sp_state_o <= ~w_sp_state_o;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            w_req_flag     <= 1'b0;
            a_req_flag     <= 1'b0;
            store_req_flag <= 1'b0;
        end else begin
            if (start_w_i)          w_req_flag <= 1'b1;
            else if (w_req_clr)     w_req_flag <= 1'b0;

            if (start_a_i)          a_req_flag <= 1'b1;
            else if (a_req_clr)     a_req_flag <= 1'b0;

            if (results_ready_i)    store_req_flag <= 1'b1;
            else if (store_req_clr) store_req_flag <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst || tile_idx_clr) tile_idx <= '0;
        else if (tile_idx_inc)   tile_idx <= tile_idx + 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst)                act_addr <= '0;
        else if (act_addr_ld)   act_addr <= rocc_src_addr_i;
        else if (act_addr_inc)  act_addr <= act_addr + ACT_TILE_BYTES;
    end

    always_ff @(posedge clk) begin
        if (rst)                comp_hold <= 1'b0;
        else if (comp_hold_set) comp_hold <= 1'b1;
        else if (comp_hold_clr) comp_hold <= 1'b0;
    end


    always_comb begin
        // Default Assignments
        acc_rd          = 1'b0;
        a_sp_wr_clr_o  =  1'b0;
        dma_go_pulse    = 1'b0;
        dma_mode_o      = 1'b0;
        start_w_load_o  = 1'b0;
        a_sp_state_flip = 1'b0;
        w_sp_state_flip = 1'b0;

        w_req_clr     = 1'b0;
        a_req_clr     = 1'b0;
        store_req_clr = 1'b0;

        tile_idx_clr  = 1'b0;
        tile_idx_inc  = 1'b0;
        act_addr_ld   = 1'b0;
        act_addr_inc  = 1'b0;

        comp_hold_set = 1'b0;
        comp_hold_clr = 1'b0;
        start_comp_o  = 1'b0;

        weight_fetch_o = 1'b0;
        dma_src_addr_o = rocc_src_addr_i;
        dma_length_o   = rocc_length_i;
        dma_dst_addr_o = rocc_dst_addr_i;

        if (comp_hold && !dp_busy_i) begin
            start_comp_o  = 1'b1;
            comp_hold_clr = 1'b1;
        end

        case (curr_state)
            IDLE : begin
                if (w_req_flag) begin
                    w_req_clr  = 1'b1;
                    next_state = W_FETCH_REQ;
                end
                else if (a_req_flag) begin
                    a_req_clr    = 1'b1;
                    tile_idx_clr = 1'b1;
                    act_addr_ld  = 1'b1;
                    next_state   = A_FETCH_REQ;
                end
                else if (store_req_flag) begin
                    store_req_clr = 1'b1;
                    next_state    = STORE_REQ;
                end
                else next_state = IDLE;
            end

            W_FETCH_REQ : begin
                dma_go_pulse   = 1'b1;
                weight_fetch_o = 1'b1; 
                dma_src_addr_o = rocc_src_addr_i;
                dma_length_o   = rocc_length_i;
                next_state     = W_FETCH_WAIT;
            end

            W_FETCH_WAIT : begin
                weight_fetch_o = 1'b1; 
                
                if (dma_load_finish_i) begin
                    start_w_load_o   = 1'b1;
                    w_sp_state_flip  = 1'b1;
                    next_state       = IDLE;
                end
                else next_state = W_FETCH_WAIT;
            end

            A_FETCH_REQ : begin
                dma_go_pulse   = 1'b1;
                a_sp_wr_clr_o  = 1'b1;
                dma_src_addr_o = act_addr;
                dma_length_o   = ACT_TILE_BYTES;
                next_state     = A_FETCH_WAIT;
            end

            A_FETCH_WAIT : begin
                if (dma_load_finish_i) next_state = A_FETCH_HANDOFF;
                else next_state = A_FETCH_WAIT;
            end

            A_FETCH_HANDOFF : begin
                if (!comp_hold) begin
                    a_sp_state_flip = 1'b1;
                    comp_hold_set = 1'b1;
                    if (tile_idx == K_TILE-1) begin
                        next_state = IDLE;
                    end else begin
                        tile_idx_inc = 1'b1;
                        act_addr_inc = 1'b1;
                        next_state   = A_FETCH_REQ;
                    end
                end
                else next_state = A_FETCH_HANDOFF;
            end

            STORE_REQ : begin
                dma_go_pulse   = 1'b1;
                dma_mode_o     = 1'b1; 
                dma_dst_addr_o = rocc_dst_addr_i;
                dma_length_o   = STORE_BYTES;
                next_state     = STORE_WAIT;
            end

            STORE_WAIT : begin
                acc_rd     = 1'b1;
                dma_mode_o = 1'b1; 
                if (dma_load_finish_i) next_state = IDLE;
                else next_state = STORE_WAIT;
            end

            default: next_state = IDLE;
        endcase
    end

    assign dma_busy_o = (curr_state != IDLE) || dp_busy_i || comp_hold;

endmodule