import pe_pkg::*;

module DP (
    input  logic signed [OP-1:0][DATA_WIDTH-1:0]  a_i,
    input  logic signed [OP-1:0][DATA_WIDTH-1:0]  w_i,
    input  logic signed [P_DATA_WIDTH-1:0]        parsum_i,
    input  logic                                  comp_e,
    output logic signed [OP-1:0][DATA_WIDTH-1:0]  a_o,
    output logic signed [P_DATA_WIDTH-1:0]        parsum_o
);

    localparam int POW2_OP = 1 << $clog2(OP);
    localparam int LEVELS  = $clog2(POW2_OP);

    logic signed [P_DATA_WIDTH-1:0] tree [LEVELS+1][POW2_OP];

    always_comb begin
        a_o = '0;
        parsum_o = '0;
        for (int lvl = 0; lvl <= LEVELS; lvl++) begin
            for (int i = 0; i < POW2_OP; i++) begin
                tree[lvl][i] = '0;
            end
        end

        if (comp_e) begin
            a_o = a_i;
            for (int i = 0; i < POW2_OP; i++) begin
                if (i < OP) begin
                    tree[0][i] = a_i[i] * w_i[i];
                end
            end
            for (int lvl = 1; lvl <= LEVELS; lvl++) begin
                for (int i = 0; i < (POW2_OP >> lvl); i++) begin
                    tree[lvl][i] = tree[lvl-1][i*2] + tree[lvl-1][i*2 + 1];
                end
            end
            parsum_o = parsum_i + tree[LEVELS][0];
        end
    end

endmodule