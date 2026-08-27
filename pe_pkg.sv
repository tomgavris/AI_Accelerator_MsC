package pe_pkg;

    // Data width parameters
    localparam DATA_WIDTH = 8;
    localparam P_DATA_WIDTH = 16;

    // SA parameters  
    localparam OP = 2;
    localparam N = 4;
    localparam M = 8;


    localparam CYCLES = 2;
    localparam W_CYCLES = M;

    // Memory parameters
    localparam PARTITIONS = 4;
    localparam CONC_ADD = M/PARTITIONS; // Concurrent addresses read from each partition
    localparam CONC_ADD_D = CONC_ADD*N*OP; // The sum of the data read form an address
    localparam SRAM_WIDTH = CONC_ADD*N*OP*DATA_WIDTH; // One address read for each partition

    // Batch parameters
    localparam BATCH_SIZE = 8;
    localparam K_TILE = 8;         // K is the number of tiles needed before we get one result

    // Memory sizes
    localparam SP_SIZE = 2048; // Scratchpad size
    localparam SRAM_SIZE = SP_SIZE/PARTITIONS;  
    localparam WEIGHT_SP_SIZE  = M; 
    localparam ACC_SIZE = BATCH_SIZE;

    // DMA parameters
    localparam SP_ADDR    = 32'd0;
endpackage