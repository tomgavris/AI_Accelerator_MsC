// import pe_pkg::*;

module serializer #(
    parameter int M = 8,
    parameter int N = 4,
    parameter int DATA_WIDTH = 8,
    parameter int IN_WIDTH  = M * N * DATA_WIDTH,
    parameter int OUT_WIDTH = 64
)(
    input  logic                 clk, rst,
    
    input  logic                 valid_i,  // From Acc.
    input  logic [IN_WIDTH-1:0]  data_i,   // From Quantizer
    output logic                 ready_o,  // To Accumulator
    
    // DMA Interface
    input  logic                 dma_ready_i, // DMA busy
    output logic                 valid_o,     
    output logic [OUT_WIDTH-1:0] data_o
);

    localparam TOTAL_CHUNKS = IN_WIDTH / OUT_WIDTH;
    
    logic [IN_WIDTH-1:0]               shift_reg;
    logic [$clog2(TOTAL_CHUNKS+1)-1:0] chunk_count;

    typedef enum logic {
        IDLE  = 1'b0,
        SHIFT = 1'b1
    } state_t;
    
    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            shift_reg   <= '0;
            chunk_count <= '0;
        end else begin
            state <= next_state;
            
            if (state == IDLE && valid_i && ready_o) begin
                shift_reg   <= data_i;
                chunk_count <= TOTAL_CHUNKS;
            end 
            else if (state == SHIFT && valid_o && dma_ready_i) begin
                shift_reg   <= shift_reg >> OUT_WIDTH;
                chunk_count <= chunk_count - 1'b1;
            end
        end
    end

    always_comb begin
        
        next_state = state;
        ready_o    = 1'b0;
        valid_o    = 1'b0;
        data_o     = '0;

        case (state)
            IDLE: begin
                ready_o = 1'b1;
                
                if (valid_i) begin
                    next_state = SHIFT;
                end
            end
            
            SHIFT: begin
                valid_o = 1'b1;
                
                data_o  = shift_reg[OUT_WIDTH-1:0];
                
                // If we are on the final chunk and the DMA takes it, return to IDLE
                if (dma_ready_i && chunk_count == 1) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule