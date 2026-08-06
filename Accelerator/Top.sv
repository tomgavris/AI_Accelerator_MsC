import pe_pkg::*;

module top (
    input  logic clk, rst,

    // RoCC control signals
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
    input  logic        busy,

    AXI4ReadIntf.Master  AxiReadIntf,
    AXI4WriteIntf.Master AxiWriteIntf,
    output logic         core_cmd_ready_o
);
    
    logic        start_w, start_a, stop_comp, cu_hold;
    
    // RoCC Translator to DMA
    logic [63:0] dma_src_addr;
    logic [31:0] dma_length, dma_dst_addr;

    // Mem FSM to DP FSM
    logic        start_w_load, start_comp;
    
    // DP FSM to Mem FSM
    logic        results_ready;

    // Mem FSM to DMA
    logic        dma_go_pulse, dma_mode;        
    logic        dma_load_finish, dma_busy; 

    // Control to Scratchpad
    logic sp_rd, sp_wr, sp_state;
    logic [PARTITIONS-1:0] sp_wr_en_onehot; 
    
    // DMA to Scratchpad
    logic [63:0]          raw_dma_data;
    logic                 raw_dma_valid;
    logic [SRAM_WIDTH-1:0] sp_dma_data;

    // Memory Counters 
    logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_wr_add; 
    logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_rd_add;
    logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_rd_skewed;
    
    
    logic sp_wr_clear;
    assign sp_wr_clear = dma_go_pulse & ~dma_mode; 
    
    // Scratchpad to Systolic Array
    logic        sp_ready, sp_valid;
    logic signed [PARTITIONS-1:0][DATA_WIDTH-1:0] sp_o;

    // Control to Accumulator
    logic acc_op, acc_hold, acc_state, acc_rd;

    logic [$clog2(ACC_SIZE)-1:0] acc_wr_addr;
    logic [$clog2(ACC_SIZE)-1:0] acc_rd_addr;

    // DP FSM to Systolic Array
    logic        sa_wr_wire, sa_comp_wire;

    // Handshakes: SA and Accumulator
    logic        sa_acc_handshake; 
    
    // Systolic Array to Accumulator
    logic signed [M-1:0][N-1:0][P_DATA_WIDTH-1:0] sa_results;
    logic signed [M-1:0][N-1:0][P_DATA_WIDTH-1:0] acc_results_i;
    
    // Output Datapath Wires 
    logic        acc_valid;
    logic        acc_valid_wire;
    logic        dma_ready_wire;
    logic        dma_acc_ready_out;
    
    logic signed [(M*N*P_DATA_WIDTH)-1:0] acc_data;     
    logic signed [(M*N*DATA_WIDTH)-1:0]   serial_i;     
    logic [63:0]                          dma_acc_data; 

    // Skewing Wires
    logic                                                               no_skew_wire;
    logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                 sa_i_wire;
    logic signed [PARTITIONS-1:0][CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]  unskewed_data;
    logic signed [CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]          skewed_data;

    assign sa_i_wire = no_skew_wire ? skewed_data : unskewed_data;

    // Valid Signal Delay Pipeline
    localparam VALID_DELAY = M - 1;
    logic [VALID_DELAY-1:0] handshake_shift_reg;
    logic                   delayed_sa_acc_handshake;

    always_ff @(posedge clk) begin
        if (rst) begin
            handshake_shift_reg <= '0;
        end else begin
            handshake_shift_reg[0] <= sa_acc_handshake;

            for (int i = 1; i < VALID_DELAY; i++) begin
                handshake_shift_reg[i] <= handshake_shift_reg[i-1];
            end
        end
    end

    assign delayed_sa_acc_handshake = handshake_shift_reg[VALID_DELAY-1];

    // Control / Top-Level Modules
    mem_fsm mem_fsm_inst (
        .clk(clk), 
        .rst(rst),
        .start_w_i(start_w), 
        .start_a_i(start_a),                   
        .results_ready_i(results_ready),                     
        .dma_load_finish_i(dma_load_finish),
        .sp_state_o(sp_state),
        .start_w_load_o(start_w_load), 
        .start_comp_o(start_comp),          
        .acc_rd(acc_rd),                            
        .dma_go_pulse(dma_go_pulse),
        .dma_mode_o(dma_mode),                      
        .dma_busy_o(dma_busy)              
    );

    dp_fsm dp_fsm_inst (
        .clk(clk), 
        .rst(rst),
        .stop_comp_i(stop_comp), 
        .cu_hold_i(cu_hold),              
        .start_w_load_i(start_w_load),
        .start_comp_i(start_comp),        
        .sa_valid_i(sa_acc_handshake), 
        .no_skew(no_skew_wire),
        .results_ready_o(results_ready),
        .sp_rd_o(sp_rd),                
        .acc_op_o(acc_op), 
        .acc_hold_o(acc_hold), 
        .acc_state_o(acc_state),       
        .sa_wr_o(sa_wr_wire), 
        .sa_comp_e_o(sa_comp_wire),
        .out_count(acc_wr_addr)
    );

    
    // Data Path Core
    DPPE_SA DPPE_SA_inst (
        .sa_a_i(sa_i_wire),
        .clk(clk), 
        .sa_rst(rst), 
        .sa_wr_e(sa_wr_wire), 
        .sa_comp_e(sa_comp_wire),
        .sa_w_i('0), // Will change for multiple tiles
        .sa_valid_o(sa_acc_handshake),
        .sa_a_o(), 
        .sa_parsum_o(sa_results) 
    );

    accumulator accumulator_inst (
        .clk(clk), 
        .rst(rst), 
        .op(acc_op), 
        .hold(acc_hold), 
        .state(acc_state),
        .valid_i(delayed_sa_acc_handshake), 
        .acc_rd(acc_rd),
        .acc_wr_addr(acc_wr_addr), 
        .acc_rd_addr(acc_wr_addr), 
        .acc_i(acc_results_i),
        .valid_o(acc_valid),       
        .acc_ready(),              
        .acc_o(acc_data)           
    );

    DMA DMA_inst (
        .ACLK(clk),
        .ARESETn(~rst),
        .src_addr(dma_src_addr[31:0]),
        .dst_addr(dma_dst_addr),
        .length(dma_length),
        .go_pulse(dma_go_pulse), 
        .dma_mode_i(dma_mode), 
        .acc_data_i(dma_acc_data), 
        .acc_valid_i(acc_valid_wire),
        .acc_ready_o(dma_acc_ready_out),
        .sp_ready_i(1'b1), 
        .sp_data_o(raw_dma_data),
        .sp_valid_o(raw_dma_valid),
        .busy(), // Left unconnected so mem_fsm has exclusive control
        .dma_load_finish_o(dma_load_finish),
        .AxiReadIntf(AxiReadIntf),
        .AxiWriteIntf(AxiWriteIntf)
    );
    
    BANKED_SP BANKED_SP_inst (
        .clk(clk), 
        .rst(rst), 
        .sp_i({PARTITIONS{sp_dma_data}}), 
        .sp_rd_i(), 
        .sp_wr_i(sp_wr_en_onehot),        
        .sp_state_i(sp_state),  
        .sp_wr_add(sp_wr_add), 
        .sp_rd_add(sp_rd_skewed), 
        .sp_ready_o(), 
        .sp_valid_o(), 
        .sp_o(unskewed_data)
    );

    
    sp_wr_counter sp_wr_counter_inst (
        .clk(clk),
        .rst(rst),
        .sp_wr_i(sp_wr),
        .clear_i(sp_wr_clear),
        .sp_wr_add_o(sp_wr_add),
        .sp_wr_en_o(sp_wr_en_onehot)
    );

    RoCCTran RoCCTran_inst (
        .clk(clk), 
        .rst(rst), 
        .core_cmd_valid(core_cmd_valid), 
        .core_cmd_funct(core_cmd_funct),
        .core_cmd_inst_opcode_i(core_cmd_inst_opcode_i),
        .core_cmd_inst_rs1_i(core_cmd_inst_rs1_i),
        .core_cmd_inst_xs1_i(core_cmd_inst_xs1_i),  
        .core_cmd_rs1(core_cmd_rs1),
        .core_cmd_inst_rs2_i(core_cmd_inst_rs2_i),
        .core_cmd_inst_xs2_i(core_cmd_inst_xs2_i),  
        .core_cmd_rs2(core_cmd_rs2),
        .dma_busy_i(dma_busy),
        .core_cmd_ready_o(core_cmd_ready_o),
        .dma_src_addr_o(dma_src_addr),
        .dma_length_o(dma_length),
        .dma_dst_addr_o(dma_dst_addr),
        .cu_hold_o(cu_hold), 
        .stop_comp_o(stop_comp),
        .start_w_o(start_w), 
        .start_a_o(start_a)                 
    );

    // Skewing / Deskewing
    genvar part;
    generate
        for(part = 0; part < PARTITIONS; part++) begin
            skewing_mod skewing_mod_inst(
                .skew_mod_i(unskewed_data[part]),
                .clk(clk), 
                .rst(rst),
                .skew_mod_o(skewed_data[part*CONC_ADD +: CONC_ADD])
            );
        end
    endgenerate

    deskewing_mod deskewing_mod_inst(
        .deskew_mod_i(sa_results),
        .clk(clk), 
        .rst(rst),
        .deskew_mod_o(acc_results_i)
    );

    Read_skew Read_skew_inst (
        .clk(clk), 
        .rst(rst),
        .sp_rd_i(sp_rd),     
        .sp_rd_o(sp_rd_skewed), 
        .sp_rd_add_o(sp_rd_add)
    );

    // Output Datapath 
    Quantizer Quantizer_inst (
        .quantize_i(acc_data),
        .quantize_o(serial_i)
    );

    generate
        if (M * N * DATA_WIDTH == 64) begin
            // SCENARIO 1: M * N * DATA_WIDTH == 64
            // Bypass the Serializer module
            assign dma_acc_data   = serial_i;
            assign acc_valid_wire = acc_valid;
            assign dma_ready_wire = dma_acc_ready_out;
            
        end else begin
            // SCENARIO 2: M * N * DATA_WIDTH > 64
            serializer serializer_inst (
                .clk(clk), 
                .rst(rst),
                .valid_i(acc_valid),  
                .data_i(serial_i),
                .ready_o(dma_ready_wire),  
                .dma_ready_i(dma_acc_ready_out), 
                .valid_o(acc_valid_wire),     
                .data_o(dma_acc_data)
            );
        end
    endgenerate

    generate
        if (SRAM_WIDTH == 64) begin
            // SCENARIO 1: SRAM_WIDTH == 64
            // Bypass the Concat module
            assign sp_dma_data = raw_dma_data;
            assign sp_wr       = raw_dma_valid;
            
        end else begin
            // SCENARIO 2: SRAM_WIDTH > 64 
            // Use Concat 
            concat concat_inst (
                .concat_i(raw_dma_data),
                .clk(clk), 
                .rst(rst),
                .enable(raw_dma_valid), 
                .valid_o(sp_wr),
                .concat_o(sp_dma_data)
            );
        end
    endgenerate

endmodule