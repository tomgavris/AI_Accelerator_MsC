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
    input   logic           ACLK,
    input   logic           ARESETn,

    // Reader Cmd/Stat Interface
    ReadyValidIntf.Slave    RdCmdIntf,
    ReadyValidIntf.Master   RdStatIntf,

    input   logic           dma_mode,      // 0 = Fetch (L2), 1 = Store (Acc)
    input   logic [63:0]    acc_data_i,
    input   logic           acc_valid_i,
    output  logic           acc_ready_o,

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
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),
        .CmdIntf        (RdCmdIntf),
        .StatIntf       (RdStatIntf),
        .DataIntf       (reader_data_intf),
        .ReadIntf       (ReadIntf)
    );

    always_comb begin
        if (dma_mode == 1'b1) begin
            // -------------------------------------------------------------
            // STORE MODE: Accumulator writes directly into the FIFO
            // -------------------------------------------------------------
            fifoEnqIntf.Valid       = acc_valid_i;
            
            // Format the raw 64-bit Accumulator data into the DMA's Packet format
            fifoEnqIntf.Data        = '0;           // Clear all fields
            fifoEnqIntf.Data.Data   = acc_data_i;   // Map the payload
            fifoEnqIntf.Data.Last   = 1'b0;         // Writer will handle AXI burst boundaries
            
            acc_ready_o             = fifoEnqIntf.Ready;
            
            // Pause the Reader
            reader_data_intf.Ready  = 1'b0; 
        end 
        else begin
            // -------------------------------------------------------------
            // FETCH MODE: AXI Reader writes into the FIFO
            // -------------------------------------------------------------
            fifoEnqIntf.Valid       = reader_data_intf.Valid;
            fifoEnqIntf.Data        = reader_data_intf.Data;
            reader_data_intf.Ready  = fifoEnqIntf.Ready;
            
            // Pause the Accumulator
            acc_ready_o             = 1'b0;
        end
    end

    PeekQueue #(.DEPTH(FIFO_DEPTH)) peek_queue_inst (
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),
        .Abort          (1'b0),
        .EnqIntf        (fifoEnqIntf),
        .DeqIntf        (fifoDeqIntf)
    );

    Writer writer_inst (
        .ACLK           (ACLK),
        .ARESETn        (ARESETn),
        .CmdIntf        (WrCmdIntf),
        .StatIntf       (WrStatIntf),
        .DataIntf       (fifoDeqIntf),
        .WriteIntf      (WriteIntf)
    );

endmodule
