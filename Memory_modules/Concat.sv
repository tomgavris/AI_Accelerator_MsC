import pe_pkg::*;

module concat (
    input  logic signed [DATA_WIDTH-1:0] concat_i,
    input  logic                         clk, rst, 
    output logic                         valid_o,
    output logic signed [SRAM_WIDTH-1:0] concat_o
);
    logic [$clog2(CONC_ADD)-1:0]   counter = 0;
    logic [DATA_WIDTH-1:0] raw_data [CONC_ADD-1:0];
    logic [SRAM_WIDTH-1:0] res;

    always_ff @(posedge clk) begin
        if(rst) begin
            counter  <= '0;
            concat_o <= '0;
            valid_o  <=  0;
            for (int i = 0; i < CONC_ADD; i++) raw_data[i] <= '0;
        end
        else    
            raw_data[counter] <= concat_i;

            if(counter == CONC_ADD-1) begin
                for (int i = 0; i < CONC_ADD - 1; i++) begin
                    concat_o[i*DATA_WIDTH +: DATA_WIDTH] <= raw_data[i];
                end
            valid_o <= 1;
            counter <= '0;
            end
        else begin
            counter           <= counter + 1;
            valid_o           <=  0;
        end
    end

endmodule