// import pe_pkg::*;

module concat #(
    parameter CONCAT_WIDTH = 1024
    )(
    input  logic signed [63:0]              concat_i,
    input  logic                            clk, rst, enable, 
    output logic                            valid_o,
    output logic signed [CONCAT_WIDTH-1:0]  concat_o
);
    // Chunks paremeter shields the module from running it problems with other parameters
    localparam CHUNKS = CONCAT_WIDTH / 64;

    logic [$clog2(CHUNKS+1)-1:0]   counter;
    logic [CHUNKS-1:0][63:0]       raw_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            counter  <= '0;
            concat_o <= '0;
            valid_o  <= 1'b0;
            for (int i = 0; i < CHUNKS; i++) raw_data[i] <= '0;
        end else begin
            valid_o <= 1'b0;
            if (enable) begin
                raw_data[counter] <= concat_i;

                if (counter == CHUNKS-1) begin
                    for (int i = 0; i < CHUNKS-1; i++)
                        concat_o[i*64 +: 64] <= raw_data[i];

                    // The last data package should not be delayed by the raw_data register
                    concat_o[(CHUNKS-1)*64 +: 64] <= concat_i; 
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