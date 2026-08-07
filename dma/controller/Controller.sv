// =============================================================================
// filename     : Controller.sv
// description  : DMA Contoller
// author       : Gedeon Nyengele
// =============================================================================
//
//
// Assumptions:
//  - Transfer addresses are 8-byte-aligned
//
// TO-DO:
//  - Add support for ABORT
// =============================================================================
module Controller (
    // Clock and Reset
    input   logic           clk,
    input   logic           ARESETn,

    // RoCC Interface
    input   logic [31:0]    src_addr,
    input   logic [31:0]    dst_addr,
    input   logic [31:0]    length,
    input   logic           go_pulse, dma_mode,

    output  logic           busy, 

    // DMA controll
    output logic            dma_load_finish_o,

    // Read Cmd/Stat Interface
    ReadyValidIntf.Master   RdCmdIntf,
    ReadyValidIntf.Slave    RdStatIntf,

    // Write Cmd/Stat Interface
    ReadyValidIntf.Master   WrCmdIntf,
    ReadyValidIntf.Slave    WrStatIntf
);

    import DmaPkg::TransCmd_t;

    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        POST        = 2'b01,
        STAT        = 2'b11,
        XXX         = 'x
    } state_e;

    logic busy_q;
    
    // State Variables
    state_e         state, next;
    
    // Read Engine Connections
    ReadyValidIntf #(.DataTy(TransCmd_t))   rd_trans_cmd_intf();
    ReadyValidIntf #(.DataTy(logic[1:0]))   rd_trans_stat_intf();

    // Write Engine Connections
    ReadyValidIntf #(.DataTy(TransCmd_t))   wr_trans_cmd_intf();
    ReadyValidIntf #(.DataTy(logic[1:0]))   wr_trans_stat_intf();

    // Internal Signals
    logic           read_cmd_posted;
    logic           write_cmd_posted;
    logic           read_stat_posted;
    logic           write_stat_posted;
    logic [1:0]     read_stat;
    logic [1:0]     write_stat;
    logic [1:0]     err_stat;

    always_ff @(posedge clk or negedge ARESETn) begin
        if (!ARESETn) busy_q <= 1'b0;
        else          busy_q <= busy;
    end
    
    assign dma_load_finish_o = (busy_q == 1'b1) && (busy == 1'b0);

    assign busy = (state != IDLE);

    //
    // Transaction Splitter for Read Engine
    //
    Splitter read_splitter (
        .clk           (clk),
        .ARESETn        (ARESETn),
        .TransCmdIntf   (rd_trans_cmd_intf),
        .TransStatIntf  (rd_trans_stat_intf),
        .CmdIntf        (RdCmdIntf),
        .StatIntf       (RdStatIntf)
    );

    //
    // Transaction Splitter for Write Engine
    //
    Splitter write_splitter (
        .clk           (clk),
        .ARESETn        (ARESETn),
        .TransCmdIntf   (wr_trans_cmd_intf),
        .TransStatIntf  (wr_trans_stat_intf),
        .CmdIntf        (WrCmdIntf),
        .StatIntf       (WrStatIntf)
    );

    //
    // State Register Update
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)   state <= IDLE;
        else            state <= next;

    //
    // Next State Logic
    //
    always_comb begin
        next = XXX;
        case (state)
            IDLE    :   if (go_pulse && (length == '0))
                            next = STAT;
                        else if (go_pulse)
                            next = POST;
                        else
                            next = IDLE; //@ loopback
            POST    :   if (read_cmd_posted & write_cmd_posted)
                            next = STAT;
                        else
                            next = POST; //@ loopback
            STAT    :   if (read_stat_posted & write_stat_posted)
                            next = IDLE;
                        else
                            next = STAT;
            default :       next = XXX;
        endcase
    end


    //
    // Error Status Code
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)       err_stat    <= '0;
        else case(state)
            IDLE    :   if (go_pulse && (length == '0))
                            err_stat    <= 2'b10;
                        else
                            err_stat    <= '0;
        endcase

    //
    // Read Status
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn) begin
            read_stat_posted    <= '0;
            read_stat           <= '0;
        end
        else case (state)
            IDLE    :   begin
                            read_stat_posted    <= '0;
                            read_stat           <= '0;
                        end
            STAT    :   if (rd_trans_stat_intf.Valid || (err_stat != '0)) begin
                            read_stat_posted    <= '1;
                            read_stat           <= rd_trans_stat_intf.Data;
                        end
                        else if (dma_mode == 1) begin
                            read_stat_posted    <= '1;
                        end
        endcase

    // dma_mode = 1 -> storing data from Acc to L2
    // dma_mode = 0 -> storing data from L2 to SP
    assign rd_trans_stat_intf.Ready = (state == STAT) && (dma_mode == 1'b0);

    //
    // Write Status
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn) begin
            write_stat_posted    <= '0;
            write_stat           <= '0;
        end
        else case (state)
            IDLE    :   begin
                            write_stat_posted    <= '0;
                            write_stat           <= '0;
                        end
            STAT    :   if (wr_trans_stat_intf.Valid || (err_stat != '0)) begin
                            write_stat_posted    <= '1;
                            write_stat           <= wr_trans_stat_intf.Data;
                        end
                        // BYPASS THE WRITER IN FETCH MODE
                        else if (dma_mode == 1'b0) begin 
                            write_stat_posted    <= '1;
                        end
        endcase

    // LOCK THE READY SIGNAL IN FETCH MODE
    assign wr_trans_stat_intf.Ready = (state == STAT) && (dma_mode == 1'b1);

    //
    // Read Command
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)   begin
            read_cmd_posted             <= '0;
            rd_trans_cmd_intf.Valid     <= '0;
            rd_trans_cmd_intf.Data      <= '0;
        end
        else case (state)
            IDLE    :   begin
                            if (go_pulse && (length != '0)) begin
                                if (dma_mode == 1'b0) begin // ONLY POST IF FETCHING
                                    read_cmd_posted                 <= '0;
                                    rd_trans_cmd_intf.Valid         <= '1;
                                    rd_trans_cmd_intf.Data.NumBytes <= length;
                                    rd_trans_cmd_intf.Data.Address  <= src_addr;
                                end else begin
                                    read_cmd_posted                 <= '1; // AUTO-POST
                                    rd_trans_cmd_intf.Valid         <= '0;
                                    rd_trans_cmd_intf.Data          <= '0;
                                end
                            end
                            else begin
                                read_cmd_posted                 <= '0;
                                rd_trans_cmd_intf.Valid         <= '0;
                                rd_trans_cmd_intf.Data          <= '0;
                            end
                        end
            POST    :   if (rd_trans_cmd_intf.Ready && (dma_mode == 1'b0)) begin
                            read_cmd_posted                     <= '1;
                            rd_trans_cmd_intf.Valid             <= '0;
                        end
        endcase

    //
    // Write Command
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)   begin
            write_cmd_posted            <= '0;
            wr_trans_cmd_intf.Valid     <= '0;
            wr_trans_cmd_intf.Data      <= '0;
        end
        else case (state)
            IDLE    :   begin
                            if (go_pulse && (length != '0)) begin
                                if (dma_mode == 1'b1) begin // ONLY POST IF STORING
                                    write_cmd_posted                <= '0;
                                    wr_trans_cmd_intf.Valid         <= '1;
                                    wr_trans_cmd_intf.Data.NumBytes <= length;
                                    wr_trans_cmd_intf.Data.Address  <= dst_addr;
                                end else begin
                                    write_cmd_posted                <= '1; // AUTO-POST
                                    wr_trans_cmd_intf.Valid         <= '0;
                                    wr_trans_cmd_intf.Data          <= '0;
                                end
                            end
                            else begin
                                write_cmd_posted                <= '0;
                                wr_trans_cmd_intf.Valid         <= '0;
                                wr_trans_cmd_intf.Data          <= '0;
                            end
                        end
            POST    :   if (wr_trans_cmd_intf.Ready && (dma_mode == 1'b1)) begin
                            write_cmd_posted                    <= '1;
                            wr_trans_cmd_intf.Valid             <= '0;
                        end
        endcase

endmodule