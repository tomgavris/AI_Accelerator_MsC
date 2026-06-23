import pe_pkg::*;

module double_buffer_tb();

    logic signed [DATA_WIDTH-1:0]  db_i, error_count = 0;
    logic [$clog2(SRAM_SIZE)-1:0]  db_wr_add, db_rd_add; 
    logic                          clk, rst, state;
    logic signed [DATA_WIDTH-1:0]  db_o;

    double_buffer double_buffer_i(
        .clk(clk), 
        .rst(rst),
        .db_wr_add(db_wr_add),
        .db_rd_add(db_rd_add),
        .db_i(db_i),
        .state(state),
        .db_o(db_o)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst <= 1;
        state <= 0;
        @(posedge clk);
        rst <= 0;

        for (int i = 0; i < 8; i++) begin
            state <= 0;
            db_wr_add <= i;
            db_rd_add <= 0;
            db_i <= i;
            @(posedge clk);
        end
        
        for (int j = 0; j <= 8; j++) begin
            if (j < 8) begin
                state <= 1;
                db_wr_add <= j;
                db_rd_add <= j;
                db_i <= j;
            end
            
            @(posedge clk);  
            @(negedge clk); 
            if (j > 0) begin
                if (db_o != (j - 1)) begin
                    $display("Phase 2 Mismatch: expected %0d, got db_o = %0d", (j - 1), db_o);
                    error_count <= error_count + 1;
                end
            end
        end

        
        @(posedge clk); 
        
        for (int i = 0; i <= 8; i++) begin
            
            if (i < 8) begin
                state <= 0;
                db_wr_add <= i;
                db_rd_add <= i;
                db_i <= i;
            end
            
            @(posedge clk);
            @(negedge clk);
            
            if (i > 0) begin
                if (db_o != (i - 1)) begin
                    $display("Phase 3 Mismatch: expected %0d, got db_o = %0d", (i - 1), db_o);
                    error_count <= error_count + 1;
                end
            end
        end

        if(error_count == 0)  begin
            $display("TEST SUCCESSFUL!\n");
        end else begin
            $display("TEST FAILED with %0d errors.\n", error_count);
        end

        repeat(4) @(posedge clk);
        $finish;
    end

endmodule