import pe_pkg::*;

module Quantizer (
    input  logic signed [(M*N*P_DATA_WIDTH)-1:0] quantize_i,
    output logic signed [(M*N*DATA_WIDTH)-1:0]   quantize_o
);
    localparam signed [DATA_WIDTH-1:0]          MAX_VAL =  (1 << (DATA_WIDTH-1)) - 1;
    localparam signed [DATA_WIDTH-1:0]          MIN_VAL = -(1 <<< (DATA_WIDTH-1));  

    always_comb begin 
        for(int i = 0; i < M*N; i++) begin
            logic signed [P_DATA_WIDTH-1:0] current_val;
            logic signed [P_DATA_WIDTH-1:0] shifted_val;
            
            current_val = quantize_i[i*P_DATA_WIDTH +: P_DATA_WIDTH];
            shifted_val = current_val >>> (P_DATA_WIDTH - DATA_WIDTH);

            if (shifted_val > MAX_VAL) begin
                quantize_o[i*DATA_WIDTH +: DATA_WIDTH] = MAX_VAL;
            end 
            else if (shifted_val < MIN_VAL) begin
                quantize_o[i*DATA_WIDTH +: DATA_WIDTH] = MIN_VAL;
            end 
            else begin
                quantize_o[i*DATA_WIDTH +: DATA_WIDTH] = shifted_val[DATA_WIDTH-1:0];
            end
        end
    end

endmodule