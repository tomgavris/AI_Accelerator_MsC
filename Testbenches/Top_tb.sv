`timescale 1ns / 1ps
import pe_pkg::*;

module tb_top();

    // -----------------------------------------------------------------
    // Core Clock and Reset
    // -----------------------------------------------------------------
    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -----------------------------------------------------------------
    // RoCC Command Interface
    // -----------------------------------------------------------------
    logic        core_cmd_valid = 1'b0;
    logic [6:0]  core_cmd_funct = '0;
    logic [6:0]  core_cmd_inst_opcode_i = 7'b0001011;
    logic [4:0]  core_cmd_inst_rs1_i    = 5'd10;
    logic        core_cmd_inst_xs1_i    = 1'b1;
    logic [63:0] core_cmd_rs1           = '0;
    logic [4:0]  core_cmd_inst_rs2_i    = 5'd11;
    logic        core_cmd_inst_xs2_i    = 1'b1;
    logic [63:0] core_cmd_rs2           = '0;
    logic        busy = 1'b0;
    logic        core_cmd_ready_o;

    // -----------------------------------------------------------------
    // AXI Interfaces
    // -----------------------------------------------------------------
    AXI4ReadIntf  AxiReadIntf();
    AXI4WriteIntf AxiWriteIntf();

    top dut (
        .clk(clk), .rst(rst),
        .core_cmd_valid(core_cmd_valid),
        .core_cmd_funct(core_cmd_funct),
        .core_cmd_inst_opcode_i(core_cmd_inst_opcode_i),
        .core_cmd_inst_rs1_i(core_cmd_inst_rs1_i),
        .core_cmd_inst_xs1_i(core_cmd_inst_xs1_i),
        .core_cmd_rs1(core_cmd_rs1),
        .core_cmd_inst_rs2_i(core_cmd_inst_rs2_i),
        .core_cmd_inst_xs2_i(core_cmd_inst_xs2_i),
        .core_cmd_rs2(core_cmd_rs2),
        .busy(busy),
        .AxiReadIntf(AxiReadIntf),
        .AxiWriteIntf(AxiWriteIntf),
        .core_cmd_ready_o(core_cmd_ready_o)
    );

    // -----------------------------------------------------------------
    // Simulated L2. Sized to cover weight source, activation source
    // (all K_TILE tiles' worth), and the store destination region.
    // NOTE: this is large (512KB) because a full K_TILE=64 autonomous
    // run genuinely needs that much source data -- not a mistake.
    // -----------------------------------------------------------------
    localparam int MEM_BYTES = 32'h0008_0000; // 512KB
    logic [7:0] sys_memory [0:MEM_BYTES-1];

    localparam logic [31:0] WEIGHT_SRC_ADDR = 32'h0001_0000;
    localparam logic [31:0] ACT_SRC_BASE    = 32'h0002_0000;
    localparam logic [31:0] STORE_DST_ADDR  = 32'h0000_0000;

    localparam int RAW_TOTAL = M*N*OP*K_TILE;
    localparam int SHIFTED   = RAW_TOTAL >>> (P_DATA_WIDTH-DATA_WIDTH);
    localparam logic signed [7:0] EXPECTED_BYTE = 
        (SHIFTED > 127)  ? 8'sd127 :
        (SHIFTED < -128) ? -8'sd128 : 
                        SHIFTED[7:0];


    // Exact byte counts this design actually needs, derived the same
    // way ACT_TILE_BYTES/STORE_BYTES are derived inside mem_fsm --
    // kept local here so the testbench doesn't silently drift from
    // mem_fsm's own math if pe_pkg parameters change.
    localparam int WEIGHT_FETCH_BYTES = M * (M*N*N*OP*DATA_WIDTH/8);          // 2048
    localparam int ACT_TOTAL_BYTES    = K_TILE * (BATCH_SIZE*M*N*OP*DATA_WIDTH/8); // 262144
    localparam int STORE_TOTAL_BYTES  = (BATCH_SIZE*M*N*DATA_WIDTH)/8;        // 2048

    // Expected quantized output byte, derived by hand from DP/DPPE math
    // for the all-ones weight/activation pattern (see chat writeup).

    // -----------------------------------------------------------------
    // AXI4 Read Slave -- 64-bit beats, matching Reader.sv's hardcoded
    // ARSIZE=3'b011. AxiPkg's RDATA field is declared SRAM_WIDTH bits
    // (128), wider than what Reader actually transfers per beat; only
    // the low 64 bits are meaningful here, matching what Reader/concat
    // actually consume. Upper bits left at 0 -- not modeled further.
    // -----------------------------------------------------------------
    logic [31:0] read_addr;
    logic [7:0]  read_len;

    always_ff @(posedge clk) begin
        if (rst) begin
            AxiReadIntf.RdAddrReady <= 1'b0;
            AxiReadIntf.RdDataValid <= 1'b0;
            AxiReadIntf.RdDataPayload.RDATA <= '0;
            AxiReadIntf.RdDataPayload.RRESP <= '0;
            AxiReadIntf.RdDataPayload.RID   <= '0;
            read_addr <= '0;
            read_len  <= '0;
        end else begin
            if (AxiReadIntf.RdAddrValid && !AxiReadIntf.RdAddrReady) begin
                AxiReadIntf.RdAddrReady <= 1'b1;
                read_addr <= AxiReadIntf.RdAddrPayload.ARADDR;
                read_len  <= AxiReadIntf.RdAddrPayload.ARLEN;
            end else if (AxiReadIntf.RdAddrReady) begin
                AxiReadIntf.RdAddrReady <= 1'b0;
            end

            if (AxiReadIntf.RdAddrReady && AxiReadIntf.RdAddrValid) begin
                AxiReadIntf.RdDataValid <= 1'b1;
            end else if (AxiReadIntf.RdDataValid && AxiReadIntf.RdDataReady) begin
                if (read_len == 8'd0) begin
                    AxiReadIntf.RdDataValid <= 1'b0;
                end else begin
                    read_len  <= read_len - 8'd1;
                    read_addr <= read_addr + 32'd8;
                end
            end

            AxiReadIntf.RdDataPayload.RDATA[63:0] <= {
                sys_memory[read_addr+7], sys_memory[read_addr+6],
                sys_memory[read_addr+5], sys_memory[read_addr+4],
                sys_memory[read_addr+3], sys_memory[read_addr+2],
                sys_memory[read_addr+1], sys_memory[read_addr]
            };
        end
    end

    assign AxiReadIntf.RdDataPayload.RLAST =
        AxiReadIntf.RdDataValid && (read_len == 8'd0);

    // -----------------------------------------------------------------
    // AXI4 Write Slave -- 64-bit beats
    // -----------------------------------------------------------------
    logic [31:0] write_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            AxiWriteIntf.WrAddrReady <= 1'b0;
            AxiWriteIntf.WrDataReady <= 1'b0;
            AxiWriteIntf.WrRespValid <= 1'b0;
            AxiWriteIntf.WrRespPayload.BRESP <= '0;
            AxiWriteIntf.WrRespPayload.BID   <= '0;
            write_addr <= '0;
        end else begin
            if (AxiWriteIntf.WrAddrValid && !AxiWriteIntf.WrAddrReady) begin
                AxiWriteIntf.WrAddrReady <= 1'b1;
                write_addr <= AxiWriteIntf.WrAddrPayload.AWADDR;
            end else if (AxiWriteIntf.WrAddrReady) begin
                AxiWriteIntf.WrAddrReady <= 1'b0;
            end

            if (AxiWriteIntf.WrAddrReady && AxiWriteIntf.WrAddrValid) begin
                AxiWriteIntf.WrDataReady <= 1'b1;
            end else if (AxiWriteIntf.WrDataValid && AxiWriteIntf.WrDataReady) begin
                sys_memory[write_addr]   <= AxiWriteIntf.WrDataPayload.WDATA[7:0];
                sys_memory[write_addr+1] <= AxiWriteIntf.WrDataPayload.WDATA[15:8];
                sys_memory[write_addr+2] <= AxiWriteIntf.WrDataPayload.WDATA[23:16];
                sys_memory[write_addr+3] <= AxiWriteIntf.WrDataPayload.WDATA[31:24];
                sys_memory[write_addr+4] <= AxiWriteIntf.WrDataPayload.WDATA[39:32];
                sys_memory[write_addr+5] <= AxiWriteIntf.WrDataPayload.WDATA[47:40];
                sys_memory[write_addr+6] <= AxiWriteIntf.WrDataPayload.WDATA[55:48];
                sys_memory[write_addr+7] <= AxiWriteIntf.WrDataPayload.WDATA[63:56];
                write_addr <= write_addr + 32'd8;

                if (AxiWriteIntf.WrDataPayload.WLAST) begin
                    AxiWriteIntf.WrDataReady <= 1'b0;
                    AxiWriteIntf.WrRespValid <= 1'b1;
                end
            end

            if (AxiWriteIntf.WrRespValid && AxiWriteIntf.WrRespReady) begin
                AxiWriteIntf.WrRespValid <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------
    // RoCC Command Task
    // -----------------------------------------------------------------
    task automatic send_rocc_cmd(input [6:0] funct, input [63:0] rs1, input [63:0] rs2);
        begin
            @(posedge clk);
            while (!core_cmd_ready_o) @(posedge clk);
            core_cmd_valid <= 1'b1;
            core_cmd_funct <= funct;
            core_cmd_rs1   <= rs1;
            core_cmd_rs2   <= rs2;
            @(posedge clk);
            core_cmd_valid <= 1'b0;
        end
    endtask

    task automatic dump_diagnostics();
        begin
            $display("---- DIAGNOSTIC DUMP @ %0t ----", $time);
            $display("  mem_fsm.curr_state   = %0d  comp_hold=%0b", dut.mem_fsm_inst.curr_state, dut.mem_fsm_inst.comp_hold);
            $display("  dp_fsm.curr_state    = %0d  in=%0d out=%0d k_tile=%0d",
                    dut.dp_fsm_inst.curr_state, dut.dp_fsm_inst.in_count,
                    dut.dp_fsm_inst.out_count, dut.dp_fsm_inst.k_tile_count);
            $display("  Controller.state (rd/wr split) = %0d",  dut.DMA_inst.controller_inst.state);
            $display("  write_splitter.state = %0d  rem_bytes=%0d cur_addr=%0h",
                    dut.DMA_inst.controller_inst.write_splitter.state,
                    dut.DMA_inst.controller_inst.write_splitter.rem_bytes,
                    dut.DMA_inst.controller_inst.write_splitter.cur_addr);
            $display("  Writer.state = %0d", dut.DMA_inst.data_mover_inst.writer_inst.state);
            $display("  AxiWriteIntf AW V/R = %0b/%0b  W V/R = %0b/%0b  B V/R = %0b/%0b",
                    AxiWriteIntf.WrAddrValid, AxiWriteIntf.WrAddrReady,
                    AxiWriteIntf.WrDataValid, AxiWriteIntf.WrDataReady,
                    AxiWriteIntf.WrRespValid, AxiWriteIntf.WrRespReady);
            $display("  acc_valid_wire=%0b dma_ready_wire=%0b dma_acc_ready_out=%0b",
                    dut.acc_valid_wire, dut.dma_ready_wire, dut.dma_acc_ready_out);
            $display("  acc.valid_o=%0b drain_active=%0b all_sent=%0b drain_addr=%0d",
                    dut.accumulator_inst.valid_o, dut.accumulator_inst.drain_active,
                    dut.accumulator_inst.all_sent, dut.accumulator_inst.drain_addr);
            $display("  serializer.state=%0d chunk_count=%0d valid_i=%0b",
                    dut.serializer_inst.state, dut.serializer_inst.chunk_count,
                    dut.serializer_inst.valid_i);
            $display("--------------------------------");
        end
    endtask

    task automatic monitor_post_compute();
        forever begin
            @(posedge clk);
            if (dut.mem_fsm_inst.curr_state >= 6) begin // STORE_REQ or STORE_WAIT
                $display("[%0t] STORE: mem_fsm=%0d dp_fsm=%0d in=%0d out=%0d | write_splitter=%0d Writer=%0d AW=%0b/%0b W=%0b/%0b",
                    $time, dut.mem_fsm_inst.curr_state, dut.dp_fsm_inst.curr_state,
                    dut.dp_fsm_inst.in_count, dut.dp_fsm_inst.out_count,
                    dut.DMA_inst.controller_inst.write_splitter.state,
                    dut.DMA_inst.data_mover_inst.writer_inst.state,
                    AxiWriteIntf.WrAddrValid, AxiWriteIntf.WrAddrReady,
                    AxiWriteIntf.WrDataValid, AxiWriteIntf.WrDataReady);
            end
        end
    endtask

    task automatic wait_for_busy_episode(input string label, input int max_cycles);
        int cyc = 0;
        begin
            while (core_cmd_ready_o && cyc < max_cycles) begin
                @(posedge clk); cyc++;
            end
            while (!core_cmd_ready_o && cyc < max_cycles) begin
                @(posedge clk); cyc++;
            end
            if (cyc >= max_cycles) begin
                $display("[%0t] TIMEOUT in wait_for_busy_episode(%s) after %0d cycles", $time, label, max_cycles);
                dump_diagnostics();
                $finish;
            end
        end
    endtask

    task automatic monitor_dp_progress();
        forever begin
            @(posedge clk);
            if (dut.dp_fsm_inst.curr_state == 2) begin // COMP
                $display("[%0t] COMP: in_count=%0d out_count=%0d k_tile=%0d sa_valid=%0b a_sp_state=%0b tile_idx=%0d comp_hold=%0b",
                    $time,
                    dut.dp_fsm_inst.in_count,
                    dut.dp_fsm_inst.out_count,
                    dut.dp_fsm_inst.k_tile_count,
                    dut.sa_acc_handshake,
                    dut.a_sp_state,
                    dut.mem_fsm_inst.tile_idx,
                    dut.mem_fsm_inst.comp_hold);
            end
        end
    endtask

    integer start_comp_count = 0;
    always @(posedge clk) begin
        if (dut.start_comp) begin
            start_comp_count++;
            $display("[%0t] start_comp pulse #%0d -- mem_fsm.tile_idx=%0d dp_fsm.k_tile_count=%0d",
                    $time, start_comp_count, dut.mem_fsm_inst.tile_idx, dut.dp_fsm_inst.k_tile_count);
        end
    end

    // ================= X-origin watcher =================
    logic x_w, x_a, x_sk, x_ps, x_ds, x_ad, x_si, x_dd;

    always @(posedge clk) begin
        if (rst) begin
            x_w <= 1'b0; x_a  <= 1'b0; x_sk <= 1'b0; x_ps <= 1'b0;
            x_ds<= 1'b0; x_ad <= 1'b0; x_si <= 1'b0; x_dd <= 1'b0;
        end else begin
            if (!x_w  && $isunknown(dut.weights))       begin $display("[%0t] FIRST X: weights (weights_sp out)", $time);   x_w  <= 1'b1; end
            if (!x_a  && $isunknown(dut.activations))   begin $display("[%0t] FIRST X: activations (act_sp out)", $time);   x_a  <= 1'b1; end
            if (!x_sk && $isunknown(dut.skewed_data))   begin $display("[%0t] FIRST X: skewed_data (into SA)", $time);      x_sk <= 1'b1; end
            if (!x_ps && $isunknown(dut.sa_results))    begin $display("[%0t] FIRST X: sa_parsum (SA out)", $time);         x_ps <= 1'b1; end
            if (!x_ds && $isunknown(dut.acc_results_i)) begin $display("[%0t] FIRST X: acc_results_i (post-deskew)", $time);x_ds <= 1'b1; end
            if (!x_ad && $isunknown(dut.acc_data))      begin $display("[%0t] FIRST X: acc_data (acc out)", $time);         x_ad <= 1'b1; end
            if (!x_si && $isunknown(dut.serial_i))      begin $display("[%0t] FIRST X: serial_i (post-quant)", $time);      x_si <= 1'b1; end
            if (!x_dd && $isunknown(dut.dma_acc_data))  begin $display("[%0t] FIRST X: dma_acc_data (into DMA)", $time);    x_dd <= 1'b1; end
        end
    end

    // ================= Accumulator write coverage =================
    integer wr_hits [0:255];
    integer cov_idx;

    initial begin
        for (cov_idx = 0; cov_idx < 256; cov_idx = cov_idx + 1) wr_hits[cov_idx] = 0;
    end

    always @(posedge clk) begin
        if (!rst && dut.accumulator_inst.valid_reg) begin
            $display("[%0t] WR addr=%0d idx_in_tile=%0d db_state=%0b op_reg=%0b k_tile=%0d flip=%0b k_inc=%0b k_clr=%0b res_rdy=%0b lane3=%0h",
                $time,
                dut.accumulator_inst.wr_add_reg,
                dut.accumulator_inst.wr_add_reg,          // same value, just for clarity vs BATCH_SIZE-1
                dut.accumulator_inst.double_buffer_i.state,
                dut.accumulator_inst.op_reg,
                dut.dp_fsm_inst.k_tile_count,
                dut.dp_fsm_inst.acc_state_flip,
                dut.dp_fsm_inst.k_increase,
                dut.dp_fsm_inst.k_clear,
                dut.dp_fsm_inst.results_ready_o,
                dut.accumulator_inst.acc_res_w[47:32]);   // just address-3's own 16-bit lane, not the whole word
        end
    end

    // In tb_top, module-level:
    always @(posedge clk) begin
        if (!rst && dut.acc_valid_wire) begin
            $display("[%0t] SERIALIZER OUT beat: data=%h", $time, dut.dma_acc_data);
        end
    end

    always @(posedge clk) begin
        if (!rst && dut.mem_fsm_inst.curr_state == 7 /*STORE_WAIT*/ &&
            dut.accumulator_inst.drain_addr == BATCH_SIZE-1 &&
            dut.accumulator_inst.valid_o) begin
            $display("[%0t] DRAIN READ addr=%0d data=%0d (0x%0h)",
                $time, dut.accumulator_inst.drain_addr,
                dut.accumulator_inst.acc_o, dut.accumulator_inst.acc_o);
        end
    end

    always @(posedge clk) begin
        if (!rst && AxiWriteIntf.WrDataValid && AxiWriteIntf.WrDataReady) begin
            $display("[%0t] L2 WRITE beat: addr=%0h data=%h wlast=%0b",
                $time, write_addr, AxiWriteIntf.WrDataPayload.WDATA,
                AxiWriteIntf.WrDataPayload.WLAST);
        end
    end

    // -----------------------------------------------------------------
    // Main Simulation Block
    // -----------------------------------------------------------------
    integer i;
    integer mismatches;

    initial begin
        $display("Starting full-pipeline accelerator simulation (uniform 1s pattern)...");
        rst = 1'b1;

        // Fill only the ranges actually used -- fills the full 262144-byte
        // activation region, so this loop is not fast; expect a real wait
        // at simulation startup before cycle 0 even begins.
        for (i = 0; i < WEIGHT_FETCH_BYTES; i++)
            sys_memory[WEIGHT_SRC_ADDR + i] = 8'h01;
        for (i = 0; i < ACT_TOTAL_BYTES; i++)
            sys_memory[ACT_SRC_BASE + i] = 8'h01;
        for (i = 0; i < STORE_TOTAL_BYTES; i++)
            sys_memory[STORE_DST_ADDR + i] = 8'hFF; // sentinel: "never written"

        #100;
        @(posedge clk);
        rst = 1'b0;
        // fork monitor_dp_progress(); join_none;
        $display("[%0t] Reset released.", $time);

        // W_FETCH: funct=1, rs1=weight src addr, rs2={length, dst(unused)}
        send_rocc_cmd(7'd1, {32'd0, WEIGHT_SRC_ADDR}, {WEIGHT_FETCH_BYTES[31:0], 32'd0});
        wait_for_busy_episode("W_FETCH", 5000);
        $display("[%0t] W_FETCH complete.", $time);

        // A_FETCH: funct=2, rs1=activation src BASE addr (tile 0),
        // rs2={length(unused by mem_fsm's internal tiling -- placeholder), dst=store addr}.
        // mem_fsm internally loops K_TILE times from this base address;
        // the length field here is ignored by the autonomous fetch loop.
        send_rocc_cmd(7'd2, {32'd0, ACT_SRC_BASE}, {32'd0, STORE_DST_ADDR});

        // This covers ALL K_TILE fetch+compute tiles in one continuous
        // busy episode -- expect this to be the long one.
        wait_for_busy_episode("A_FETCH + all K_TILE compute", 350000);
        $display("[%0t] All-tile fetch + compute complete.", $time);

        // Autonomous STORE, triggered internally once results_ready fires
        wait_for_busy_episode("STORE (autonomous)", 5000);
        $display("[%0t] Store complete.", $time);

        // Self-check: every byte of the store region should be EXPECTED_BYTE
        mismatches = 0;
        for (i = 0; i < STORE_TOTAL_BYTES; i++) begin
            if (sys_memory[STORE_DST_ADDR + i] !== EXPECTED_BYTE) begin
                if (mismatches < 10) begin
                    $display("  MISMATCH at byte %0d: got %0d (0x%0h), expected %0d",
                              i, $signed(sys_memory[STORE_DST_ADDR+i]),
                              sys_memory[STORE_DST_ADDR+i], EXPECTED_BYTE);
                end
                mismatches++;
            end
        end

        if (mismatches == 0) begin
            $display("========================================");
            $display("   SUCCESS: all %0d output bytes == %0d", STORE_TOTAL_BYTES, EXPECTED_BYTE);
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   FAILED: %0d / %0d bytes mismatched", mismatches, STORE_TOTAL_BYTES);
            $display("========================================");
        end
        for (cov_idx = 0; cov_idx < BATCH_SIZE; cov_idx = cov_idx + 1)
            if (wr_hits[cov_idx] != K_TILE)
                $display("COVERAGE GAP: addr %0d written %0d times (expected %0d)",
                          cov_idx, wr_hits[cov_idx], K_TILE);
        $finish;
    end

endmodule