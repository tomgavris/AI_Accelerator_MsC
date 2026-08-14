// =============================================================================
// filename     : PeekQueue.sv
// description  : Utility Queue
// author       : Gedeon Nyengele
// =============================================================================
//
// Parameter `DEPTH` must be a power-of-two
//
// =============================================================================
module PeekQueue #(parameter DEPTH)
(
    // Clock and Reset
    input   logic           clk,
    input   logic           ARESETn,

    // Abort
    input   logic           Abort,

    // Enqueue Interface
    ReadyValidIntf.Slave    EnqIntf,

    // Dequeue Interface
    ReadyValidIntf.Master   DeqIntf
);

    // Local Parameters
    // FIX: Upgraded to SystemVerilog's native $clog2() function
    localparam  ADDR_WIDTH  = $clog2(DEPTH);

    // Internal Signals and Registers
    logic [ADDR_WIDTH:0]    int_counter;
    logic [ADDR_WIDTH-1:0]  int_rdptr;
    logic [ADDR_WIDTH-1:0]  int_wrptr;

    // Internal Memory
    logic   [$bits(EnqIntf.Data)-1:0] int_mem[DEPTH-1:0];

    //
    // Internal Counter Update Logic
    //
    always_ff @(posedge clk or negedge ARESETn)
    if (!ARESETn)
        int_counter <= '0;
    else if (Abort)
        int_counter <= '0;
    else if ((EnqIntf.Ready & EnqIntf.Valid) && (DeqIntf.Ready & DeqIntf.Valid))
        int_counter <= int_counter;     // Simultaneous Read and Write
    else if (EnqIntf.Ready & EnqIntf.Valid)
        int_counter <= int_counter + 1; // Write
    else if (DeqIntf.Ready & DeqIntf.Valid)
        int_counter <= int_counter - 1; // Read

    //
    // Ready and Valid Logic
    //
    always_comb begin
        EnqIntf.Ready   = int_counter != DEPTH;
        DeqIntf.Valid   = int_counter != '0;
    end

    //
    // Read Pointer Update Logic
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)                               int_rdptr <= '0;
        else if (Abort)                             int_rdptr <= '0;
        else if (DeqIntf.Ready & DeqIntf.Valid)     int_rdptr <= int_rdptr + 1;

    //
    // Write Pointer Update Logic
    //
    always_ff @(posedge clk or negedge ARESETn)
        if (!ARESETn)                               int_wrptr <= '0;
        else if (Abort)                             int_wrptr <= '0;
        else if (EnqIntf.Ready & EnqIntf.Valid)     int_wrptr <= int_wrptr + 1;

    //
    // Write Operation (synchronous)
    //
    always_ff @(posedge clk)
        if (EnqIntf.Ready & EnqIntf.Valid)  int_mem[int_wrptr]  <= EnqIntf.Data;

    //
    // Read Operation (asynchronous)
    //
    assign DeqIntf.Data = int_mem[int_rdptr];

endmodule