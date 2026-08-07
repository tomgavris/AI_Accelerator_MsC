// =============================================================================
// filename     : DataMover.sv
// description  : DataMover is a Reader-Writer Combo
// author       : Gedeon Nyengele
// =============================================================================
//
// Assumptions:
//  - Transfer addresses are 8-byte-aligned
//
// TO-DO:
//  - Add support for ABORT
// =============================================================================
module DataMover #(parameter FIFO_DEPTH = 256) (
    // Clock and Reset
    input   logic           clk,
    input   logic           ARESETn,

    // Reader Cmd/Stat Interface
    ReadyValidIntf.Slave    RdCmdIntf,
    ReadyValidIntf.Master   RdStatIntf,

    input   logic           dma_mode,      // 0 = Fetch (L2), 1 = Store (Acc)

    // Accumulator Interface
    input   logic [63:0]    acc_data_i,
    input   logic           acc_valid_i,
    output  logic           acc_ready_o,

    // SP Interface
    input   logic           sp_ready_i,
    output  logic [63:0]    sp_data_o,
    output  logic           sp_valid_o,

    // Writer Cmd/Stat Interface
    ReadyValidIntf.Slave    WrCmdIntf,
    ReadyValidIntf.Master   WrStatIntf,

    // AXI4 Read Interface
    AXI4ReadIntf.Master     ReadIntf,

    // AXI4 Write Interface
    AXI4WriteIntf.Master    WriteIntf
);

    import DmaPkg::Packet_t;

    ReadyValidIntf #(.DataTy(Packet_t))     fifoEnqIntf();
    ReadyValidIntf #(.DataTy(Packet_t))     fifoDeqIntf();
    ReadyValidIntf #(.DataTy(Packet_t))     reader_data_intf();

    Reader reader_inst (
        .clk            (clk),
        .ARESETn        (ARESETn),
        .CmdIntf        (RdCmdIntf),
        .StatIntf       (RdStatIntf),
        .DataIntf       (reader_data_intf),
        .ReadIntf       (ReadIntf)
    );

    always_comb begin
        // Default Assignments (Prevents latches and guarantees clean signals)
        fifoEnqIntf.Valid       = 1'b0;
        fifoEnqIntf.Data        = '0;
        acc_ready_o             = 1'b0;
        
        reader_data_intf.Ready  = 1'b0;
        sp_valid_o              = 1'b0;
        sp_data_o               = '0;

        if (dma_mode == 1'b1) begin
            // -------------------------------------------------------------
            // STORE MODE: Accumulator writes directly into the FIFO
            // -------------------------------------------------------------
            fifoEnqIntf.Valid = acc_valid_i;
            fifoEnqIntf.Data  = acc_data_i;      
            acc_ready_o       = fifoEnqIntf.Ready;
        end 
        else begin
            // -------------------------------------------------------------
            // FETCH MODE: AXI Reader writes directly to the SP (Bypass FIFO)
            // -------------------------------------------------------------
            sp_valid_o              = reader_data_intf.Valid;
            
            // Extract the raw 64-bit payload from the DMA's Packet struct
            sp_data_o               = reader_data_intf.Data; 
            
            // Route the SP's backpressure directly to the AXI Reader
            reader_data_intf.Ready  = sp_ready_i;
        end
    end

    PeekQueue #(.DEPTH(FIFO_DEPTH)) peek_queue_inst (
        .clk            (clk),
        .ARESETn        (ARESETn),
        .Abort          (1'b0),
        .EnqIntf        (fifoEnqIntf),
        .DeqIntf        (fifoDeqIntf)
    );

    Writer writer_inst (
        .clk              (clk),
        .ARESETn        (ARESETn),
        .CmdIntf        (WrCmdIntf),
        .StatIntf       (WrStatIntf),
        .DataIntf       (fifoDeqIntf),
        .WriteIntf      (WriteIntf)
    );

endmodule
