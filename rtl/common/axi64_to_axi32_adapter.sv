// ==============================================================================
// Module: axi64_to_axi32_adapter
// Project: RISC-V VeeR EL2 SoC Integration
// Description:
//   Converts 64-bit AXI4 Master transactions (VeeR EL2 IFU / LSU) to 32-bit AXI4
//   Interconnect transactions.
//
// Features:
//   - 64-bit Master Data Width <-> 32-bit Slave Data Width
//   - Master ID width parameter (default 4) <-> 8-bit Slave ID width
//   - Read translation:
//       * arsize >= 3 (64-bit / 8 bytes): performs two consecutive 32-bit reads
//         at addr and addr+4, combining them into 64-bit rdata {hi, lo}.
//       * arsize <= 2 (32-bit / <= 4 bytes): performs a single 32-bit read and
//         replicates rdata as {s_rdata, s_rdata} for both 32-bit lanes.
//   - Write translation:
//       * If wstrb[7:4] == 0: single 32-bit write of wdata[31:0] to addr[31:0].
//       * If wstrb[3:0] == 0: single 32-bit write of wdata[63:32] to addr|4.
//       * If both active: two consecutive 32-bit writes to addr and addr+4.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module axi64_to_axi32_adapter #(
    parameter M_ID_WIDTH = 4,
    parameter S_ID_WIDTH = 8
)(
    input  wire                     clk,
    input  wire                     rst,

    // ============================================================
    // 64-bit AXI4 Master Interface (from VeeR EL2)
    // ============================================================
    // Write Address
    input  wire                     m_axi_awvalid,
    output reg                      m_axi_awready,
    input  wire [M_ID_WIDTH-1:0]    m_axi_awid,
    input  wire [31:0]              m_axi_awaddr,
    input  wire [7:0]               m_axi_awlen,
    input  wire [2:0]               m_axi_awsize,
    input  wire [1:0]               m_axi_awburst,
    input  wire                     m_axi_awlock,
    input  wire [3:0]               m_axi_awcache,
    input  wire [2:0]               m_axi_awprot,
    input  wire [3:0]               m_axi_awqos,
    input  wire [3:0]               m_axi_awregion,

    // Write Data
    input  wire                     m_axi_wvalid,
    output reg                      m_axi_wready,
    input  wire [63:0]              m_axi_wdata,
    input  wire [7:0]               m_axi_wstrb,
    input  wire                     m_axi_wlast,

    // Write Response
    output reg                      m_axi_bvalid,
    input  wire                     m_axi_bready,
    output reg  [1:0]               m_axi_bresp,
    output reg  [M_ID_WIDTH-1:0]    m_axi_bid,

    // Read Address
    input  wire                     m_axi_arvalid,
    output reg                      m_axi_arready,
    input  wire [M_ID_WIDTH-1:0]    m_axi_arid,
    input  wire [31:0]              m_axi_araddr,
    input  wire [7:0]               m_axi_arlen,
    input  wire [2:0]               m_axi_arsize,
    input  wire [1:0]               m_axi_arburst,
    input  wire                     m_axi_arlock,
    input  wire [3:0]               m_axi_arcache,
    input  wire [2:0]               m_axi_arprot,
    input  wire [3:0]               m_axi_arqos,
    input  wire [3:0]               m_axi_arregion,

    // Read Data
    output reg                      m_axi_rvalid,
    input  wire                     m_axi_rready,
    output reg  [M_ID_WIDTH-1:0]    m_axi_rid,
    output reg  [63:0]              m_axi_rdata,
    output reg  [1:0]               m_axi_rresp,
    output reg                      m_axi_rlast,

    // ============================================================
    // 32-bit AXI4 Slave Interface (to Interconnect)
    // ============================================================
    // Write Address
    output reg                      s_axi_awvalid,
    input  wire                     s_axi_awready,
    output reg  [S_ID_WIDTH-1:0]    s_axi_awid,
    output reg  [31:0]              s_axi_awaddr,
    output reg  [7:0]               s_axi_awlen,
    output reg  [2:0]               s_axi_awsize,
    output reg  [1:0]               s_axi_awburst,
    output reg                      s_axi_awlock,
    output reg  [3:0]               s_axi_awcache,
    output reg  [2:0]               s_axi_awprot,
    output reg  [3:0]               s_axi_awqos,
    output reg  [3:0]               s_axi_awregion,

    // Write Data
    output reg                      s_axi_wvalid,
    input  wire                     s_axi_wready,
    output reg  [31:0]              s_axi_wdata,
    output reg  [3:0]               s_axi_wstrb,
    output reg                      s_axi_wlast,

    // Write Response
    input  wire                     s_axi_bvalid,
    output reg                      s_axi_bready,
    input  wire [1:0]               s_axi_bresp,
    input  wire [S_ID_WIDTH-1:0]    s_axi_bid,

    // Read Address
    output reg                      s_axi_arvalid,
    input  wire                     s_axi_arready,
    output reg  [S_ID_WIDTH-1:0]    s_axi_arid,
    output reg  [31:0]              s_axi_araddr,
    output reg  [7:0]               s_axi_arlen,
    output reg  [2:0]               s_axi_arsize,
    output reg  [1:0]               s_axi_arburst,
    output reg                      s_axi_arlock,
    output reg  [3:0]               s_axi_arcache,
    output reg  [2:0]               s_axi_arprot,
    output reg  [3:0]               s_axi_arqos,
    output reg  [3:0]               s_axi_arregion,

    // Read Data
    input  wire                     s_axi_rvalid,
    output reg                      s_axi_rready,
    input  wire [S_ID_WIDTH-1:0]    s_axi_rid,
    input  wire [31:0]              s_axi_rdata,
    input  wire [1:0]               s_axi_rresp,
    input  wire                     s_axi_rlast
);

    // ============================================================
    // READ CHANNEL FSM
    // ============================================================
    localparam [2:0]
        R_IDLE        = 3'd0,
        R_NARROW_CMD  = 3'd1,
        R_NARROW_DATA = 3'd2,
        R_WIDE_CMD0   = 3'd3,
        R_WIDE_DATA0  = 3'd4,
        R_WIDE_CMD1   = 3'd5,
        R_WIDE_DATA1  = 3'd6,
        R_WIDE_RESP   = 3'd7;

    reg [2:0]               r_state;
    reg [31:0]              r_addr_q;
    reg [M_ID_WIDTH-1:0]    r_id_q;
    reg [2:0]               r_size_q;
    reg [1:0]               r_burst_q;
    reg [3:0]               r_cache_q;
    reg [2:0]               r_prot_q;
    reg [3:0]               r_qos_q;
    reg [3:0]               r_region_q;
    reg                     r_lock_q;

    reg [31:0]              r_data_lo_q;
    reg [1:0]               r_resp_lo_q;
    reg [31:0]              r_data_hi_q;
    reg [1:0]               r_resp_hi_q;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_state        <= R_IDLE;
            m_axi_arready  <= 1'b0;
            s_axi_arvalid  <= 1'b0;
            s_axi_arid     <= '0;
            s_axi_araddr   <= '0;
            s_axi_arlen    <= 8'd0;
            s_axi_arsize   <= 3'd2;
            s_axi_arburst  <= 2'b01;
            s_axi_arlock   <= 1'b0;
            s_axi_arcache  <= 4'b0;
            s_axi_arprot   <= 3'b0;
            s_axi_arqos    <= 4'b0;
            s_axi_arregion <= 4'b0;
            s_axi_rready   <= 1'b0;
            m_axi_rvalid   <= 1'b0;
            m_axi_rid      <= '0;
            m_axi_rdata    <= '0;
            m_axi_rresp    <= 2'b00;
            m_axi_rlast    <= 1'b0;
            r_addr_q       <= '0;
            r_id_q         <= '0;
            r_size_q       <= '0;
            r_burst_q      <= '0;
            r_cache_q      <= '0;
            r_prot_q       <= '0;
            r_qos_q        <= '0;
            r_region_q     <= '0;
            r_lock_q       <= 1'b0;
            r_data_lo_q    <= '0;
            r_resp_lo_q    <= 2'b00;
            r_data_hi_q    <= '0;
            r_resp_hi_q    <= 2'b00;
        end else begin
            case (r_state)
                R_IDLE: begin
                    m_axi_arready <= 1'b1;
                    m_axi_rvalid  <= 1'b0;
                    s_axi_arvalid <= 1'b0;
                    s_axi_rready  <= 1'b0;

                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arready <= 1'b0;
                        r_addr_q      <= m_axi_araddr;
                        r_id_q        <= m_axi_arid;
                        r_size_q      <= m_axi_arsize;
                        r_burst_q     <= m_axi_arburst;
                        r_cache_q     <= m_axi_arcache;
                        r_prot_q      <= m_axi_arprot;
                        r_qos_q       <= m_axi_arqos;
                        r_region_q    <= m_axi_arregion;
                        r_lock_q      <= m_axi_arlock;

                        if (m_axi_arlen > 8'd0) begin
                            // Multi-beat bursts not supported by this 64-to-32 bridge; return SLVERR
                            m_axi_rvalid <= 1'b1;
                            m_axi_rid    <= m_axi_arid;
                            m_axi_rdata  <= 64'd0;
                            m_axi_rresp  <= 2'b10; // SLVERR
                            m_axi_rlast  <= 1'b1;
                            r_state      <= R_WIDE_RESP;
                        end else if (m_axi_arsize >= 3'd3) begin
                            // 64-bit access: fetch 2 words
                            s_axi_arvalid  <= 1'b1;
                            s_axi_arid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, m_axi_arid};
                            s_axi_araddr   <= {m_axi_araddr[31:3], 3'b000};
                            s_axi_arlen    <= 8'd0;
                            s_axi_arsize   <= 3'd2; // 4 bytes
                            s_axi_arburst  <= m_axi_arburst;
                            s_axi_arlock   <= m_axi_arlock;
                            s_axi_arcache  <= m_axi_arcache;
                            s_axi_arprot   <= m_axi_arprot;
                            s_axi_arqos    <= m_axi_arqos;
                            s_axi_arregion <= m_axi_arregion;
                            r_state        <= R_WIDE_CMD0;
                        end else begin
                            // Narrow access (<= 4 bytes): single 32-bit beat
                            s_axi_arvalid  <= 1'b1;
                            s_axi_arid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, m_axi_arid};
                            s_axi_araddr   <= m_axi_araddr;
                            s_axi_arlen    <= 8'd0;
                            s_axi_arsize   <= m_axi_arsize;
                            s_axi_arburst  <= m_axi_arburst;
                            s_axi_arlock   <= m_axi_arlock;
                            s_axi_arcache  <= m_axi_arcache;
                            s_axi_arprot   <= m_axi_arprot;
                            s_axi_arqos    <= m_axi_arqos;
                            s_axi_arregion <= m_axi_arregion;
                            r_state        <= R_NARROW_CMD;
                        end
                    end
                end

                // Narrow Read: Wait for command acceptance
                R_NARROW_CMD: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arvalid <= 1'b0;
                        s_axi_rready  <= 1'b1;
                        r_state       <= R_NARROW_DATA;
                    end
                end

                // Narrow Read: Wait for response data
                R_NARROW_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rready <= 1'b0;
                        m_axi_rvalid <= 1'b1;
                        m_axi_rid    <= r_id_q;
                        m_axi_rdata  <= {s_axi_rdata, s_axi_rdata}; // duplicate across lanes
                        m_axi_rresp  <= s_axi_rresp;
                        m_axi_rlast  <= 1'b1;
                        r_state      <= R_WIDE_RESP;
                    end
                end

                // Wide Read: Word 0 command accepted?
                R_WIDE_CMD0: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arvalid <= 1'b0;
                        s_axi_rready  <= 1'b1;
                        r_state       <= R_WIDE_DATA0;
                    end
                end

                // Wide Read: Word 0 data response
                R_WIDE_DATA0: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rready <= 1'b0;
                        r_data_lo_q  <= s_axi_rdata;
                        r_resp_lo_q  <= s_axi_rresp;

                        // Issue Word 1 command
                        s_axi_arvalid  <= 1'b1;
                        s_axi_arid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, r_id_q};
                        s_axi_araddr   <= {r_addr_q[31:3], 3'b100};
                        s_axi_arlen    <= 8'd0;
                        s_axi_arsize   <= 3'd2;
                        s_axi_arburst  <= r_burst_q;
                        s_axi_arlock   <= r_lock_q;
                        s_axi_arcache  <= r_cache_q;
                        s_axi_arprot   <= r_prot_q;
                        s_axi_arqos    <= r_qos_q;
                        s_axi_arregion <= r_region_q;
                        r_state        <= R_WIDE_CMD1;
                    end
                end

                // Wide Read: Word 1 command accepted?
                R_WIDE_CMD1: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arvalid <= 1'b0;
                        s_axi_rready  <= 1'b1;
                        r_state       <= R_WIDE_DATA1;
                    end
                end

                // Wide Read: Word 1 data response
                R_WIDE_DATA1: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rready <= 1'b0;
                        m_axi_rvalid <= 1'b1;
                        m_axi_rid    <= r_id_q;
                        m_axi_rdata  <= {s_axi_rdata, r_data_lo_q};
                        m_axi_rresp  <= r_resp_lo_q | s_axi_rresp;
                        m_axi_rlast  <= 1'b1;
                        r_state      <= R_WIDE_RESP;
                    end
                end

                // Wait for Master to accept response
                R_WIDE_RESP: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rvalid <= 1'b0;
                        m_axi_rlast  <= 1'b0;
                        r_state      <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    // ============================================================
    // WRITE CHANNEL FSM
    // ============================================================
    localparam [2:0]
        W_IDLE       = 3'd0,
        W_CMD_DATA0  = 3'd1,
        W_WAIT_RESP0 = 3'd2,
        W_CMD_DATA1  = 3'd3,
        W_WAIT_RESP1 = 3'd4,
        W_RESP       = 3'd5;

    reg [2:0]               w_state;
    reg                     aw_captured;
    reg                     w_captured;
    reg [31:0]              w_addr_q;
    reg [M_ID_WIDTH-1:0]    w_id_q;
    reg [7:0]               w_len_q;
    reg [2:0]               w_size_q;
    reg [1:0]               w_burst_q;
    reg [3:0]               w_cache_q;
    reg [2:0]               w_prot_q;
    reg [3:0]               w_qos_q;
    reg [3:0]               w_region_q;
    reg                     w_lock_q;

    reg [63:0]              w_data_q;
    reg [7:0]               w_strb_q;

    reg [1:0]               w_resp_lo_q;
    reg                     two_beat_write;

    reg                     aw_done;
    reg                     w_done;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            w_state        <= W_IDLE;
            aw_captured    <= 1'b0;
            w_captured     <= 1'b0;
            m_axi_awready  <= 1'b0;
            m_axi_wready   <= 1'b0;
            m_axi_bvalid   <= 1'b0;
            m_axi_bid      <= '0;
            m_axi_bresp    <= 2'b00;
            s_axi_awvalid  <= 1'b0;
            s_axi_awid     <= '0;
            s_axi_awaddr   <= '0;
            s_axi_awlen    <= 8'd0;
            s_axi_awsize   <= 3'd2;
            s_axi_awburst  <= 2'b01;
            s_axi_awlock   <= 1'b0;
            s_axi_awcache  <= 4'b0;
            s_axi_awprot   <= 3'b0;
            s_axi_awqos    <= 4'b0;
            s_axi_awregion <= 4'b0;
            s_axi_wvalid   <= 1'b0;
            s_axi_wdata    <= '0;
            s_axi_wstrb    <= 4'b0;
            s_axi_wlast    <= 1'b0;
            s_axi_bready   <= 1'b0;
            w_addr_q       <= '0;
            w_id_q         <= '0;
            w_len_q        <= 8'd0;
            w_size_q       <= '0;
            w_burst_q      <= '0;
            w_cache_q      <= '0;
            w_prot_q       <= '0;
            w_qos_q        <= '0;
            w_region_q     <= '0;
            w_lock_q       <= 1'b0;
            w_data_q       <= '0;
            w_strb_q       <= 8'b0;
            w_resp_lo_q    <= 2'b00;
            two_beat_write <= 1'b0;
            aw_done        <= 1'b0;
            w_done         <= 1'b0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    m_axi_bvalid  <= 1'b0;
                    s_axi_awvalid <= 1'b0;
                    s_axi_wvalid  <= 1'b0;
                    s_axi_bready  <= 1'b0;

                    // Ready to capture address and data from master
                    m_axi_awready <= !aw_captured;
                    m_axi_wready  <= !w_captured;

                    if (m_axi_awvalid && m_axi_awready) begin
                        w_addr_q      <= m_axi_awaddr;
                        w_id_q        <= m_axi_awid;
                        w_len_q       <= m_axi_awlen;
                        w_size_q      <= m_axi_awsize;
                        w_burst_q     <= m_axi_awburst;
                        w_cache_q     <= m_axi_awcache;
                        w_prot_q      <= m_axi_awprot;
                        w_qos_q       <= m_axi_awqos;
                        w_region_q    <= m_axi_awregion;
                        w_lock_q      <= m_axi_awlock;
                        aw_captured   <= 1'b1;
                        m_axi_awready <= 1'b0;
                    end

                    if (m_axi_wvalid && m_axi_wready) begin
                        w_data_q     <= m_axi_wdata;
                        w_strb_q     <= m_axi_wstrb;
                        w_captured   <= 1'b1;
                        m_axi_wready <= 1'b0;
                    end

                    // Check if both address and data are captured (either previously or this cycle)
                    if ((aw_captured || (m_axi_awvalid && m_axi_awready)) &&
                        (w_captured  || (m_axi_wvalid && m_axi_wready))) begin
                        
                        reg [31:0]              cur_addr;
                        reg [7:0]               cur_strb;
                        reg [63:0]              cur_data;
                        reg [2:0]               cur_size;
                        reg [7:0]               cur_len;
                        reg [M_ID_WIDTH-1:0]    cur_id;
                        reg [1:0]               cur_burst;
                        reg                     cur_lock;
                        reg [3:0]               cur_cache;
                        reg [2:0]               cur_prot;
                        reg [3:0]               cur_qos;
                        reg [3:0]               cur_region;

                        cur_addr   = (m_axi_awvalid && m_axi_awready) ? m_axi_awaddr   : w_addr_q;
                        cur_strb   = (m_axi_wvalid  && m_axi_wready)  ? m_axi_wstrb    : w_strb_q;
                        cur_data   = (m_axi_wvalid  && m_axi_wready)  ? m_axi_wdata    : w_data_q;
                        cur_size   = (m_axi_awvalid && m_axi_awready) ? m_axi_awsize   : w_size_q;
                        cur_len    = (m_axi_awvalid && m_axi_awready) ? m_axi_awlen    : w_len_q;
                        cur_id     = (m_axi_awvalid && m_axi_awready) ? m_axi_awid     : w_id_q;
                        cur_burst  = (m_axi_awvalid && m_axi_awready) ? m_axi_awburst  : w_burst_q;
                        cur_lock   = (m_axi_awvalid && m_axi_awready) ? m_axi_awlock   : w_lock_q;
                        cur_cache  = (m_axi_awvalid && m_axi_awready) ? m_axi_awcache  : w_cache_q;
                        cur_prot   = (m_axi_awvalid && m_axi_awready) ? m_axi_awprot   : w_prot_q;
                        cur_qos    = (m_axi_awvalid && m_axi_awready) ? m_axi_awqos    : w_qos_q;
                        cur_region = (m_axi_awvalid && m_axi_awready) ? m_axi_awregion : w_region_q;

                        aw_captured <= 1'b0;
                        w_captured  <= 1'b0;
                        aw_done     <= 1'b0;
                        w_done      <= 1'b0;

                        // Burst safety check: reject unsupported multi-beat bursts with SLVERR
                        if (cur_len > 8'd0) begin
                            two_beat_write <= 1'b0;
                            m_axi_bvalid   <= 1'b1;
                            m_axi_bid      <= cur_id;
                            m_axi_bresp    <= 2'b10; // SLVERR
                            w_state        <= W_RESP;
                        end else if ((cur_strb[3:0] != 4'b0) && (cur_strb[7:4] != 4'b0)) begin
                            // Two-beat write needed (Word 0 then Word 1)
                            two_beat_write <= 1'b1;
                            s_axi_awvalid  <= 1'b1;
                            s_axi_awid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, cur_id};
                            s_axi_awaddr   <= {cur_addr[31:3], 3'b000};
                            s_axi_awlen    <= 8'd0;
                            s_axi_awsize   <= 3'd2; // 4 bytes
                            s_axi_awburst  <= cur_burst;
                            s_axi_awlock   <= cur_lock;
                            s_axi_awcache  <= cur_cache;
                            s_axi_awprot   <= cur_prot;
                            s_axi_awqos    <= cur_qos;
                            s_axi_awregion <= cur_region;

                            s_axi_wvalid   <= 1'b1;
                            s_axi_wdata    <= cur_data[31:0];
                            s_axi_wstrb    <= cur_strb[3:0];
                            s_axi_wlast    <= 1'b1;

                            w_state        <= W_CMD_DATA0;
                        end else if (cur_strb[7:4] != 4'b0) begin
                            // Single write targeting upper 32-bit word
                            two_beat_write <= 1'b0;
                            s_axi_awvalid  <= 1'b1;
                            s_axi_awid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, cur_id};
                            s_axi_awaddr   <= cur_addr[2] ? cur_addr : {cur_addr[31:3], 3'b100};
                            s_axi_awlen    <= 8'd0;
                            s_axi_awsize   <= (cur_size > 3'd2) ? 3'd2 : cur_size;
                            s_axi_awburst  <= cur_burst;
                            s_axi_awlock   <= cur_lock;
                            s_axi_awcache  <= cur_cache;
                            s_axi_awprot   <= cur_prot;
                            s_axi_awqos    <= cur_qos;
                            s_axi_awregion <= cur_region;

                            s_axi_wvalid   <= 1'b1;
                            s_axi_wdata    <= cur_data[63:32];
                            s_axi_wstrb    <= cur_strb[7:4];
                            s_axi_wlast    <= 1'b1;

                            w_state        <= W_CMD_DATA0;
                        end else begin
                            // Single write targeting lower 32-bit word (or default)
                            two_beat_write <= 1'b0;
                            s_axi_awvalid  <= 1'b1;
                            s_axi_awid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, cur_id};
                            s_axi_awaddr   <= cur_addr;
                            s_axi_awlen    <= 8'd0;
                            s_axi_awsize   <= (cur_size > 3'd2) ? 3'd2 : cur_size;
                            s_axi_awburst  <= cur_burst;
                            s_axi_awlock   <= cur_lock;
                            s_axi_awcache  <= cur_cache;
                            s_axi_awprot   <= cur_prot;
                            s_axi_awqos    <= cur_qos;
                            s_axi_awregion <= cur_region;

                            s_axi_wvalid   <= 1'b1;
                            s_axi_wdata    <= cur_data[31:0];
                            s_axi_wstrb    <= cur_strb[3:0];
                            s_axi_wlast    <= 1'b1;

                            w_state        <= W_CMD_DATA0;
                        end
                    end
                end

                // Wait for AW and W handshake on slave interface
                W_CMD_DATA0: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awvalid <= 1'b0;
                        aw_done       <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wvalid  <= 1'b0;
                        s_axi_wlast   <= 1'b0;
                        w_done        <= 1'b1;
                    end

                    if ((aw_done || (s_axi_awvalid && s_axi_awready)) &&
                        (w_done  || (s_axi_wvalid && s_axi_wready))) begin
                        aw_done      <= 1'b0;
                        w_done       <= 1'b0;
                        s_axi_bready <= 1'b1;
                        w_state      <= W_WAIT_RESP0;
                    end
                end

                // Wait for response from slave
                W_WAIT_RESP0: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bready <= 1'b0;
                        w_resp_lo_q  <= s_axi_bresp;

                        if (two_beat_write) begin
                            // Issue second beat (Word 1)
                            s_axi_awvalid  <= 1'b1;
                            s_axi_awid     <= {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, w_id_q};
                            s_axi_awaddr   <= {w_addr_q[31:3], 3'b100};
                            s_axi_awlen    <= 8'd0;
                            s_axi_awsize   <= 3'd2;
                            s_axi_awburst  <= w_burst_q;
                            s_axi_awlock   <= w_lock_q;
                            s_axi_awcache  <= w_cache_q;
                            s_axi_awprot   <= w_prot_q;
                            s_axi_awqos    <= w_qos_q;
                            s_axi_awregion <= w_region_q;

                            s_axi_wvalid   <= 1'b1;
                            s_axi_wdata    <= w_data_q[63:32];
                            s_axi_wstrb    <= w_strb_q[7:4];
                            s_axi_wlast    <= 1'b1;

                            w_state        <= W_CMD_DATA1;
                        end else begin
                            // Single write complete: drive response to master
                            m_axi_bvalid <= 1'b1;
                            m_axi_bid    <= w_id_q;
                            m_axi_bresp  <= s_axi_bresp;
                            w_state      <= W_RESP;
                        end
                    end
                end

                // Beat 1 AW and W handshake
                W_CMD_DATA1: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awvalid <= 1'b0;
                        aw_done       <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wvalid  <= 1'b0;
                        s_axi_wlast   <= 1'b0;
                        w_done        <= 1'b1;
                    end

                    if ((aw_done || (s_axi_awvalid && s_axi_awready)) &&
                        (w_done  || (s_axi_wvalid && s_axi_wready))) begin
                        aw_done      <= 1'b0;
                        w_done       <= 1'b0;
                        s_axi_bready <= 1'b1;
                        w_state      <= W_WAIT_RESP1;
                    end
                end

                // Wait for response to Beat 1
                W_WAIT_RESP1: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bready <= 1'b0;
                        m_axi_bvalid <= 1'b1;
                        m_axi_bid    <= w_id_q;
                        m_axi_bresp  <= w_resp_lo_q | s_axi_bresp;
                        w_state      <= W_RESP;
                    end
                end

                // Wait for master to accept B response
                W_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bvalid <= 1'b0;
                        w_state      <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
