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
    // Simulated L2.
    // -----------------------------------------------------------------
    localparam int MEM_BYTES = 32'h0008_0000; // 512KB
    logic [7:0] sys_memory [0:MEM_BYTES-1];

    localparam logic [31:0] WEIGHT_SRC_ADDR = 32'h0001_0000;
    localparam logic [31:0] ACT_SRC_BASE    = 32'h0002_0000;
    localparam logic [31:0] STORE_DST_ADDR  = 32'h0000_0000;

    localparam int OP_SUM = 3;

    integer pulse_num = 0;

    localparam int WEIGHT_FETCH_BYTES    = M * (M*N*N*OP*DATA_WIDTH/8);
    localparam int ACT_TILE_BYTES        = (BATCH_SIZE * M * N * OP * DATA_WIDTH) / 8;
    localparam int ACT_TOTAL_BYTES       = K_TILE * ACT_TILE_BYTES;
    localparam int BYTES_PER_BATCH_ENTRY = (M * N * OP * DATA_WIDTH) / 8;
    localparam int STORE_TOTAL_BYTES     = (BATCH_SIZE*M*N*DATA_WIDTH)/8;
    localparam int BYTES_PER_ADDR        = (M*N*DATA_WIDTH)/8;

    function automatic byte expected_byte(input int b);
        longint raw;
        int shifted;
        raw     = longint'(M) * N * OP_SUM * (4*(b+1)) * K_TILE;
        shifted = raw >>> (P_DATA_WIDTH - DATA_WIDTH);
        if (shifted > 127)       expected_byte = 8'sd127;
        else if (shifted < -128) expected_byte = -8'sd128;
        else                     expected_byte = shifted[7:0];
    endfunction

    // -----------------------------------------------------------------
    // AXI4 Read Slave -- 64-bit beats
    // -----------------------------------------------------------------
    logic [31:0] read_addr;
    logic [7:0]  read_len;

    always_ff @(posedge clk) begin
        if (rst) begin
            AxiReadIntf.RdAddrReady <= 1'b0;
            AxiReadIntf.RdDataValid <= 1'b0;
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
        end
    end

    assign AxiReadIntf.RdDataPayload.RDATA[63:0] = {
        sys_memory[read_addr+7], sys_memory[read_addr+6],
        sys_memory[read_addr+5], sys_memory[read_addr+4],
        sys_memory[read_addr+3], sys_memory[read_addr+2],
        sys_memory[read_addr+1], sys_memory[read_addr]
    };

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

    // ================= Accumulator write coverage =================
    integer wr_hits [0:255];
    integer cov_idx;

    initial begin
        for (cov_idx = 0; cov_idx < 256; cov_idx = cov_idx + 1) wr_hits[cov_idx] = 0;
    end

    integer axi_beat_count = 0;
    always @(posedge clk) begin
        if (rst) begin
            axi_beat_count = 0;
        end else begin
            if (dut.a_raw_dma_valid && AxiReadIntf.RdDataReady) begin
                axi_beat_count++;
            end
            
            if (dut.mem_fsm_inst.curr_state == 3'd4 && dut.dma_load_finish) begin
                $display("[%0t] A_FETCH COMPLETE: TOTAL AXI BEATS THIS TILE = %0d (expected %0d)", 
                         $time, axi_beat_count, ACT_TILE_BYTES/8);
                axi_beat_count = 0; 
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && dut.a_raw_dma_valid) begin 
            $display("[%0t] PRE-CONCAT: raw_dma_data=%0h  AxiReadIntf.RdDataValid=%0b RdDataReady=%0b RDATA=%0h",
                $time, dut.raw_dma_data,
                AxiReadIntf.RdDataValid, AxiReadIntf.RdDataReady,
                AxiReadIntf.RdDataPayload.RDATA);
        end
    end

    always @(posedge clk) begin
        if (!rst && dut.acc_valid_wire) begin
            $display("[%0t] SERIALIZER OUT beat: data=%h", $time, dut.dma_acc_data);
        end
    end

    always @(posedge clk) begin
        if (!rst && AxiWriteIntf.WrDataValid && AxiWriteIntf.WrDataReady) begin
            $display("[%0t] L2 WRITE beat: addr=%0h data=%h wlast=%0b",
                $time, write_addr, AxiWriteIntf.WrDataPayload.WDATA,
                AxiWriteIntf.WrDataPayload.WLAST);
        end
    end

    always @(posedge clk) begin
        if (!rst && dut.sa_comp_wire) begin
            $display("[%0t] SA_IN in_count=%0d | a_sp_state=%0b sp_rd_add[0]=%0d | r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d r7=%0d",
                $time, dut.dp_fsm_inst.in_count, 
                dut.a_sp_state, dut.sp_rd_add[0],
                $signed(dut.skewed_data[0][0][0]), $signed(dut.skewed_data[1][0][0]),
                $signed(dut.skewed_data[2][0][0]), $signed(dut.skewed_data[3][0][0]),
                $signed(dut.skewed_data[4][0][0]), $signed(dut.skewed_data[5][0][0]),
                $signed(dut.skewed_data[6][0][0]), $signed(dut.skewed_data[7][0][0]));
        end
    end

    // -----------------------------------------------------------------
    // Main Simulation Block
    // -----------------------------------------------------------------
    integer i;
    integer mismatches;

    initial begin
        $display("Starting full-pipeline simulation...");
        rst = 1'b1;

        for (i = 0; i < WEIGHT_FETCH_BYTES; i++)
            sys_memory[WEIGHT_SRC_ADDR + i] = (i % 2 == 0) ? 8'h01 : 8'h02;

        for (int k_idx = 0; k_idx < K_TILE; k_idx++) begin
            for (int b_idx = 0; b_idx < BATCH_SIZE; b_idx++) begin
                automatic byte v = 4*(b_idx+1); 
                for (int j_idx = 0; j_idx < BYTES_PER_BATCH_ENTRY; j_idx++)
                    sys_memory[ACT_SRC_BASE + k_idx*ACT_TILE_BYTES
                               + b_idx*BYTES_PER_BATCH_ENTRY + j_idx] = v;
            end
        end

        for (i = 0; i < STORE_TOTAL_BYTES; i++)
            sys_memory[STORE_DST_ADDR + i] = 8'hFF; 

        #100;
        @(posedge clk);
        rst = 1'b0;
        $display("[%0t] Reset released.", $time);

        send_rocc_cmd(7'd1, {32'd0, WEIGHT_SRC_ADDR}, {WEIGHT_FETCH_BYTES[31:0], 32'd0});
        wait_for_busy_episode("W_FETCH", 5000);
        $display("[%0t] W_FETCH complete.", $time);

        send_rocc_cmd(7'd2, {32'd0, ACT_SRC_BASE}, {32'd0, STORE_DST_ADDR});
        wait_for_busy_episode("A_FETCH + all K_TILE compute", 350000);
        $display("[%0t] All-tile fetch + compute complete.", $time);

        wait_for_busy_episode("STORE (autonomous)", 5000);
        $display("[%0t] Store complete.", $time);

        mismatches = 0;
        for (i = 0; i < STORE_TOTAL_BYTES; i++) begin
            automatic int b = i / BYTES_PER_ADDR;
            automatic byte exp = expected_byte(b);
            if (sys_memory[STORE_DST_ADDR + i] !== exp) begin
                if (mismatches < 20) begin
                    $display("  MISMATCH byte %0d (addr %0d): got %0d (0x%0h), expected %0d",
                              i, b, $signed(sys_memory[STORE_DST_ADDR+i]),
                              sys_memory[STORE_DST_ADDR+i], exp);
                end
                mismatches++;
            end
        end

        if (mismatches == 0) begin
            $display("========================================");
            $display("   SUCCESS: all %0d output bytes match their per-address expected value", STORE_TOTAL_BYTES);
            for (int b = 0; b < BATCH_SIZE; b++)
                $display("     addr %0d -> expected %0d", b, expected_byte(b));
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   FAILED: %0d / %0d bytes mismatched", mismatches, STORE_TOTAL_BYTES);
            $display("========================================");
        end

        $finish;
    end

endmodule