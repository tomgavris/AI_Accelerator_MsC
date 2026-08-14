// =============================================================================
// filename     : DMA.sv
// description  : DMA Top-Level
// author       : Gedeon Nyengele
// =============================================================================
//
// Rules:
//  -   Parameter `FIFO_DEPTH` must be a power of 2
//  -   Addresses must be 8-byte-aligned
//
// TO-DO:
//  - Support for ABORT condition
// =============================================================================
module DMA #(parameter FIFO_DEPTH = 256)
(
    // Clock and Reset
    input   logic           clk,
    input   logic           ARESETn,
    
    // RoCC Interface
    input   logic [31:0]    src_addr,
    input   logic [31:0]    dst_addr,
    input   logic [31:0]    length,
    input   logic           go_pulse, 
    input   logic           dma_mode_i, 

    // Accumulator Interface
    input   logic [63:0]    acc_data_i,
    input   logic           acc_valid_i,
    output  logic           acc_ready_o,

    // SP Interface
    input   logic           sp_ready_i,
    input   logic           weight_fetch_i,
    output  logic [63:0]    sp_data_o,
    output  logic           w_sp_valid_o, 
    output  logic           a_sp_valid_o,
    

    output  logic           busy,
    output  logic           dma_load_finish_o,
    

    // AXI4 Reader Port
    AXI4ReadIntf.Master     AxiReadIntf,

    // AXI4 Writer Port
    AXI4WriteIntf.Master    AxiWriteIntf
);

    import DmaPkg::Cmd_t;

    ReadyValidIntf #(.DataTy(Cmd_t))        rd_cmd_intf();
    ReadyValidIntf #(.DataTy(logic[1:0]))   rd_stat_intf();

    ReadyValidIntf #(.DataTy(Cmd_t))        wr_cmd_intf();
    ReadyValidIntf #(.DataTy(logic[1:0]))   wr_stat_intf();

    Controller controller_inst (
        .clk                (clk),
        .ARESETn            (ARESETn),
        .src_addr           (src_addr),
        .dst_addr           (dst_addr),
        .length             (length),
        .go_pulse           (go_pulse), 
        .busy               (busy),
        .dma_load_finish_o  (dma_load_finish_o),
        .dma_mode           (dma_mode_i),
        .RdCmdIntf          (rd_cmd_intf),
        .RdStatIntf         (rd_stat_intf),
        .WrCmdIntf          (wr_cmd_intf),
        .WrStatIntf         (wr_stat_intf)
    );

    DataMover #(.FIFO_DEPTH(FIFO_DEPTH)) data_mover_inst (
        .clk                (clk),
        .ARESETn            (ARESETn),
        
        .dma_mode           (dma_mode_i),     
        .acc_data_i         (acc_data_i),   
        .acc_valid_i        (acc_valid_i),  
        .acc_ready_o        (acc_ready_o),  

        .weight_fetch_i     (weight_fetch_i),
        .sp_ready_i         (sp_ready_i),
        .sp_data_o          (sp_data_o),
        .w_sp_valid_o       (w_sp_valid_o),
        .a_sp_valid_o       (a_sp_valid_o),

        .RdCmdIntf          (rd_cmd_intf),
        .RdStatIntf         (rd_stat_intf),
        .WrCmdIntf          (wr_cmd_intf),
        .WrStatIntf         (wr_stat_intf),
        .ReadIntf           (AxiReadIntf),
        .WriteIntf          (AxiWriteIntf)
    );

endmodule
