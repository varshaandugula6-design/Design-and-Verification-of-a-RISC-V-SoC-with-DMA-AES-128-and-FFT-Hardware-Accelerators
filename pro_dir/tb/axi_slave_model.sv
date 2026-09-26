// =============================================================================
// File        : axi_slave_model.sv
// Description : AXI4 Slave Model — responds to one downstream (m*_axi) port
//               of the DUT.
//
//   * Accepts AXI write transactions → stores to an internal memory array
//   * Accepts AXI read  transactions → returns stored data XOR'd with a
//     unique slave signature so the scoreboard can identify which slave
//     responded even before data was written.
//
//   Read-data formula (when no prior write):
//     rdata = {SLAVE_ID[3:0], 4'hF, 8'h00, addr[15:0]}
//   After a write to an address:
//     rdata = stored write data
//
//   Slave signatures (upper nibble of SLAVE_ID):
//     Slave 0 → 0x0F000000 | addr[15:0]
//     Slave 1 → 0x1F000000 | addr[15:0]
//     ...
//     Slave 6 → 0x6F000000 | addr[15:0]
//
//   BRESP / RRESP = 2'b00 (OKAY) for all mapped accesses
//
//   Timing: accepts new AW/AR requests on every cycle that VALID is high.
//   Supports outstanding queue depth = 1 for simplicity.
// =============================================================================

`timescale 1ns/1ps

module axi_slave_model #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter ID_WIDTH     = 8,
    parameter STRB_WIDTH   = DATA_WIDTH/8,
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH  = 1,
    parameter BUSER_WIDTH  = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH  = 1,
    parameter SLAVE_ID     = 0,         // 0..6, used for data signature
    parameter MEM_DEPTH    = 256        // number of 32-bit words addressable
) (
    input  logic clk,
    input  logic rst,

    // ----- Write Address Channel -----
    input  logic [ID_WIDTH-1:0]     awid,
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic [7:0]              awlen,
    input  logic [2:0]              awsize,
    input  logic [1:0]              awburst,
    input  logic                    awlock,
    input  logic [3:0]              awcache,
    input  logic [2:0]              awprot,
    input  logic [3:0]              awqos,
    input  logic [AWUSER_WIDTH-1:0] awuser,
    input  logic                    awvalid,
    output logic                    awready,

    // ----- Write Data Channel -----
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [STRB_WIDTH-1:0]   wstrb,
    input  logic                    wlast,
    input  logic [WUSER_WIDTH-1:0]  wuser,
    input  logic                    wvalid,
    output logic                    wready,

    // ----- Write Response Channel -----
    output logic [ID_WIDTH-1:0]     bid,
    output logic [1:0]              bresp,
    output logic [BUSER_WIDTH-1:0]  buser,
    output logic                    bvalid,
    input  logic                    bready,

    // ----- Read Address Channel -----
    input  logic [ID_WIDTH-1:0]     arid,
    input  logic [ADDR_WIDTH-1:0]   araddr,
    input  logic [7:0]              arlen,
    input  logic [2:0]              arsize,
    input  logic [1:0]              arburst,
    input  logic                    arlock,
    input  logic [3:0]              arcache,
    input  logic [2:0]              arprot,
    input  logic [3:0]              arqos,
    input  logic [ARUSER_WIDTH-1:0] aruser,
    input  logic                    arvalid,
    output logic                    arready,

    // ----- Read Data Channel -----
    output logic [ID_WIDTH-1:0]     rid,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic                    rlast,
    output logic [RUSER_WIDTH-1:0]  ruser,
    output logic                    rvalid,
    input  logic                    rready
);

    // =========================================================================
    // Internal memory — word-addressed.  Only lower MEM_DEPTH words stored.
    // We use a reg array so only always_ff writes it (no initial block conflict).
    // =========================================================================
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Bit-width for mem index (avoid width warnings)
    localparam MEM_IDX_W = $clog2(MEM_DEPTH);

    function automatic [MEM_IDX_W-1:0] mem_index(input [ADDR_WIDTH-1:0] a);
        // map byte address → word index within mem, wrap-around
        mem_index = a[MEM_IDX_W+1:2];   // word-align, then wrap
    endfunction

    function automatic [DATA_WIDTH-1:0] default_sig(input [ADDR_WIDTH-1:0] a);
        // Unique signature so scoreboard knows which slave responded
        default_sig = {SLAVE_ID[3:0], 4'hF, 8'h00, a[15:0]};
    endfunction

    // =========================================================================
    // Write path state machine
    // =========================================================================
    typedef enum logic [1:0] {
        WR_IDLE = 2'b00,
        WR_W    = 2'b01,
        WR_B    = 2'b10
    } wr_state_t;

    wr_state_t wr_state;

    logic [ID_WIDTH-1:0]   wr_id_q;
    logic [ADDR_WIDTH-1:0] wr_addr_q;
    logic [7:0]            wr_len_q;
    logic [7:0]            wr_beat_cnt;

    integer k;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_state    <= WR_IDLE;
            awready     <= 1'b1;
            wready      <= 1'b0;
            bvalid      <= 1'b0;
            bid         <= '0;
            bresp       <= 2'b00;
            buser       <= '0;
            wr_id_q     <= '0;
            wr_addr_q   <= '0;
            wr_len_q    <= '0;
            wr_beat_cnt <= '0;
            // Initialize memory to default signatures
            for (k = 0; k < MEM_DEPTH; k = k + 1)
                mem[k] <= {SLAVE_ID[3:0], 4'hF, 8'h00, k[15:0]};
        end else begin
            case (wr_state)
                // ---------------------------------------------------------
                WR_IDLE: begin
                    awready <= 1'b1;
                    wready  <= 1'b0;
                    bvalid  <= 1'b0;
                    if (awvalid && awready) begin
                        wr_id_q     <= awid;
                        wr_addr_q   <= awaddr;
                        wr_len_q    <= awlen;
                        wr_beat_cnt <= '0;
                        awready     <= 1'b0;
                        wready      <= 1'b1;
                        wr_state    <= WR_W;
                    end
                end

                // ---------------------------------------------------------
                WR_W: begin
                    wready <= 1'b1;
                    if (wvalid && wready) begin
                        // Write data with byte strobes
                        begin
                            logic [ADDR_WIDTH-1:0]  cur_addr;
                            logic [MEM_IDX_W-1:0]   widx;
                            integer                  b;
                            cur_addr = wr_addr_q + (wr_beat_cnt << 2);
                            widx = mem_index(cur_addr);
                            for (b = 0; b < STRB_WIDTH; b = b + 1) begin
                                if (wstrb[b])
                                    mem[widx][b*8 +: 8] <= wdata[b*8 +: 8];
                            end
                        end
                        wr_beat_cnt <= wr_beat_cnt + 1;
                        if (wlast) begin
                            wready   <= 1'b0;
                            wr_state <= WR_B;
                        end
                    end
                end

                // ---------------------------------------------------------
                WR_B: begin
                    bvalid <= 1'b1;
                    bid    <= wr_id_q;
                    bresp  <= 2'b00;   // OKAY
                    buser  <= '0;
                    if (bvalid && bready) begin
                        bvalid   <= 1'b0;
                        awready  <= 1'b1;
                        wr_state <= WR_IDLE;
                    end
                end

                // ---------------------------------------------------------
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Read path state machine
    // =========================================================================
    typedef enum logic [1:0] {
        RD_IDLE = 2'b00,
        RD_DATA = 2'b01
    } rd_state_t;

    rd_state_t rd_state;

    logic [ID_WIDTH-1:0]   rd_id_q;
    logic [ADDR_WIDTH-1:0] rd_addr_q;
    logic [7:0]            rd_len_q;
    logic [7:0]            rd_beat_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_state    <= RD_IDLE;
            arready     <= 1'b1;
            rvalid      <= 1'b0;
            rid         <= '0;
            rdata       <= '0;
            rresp       <= 2'b00;
            rlast       <= 1'b0;
            ruser       <= '0;
            rd_id_q     <= '0;
            rd_addr_q   <= '0;
            rd_len_q    <= '0;
            rd_beat_cnt <= '0;
        end else begin
            case (rd_state)
                // ---------------------------------------------------------
                RD_IDLE: begin
                    arready <= 1'b1;
                    rvalid  <= 1'b0;
                    if (arvalid && arready) begin
                        rd_id_q     <= arid;
                        rd_addr_q   <= araddr;
                        rd_len_q    <= arlen;
                        rd_beat_cnt <= '0;
                        arready     <= 1'b0;
                        rd_state    <= RD_DATA;
                    end
                end

                // ---------------------------------------------------------
                RD_DATA: begin
                    if (!rvalid || rready) begin
                        begin
                            logic [ADDR_WIDTH-1:0]  cur_addr;
                            logic [MEM_IDX_W-1:0]   ridx;
                            cur_addr = rd_addr_q + (rd_beat_cnt << 2);
                            ridx     = mem_index(cur_addr);
                            rdata   <= mem[ridx];
                        end
                        rid   <= rd_id_q;
                        rresp <= 2'b00;
                        ruser <= '0;
                        rlast <= (rd_beat_cnt == rd_len_q);
                        rvalid <= 1'b1;

                        if (rd_beat_cnt == rd_len_q) begin
                            rd_state <= RD_IDLE;
                            arready  <= 1'b1;
                        end else begin
                            rd_beat_cnt <= rd_beat_cnt + 1;
                        end
                    end
                end

                // ---------------------------------------------------------
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule : axi_slave_model
