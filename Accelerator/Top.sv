module top #( 
    // --- INDEPENDENT VARIABLES ---
    // Passed in from the Chisel BlackBox
    parameter int N = 4,
    parameter int M = 8,
    parameter int OP = 2,
    parameter int DATA_WIDTH = 8,
    parameter int P_DATA_WIDTH = 16,
    parameter int PARTITIONS = 4,
    parameter int BATCH_SIZE = 8,
    parameter int K_TILE = 8,

    // --- DEPENDENT VARIABLES ---
    // Calculated automatically
    parameter int CONC_ADD       = M / PARTITIONS,
    parameter int SRAM_WIDTH     = CONC_ADD * N * OP * DATA_WIDTH,
    parameter int SP_SIZE        = 2048,
    parameter int SRAM_SIZE      = SP_SIZE / PARTITIONS,
    parameter int WEIGHT_SP_SIZE = M,
    parameter int ACC_SIZE       = BATCH_SIZE
)(
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
    logic        weight_fetch;
    logic [31:0] seq_src_addr, seq_length, seq_dst_addr;

    // Control to Scratchpads
    logic                   a_sp_state, w_sp_state;
    logic                   sp_rd, w_sp_rd, w_sp_rd_o;
    logic                   a_sp_wr, w_sp_wr;
    logic [PARTITIONS-1:0]  sp_wr_en_onehot; 
    logic                   w_sp_wr_en;
    logic                   a_SP_wr_clr;
    
    // Data: DMA to Concat to Scratchpads
    logic [63:0]                     raw_dma_data;
    logic                            w_raw_dma_valid, a_raw_dma_valid;
    logic [SRAM_WIDTH-1:0]           sp_dma_data;
    logic [M*N*N*OP*DATA_WIDTH-1:0]  w_sp_data;

    // Memory Counters 
    logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_wr_add; 
    logic [PARTITIONS-1:0][$clog2(SRAM_SIZE)-1:0] sp_rd_add;
    logic [PARTITIONS-1:0]                        sp_rd_skewed;
    
    logic [$clog2(WEIGHT_SP_SIZE)-1:0]            w_sp_wr_add;
    logic [$clog2(WEIGHT_SP_SIZE)-1:0]            w_sp_rd_add;

    // Control to Accumulator
    logic acc_op, acc_hold, acc_state, acc_rd;
    logic [$clog2(ACC_SIZE)-1:0] acc_rd_add;
    logic [$clog2(ACC_SIZE)-1:0] acc_wr_addr;

    // DP FSM to Systolic Array
    logic        sa_wr_wire, sa_comp_wire;
    logic        dp_busy_wire;

    // Handshakes: SA and Accumulator
    logic        sa_acc_handshake; 
    
    // Systolic Array Datapath Wires
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
    logic                                                                       no_skew_wire;
    logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                         sa_i_wire;
    logic signed [M-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                         skewed_data;

    // ===========================
    // Valid Signal Delay Pipeline
    // ===========================

    
    // delayed_sa_acc_handshake


    localparam VALID_DELAY = M - 1;
    logic [VALID_DELAY-1:0] handshake_shift_reg;
    logic                   delayed_sa_acc_handshake;

    logic [PARTITIONS-1:0][CONC_ADD-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]   activations;
    logic [M-1:0][N-1:0][N-1:0][OP-1:0][DATA_WIDTH-1:0]                   weights;

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

    logic [VALID_DELAY-1:0][$clog2(ACC_SIZE)-1:0]  wr_shift_reg;
    logic [$clog2(ACC_SIZE)-1:0]                   delayed_acc_wr_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_shift_reg <= '0;
        end else begin
            wr_shift_reg[0] <= acc_wr_addr;

            for (int i = 1; i < VALID_DELAY; i++) begin
                wr_shift_reg[i] <= wr_shift_reg[i-1];
            end
        end
    end

    assign delayed_acc_wr_addr = wr_shift_reg[VALID_DELAY-1];

    // delayed_acc_op
    logic [VALID_DELAY-1:0] op_shift_reg;
    logic                   delayed_acc_op;

    always_ff @(posedge clk) begin
        if (rst) begin
            op_shift_reg <= '0;
        end else begin
            op_shift_reg[0] <= acc_op;
            for (int i = 1; i < VALID_DELAY; i++) begin
                op_shift_reg[i] <= op_shift_reg[i-1];
            end
        end
    end

    assign delayed_acc_op = op_shift_reg[VALID_DELAY-1];

    // delayed_results_ready
    localparam RESULTS_DELAY = VALID_DELAY + 3;
    logic [RESULTS_DELAY-1:0] results_ready_shift_reg;
    logic                     delayed_results_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            results_ready_shift_reg <= '0;
        end else begin
            results_ready_shift_reg[0] <= results_ready;
            for (int i = 1; i < RESULTS_DELAY; i++) begin
                results_ready_shift_reg[i] <= results_ready_shift_reg[i-1];
            end
        end
    end

    assign delayed_results_ready = results_ready_shift_reg[RESULTS_DELAY-1];

    //============================
    // Module instantiation
    //============================
    mem_fsm #(.BATCH_SIZE(BATCH_SIZE), .K_TILE(K_TILE)) mem_fsm_inst (
        .clk(clk), 
        .rst(rst),
        .start_w_i(start_w), 
        .start_a_i(start_a),
        .results_ready_i(delayed_results_ready), 
        .dma_load_finish_i(dma_load_finish),
        .dp_busy_i(dp_busy_wire),
        .rocc_src_addr_i(dma_src_addr[31:0]), 
        .rocc_length_i(dma_length), 
        .rocc_dst_addr_i(dma_dst_addr),
        .a_sp_state_o(a_sp_state), 
        .w_sp_state_o(w_sp_state), 
        .start_w_load_o(start_w_load), 
        .start_comp_o(start_comp),
        .acc_rd(acc_rd), 
        .a_sp_wr_clr_o(a_sp_wr_clr),
        .weight_fetch_o(weight_fetch),
        .dma_go_pulse(dma_go_pulse), 
        .dma_mode_o(dma_mode), 
        .dma_busy_o(dma_busy),
        .dma_src_addr_o(seq_src_addr), 
        .dma_length_o(seq_length), 
        .dma_dst_addr_o(seq_dst_addr)
    );


    dp_fsm #(
        .M(M),  
        .BATCH_SIZE(BATCH_SIZE), 
        .K_TILE(K_TILE)
    ) dp_fsm_inst (
        .clk(clk), 
        .rst(rst),
        .stop_comp_i(stop_comp), 
        .cu_hold_i(cu_hold),
        .start_w_load_i(start_w_load), 
        .start_comp_i(start_comp),
        .sa_valid_i(sa_acc_handshake), 
        .no_skew(no_skew_wire),
        .results_ready_o(results_ready), 
        .a_sp_rd_o(sp_rd),
        .w_sp_rd_o(w_sp_rd),
        .acc_op_o(acc_op), 
        .acc_hold_o(acc_hold), 
        .acc_state_o(), // acc_state was there beforehand
        .sa_wr_o(sa_wr_wire), 
        .sa_comp_e_o(sa_comp_wire),
        .out_count(acc_wr_addr),
        .dp_busy_o(dp_busy_wire)
    );

    
    // Data Path Core
    DPPE_SA #(.M(M), .N(N), .OP(OP), .DATA_WIDTH(DATA_WIDTH), .P_DATA_WIDTH(P_DATA_WIDTH)) DPPE_SA_inst (
        .sa_a_i(skewed_data),
        .clk(clk), 
        .sa_rst(rst), 
        .sa_wr_e(sa_wr_wire), 
        .sa_comp_e(sa_comp_wire),
        .sa_w_i(weights), 
        .sa_valid_o(sa_acc_handshake),
        .sa_a_o(), 
        .sa_parsum_o(sa_results) 
    );

    accumulator #(.M(M), .N(N), .BATCH_SIZE(BATCH_SIZE), .DATA_WIDTH(DATA_WIDTH), .P_DATA_WIDTH(P_DATA_WIDTH)) accumulator_inst (
        .clk(clk), 
        .rst(rst), 
        .op(delayed_acc_op), 
        .hold(acc_hold), 
        .valid_i(delayed_sa_acc_handshake), 
        .dma_ready_i(dma_ready_wire),
        .acc_rd(acc_rd),
        .acc_wr_addr(delayed_acc_wr_addr), 
        .acc_rd_addr_i(delayed_acc_wr_addr), 
        .acc_i(acc_results_i),
        .valid_o(acc_valid),       
        .acc_ready(),              
        .acc_o(acc_data)           
    );

    DMA DMA_inst (
        .clk(clk), 
        .ARESETn(~rst),
        .src_addr(seq_src_addr[31:0]),
        .dst_addr(seq_dst_addr),
        .length(seq_length),
        .go_pulse(dma_go_pulse), 
        .dma_mode_i(dma_mode),
        .acc_data_i(dma_acc_data), 
        .acc_valid_i(acc_valid_wire),
        .acc_ready_o(dma_acc_ready_out),
        .sp_ready_i(1'b1),
        .weight_fetch_i(weight_fetch),
        .sp_data_o(raw_dma_data), 
        .w_sp_valid_o(w_raw_dma_valid),
        .a_sp_valid_o(a_raw_dma_valid),
        .busy(),
        .dma_load_finish_o(dma_load_finish),
        .AxiReadIntf(AxiReadIntf), 
        .AxiWriteIntf(AxiWriteIntf)
    );
    
    activations_sp #(
        .N(N),
        .M(M),
        .OP(OP),
        .DATA_WIDTH(DATA_WIDTH),
        .PARTITIONS(PARTITIONS),
        .SP_SIZE(SP_SIZE)
        ) activations_sp_inst (
        .clk(clk), 
        .rst(rst), 
        .sp_i({PARTITIONS{sp_dma_data}}), 
        .sp_rd_i(sp_rd_skewed), 
        .sp_wr_i(sp_wr_en_onehot),        
        .sp_state_i(a_sp_state),  
        .sp_wr_add(sp_wr_add), 
        .sp_rd_add(sp_rd_add), 
        .sp_ready_o(), 
        .sp_valid_o(), 
        .sp_o(activations)
    );

    weights_sp #(
        .M(M), 
        .N(N), 
        .OP(OP), 
        .DATA_WIDTH(DATA_WIDTH), 
        .PARTITIONS(PARTITIONS)
        ) weights_sp_inst (
        .clk(clk), 
        .rst(rst), 
        .sp_i(w_sp_data), 
        .sp_rd_i(w_sp_rd_o),  
        .sp_wr_i(w_sp_wr_en),      
        .sp_state_i(w_sp_state), 
        .sp_wr_add(w_sp_wr_add), 
        .sp_rd_add(w_sp_rd_add), 
        .sp_ready_o(), 
        .sp_valid_o(), 
        .sp_o(weights)
    );

    
    a_SP_wr_count #(
        .PARTITIONS(PARTITIONS),
        .SRAM_SIZE(SRAM_SIZE)
    ) a_SP_wr_count_inst (
        .clk(clk),
        .rst(rst),
        .sp_wr_i(a_sp_wr),
        .clear_i(a_sp_wr_clr),
        .sp_wr_add_o(sp_wr_add),
        .sp_wr_en_o(sp_wr_en_onehot)
    );

    w_SP_wr_count #(
        .WEIGHT_SP_SIZE(WEIGHT_SP_SIZE)
    ) w_SP_wr_count_inst (
        .clk(clk),
        .rst(rst),
        .sp_wr_i(w_sp_wr),
        .clear_i(start_w_load), 
        .sp_wr_add_o(w_sp_wr_add),
        .sp_wr_en_o(w_sp_wr_en)
    );

    Read_skew #(
        .PARTITIONS(PARTITIONS),
        .M(M),
        .SP_SIZE(SP_SIZE),
        .CONC_ADD(CONC_ADD),
        .SRAM_SIZE(SRAM_SIZE),
        .WEIGHT_SP_SIZE(WEIGHT_SP_SIZE)
    ) Read_skew_inst (
        .clk(clk), 
        .rst(rst),
        .sp_rd_i(sp_rd),     
        .sp_rd_o(sp_rd_skewed), 
        .sp_rd_add_o(sp_rd_add)
    );

    Weight_sp_rd #(
        .WEIGHT_SP_SIZE(WEIGHT_SP_SIZE)
    ) Weight_sp_rd_inst (
        .clk(clk), 
        .rst(rst),
        .clear_i(start_w_load), 
        .sp_rd_i(w_sp_rd),     
        .sp_rd_o(w_sp_rd_o), 
        .sp_rd_add_o(w_sp_rd_add)
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
            skewing_mod #(
        .CONC_ADD(CONC_ADD),
        .N(N),
        .OP(OP),
        .DATA_WIDTH(DATA_WIDTH)
    ) skewing_mod_inst(
                .skew_mod_i(activations[part]),
                .clk(clk), 
                .rst(rst),
                .skew_mod_o(skewed_data[part*CONC_ADD +: CONC_ADD])
            );
        end
    endgenerate

    deskewing_mod #(
        .M(M),
        .N(N),
        .P_DATA_WIDTH(P_DATA_WIDTH)
    ) deskewing_mod_inst(
        .deskew_mod_i(sa_results),
        .clk(clk), 
        .rst(rst),
        .deskew_mod_o(acc_results_i)
    );

    // Output Datapath 
    Quantizer #(
        .N(N),
        .M(M),
        .DATA_WIDTH(DATA_WIDTH),
        .P_DATA_WIDTH(P_DATA_WIDTH)
    ) Quantizer_inst (
        .quantize_i(acc_data),
        .quantize_o(serial_i)
    );

    serializer #(
        .M(M),
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .IN_WIDTH(M * N * DATA_WIDTH),
        .OUT_WIDTH(64) // Assuming your RoCC/AXI bus remains 64-bit
    ) serializer_inst (
        .clk(clk), 
        .rst(rst),
        .valid_i(acc_valid),  
        .data_i(serial_i),
        .ready_o(dma_ready_wire),  
        .dma_ready_i(dma_acc_ready_out), 
        .valid_o(acc_valid_wire),     
        .data_o(dma_acc_data)
    );
    
    concat #(
        .CONCAT_WIDTH(M * N * N * OP * DATA_WIDTH)
    ) weight_concat_inst (
        .concat_i(raw_dma_data),
        .clk(clk), 
        .rst(rst),
        .enable(w_raw_dma_valid), // From DMA
        .valid_o(w_sp_wr),
        .concat_o(w_sp_data)
    );


    concat #(.CONCAT_WIDTH(SRAM_WIDTH))
        activations_concat_inst (        
        .concat_i(raw_dma_data),
        .clk(clk),                         
        .rst(rst),
        .enable(a_raw_dma_valid), // From DMA
        .valid_o(a_sp_wr),
        .concat_o(sp_dma_data)
    );        

endmodule