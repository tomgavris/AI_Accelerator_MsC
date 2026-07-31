package pe_pkg;

    // parameters relating to data width
    localparam DATA_WIDTH = 8;
    localparam P_DATA_WIDTH = 16;

    // parameters relating to the SA architecture
    localparam OP = 2;
    localparam N = 2;
    localparam M = 2;


    localparam CYCLES = 2;
    localparam W_CYCLES = M;

    // parameters relating to memory
    localparam PARTITIONS = 4;
    localparam SP_SIZE = 2048; // Scratchpad size
    localparam ACC_SIZE = 512;
    localparam SRAM_SIZE = SP_SIZE/PARTITIONS;
    localparam CONC_ADD = M/PARTITIONS; // Concurrent addresses read from each partition
    localparam CONC_ADD_D = CONC_ADD*N*OP; // The sum of the data read form an address
    localparam SRAM_WIDTH = CONC_ADD*N*OP*DATA_WIDTH; // One address read for each partition  

    // DMA parameters
    localparam WEIGHT_LEN = 256;
    localparam SP_ADDR    = 32'd0;

    // Batch parameters
    localparam BATCH_SIZE = 64;
    localparam K_TILE = 64;         // K is the number of tiles needed before we get one result
endpackage