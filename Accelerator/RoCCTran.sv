import pe_pkg::*;

module RoCCTran (
    input  logic        clk, rst, 

    //RoCC control signals
    input  logic        core_cmd_valid, 

    // RoCC commmand signals 
    input  logic [6:0]  core_cmd_funct,
    input  logic [6:0]  core_cmd_inst_opcode_i,

    input  logic [4:0]  core_cmd_inst_rs1_i,
    input  logic        core_cmd_inst_xs1_i,  
    input  logic [63:0] core_cmd_rs1,

    input  logic [4:0]  core_cmd_inst_rs2_i,
    input  logic        core_cmd_inst_xs2_i,  
    input  logic [63:0] core_cmd_rs2,

    // Busy signal
    input  logic        dma_busy_i,

    output logic        core_cmd_ready_o,

    // DMA address
    output logic [63:0] dma_src_addr_o,
    output logic [31:0] dma_length_o,
    output logic [31:0] dma_dst_addr_o,

    // DP FSM signals
    output logic cu_hold_o, 
    output logic stop_comp_o,

    // Mem FSM signals 
    output logic start_w_o, 
    output logic start_a_o                   
);  

    assign core_cmd_ready_o = !dma_busy_i;

    always_ff @(posedge clk) begin 
        if (rst) begin

            // DMA address
            dma_src_addr_o <= 0;
            dma_length_o   <= 0;
            dma_dst_addr_o <= 0;

            // DP FSM signals
            cu_hold_o    <= 0; 
            stop_comp_o  <= 0; 

            // Mem FSM signals 
            start_w_o <= 0; 
            start_a_o <= 0;
        end 
        else begin

            start_w_o   <= 0; 
            start_a_o   <= 0;
            stop_comp_o <= 0;

            if (core_cmd_valid && core_cmd_ready_o) begin

                case (core_cmd_funct)
                    7'd1 : begin // W_FETCH
                        start_w_o <= 1;
                        dma_src_addr_o <= core_cmd_rs1;
                        dma_length_o   <= core_cmd_rs2[63:32];
                        dma_dst_addr_o <= core_cmd_rs2[31:0];
                    end

                    7'd2 : begin // A_FETCH
                        start_a_o <= 1;
                        dma_src_addr_o <= core_cmd_rs1;
                        dma_length_o   <= core_cmd_rs2[63:32];
                        dma_dst_addr_o <= core_cmd_rs2[31:0];
                    end

                    7'd4 : begin // HOLD
                        cu_hold_o    <= 1;
                    end

                    7'd16 : begin // STOP COMP
                        stop_comp_o  <= 1;
                    end

                    default: begin
                        
                    end
                endcase
            end
        end
    end

endmodule

