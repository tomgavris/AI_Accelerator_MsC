import pe_pkg::*;

module concat (
    input  logic signed [DATA_WIDTH-1:0] concat_i,
    input  logic                         clk, rst, enable, 
    output logic                         valid_o,
    output logic signed [SRAM_WIDTH-1:0] concat_o
);
    logic [$clog2(CONC_ADD)-1:0]   counter;
    logic [DATA_WIDTH-1:0]         raw_data [CONC_ADD-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            counter  <= '0;
            concat_o <= '0;
            valid_o  <= 1'b0;
            for (int i = 0; i < CONC_ADD; i++) raw_data[i] <= '0;
        end else begin
            valid_o <= 1'b0;
            if (enable) begin
                raw_data[counter] <= concat_i;

                if (counter == CONC_ADD-1) begin
                    for (int i = 0; i < CONC_ADD-1; i++)
                        concat_o[i*DATA_WIDTH +: DATA_WIDTH] <= raw_data[i];
                    concat_o[(CONC_ADD-1)*DATA_WIDTH +: DATA_WIDTH] <= concat_i; 
                    valid_o <= 1'b1;
                    counter <= '0;
                end else begin
                    valid_o <= 1'b0;
                    counter <= counter + 1'b1;
                end
            end
        end
    end

endmodule