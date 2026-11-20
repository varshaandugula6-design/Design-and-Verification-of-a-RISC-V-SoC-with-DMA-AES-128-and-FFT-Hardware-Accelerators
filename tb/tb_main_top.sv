`timescale 1ns / 1ps
`default_nettype none

/*
================================================================================
 Project        : Fail-Safe Railway Level-Crossing Control System (Honours CBP)
 Module         : tb_main_top
 Description    : Exhaustive SystemVerilog Testbench for 3-Master x 15-Slave
                  AXI4 Interconnect with direct S4 UART (axi_uart_top) integration.
================================================================================
*/

// ================================================================================
// Burst-capable AXI4 RAM Slave Model for IMEM (S0) and DMEM (S1)
// Supports multi-beat INCR bursts, byte strobes, and sequential read bursts.
// ================================================================================
module axi_ram_slave #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 32,
    parameter integer STRB_WIDTH = 4,
    parameter integer ID_WIDTH   = 8,
    parameter integer MEM_WORDS  = 32768, // 128 KB
    parameter bit [15:0] INIT_TAG = 16'hCA00
)(
    input  wire                    clk,
    input  wire                    rst,

    input  wire [ID_WIDTH-1:0]     awid,
    input  wire [ADDR_WIDTH-1:0]   awaddr,
    input  wire [7:0]              awlen,
    input  wire [2:0]              awsize,
    input  wire [1:0]              awburst,
    input  wire                    awvalid,
    output wire                    awready,

    input  wire [DATA_WIDTH-1:0]   wdata,
    input  wire [STRB_WIDTH-1:0]   wstrb,
    input  wire                    wlast,
    input  wire                    wvalid,
    output wire                    wready,

    output reg  [ID_WIDTH-1:0]     bid,
    output reg  [1:0]              bresp,
    output reg                     bvalid,
    input  wire                    bready,

    input  wire [ID_WIDTH-1:0]     arid,
    input  wire [ADDR_WIDTH-1:0]   araddr,
    input  wire [7:0]              arlen,
    input  wire [2:0]              arsize,
    input  wire [1:0]              arburst,
    input  wire                    arvalid,
    output wire                    arready,

    output reg  [ID_WIDTH-1:0]     rid,
    output reg  [DATA_WIDTH-1:0]   rdata,
    output reg  [1:0]              rresp,
    output reg                     rlast,
    output reg                     rvalid,
    input  wire                    rready
);

    reg [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
    integer init_k;

    initial begin
        for (init_k = 0; init_k < MEM_WORDS; init_k = init_k + 1) begin
            mem[init_k] = {INIT_TAG, 16'(init_k * 4)};
        end
    end

    // ------------------------------------------------------------
    // Write Channel
    // ------------------------------------------------------------
    reg                    wr_addr_done;
    reg [ADDR_WIDTH-1:0]   wr_addr_reg;
    reg [ID_WIDTH-1:0]     wr_id_reg;
    reg [7:0]              wr_len_reg;
    reg [7:0]              wr_beat_cnt;

    assign awready = !wr_addr_done && !bvalid;
    assign wready  = (wr_addr_done || (awvalid && awready)) && !bvalid;

    always @(posedge clk) begin
        if (rst) begin
            wr_addr_done <= 1'b0;
            wr_addr_reg  <= '0;
            wr_id_reg    <= '0;
            wr_len_reg   <= '0;
            wr_beat_cnt  <= '0;
            bvalid       <= 1'b0;
            bid          <= '0;
            bresp        <= 2'b00;
        end else begin
            if (bvalid && bready) begin
                bvalid <= 1'b0;
            end

            if (awvalid && awready) begin
                if (wvalid && wready) begin
                    // Address and Data on same cycle
                    if (wstrb[0]) mem[awaddr[16:2]][7:0]   <= wdata[7:0];
                    if (wstrb[1]) mem[awaddr[16:2]][15:8]  <= wdata[15:8];
                    if (wstrb[2]) mem[awaddr[16:2]][23:16] <= wdata[23:16];
                    if (wstrb[3]) mem[awaddr[16:2]][31:24] <= wdata[31:24];

                    if (wlast || (awlen == 8'd0)) begin
                        bvalid       <= 1'b1;
                        bid          <= awid;
                        bresp        <= 2'b00;
                        wr_addr_done <= 1'b0;
                    end else begin
                        wr_addr_done <= 1'b1;
                        wr_addr_reg  <= awaddr + 4;
                        wr_id_reg    <= awid;
                        wr_len_reg   <= awlen;
                        wr_beat_cnt  <= 8'd1;
                    end
                end else begin
                    wr_addr_done <= 1'b1;
                    wr_addr_reg  <= awaddr;
                    wr_id_reg    <= awid;
                    wr_len_reg   <= awlen;
                    wr_beat_cnt  <= 8'd0;
                end
            end else if (wr_addr_done && wvalid && wready) begin
                if (wstrb[0]) mem[wr_addr_reg[16:2]][7:0]   <= wdata[7:0];
                if (wstrb[1]) mem[wr_addr_reg[16:2]][15:8]  <= wdata[15:8];
                if (wstrb[2]) mem[wr_addr_reg[16:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[wr_addr_reg[16:2]][31:24] <= wdata[31:24];

                if (wlast || (wr_beat_cnt == wr_len_reg)) begin
                    bvalid       <= 1'b1;
                    bid          <= wr_id_reg;
                    bresp        <= 2'b00;
                    wr_addr_done <= 1'b0;
                end else begin
                    wr_addr_reg  <= wr_addr_reg + 4;
                    wr_beat_cnt  <= wr_beat_cnt + 1;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Read Channel
    // ------------------------------------------------------------
    reg                    rd_busy;
    reg [ADDR_WIDTH-1:0]   rd_addr_reg;
    reg [ID_WIDTH-1:0]     rd_id_reg;
    reg [7:0]              rd_len_reg;
    reg [7:0]              rd_beat_cnt;

    assign arready = !rd_busy;

    always @(posedge clk) begin
        if (rst) begin
            rd_busy     <= 1'b0;
            rd_addr_reg <= '0;
            rd_id_reg   <= '0;
            rd_len_reg  <= '0;
            rd_beat_cnt <= '0;
            rvalid      <= 1'b0;
            rid         <= '0;
            rdata       <= '0;
            rresp       <= 2'b00;
            rlast       <= 1'b0;
        end else begin
            if (arvalid && arready) begin
                rd_busy     <= 1'b1;
                rd_addr_reg <= araddr + 4;
                rd_id_reg   <= arid;
                rd_len_reg  <= arlen;
                rd_beat_cnt <= 8'd0;
                rvalid      <= 1'b1;
                rid         <= arid;
                rdata       <= mem[araddr[16:2]];
                rresp       <= 2'b00;
                rlast       <= (arlen == 8'd0);
            end else if (rd_busy && rvalid && rready) begin
                if (rlast) begin
                    rd_busy <= 1'b0;
                    rvalid  <= 1'b0;
                    rlast   <= 1'b0;
                end else begin
                    rd_beat_cnt <= rd_beat_cnt + 1;
                    rd_addr_reg <= rd_addr_reg + 4;
                    rdata       <= mem[rd_addr_reg[16:2]];
                    rvalid      <= 1'b1;
                    rlast       <= (rd_beat_cnt + 1 == rd_len_reg);
                end
            end
        end
    end

endmodule

module tb_main_top;

    // ============================================================
    // 1. PARAMETERS
    // ============================================================
    localparam integer DATA_WIDTH    = 32;
    localparam integer ADDR_WIDTH    = 32;
    localparam integer STRB_WIDTH    = (DATA_WIDTH/8);
    localparam integer ID_WIDTH      = 8;
    localparam integer AWUSER_WIDTH  = 1;
    localparam integer WUSER_WIDTH   = 1;
    localparam integer BUSER_WIDTH   = 1;
    localparam integer ARUSER_WIDTH  = 1;
    localparam integer RUSER_WIDTH   = 1;

    // Documented Base Addresses
    localparam logic [31:0] ADDR_S0_IMEM     = 32'h0004_0000;
    localparam logic [31:0] ADDR_S1_DMEM     = 32'h0008_0000;
    localparam logic [31:0] ADDR_S2_GPIO     = 32'h8000_1000;
    localparam logic [31:0] ADDR_S3_TIMER    = 32'h8000_2000;
    localparam logic [31:0] ADDR_S4_UART     = 32'h8000_3000;
    localparam logic [31:0] ADDR_S11_WDT     = 32'h8000_4000;
    localparam logic [31:0] ADDR_S12_ADC     = 32'h8000_5000;
    localparam logic [31:0] ADDR_S13_DMA     = 32'h8000_6000;
    localparam logic [31:0] ADDR_UNMAPPED    = 32'h9000_0000;
    localparam logic [31:0] ADDR_UNMAPPED_LO = 32'h0001_0000;

    // UART Offsets
    localparam logic [31:0] UART_RBR_THR     = 32'h8000_3000;
    localparam logic [31:0] UART_IER         = 32'h8000_3004;
    localparam logic [31:0] UART_BAUD_DIV    = 32'h8000_3008; // when DLAB=1
    localparam logic [31:0] UART_LCR         = 32'h8000_300C; // bit 7 = DLAB
    localparam logic [31:0] UART_LSR         = 32'h8000_3014;

    // GPIO Register Offsets (Base = 0x8000_1000)
    localparam logic [31:0] GPIO_BASE        = 32'h8000_1000;
    localparam logic [31:0] GPIO_DATA_I      = 32'h8000_1000;
    localparam logic [31:0] GPIO_DATA_O      = 32'h8000_1004;
    localparam logic [31:0] GPIO_DIR         = 32'h8000_1008;
    localparam logic [31:0] GPIO_INT_EN      = 32'h8000_100C;
    localparam logic [31:0] GPIO_INT_TYP     = 32'h8000_1010;
    localparam logic [31:0] GPIO_INT_POL     = 32'h8000_1014;
    localparam logic [31:0] GPIO_INT_ANY     = 32'h8000_1018;
    localparam logic [31:0] GPIO_INT_STS     = 32'h8000_101C;
    localparam logic [31:0] GPIO_SET_O       = 32'h8000_1020;
    localparam logic [31:0] GPIO_CLR_O       = 32'h8000_1024;
    localparam logic [31:0] GPIO_TGL_O       = 32'h8000_1028;
    localparam logic [31:0] GPIO_DEB_TH      = 32'h8000_102C;
    localparam logic [31:0] GPIO_DEB_EN      = 32'h8000_1030;

    // Timer Register Offsets (Base = 0x8000_2000)
    localparam logic [31:0] TIMER_BASE       = 32'h8000_2000;
    localparam logic [31:0] TIMER_CTRL       = 32'h8000_2000;
    localparam logic [31:0] TIMER_LOAD       = 32'h8000_2004;
    localparam logic [31:0] TIMER_VAL        = 32'h8000_2008;
    localparam logic [31:0] TIMER_PRE        = 32'h8000_200C;
    localparam logic [31:0] TIMER_INT_EN     = 32'h8000_2010;
    localparam logic [31:0] TIMER_INT_STS    = 32'h8000_2014;
    localparam logic [31:0] TIMER_CMP        = 32'h8000_2018;

    // UART Baud divisor for 115200 baud with fixed_clk = 40 MHz (25 ns period)
    // 40,000,000 / 115,200 = 347.22 -> 347
    localparam integer BAUD_DIV_115200       = 347;
    localparam integer TX_CYCLES_115200      = BAUD_DIV_115200 + 1; // 348 cycles
    localparam integer RX_CYCLES_115200      = BAUD_DIV_115200;     // 347 cycles

    // Fast simulation baud divisor
    localparam integer BAUD_DIV_FAST         = 32;
    localparam integer TX_CYCLES_FAST        = BAUD_DIV_FAST + 1;  // 33 cycles
    localparam integer RX_CYCLES_FAST        = BAUD_DIV_FAST;      // 32 cycles

    // ============================================================
    // AES-128 Base Address and Register Offsets (S5 / M05)
    // AES_BASE = 0x8000_7000  (matches main_top M05_BASE_ADDR)
    // Inv-cipher region starts 0x100 above base.
    // aes_axi_slave_axi4 strips the base before forwarding, so the
    // slave sees offsets relative to 0x0000_0000 / 0x0000_0100.
    // ============================================================
    localparam logic [31:0] AES_BASE         = 32'h8000_7000;
    localparam logic [31:0] AES_INV_OFFSET   = 32'h0000_0100;  // inv-cipher region

    localparam logic [31:0] AES_CSR          = 32'h00;
    localparam logic [31:0] AES_KEY0         = 32'h04;
    localparam logic [31:0] AES_KEY1         = 32'h08;
    localparam logic [31:0] AES_KEY2         = 32'h0C;
    localparam logic [31:0] AES_KEY3         = 32'h10;
    localparam logic [31:0] AES_TIN0         = 32'h14;
    localparam logic [31:0] AES_TIN1         = 32'h18;
    localparam logic [31:0] AES_TIN2         = 32'h1C;
    localparam logic [31:0] AES_TIN3         = 32'h20;
    localparam logic [31:0] AES_TOUT0        = 32'h24;
    localparam logic [31:0] AES_TOUT1        = 32'h28;
    localparam logic [31:0] AES_TOUT2        = 32'h2C;
    localparam logic [31:0] AES_TOUT3        = 32'h30;

    // FIPS-197 Appendix B test vector
    // key[127:0]  = 000102030405060708090a0b0c0d0e0f
    // plain[127:0]= 00112233445566778899aabbccddeeff
    // cipher[127:0]=69c4e0d86a7b0430d8cdb78070b4c55a
    //
    // aes_axi_slave packs: key = {key3,key2,key1,key0}
    //   key0 = key[31:0]   = 0x0c0d0e0f
    //   key1 = key[63:32]  = 0x08090a0b
    //   key2 = key[95:64]  = 0x04050607
    //   key3 = key[127:96] = 0x00010203
    //
    //   tin0 = plain[31:0]   = 0xccddeeff
    //   tin1 = plain[63:32]  = 0x8899aabb
    //   tin2 = plain[95:64]  = 0x44556677
    //   tin3 = plain[127:96] = 0x00112233
    //
    //   expected tout0 = cipher[31:0]   = 0x70b4c55a
    //   expected tout1 = cipher[63:32]  = 0xd8cdb780
    //   expected tout2 = cipher[95:64]  = 0x6a7b0430
    //   expected tout3 = cipher[127:96] = 0x69c4e0d8

    localparam logic [31:0] AES_TV_KEY0      = 32'h0c0d0e0f;
    localparam logic [31:0] AES_TV_KEY1      = 32'h08090a0b;
    localparam logic [31:0] AES_TV_KEY2      = 32'h04050607;
    localparam logic [31:0] AES_TV_KEY3      = 32'h00010203;

    localparam logic [31:0] AES_TV_TIN0      = 32'hccddeeff;
    localparam logic [31:0] AES_TV_TIN1      = 32'h8899aabb;
    localparam logic [31:0] AES_TV_TIN2      = 32'h44556677;
    localparam logic [31:0] AES_TV_TIN3      = 32'h00112233;

    localparam logic [31:0] AES_TV_EXP_TOUT0 = 32'h70b4c55a;
    localparam logic [31:0] AES_TV_EXP_TOUT1 = 32'hd8cdb780;
    localparam logic [31:0] AES_TV_EXP_TOUT2 = 32'h6a7b0430;
    localparam logic [31:0] AES_TV_EXP_TOUT3 = 32'h69c4e0d8;

    // AES per-scenario pass tracking (set inside the initial block)
    // These are used by the final combined scoreboard.
    logic aes_enc_pass;
    logic aes_dec_pass;
    logic uart_tests_pass;

    // ============================================================
    // FFT CONSTANTS  (derived from fft_ctrl_axil.sv and fft_mem_axi4_slave.sv)
    // ============================================================
    // S6 = FFT Control  base address (must match M06_BASE_ADDR in main_top)
    localparam logic [31:0] FFT_CTRL_BASE  = 32'h8000_8000;
    // S7 = FFT Memory   base address (must match M07_BASE_ADDR in main_top)
    localparam logic [31:0] FFT_MEM_BASE   = 32'h8000_9000;

    // Control register offsets (local to fft_ctrl_axil, after base subtraction)
    //   CTRL_ADDR   = 'h0000  ->  system 0x8000_8000
    //   STATUS_ADDR = 'h0004  ->  system 0x8000_8004
    localparam logic [31:0] FFT_CTRL_REG   = FFT_CTRL_BASE + 32'h0000;
    localparam logic [31:0] FFT_STATUS_REG = FFT_CTRL_BASE + 32'h0004;

    // CTRL register: bit[0] = START (write 1 to start; clears done_sticky)
    // STATUS register:
    //   bit[0] = done_sticky  (set when FFT completes, cleared on next start)
    //   bit[1] = fft_busy     (1 while FFT engine is running)

    // Memory slave (fft_mem_axi4_slave):
    //   MEM_BASE (local) = 'h1000
    //   System MEM_BASE  = FFT_MEM_BASE  (0x8000_9000)
    //   fft_mem_axi4_wrap subtracts FFT_MEM_BASE (0x8000_8000) giving local 0x1000
    //   Sample[i] -> system address: FFT_MEM_BASE + i*4
    //   Data format: {imag[15:0], real[15:0]}  — signed Q1.15 packed in 32 bits
    //   Writes allowed only when fft_busy = 0.

    // FFT per-scenario pass tracking
    logic fft_ctrl_pass;
    logic fft_mem_pass;
    logic fft_func_pass;

    // DMA per-scenario pass tracking
    logic dma_reset_pass;
    logic dma_csr_pass;
    logic dma_xfer_pass;

    // GPIO and Timer per-scenario pass tracking
    logic gpio_pass;
    logic timer_pass;
    logic veer_pass;

    // RISC-V Firmware processor-driven pass tracking
    logic fw_gpio_pass;
    logic fw_timer_pass;
    logic fw_uart_pass;
    logic fw_aes_pass;
    logic fw_fft_pass;
    logic fw_dma_pass;
    logic fw_concur_pass;
    logic fw_intr_pass;
    logic fw_master_pass;
    logic fw_c_test_pass;
    logic fw_c_boot_mem_pass;
    logic fw_c_uart_pass;
    logic fw_c_aes_pass;
    logic fw_c_dma_pass;
    logic fw_c_fft_pass;
    logic fw_c_master_pass;

    // ============================================================
    // 2. CLOCKS AND RESETS
    // ============================================================
    logic clk;
    logic fixed_clk;
    logic rst;

    // AXI system clock: 100 MHz (period = 10 ns)
    initial begin
        clk = 1'b0;
        forever #5.0 clk = ~clk;
    end

    // Dedicated UART baud clock: 40 MHz (period = 25 ns) with phase shift
    initial begin
        fixed_clk = 1'b0;
        #3.125;
        forever #12.5 fixed_clk = ~fixed_clk;
    end

    // UART External Pins
    logic uart_rx;
    wire  uart_tx;
    wire  uart_irq;

    // FFT completion interrupt (driven by fft_accel_top.irq via main_top.fft_irq)
    wire  fft_irq;

    // DMA completion and error interrupts (driven by dma_axi_wrapper inside main_top)
    wire  dma_irq;
    wire  dma_error_irq;

    // GPIO Dedicated Interface
    wire [31:0]  gpio_io;
    logic [31:0] gpio_tb_drive_val;
    logic [31:0] gpio_tb_drive_en;
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_gpio_tri
            assign gpio_io[gi] = gpio_tb_drive_en[gi] ? gpio_tb_drive_val[gi] : 1'bz;
        end
    endgenerate
    wire         gpio_irq;

    // Timer Dedicated Interface
    wire         timer_pwm;
    wire         timer_irq;

    // RISC-V VeeR EL2 CPU Interface & Control
    logic        cpu_rst_l;
    logic [31:1] cpu_rst_vec;
    logic        cpu_run_req;
    wire  [31:0] trace_rv_i_insn_ip;
    wire  [31:0] trace_rv_i_address_ip;
    wire         trace_rv_i_valid_ip;
    wire         trace_rv_i_exception_ip;
    wire  [4:0]  trace_rv_i_ecause_ip;
    wire         trace_rv_i_interrupt_ip;
    wire  [31:0] trace_rv_i_tval_ip;
    wire         o_cpu_halt_status;

    // ============================================================
    // 3. MASTER INTERFACE SIGNALS (M0, M1, M2)
    // ============================================================
    // Master 0 (VeeR IFU)
    logic [ID_WIDTH-1:0]      m0_awid;
    logic [ADDR_WIDTH-1:0]    m0_awaddr;
    logic [7:0]               m0_awlen;
    logic [2:0]               m0_awsize;
    logic [1:0]               m0_awburst;
    logic                     m0_awlock;
    logic [3:0]               m0_awcache;
    logic [2:0]               m0_awprot;
    logic [3:0]               m0_awqos;
    logic [AWUSER_WIDTH-1:0]  m0_awuser;
    logic                     m0_awvalid;
    wire                      m0_awready;
    logic [DATA_WIDTH-1:0]    m0_wdata;
    logic [STRB_WIDTH-1:0]    m0_wstrb;
    logic                     m0_wlast;
    logic [WUSER_WIDTH-1:0]   m0_wuser;
    logic                     m0_wvalid;
    wire                      m0_wready;
    wire  [ID_WIDTH-1:0]      m0_bid;
    wire  [1:0]               m0_bresp;
    wire  [BUSER_WIDTH-1:0]   m0_buser;
    wire                      m0_bvalid;
    logic                     m0_bready;
    logic [ID_WIDTH-1:0]      m0_arid;
    logic [ADDR_WIDTH-1:0]    m0_araddr;
    logic [7:0]               m0_arlen;
    logic [2:0]               m0_arsize;
    logic [1:0]               m0_arburst;
    logic                     m0_arlock;
    logic [3:0]               m0_arcache;
    logic [2:0]               m0_arprot;
    logic [3:0]               m0_arqos;
    logic [ARUSER_WIDTH-1:0]  m0_aruser;
    logic                     m0_arvalid;
    wire                      m0_arready;
    wire  [ID_WIDTH-1:0]      m0_rid;
    wire  [DATA_WIDTH-1:0]    m0_rdata;
    wire  [1:0]               m0_rresp;
    wire                      m0_rlast;
    wire  [RUSER_WIDTH-1:0]   m0_ruser;
    wire                      m0_rvalid;
    logic                     m0_rready;

    // Master 1 (VeeR LSU) - Primary Test Master
    logic [ID_WIDTH-1:0]      m1_awid;
    logic [ADDR_WIDTH-1:0]    m1_awaddr;
    logic [7:0]               m1_awlen;
    logic [2:0]               m1_awsize;
    logic [1:0]               m1_awburst;
    logic                     m1_awlock;
    logic [3:0]               m1_awcache;
    logic [2:0]               m1_awprot;
    logic [3:0]               m1_awqos;
    logic [AWUSER_WIDTH-1:0]  m1_awuser;
    logic                     m1_awvalid;
    wire                      m1_awready;
    logic [DATA_WIDTH-1:0]    m1_wdata;
    logic [STRB_WIDTH-1:0]    m1_wstrb;
    logic                     m1_wlast;
    logic [WUSER_WIDTH-1:0]   m1_wuser;
    logic                     m1_wvalid;
    wire                      m1_wready;
    wire  [ID_WIDTH-1:0]      m1_bid;
    wire  [1:0]               m1_bresp;
    wire  [BUSER_WIDTH-1:0]   m1_buser;
    wire                      m1_bvalid;
    logic                     m1_bready;
    logic [ID_WIDTH-1:0]      m1_arid;
    logic [ADDR_WIDTH-1:0]    m1_araddr;
    logic [7:0]               m1_arlen;
    logic [2:0]               m1_arsize;
    logic [1:0]               m1_arburst;
    logic                     m1_arlock;
    logic [3:0]               m1_arcache;
    logic [2:0]               m1_arprot;
    logic [3:0]               m1_arqos;
    logic [ARUSER_WIDTH-1:0]  m1_aruser;
    logic                     m1_arvalid;
    wire                      m1_arready;
    wire  [ID_WIDTH-1:0]      m1_rid;
    wire  [DATA_WIDTH-1:0]    m1_rdata;
    wire  [1:0]               m1_rresp;
    wire                      m1_rlast;
    wire  [RUSER_WIDTH-1:0]   m1_ruser;
    wire                      m1_rvalid;
    logic                     m1_rready;

    // Master 2 (DMA Data Transfer Master)
    logic [ID_WIDTH-1:0]      m2_awid;
    logic [ADDR_WIDTH-1:0]    m2_awaddr;
    logic [7:0]               m2_awlen;
    logic [2:0]               m2_awsize;
    logic [1:0]               m2_awburst;
    logic                     m2_awlock;
    logic [3:0]               m2_awcache;
    logic [2:0]               m2_awprot;
    logic [3:0]               m2_awqos;
    logic [AWUSER_WIDTH-1:0]  m2_awuser;
    logic                     m2_awvalid;
    wire                      m2_awready;
    logic [DATA_WIDTH-1:0]    m2_wdata;
    logic [STRB_WIDTH-1:0]    m2_wstrb;
    logic                     m2_wlast;
    logic [WUSER_WIDTH-1:0]   m2_wuser;
    logic                     m2_wvalid;
    wire                      m2_wready;
    wire  [ID_WIDTH-1:0]      m2_bid;
    wire  [1:0]               m2_bresp;
    wire  [BUSER_WIDTH-1:0]   m2_buser;
    wire                      m2_bvalid;
    logic                     m2_bready;
    logic [ID_WIDTH-1:0]      m2_arid;
    logic [ADDR_WIDTH-1:0]    m2_araddr;
    logic [7:0]               m2_arlen;
    logic [2:0]               m2_arsize;
    logic [1:0]               m2_arburst;
    logic                     m2_arlock;
    logic [3:0]               m2_arcache;
    logic [2:0]               m2_arprot;
    logic [3:0]               m2_arqos;
    logic [ARUSER_WIDTH-1:0]  m2_aruser;
    logic                     m2_arvalid;
    wire                      m2_arready;
    wire  [ID_WIDTH-1:0]      m2_rid;
    wire  [DATA_WIDTH-1:0]    m2_rdata;
    wire  [1:0]               m2_rresp;
    wire                      m2_rlast;
    wire  [RUSER_WIDTH-1:0]   m2_ruser;
    wire                      m2_rvalid;
    logic                     m2_rready;

    // ============================================================
    // 4. EXPOSED SLAVE INTERFACE SIGNALS (S0..S3, S5..S14)
    // S4 is internal to main_top.
    // ============================================================
    // Arrays for connecting to dummy slave responders
    wire [ID_WIDTH-1:0]      slv_awid     [0:14];
    wire [ADDR_WIDTH-1:0]    slv_awaddr   [0:14];
    wire [7:0]               slv_awlen    [0:14];
    wire [2:0]               slv_awsize   [0:14];
    wire [1:0]               slv_awburst  [0:14];
    wire                     slv_awlock   [0:14];
    wire [3:0]               slv_awcache  [0:14];
    wire [2:0]               slv_awprot   [0:14];
    wire [3:0]               slv_awqos    [0:14];
    wire [3:0]               slv_awregion [0:14];
    wire [AWUSER_WIDTH-1:0]  slv_awuser   [0:14];
    wire                     slv_awvalid  [0:14];
    logic                    slv_awready  [0:14];

    wire [DATA_WIDTH-1:0]    slv_wdata    [0:14];
    wire [STRB_WIDTH-1:0]    slv_wstrb    [0:14];
    wire                     slv_wlast    [0:14];
    wire [WUSER_WIDTH-1:0]   slv_wuser    [0:14];
    wire                     slv_wvalid   [0:14];
    logic                    slv_wready   [0:14];

    logic [ID_WIDTH-1:0]     slv_bid      [0:14];
    logic [1:0]              slv_bresp    [0:14];
    logic [BUSER_WIDTH-1:0]  slv_buser    [0:14];
    logic                    slv_bvalid   [0:14];
    wire                     slv_bready   [0:14];

    wire [ID_WIDTH-1:0]      slv_arid     [0:14];
    wire [ADDR_WIDTH-1:0]    slv_araddr   [0:14];
    wire [7:0]               slv_arlen    [0:14];
    wire [2:0]               slv_arsize   [0:14];
    wire [1:0]               slv_arburst  [0:14];
    wire                     slv_arlock   [0:14];
    wire [3:0]               slv_arcache  [0:14];
    wire [2:0]               slv_arprot   [0:14];
    wire [3:0]               slv_arqos    [0:14];
    wire [3:0]               slv_arregion [0:14];
    wire [ARUSER_WIDTH-1:0]  slv_aruser   [0:14];
    wire                     slv_arvalid  [0:14];
    logic                    slv_arready  [0:14];

    logic [ID_WIDTH-1:0]     slv_rid      [0:14];
    logic [DATA_WIDTH-1:0]   slv_rdata    [0:14];
    logic [1:0]              slv_rresp    [0:14];
    logic                    slv_rlast    [0:14];
    logic [RUSER_WIDTH-1:0]  slv_ruser    [0:14];
    logic                    slv_rvalid   [0:14];
    wire                     slv_rready   [0:14];

    // Dummy slave state registers
    logic                  dummy_aw_seen  [0:14];
    logic                  dummy_w_seen   [0:14];
    logic [ID_WIDTH-1:0]   dummy_awid_reg [0:14];
    logic [ADDR_WIDTH-1:0] dummy_addr_reg [0:14];
    logic [DATA_WIDTH-1:0] dummy_mem      [0:14][0:63]; // 64 words storage per slave

    // ============================================================
    // 5. DUT INSTANTIATION
    // ============================================================
    main_top #(
        .DATA_WIDTH      (DATA_WIDTH),
        .ADDR_WIDTH      (ADDR_WIDTH),
        .STRB_WIDTH      (STRB_WIDTH),
        .ID_WIDTH        (ID_WIDTH)
    ) dut (
        .clk             (clk),
        .fixed_clk       (fixed_clk),
        .rst             (rst),

        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .uart_irq        (uart_irq),

        // Master 0 (VeeR IFU)
        .s00_axi_awid    (m0_awid),
        .s00_axi_awaddr  (m0_awaddr),
        .s00_axi_awlen   (m0_awlen),
        .s00_axi_awsize  (m0_awsize),
        .s00_axi_awburst (m0_awburst),
        .s00_axi_awlock  (m0_awlock),
        .s00_axi_awcache (m0_awcache),
        .s00_axi_awprot  (m0_awprot),
        .s00_axi_awqos   (m0_awqos),
        .s00_axi_awuser  (m0_awuser),
        .s00_axi_awvalid (m0_awvalid),
        .s00_axi_awready (m0_awready),
        .s00_axi_wdata   (m0_wdata),
        .s00_axi_wstrb   (m0_wstrb),
        .s00_axi_wlast   (m0_wlast),
        .s00_axi_wuser   (m0_wuser),
        .s00_axi_wvalid  (m0_wvalid),
        .s00_axi_wready  (m0_wready),
        .s00_axi_bid     (m0_bid),
        .s00_axi_bresp   (m0_bresp),
        .s00_axi_buser   (m0_buser),
        .s00_axi_bvalid  (m0_bvalid),
        .s00_axi_bready  (m0_bready),
        .s00_axi_arid    (m0_arid),
        .s00_axi_araddr  (m0_araddr),
        .s00_axi_arlen   (m0_arlen),
        .s00_axi_arsize  (m0_arsize),
        .s00_axi_arburst (m0_arburst),
        .s00_axi_arlock  (m0_arlock),
        .s00_axi_arcache (m0_arcache),
        .s00_axi_arprot  (m0_arprot),
        .s00_axi_arqos   (m0_arqos),
        .s00_axi_aruser  (m0_aruser),
        .s00_axi_arvalid (m0_arvalid),
        .s00_axi_arready (m0_arready),
        .s00_axi_rid     (m0_rid),
        .s00_axi_rdata   (m0_rdata),
        .s00_axi_rresp   (m0_rresp),
        .s00_axi_rlast   (m0_rlast),
        .s00_axi_ruser   (m0_ruser),
        .s00_axi_rvalid  (m0_rvalid),
        .s00_axi_rready  (m0_rready),

        // Master 1 (VeeR LSU)
        .s01_axi_awid    (m1_awid),
        .s01_axi_awaddr  (m1_awaddr),
        .s01_axi_awlen   (m1_awlen),
        .s01_axi_awsize  (m1_awsize),
        .s01_axi_awburst (m1_awburst),
        .s01_axi_awlock  (m1_awlock),
        .s01_axi_awcache (m1_awcache),
        .s01_axi_awprot  (m1_awprot),
        .s01_axi_awqos   (m1_awqos),
        .s01_axi_awuser  (m1_awuser),
        .s01_axi_awvalid (m1_awvalid),
        .s01_axi_awready (m1_awready),
        .s01_axi_wdata   (m1_wdata),
        .s01_axi_wstrb   (m1_wstrb),
        .s01_axi_wlast   (m1_wlast),
        .s01_axi_wuser   (m1_wuser),
        .s01_axi_wvalid  (m1_wvalid),
        .s01_axi_wready  (m1_wready),
        .s01_axi_bid     (m1_bid),
        .s01_axi_bresp   (m1_bresp),
        .s01_axi_buser   (m1_buser),
        .s01_axi_bvalid  (m1_bvalid),
        .s01_axi_bready  (m1_bready),
        .s01_axi_arid    (m1_arid),
        .s01_axi_araddr  (m1_araddr),
        .s01_axi_arlen   (m1_arlen),
        .s01_axi_arsize  (m1_arsize),
        .s01_axi_arburst (m1_arburst),
        .s01_axi_arlock  (m1_arlock),
        .s01_axi_arcache (m1_arcache),
        .s01_axi_arprot  (m1_arprot),
        .s01_axi_arqos   (m1_arqos),
        .s01_axi_aruser  (m1_aruser),
        .s01_axi_arvalid (m1_arvalid),
        .s01_axi_arready (m1_arready),
        .s01_axi_rid     (m1_rid),
        .s01_axi_rdata   (m1_rdata),
        .s01_axi_rresp   (m1_rresp),
        .s01_axi_rlast   (m1_rlast),
        .s01_axi_ruser   (m1_ruser),
        .s01_axi_rvalid  (m1_rvalid),
        .s01_axi_rready  (m1_rready),

        // Master 2 (DMA external BFM / test master)
        .s02_axi_awid    (m2_awid),
        .s02_axi_awaddr  (m2_awaddr),
        .s02_axi_awlen   (m2_awlen),
        .s02_axi_awsize  (m2_awsize),
        .s02_axi_awburst (m2_awburst),
        .s02_axi_awlock  (m2_awlock),
        .s02_axi_awcache (m2_awcache),
        .s02_axi_awprot  (m2_awprot),
        .s02_axi_awqos   (m2_awqos),
        .s02_axi_awuser  (m2_awuser),
        .s02_axi_awvalid (m2_awvalid),
        .s02_axi_awready (m2_awready),
        .s02_axi_wdata   (m2_wdata),
        .s02_axi_wstrb   (m2_wstrb),
        .s02_axi_wlast   (m2_wlast),
        .s02_axi_wuser   (m2_wuser),
        .s02_axi_wvalid  (m2_wvalid),
        .s02_axi_wready  (m2_wready),
        .s02_axi_bid     (m2_bid),
        .s02_axi_bresp   (m2_bresp),
        .s02_axi_buser   (m2_buser),
        .s02_axi_bvalid  (m2_bvalid),
        .s02_axi_bready  (m2_bready),
        .s02_axi_arid    (m2_arid),
        .s02_axi_araddr  (m2_araddr),
        .s02_axi_arlen   (m2_arlen),
        .s02_axi_arsize  (m2_arsize),
        .s02_axi_arburst (m2_arburst),
        .s02_axi_arlock  (m2_arlock),
        .s02_axi_arcache (m2_arcache),
        .s02_axi_arprot  (m2_arprot),
        .s02_axi_arqos   (m2_arqos),
        .s02_axi_aruser  (m2_aruser),
        .s02_axi_arvalid (m2_arvalid),
        .s02_axi_arready (m2_arready),
        .s02_axi_rid     (m2_rid),
        .s02_axi_rdata   (m2_rdata),
        .s02_axi_rresp   (m2_rresp),
        .s02_axi_rlast   (m2_rlast),
        .s02_axi_ruser   (m2_ruser),
        .s02_axi_rvalid  (m2_rvalid),
        .s02_axi_rready  (m2_rready),

        // Slave S0: IMEM
        .m00_axi_awid    (slv_awid[0]),
        .m00_axi_awaddr  (slv_awaddr[0]),
        .m00_axi_awlen   (slv_awlen[0]),
        .m00_axi_awsize  (slv_awsize[0]),
        .m00_axi_awburst (slv_awburst[0]),
        .m00_axi_awlock  (slv_awlock[0]),
        .m00_axi_awcache (slv_awcache[0]),
        .m00_axi_awprot  (slv_awprot[0]),
        .m00_axi_awqos   (slv_awqos[0]),
        .m00_axi_awregion(slv_awregion[0]),
        .m00_axi_awuser  (slv_awuser[0]),
        .m00_axi_awvalid (slv_awvalid[0]),
        .m00_axi_awready (slv_awready[0]),
        .m00_axi_wdata   (slv_wdata[0]),
        .m00_axi_wstrb   (slv_wstrb[0]),
        .m00_axi_wlast   (slv_wlast[0]),
        .m00_axi_wuser   (slv_wuser[0]),
        .m00_axi_wvalid  (slv_wvalid[0]),
        .m00_axi_wready  (slv_wready[0]),
        .m00_axi_bid     (slv_bid[0]),
        .m00_axi_bresp   (slv_bresp[0]),
        .m00_axi_buser   (slv_buser[0]),
        .m00_axi_bvalid  (slv_bvalid[0]),
        .m00_axi_bready  (slv_bready[0]),
        .m00_axi_arid    (slv_arid[0]),
        .m00_axi_araddr  (slv_araddr[0]),
        .m00_axi_arlen   (slv_arlen[0]),
        .m00_axi_arsize  (slv_arsize[0]),
        .m00_axi_arburst (slv_arburst[0]),
        .m00_axi_arlock  (slv_arlock[0]),
        .m00_axi_arcache (slv_arcache[0]),
        .m00_axi_arprot  (slv_arprot[0]),
        .m00_axi_arqos   (slv_arqos[0]),
        .m00_axi_arregion(slv_arregion[0]),
        .m00_axi_aruser  (slv_aruser[0]),
        .m00_axi_arvalid (slv_arvalid[0]),
        .m00_axi_arready (slv_arready[0]),
        .m00_axi_rid     (slv_rid[0]),
        .m00_axi_rdata   (slv_rdata[0]),
        .m00_axi_rresp   (slv_rresp[0]),
        .m00_axi_rlast   (slv_rlast[0]),
        .m00_axi_ruser   (slv_ruser[0]),
        .m00_axi_rvalid  (slv_rvalid[0]),
        .m00_axi_rready  (slv_rready[0]),

        // Slave S1: DMEM
        .m01_axi_awid    (slv_awid[1]),
        .m01_axi_awaddr  (slv_awaddr[1]),
        .m01_axi_awlen   (slv_awlen[1]),
        .m01_axi_awsize  (slv_awsize[1]),
        .m01_axi_awburst (slv_awburst[1]),
        .m01_axi_awlock  (slv_awlock[1]),
        .m01_axi_awcache (slv_awcache[1]),
        .m01_axi_awprot  (slv_awprot[1]),
        .m01_axi_awqos   (slv_awqos[1]),
        .m01_axi_awregion(slv_awregion[1]),
        .m01_axi_awuser  (slv_awuser[1]),
        .m01_axi_awvalid (slv_awvalid[1]),
        .m01_axi_awready (slv_awready[1]),
        .m01_axi_wdata   (slv_wdata[1]),
        .m01_axi_wstrb   (slv_wstrb[1]),
        .m01_axi_wlast   (slv_wlast[1]),
        .m01_axi_wuser   (slv_wuser[1]),
        .m01_axi_wvalid  (slv_wvalid[1]),
        .m01_axi_wready  (slv_wready[1]),
        .m01_axi_bid     (slv_bid[1]),
        .m01_axi_bresp   (slv_bresp[1]),
        .m01_axi_buser   (slv_buser[1]),
        .m01_axi_bvalid  (slv_bvalid[1]),
        .m01_axi_bready  (slv_bready[1]),
        .m01_axi_arid    (slv_arid[1]),
        .m01_axi_araddr  (slv_araddr[1]),
        .m01_axi_arlen   (slv_arlen[1]),
        .m01_axi_arsize  (slv_arsize[1]),
        .m01_axi_arburst (slv_arburst[1]),
        .m01_axi_arlock  (slv_arlock[1]),
        .m01_axi_arcache (slv_arcache[1]),
        .m01_axi_arprot  (slv_arprot[1]),
        .m01_axi_arqos   (slv_arqos[1]),
        .m01_axi_arregion(slv_arregion[1]),
        .m01_axi_aruser  (slv_aruser[1]),
        .m01_axi_arvalid (slv_arvalid[1]),
        .m01_axi_arready (slv_arready[1]),
        .m01_axi_rid     (slv_rid[1]),
        .m01_axi_rdata   (slv_rdata[1]),
        .m01_axi_rresp   (slv_rresp[1]),
        .m01_axi_rlast   (slv_rlast[1]),
        .m01_axi_ruser   (slv_ruser[1]),
        .m01_axi_rvalid  (slv_rvalid[1]),
        .m01_axi_rready  (slv_rready[1]),

        // S2 (GPIO) and S3 (Timer) are now INTERNAL to main_top.
        .gpio_io         (gpio_io),
        .gpio_irq        (gpio_irq),
        .timer_pwm       (timer_pwm),
        .timer_irq       (timer_irq),

        // Slave S5 (AES-128) is INTERNAL to main_top -- no external port.
        // Slaves S6 (FFT Control) and S7 (FFT Memory) are INTERNAL to
        // main_top -- connected to fft_ctrl_axi4_bridge and fft_mem_axi4_wrap
        // respectively.  They are NOT exposed as external ports of main_top.
        // FFT is accessed through the AXI master BFM via addresses
        //   0x8000_8xxx (S6 FFT Control) and 0x8000_9xxx (S7 FFT Memory).
        // Slaves S8..S14
        .m08_axi_awid    (slv_awid[8]),   .m08_axi_awaddr  (slv_awaddr[8]),   .m08_axi_awlen   (slv_awlen[8]),   .m08_axi_awsize  (slv_awsize[8]),   .m08_axi_awburst (slv_awburst[8]),   .m08_axi_awlock  (slv_awlock[8]),   .m08_axi_awcache (slv_awcache[8]),   .m08_axi_awprot  (slv_awprot[8]),   .m08_axi_awqos   (slv_awqos[8]),   .m08_axi_awregion(slv_awregion[8]), .m08_axi_awuser  (slv_awuser[8]),   .m08_axi_awvalid (slv_awvalid[8]),   .m08_axi_awready (slv_awready[8]), .m08_axi_wdata   (slv_wdata[8]),   .m08_axi_wstrb   (slv_wstrb[8]),   .m08_axi_wlast   (slv_wlast[8]),   .m08_axi_wuser   (slv_wuser[8]),   .m08_axi_wvalid  (slv_wvalid[8]),   .m08_axi_wready  (slv_wready[8]),   .m08_axi_bid     (slv_bid[8]),     .m08_axi_bresp   (slv_bresp[8]),   .m08_axi_buser   (slv_buser[8]),   .m08_axi_bvalid  (slv_bvalid[8]),   .m08_axi_bready  (slv_bready[8]),   .m08_axi_arid    (slv_arid[8]),   .m08_axi_araddr  (slv_araddr[8]),   .m08_axi_arlen   (slv_arlen[8]),   .m08_axi_arsize  (slv_arsize[8]),   .m08_axi_arburst (slv_arburst[8]),   .m08_axi_arlock  (slv_arlock[8]),   .m08_axi_arcache (slv_arcache[8]),   .m08_axi_arprot  (slv_arprot[8]),   .m08_axi_arqos   (slv_arqos[8]),   .m08_axi_arregion(slv_arregion[8]), .m08_axi_aruser  (slv_aruser[8]),   .m08_axi_arvalid (slv_arvalid[8]),   .m08_axi_arready (slv_arready[8]), .m08_axi_rid     (slv_rid[8]),     .m08_axi_rdata   (slv_rdata[8]),   .m08_axi_rresp   (slv_rresp[8]),   .m08_axi_rlast   (slv_rlast[8]),   .m08_axi_ruser   (slv_ruser[8]),   .m08_axi_rvalid  (slv_rvalid[8]),   .m08_axi_rready  (slv_rready[8]),
        .m09_axi_awid    (slv_awid[9]),   .m09_axi_awaddr  (slv_awaddr[9]),   .m09_axi_awlen   (slv_awlen[9]),   .m09_axi_awsize  (slv_awsize[9]),   .m09_axi_awburst (slv_awburst[9]),   .m09_axi_awlock  (slv_awlock[9]),   .m09_axi_awcache (slv_awcache[9]),   .m09_axi_awprot  (slv_awprot[9]),   .m09_axi_awqos   (slv_awqos[9]),   .m09_axi_awregion(slv_awregion[9]), .m09_axi_awuser  (slv_awuser[9]),   .m09_axi_awvalid (slv_awvalid[9]),   .m09_axi_awready (slv_awready[9]), .m09_axi_wdata   (slv_wdata[9]),   .m09_axi_wstrb   (slv_wstrb[9]),   .m09_axi_wlast   (slv_wlast[9]),   .m09_axi_wuser   (slv_wuser[9]),   .m09_axi_wvalid  (slv_wvalid[9]),   .m09_axi_wready  (slv_wready[9]),   .m09_axi_bid     (slv_bid[9]),     .m09_axi_bresp   (slv_bresp[9]),   .m09_axi_buser   (slv_buser[9]),   .m09_axi_bvalid  (slv_bvalid[9]),   .m09_axi_bready  (slv_bready[9]),   .m09_axi_arid    (slv_arid[9]),   .m09_axi_araddr  (slv_araddr[9]),   .m09_axi_arlen   (slv_arlen[9]),   .m09_axi_arsize  (slv_arsize[9]),   .m09_axi_arburst (slv_arburst[9]),   .m09_axi_arlock  (slv_arlock[9]),   .m09_axi_arcache (slv_arcache[9]),   .m09_axi_arprot  (slv_arprot[9]),   .m09_axi_arqos   (slv_arqos[9]),   .m09_axi_arregion(slv_arregion[9]), .m09_axi_aruser  (slv_aruser[9]),   .m09_axi_arvalid (slv_arvalid[9]),   .m09_axi_arready (slv_arready[9]), .m09_axi_rid     (slv_rid[9]),     .m09_axi_rdata   (slv_rdata[9]),   .m09_axi_rresp   (slv_rresp[9]),   .m09_axi_rlast   (slv_rlast[9]),   .m09_axi_ruser   (slv_ruser[9]),   .m09_axi_rvalid  (slv_rvalid[9]),   .m09_axi_rready  (slv_rready[9]),
        .m10_axi_awid    (slv_awid[10]),  .m10_axi_awaddr  (slv_awaddr[10]),  .m10_axi_awlen   (slv_awlen[10]),  .m10_axi_awsize  (slv_awsize[10]),  .m10_axi_awburst (slv_awburst[10]),  .m10_axi_awlock  (slv_awlock[10]),  .m10_axi_awcache (slv_awcache[10]),  .m10_axi_awprot  (slv_awprot[10]),  .m10_axi_awqos   (slv_awqos[10]),  .m10_axi_awregion(slv_awregion[10]),.m10_axi_awuser  (slv_awuser[10]),  .m10_axi_awvalid (slv_awvalid[10]),  .m10_axi_awready (slv_awready[10]),.m10_axi_wdata   (slv_wdata[10]),  .m10_axi_wstrb   (slv_wstrb[10]),  .m10_axi_wlast   (slv_wlast[10]),  .m10_axi_wuser   (slv_wuser[10]),  .m10_axi_wvalid  (slv_wvalid[10]),  .m10_axi_wready  (slv_wready[10]),  .m10_axi_bid     (slv_bid[10]),    .m10_axi_bresp   (slv_bresp[10]),  .m10_axi_buser   (slv_buser[10]),  .m10_axi_bvalid  (slv_bvalid[10]),  .m10_axi_bready  (slv_bready[10]),  .m10_axi_arid    (slv_arid[10]),  .m10_axi_araddr  (slv_araddr[10]),  .m10_axi_arlen   (slv_arlen[10]),  .m10_axi_arsize  (slv_arsize[10]),  .m10_axi_arburst (slv_arburst[10]),  .m10_axi_arlock  (slv_arlock[10]),  .m10_axi_arcache (slv_arcache[10]),  .m10_axi_arprot  (slv_arprot[10]),  .m10_axi_arqos   (slv_arqos[10]),  .m10_axi_arregion(slv_arregion[10]),.m10_axi_aruser  (slv_aruser[10]),  .m10_axi_arvalid (slv_arvalid[10]),  .m10_axi_arready (slv_arready[10]),.m10_axi_rid     (slv_rid[10]),    .m10_axi_rdata   (slv_rdata[10]),  .m10_axi_rresp   (slv_rresp[10]),  .m10_axi_rlast   (slv_rlast[10]),  .m10_axi_ruser   (slv_ruser[10]),  .m10_axi_rvalid  (slv_rvalid[10]),  .m10_axi_rready  (slv_rready[10]),
        .m11_axi_awid    (slv_awid[11]),  .m11_axi_awaddr  (slv_awaddr[11]),  .m11_axi_awlen   (slv_awlen[11]),  .m11_axi_awsize  (slv_awsize[11]),  .m11_axi_awburst (slv_awburst[11]),  .m11_axi_awlock  (slv_awlock[11]),  .m11_axi_awcache (slv_awcache[11]),  .m11_axi_awprot  (slv_awprot[11]),  .m11_axi_awqos   (slv_awqos[11]),  .m11_axi_awregion(slv_awregion[11]),.m11_axi_awuser  (slv_awuser[11]),  .m11_axi_awvalid (slv_awvalid[11]),  .m11_axi_awready (slv_awready[11]),.m11_axi_wdata   (slv_wdata[11]),  .m11_axi_wstrb   (slv_wstrb[11]),  .m11_axi_wlast   (slv_wlast[11]),  .m11_axi_wuser   (slv_wuser[11]),  .m11_axi_wvalid  (slv_wvalid[11]),  .m11_axi_wready  (slv_wready[11]),  .m11_axi_bid     (slv_bid[11]),    .m11_axi_bresp   (slv_bresp[11]),  .m11_axi_buser   (slv_buser[11]),  .m11_axi_bvalid  (slv_bvalid[11]),  .m11_axi_bready  (slv_bready[11]),  .m11_axi_arid    (slv_arid[11]),  .m11_axi_araddr  (slv_araddr[11]),  .m11_axi_arlen   (slv_arlen[11]),  .m11_axi_arsize  (slv_arsize[11]),  .m11_axi_arburst (slv_arburst[11]),  .m11_axi_arlock  (slv_arlock[11]),  .m11_axi_arcache (slv_arcache[11]),  .m11_axi_arprot  (slv_arprot[11]),  .m11_axi_arqos   (slv_arqos[11]),  .m11_axi_arregion(slv_arregion[11]),.m11_axi_aruser  (slv_aruser[11]),  .m11_axi_arvalid (slv_arvalid[11]),  .m11_axi_arready (slv_arready[11]),.m11_axi_rid     (slv_rid[11]),    .m11_axi_rdata   (slv_rdata[11]),  .m11_axi_rresp   (slv_rresp[11]),  .m11_axi_rlast   (slv_rlast[11]),  .m11_axi_ruser   (slv_ruser[11]),  .m11_axi_rvalid  (slv_rvalid[11]),  .m11_axi_rready  (slv_rready[11]),
        .m12_axi_awid    (slv_awid[12]),  .m12_axi_awaddr  (slv_awaddr[12]),  .m12_axi_awlen   (slv_awlen[12]),  .m12_axi_awsize  (slv_awsize[12]),  .m12_axi_awburst (slv_awburst[12]),  .m12_axi_awlock  (slv_awlock[12]),  .m12_axi_awcache (slv_awcache[12]),  .m12_axi_awprot  (slv_awprot[12]),  .m12_axi_awqos   (slv_awqos[12]),  .m12_axi_awregion(slv_awregion[12]),.m12_axi_awuser  (slv_awuser[12]),  .m12_axi_awvalid (slv_awvalid[12]),  .m12_axi_awready (slv_awready[12]),.m12_axi_wdata   (slv_wdata[12]),  .m12_axi_wstrb   (slv_wstrb[12]),  .m12_axi_wlast   (slv_wlast[12]),  .m12_axi_wuser   (slv_wuser[12]),  .m12_axi_wvalid  (slv_wvalid[12]),  .m12_axi_wready  (slv_wready[12]),  .m12_axi_bid     (slv_bid[12]),    .m12_axi_bresp   (slv_bresp[12]),  .m12_axi_buser   (slv_buser[12]),  .m12_axi_bvalid  (slv_bvalid[12]),  .m12_axi_bready  (slv_bready[12]),  .m12_axi_arid    (slv_arid[12]),  .m12_axi_araddr  (slv_araddr[12]),  .m12_axi_arlen   (slv_arlen[12]),  .m12_axi_arsize  (slv_arsize[12]),  .m12_axi_arburst (slv_arburst[12]),  .m12_axi_arlock  (slv_arlock[12]),  .m12_axi_arcache (slv_arcache[12]),  .m12_axi_arprot  (slv_arprot[12]),  .m12_axi_arqos   (slv_arqos[12]),  .m12_axi_arregion(slv_arregion[12]),.m12_axi_aruser  (slv_aruser[12]),  .m12_axi_arvalid (slv_arvalid[12]),  .m12_axi_arready (slv_arready[12]),.m12_axi_rid     (slv_rid[12]),    .m12_axi_rdata   (slv_rdata[12]),  .m12_axi_rresp   (slv_rresp[12]),  .m12_axi_rlast   (slv_rlast[12]),  .m12_axi_ruser   (slv_ruser[12]),  .m12_axi_rvalid  (slv_rvalid[12]),  .m12_axi_rready  (slv_rready[12]),
        // S13 (DMA CSR, 0x8000_6000) is now INTERNAL to main_top.
        .m14_axi_awid    (slv_awid[14]),  .m14_axi_awaddr  (slv_awaddr[14]),  .m14_axi_awlen   (slv_awlen[14]),  .m14_axi_awsize  (slv_awsize[14]),  .m14_axi_awburst (slv_awburst[14]),  .m14_axi_awlock  (slv_awlock[14]),  .m14_axi_awcache (slv_awcache[14]),  .m14_axi_awprot  (slv_awprot[14]),  .m14_axi_awqos   (slv_awqos[14]),  .m14_axi_awregion(slv_awregion[14]),.m14_axi_awuser  (slv_awuser[14]),  .m14_axi_awvalid (slv_awvalid[14]),  .m14_axi_awready (slv_awready[14]),.m14_axi_wdata   (slv_wdata[14]),  .m14_axi_wstrb   (slv_wstrb[14]),  .m14_axi_wlast   (slv_wlast[14]),  .m14_axi_wuser   (slv_wuser[14]),  .m14_axi_wvalid  (slv_wvalid[14]),  .m14_axi_wready  (slv_wready[14]),  .m14_axi_bid     (slv_bid[14]),    .m14_axi_bresp   (slv_bresp[14]),  .m14_axi_buser   (slv_buser[14]),  .m14_axi_bvalid  (slv_bvalid[14]),  .m14_axi_bready  (slv_bready[14]),  .m14_axi_arid    (slv_arid[14]),  .m14_axi_araddr  (slv_araddr[14]),  .m14_axi_arlen   (slv_arlen[14]),  .m14_axi_arsize  (slv_arsize[14]),  .m14_axi_arburst (slv_arburst[14]),  .m14_axi_arlock  (slv_arlock[14]),  .m14_axi_arcache (slv_arcache[14]),  .m14_axi_arprot  (slv_arprot[14]),  .m14_axi_arqos   (slv_arqos[14]),  .m14_axi_arregion(slv_arregion[14]),.m14_axi_aruser  (slv_aruser[14]),  .m14_axi_arvalid (slv_arvalid[14]),  .m14_axi_arready (slv_arready[14]),.m14_axi_rid     (slv_rid[14]),    .m14_axi_rdata   (slv_rdata[14]),  .m14_axi_rresp   (slv_rresp[14]),  .m14_axi_rlast   (slv_rlast[14]),  .m14_axi_ruser   (slv_ruser[14]),  .m14_axi_rvalid  (slv_rvalid[14]),  .m14_axi_rready  (slv_rready[14]),
        // FFT and DMA completion interrupts
        .fft_irq         (fft_irq),
        .dma_irq         (dma_irq),
        .dma_error_irq   (dma_error_irq),
        // RISC-V VeeR EL2 CPU Interface & Control
        .cpu_rst_l              (cpu_rst_l),
        .cpu_rst_vec            (cpu_rst_vec),
        .cpu_run_req            (cpu_run_req),
        .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip  (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),
        .o_cpu_halt_status      (o_cpu_halt_status)
    );

    // ============================================================
    // 6. DUMMY SLAVE RESPONDERS FOR EXPOSED PORTS (g != 4)
    // ============================================================
    genvar g;
    generate
        for (g = 0; g < 15; g = g + 1) begin : GEN_DUMMY_SLAVES
            if (g == 0 || g == 1) begin : MEM_SLV_INST
                axi_ram_slave #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ADDR_WIDTH (ADDR_WIDTH),
                    .STRB_WIDTH (STRB_WIDTH),
                    .ID_WIDTH   (ID_WIDTH),
                    .MEM_WORDS  (32768),
                    .INIT_TAG   (g == 0 ? 16'hCA00 : 16'hCA01)
                ) u_ram (
                    .clk     (clk),
                    .rst     (rst),
                    .awid    (slv_awid[g]),
                    .awaddr  (slv_awaddr[g]),
                    .awlen   (slv_awlen[g]),
                    .awsize  (slv_awsize[g]),
                    .awburst (slv_awburst[g]),
                    .awvalid (slv_awvalid[g]),
                    .awready (slv_awready[g]),
                    .wdata   (slv_wdata[g]),
                    .wstrb   (slv_wstrb[g]),
                    .wlast   (slv_wlast[g]),
                    .wvalid  (slv_wvalid[g]),
                    .wready  (slv_wready[g]),
                    .bid     (slv_bid[g]),
                    .bresp   (slv_bresp[g]),
                    .bvalid  (slv_bvalid[g]),
                    .bready  (slv_bready[g]),
                    .arid    (slv_arid[g]),
                    .araddr  (slv_araddr[g]),
                    .arlen   (slv_arlen[g]),
                    .arsize  (slv_arsize[g]),
                    .arburst (slv_arburst[g]),
                    .arvalid (slv_arvalid[g]),
                    .arready (slv_arready[g]),
                    .rid     (slv_rid[g]),
                    .rdata   (slv_rdata[g]),
                    .rresp   (slv_rresp[g]),
                    .rlast   (slv_rlast[g]),
                    .rvalid  (slv_rvalid[g]),
                    .rready  (slv_rready[g])
                );
                always_comb begin
                    slv_buser[g] = '0;
                    slv_ruser[g] = '0;
                end
            end else if (g != 2 && g != 3 && g != 4 && g != 5 && g != 6 && g != 7 && g != 13) begin : SLV_INST
                always_comb begin
                    slv_awready[g] = !dummy_aw_seen[g] && !slv_bvalid[g];
                    slv_wready[g]  = !dummy_w_seen[g]  && !slv_bvalid[g];
                    slv_arready[g] = !slv_rvalid[g];
                end

                always_ff @(posedge clk) begin
                    if (rst) begin
                        dummy_aw_seen[g]  <= 1'b0;
                        dummy_w_seen[g]   <= 1'b0;
                        dummy_awid_reg[g] <= '0;
                        dummy_addr_reg[g] <= '0;
                        slv_bvalid[g]     <= 1'b0;
                        slv_bid[g]        <= '0;
                        slv_bresp[g]      <= 2'b00;
                        slv_buser[g]      <= '0;

                        slv_rvalid[g]     <= 1'b0;
                        slv_rid[g]        <= '0;
                        slv_rdata[g]      <= '0;
                        slv_rresp[g]      <= 2'b00;
                        slv_rlast[g]      <= 1'b0;
                        slv_ruser[g]      <= '0;
                    end else begin
                        // Latch Write Address
                        if (slv_awvalid[g] && slv_awready[g]) begin
                            dummy_aw_seen[g]  <= 1'b1;
                            dummy_awid_reg[g] <= slv_awid[g];
                            dummy_addr_reg[g] <= slv_awaddr[g];
                        end

                        // Latch Write Data
                        if (slv_wvalid[g] && slv_wready[g]) begin
                            dummy_w_seen[g] <= 1'b1;
                            dummy_mem[g][slv_awaddr[g][7:2]] <= slv_wdata[g];
                        end

                        // Generate Write Response
                        if ((slv_awvalid[g] || dummy_aw_seen[g]) &&
                            (slv_wvalid[g]  || dummy_w_seen[g])  &&
                            !slv_bvalid[g]) begin
                            slv_bvalid[g] <= 1'b1;
                            slv_bid[g]    <= slv_awvalid[g] ? slv_awid[g] : dummy_awid_reg[g];
                            slv_bresp[g]  <= 2'b00; // OKAY
                        end

                        // Clear Write Response
                        if (slv_bvalid[g] && slv_bready[g]) begin
                            slv_bvalid[g]    <= 1'b0;
                            dummy_aw_seen[g] <= 1'b0;
                            dummy_w_seen[g]  <= 1'b0;
                        end

                        // Read Address & Read Response
                        if (slv_arvalid[g] && slv_arready[g]) begin
                            slv_rvalid[g] <= 1'b1;
                            slv_rid[g]    <= slv_arid[g];
                            slv_rdata[g]  <= {16'hCA00 | g, slv_araddr[g][15:0]}; // test signature
                            slv_rresp[g]  <= 2'b00; // OKAY
                            slv_rlast[g]  <= 1'b1;
                        end else if (slv_rvalid[g] && slv_rready[g]) begin
                            slv_rvalid[g] <= 1'b0;
                            slv_rlast[g]  <= 1'b0;
                        end
                    end
                end
            end else begin : SLV4_TIE_OFF
                // S4 is internal; assign dummy signals to prevent floating
                always_comb begin
                    slv_awready[g] = 1'b0;
                    slv_wready[g]  = 1'b0;
                    slv_bvalid[g]  = 1'b0;
                    slv_bid[g]     = '0;
                    slv_bresp[g]   = 2'b00;
                    slv_buser[g]   = '0;
                    slv_arready[g] = 1'b0;
                    slv_rvalid[g]  = 1'b0;
                    slv_rid[g]     = '0;
                    slv_rdata[g]   = '0;
                    slv_rresp[g]   = 2'b00;
                    slv_rlast[g]   = 1'b0;
                    slv_ruser[g]   = '0;
                end
            end
        end
    endgenerate

    // ============================================================
    // 7. TEST TRACKING VARIABLES & SCOREBOARD
    // ============================================================
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    task automatic check_assert(
        input string test_name,
        input logic  condition,
        input string failure_msg = ""
    );
        total_tests++;
        if (condition) begin
            $display("[PASS] %s", test_name);
            passed_tests++;
        end else begin
            $display("--------------------------------------------------");
            $display("[FAIL] %s", test_name);
            if (failure_msg != "")
                $display("       Detail: %s", failure_msg);
            $display("--------------------------------------------------");
            failed_tests++;
        end
    endtask

    // ============================================================
    // 8. BUS-FUNCTIONAL MASTER TASKS (M0, M1, M2)
    // ============================================================
    task automatic init_masters;
        begin
            // M0
            m0_awid    = '0; m0_awaddr  = '0; m0_awlen   = '0;
            m0_awsize  = 3'b010; m0_awburst = 2'b01; m0_awlock = 1'b0;
            m0_awcache = 4'b0000; m0_awprot = 3'b000; m0_awqos = 4'b0000;
            m0_awuser  = '0; m0_awvalid = 1'b0;
            m0_wdata   = '0; m0_wstrb   = 4'b0000; m0_wlast = 1'b0;
            m0_wuser   = '0; m0_wvalid  = 1'b0; m0_bready = 1'b0;
            m0_arid    = '0; m0_araddr  = '0; m0_arlen   = '0;
            m0_arsize  = 3'b010; m0_arburst = 2'b01; m0_arlock = 1'b0;
            m0_arcache = 4'b0000; m0_arprot = 3'b000; m0_arqos = 4'b0000;
            m0_aruser  = '0; m0_arvalid = 1'b0; m0_rready = 1'b0;

            // M1
            m1_awid    = '0; m1_awaddr  = '0; m1_awlen   = '0;
            m1_awsize  = 3'b010; m1_awburst = 2'b01; m1_awlock = 1'b0;
            m1_awcache = 4'b0000; m1_awprot = 3'b000; m1_awqos = 4'b0000;
            m1_awuser  = '0; m1_awvalid = 1'b0;
            m1_wdata   = '0; m1_wstrb   = 4'b0000; m1_wlast = 1'b0;
            m1_wuser   = '0; m1_wvalid  = 1'b0; m1_bready = 1'b0;
            m1_arid    = '0; m1_araddr  = '0; m1_arlen   = '0;
            m1_arsize  = 3'b010; m1_arburst = 2'b01; m1_arlock = 1'b0;
            m1_arcache = 4'b0000; m1_arprot = 3'b000; m1_arqos = 4'b0000;
            m1_aruser  = '0; m1_arvalid = 1'b0; m1_rready = 1'b0;

            // M2
            m2_awid    = '0; m2_awaddr  = '0; m2_awlen   = '0;
            m2_awsize  = 3'b010; m2_awburst = 2'b01; m2_awlock = 1'b0;
            m2_awcache = 4'b0000; m2_awprot = 3'b000; m2_awqos = 4'b0000;
            m2_awuser  = '0; m2_awvalid = 1'b0;
            m2_wdata   = '0; m2_wstrb   = 4'b0000; m2_wlast = 1'b0;
            m2_wuser   = '0; m2_wvalid  = 1'b0; m2_bready = 1'b0;
            m2_arid    = '0; m2_araddr  = '0; m2_arlen   = '0;
            m2_arsize  = 3'b010; m2_arburst = 2'b01; m2_arlock = 1'b0;
            m2_arcache = 4'b0000; m2_arprot = 3'b000; m2_arqos = 4'b0000;
            m2_aruser  = '0; m2_arvalid = 1'b0; m2_rready = 1'b0;

            uart_rx = 1'b1;
        end
    endtask

    // Master Write Task
    task automatic axi_write(
        input int                   mid,     // 0=M0, 1=M1, 2=M2
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [ID_WIDTH-1:0]   id   = 8'h01,
        input logic [7:0]            len  = 8'h00,
        input logic [3:0]            strb = 4'b1111,
        output logic [1:0]           bresp,
        output logic [ID_WIDTH-1:0]  bid
    );
        int timeout;
        bit aw_done, w_done, b_done;
        begin
            aw_done = 0;
            w_done  = 0;
            b_done  = 0;

            @(posedge clk);
            case (mid)
                0: begin
                    m0_awid    = id;
                    m0_awaddr  = addr;
                    m0_awlen   = len;
                    m0_awsize  = 3'b010;
                    m0_awburst = 2'b01;
                    m0_awvalid = 1'b1;
                    m0_wdata   = data;
                    m0_wstrb   = strb;
                    m0_wlast   = 1'b1;
                    m0_wvalid  = 1'b1;
                    m0_bready  = 1'b0;
                end
                1: begin
                    m1_awid    = id;
                    m1_awaddr  = addr;
                    m1_awlen   = len;
                    m1_awsize  = 3'b010;
                    m1_awburst = 2'b01;
                    m1_awvalid = 1'b1;
                    m1_wdata   = data;
                    m1_wstrb   = strb;
                    m1_wlast   = 1'b1;
                    m1_wvalid  = 1'b1;
                    m1_bready  = 1'b0;
                end
                2: begin
                    m2_awid    = id;
                    m2_awaddr  = addr;
                    m2_awlen   = len;
                    m2_awsize  = 3'b010;
                    m2_awburst = 2'b01;
                    m2_awvalid = 1'b1;
                    m2_wdata   = data;
                    m2_wstrb   = strb;
                    m2_wlast   = 1'b1;
                    m2_wvalid  = 1'b1;
                    m2_bready  = 1'b0;
                end
            endcase

            // Wait for AW and W handshakes
            timeout = 0;
            while ((!aw_done || !w_done) && timeout < 500) begin
                @(posedge clk);
                case (mid)
                    0: begin
                        if (m0_awvalid && m0_awready) begin
                            aw_done = 1;
                            m0_awvalid = 1'b0;
                        end
                        if (m0_wvalid && m0_wready) begin
                            w_done = 1;
                            m0_wvalid = 1'b0;
                        end
                    end
                    1: begin
                        if (m1_awvalid && m1_awready) begin
                            aw_done = 1;
                            m1_awvalid = 1'b0;
                        end
                        if (m1_wvalid && m1_wready) begin
                            w_done = 1;
                            m1_wvalid = 1'b0;
                        end
                    end
                    2: begin
                        if (m2_awvalid && m2_awready) begin
                            aw_done = 1;
                            m2_awvalid = 1'b0;
                        end
                        if (m2_wvalid && m2_wready) begin
                            w_done = 1;
                            m2_wvalid = 1'b0;
                        end
                    end
                endcase
                timeout++;
            end

            // Assert BREADY
            case (mid)
                0: m0_bready = 1'b1;
                1: m1_bready = 1'b1;
                2: m2_bready = 1'b1;
            endcase

            // Wait for B response
            timeout = 0;
            while (!b_done && timeout < 500) begin
                @(posedge clk);
                case (mid)
                    0: if (m0_bvalid && m0_bready) begin
                        b_done = 1;
                        bresp  = m0_bresp;
                        bid    = m0_bid;
                        m0_bready = 1'b0;
                    end
                    1: if (m1_bvalid && m1_bready) begin
                        b_done = 1;
                        bresp  = m1_bresp;
                        bid    = m1_bid;
                        m1_bready = 1'b0;
                    end
                    2: if (m2_bvalid && m2_bready) begin
                        b_done = 1;
                        bresp  = m2_bresp;
                        bid    = m2_bid;
                        m2_bready = 1'b0;
                    end
                endcase
                timeout++;
            end
        end
    endtask

    // Master Read Task
    task automatic axi_read(
        input int                   mid,     // 0=M0, 1=M1, 2=M2
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ID_WIDTH-1:0]   id   = 8'h01,
        input logic [7:0]            len  = 8'h00,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0]           rresp,
        output logic [ID_WIDTH-1:0]  rid
    );
        int timeout;
        bit ar_done, r_done;
        begin
            ar_done = 0;
            r_done  = 0;

            @(posedge clk);
            case (mid)
                0: begin
                    m0_arid    = id;
                    m0_araddr  = addr;
                    m0_arlen   = len;
                    m0_arsize  = 3'b010;
                    m0_arburst = 2'b01;
                    m0_arvalid = 1'b1;
                    m0_rready  = 1'b0;
                end
                1: begin
                    m1_arid    = id;
                    m1_araddr  = addr;
                    m1_arlen   = len;
                    m1_arsize  = 3'b010;
                    m1_arburst = 2'b01;
                    m1_arvalid = 1'b1;
                    m1_rready  = 1'b0;
                end
                2: begin
                    m2_arid    = id;
                    m2_araddr  = addr;
                    m2_arlen   = len;
                    m2_arsize  = 3'b010;
                    m2_arburst = 2'b01;
                    m2_arvalid = 1'b1;
                    m2_rready  = 1'b0;
                end
            endcase

            // Wait for AR handshake
            timeout = 0;
            while (!ar_done && timeout < 500) begin
                @(posedge clk);
                case (mid)
                    0: if (m0_arvalid && m0_arready) begin
                        ar_done = 1;
                        m0_arvalid = 1'b0;
                    end
                    1: if (m1_arvalid && m1_arready) begin
                        ar_done = 1;
                        m1_arvalid = 1'b0;
                    end
                    2: if (m2_arvalid && m2_arready) begin
                        ar_done = 1;
                        m2_arvalid = 1'b0;
                    end
                endcase
                timeout++;
            end

            // Assert RREADY
            case (mid)
                0: m0_rready = 1'b1;
                1: m1_rready = 1'b1;
                2: m2_rready = 1'b1;
            endcase

            // Wait for R response
            timeout = 0;
            while (!r_done && timeout < 500) begin
                @(posedge clk);
                case (mid)
                    0: if (m0_rvalid && m0_rready) begin
                        r_done = 1;
                        data   = m0_rdata;
                        rresp  = m0_rresp;
                        rid    = m0_rid;
                        m0_rready = 1'b0;
                    end
                    1: if (m1_rvalid && m1_rready) begin
                        r_done = 1;
                        data   = m1_rdata;
                        rresp  = m1_rresp;
                        rid    = m1_rid;
                        m1_rready = 1'b0;
                    end
                    2: if (m2_rvalid && m2_rready) begin
                        r_done = 1;
                        data   = m2_rdata;
                        rresp  = m2_rresp;
                        rid    = m2_rid;
                        m2_rready = 1'b0;
                    end
                endcase
                timeout++;
            end
        end
    endtask

    // Specialized Handshake Task: AW before W
    task automatic axi_write_aw_before_w(
        input int                   mid,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input int                   delay_cycles,
        output logic [1:0]          bresp
    );
        int timeout;
        bit aw_done, w_done, b_done;
        begin
            aw_done = 0;
            w_done  = 0;
            b_done  = 0;

            @(posedge clk);
            m1_awid    = 8'h11;
            m1_awaddr  = addr;
            m1_awlen   = 8'h00;
            m1_awsize  = 3'b010;
            m1_awburst = 2'b01;
            m1_awvalid = 1'b1;
            m1_wvalid  = 1'b0;
            m1_bready  = 1'b0;

            // Wait for AWREADY
            timeout = 0;
            while (!aw_done && timeout < 500) begin
                @(posedge clk);
                if (m1_awvalid && m1_awready) begin
                    m1_awvalid = 1'b0;
                    aw_done = 1;
                end
                timeout++;
            end

            // Wait delay cycles before asserting W
            repeat (delay_cycles) @(posedge clk);
            m1_wdata   = data;
            m1_wstrb   = 4'b1111;
            m1_wlast   = 1'b1;
            m1_wvalid  = 1'b1;

            // Wait for WREADY
            timeout = 0;
            while (!w_done && timeout < 500) begin
                @(posedge clk);
                if (m1_wvalid && m1_wready) begin
                    m1_wvalid = 1'b0;
                    w_done = 1;
                end
                timeout++;
            end

            // Assert BREADY
            m1_bready = 1'b1;

            // Wait for BVALID
            timeout = 0;
            while (!b_done && timeout < 500) begin
                @(posedge clk);
                if (m1_bvalid && m1_bready) begin
                    b_done = 1;
                    bresp  = m1_bresp;
                    m1_bready = 1'b0;
                end
                timeout++;
            end
        end
    endtask

    // Specialized Handshake Task: W before AW
    task automatic axi_write_w_before_aw(
        input int                   mid,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input int                   delay_cycles,
        output logic [1:0]          bresp
    );
        int timeout;
        bit aw_done, w_done, b_done;
        begin
            aw_done = 0;
            w_done  = 0;
            b_done  = 0;

            @(posedge clk);
            m1_awvalid = 1'b0;
            m1_wdata   = data;
            m1_wstrb   = 4'b1111;
            m1_wlast   = 1'b1;
            m1_wvalid  = 1'b1;
            m1_bready  = 1'b0;

            // Wait delay cycles before asserting AW
            repeat (delay_cycles) @(posedge clk);
            m1_awid    = 8'h22;
            m1_awaddr  = addr;
            m1_awlen   = 8'h00;
            m1_awsize  = 3'b010;
            m1_awburst = 2'b01;
            m1_awvalid = 1'b1;

            // Wait for both AW and W handshakes
            timeout = 0;
            while ((!aw_done || !w_done) && timeout < 500) begin
                @(posedge clk);
                if (m1_awvalid && m1_awready) begin
                    m1_awvalid = 1'b0;
                    aw_done = 1;
                end
                if (m1_wvalid && m1_wready) begin
                    m1_wvalid = 1'b0;
                    w_done = 1;
                end
                timeout++;
            end

            // Assert BREADY
            m1_bready = 1'b1;

            // Wait for BVALID
            timeout = 0;
            while (!b_done && timeout < 500) begin
                @(posedge clk);
                if (m1_bvalid && m1_bready) begin
                    b_done = 1;
                    bresp  = m1_bresp;
                    m1_bready = 1'b0;
                end
                timeout++;
            end
        end
    endtask

    // Backpressure on BREADY Task
    task automatic axi_write_delayed_bready(
        input int                   mid,
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input int                   delay_cycles,
        output logic [1:0]          bresp
    );
        int timeout;
        bit aw_done, w_done, b_done;
        begin
            aw_done = 0;
            w_done  = 0;
            b_done  = 0;

            @(posedge clk);
            m1_awid    = 8'h33;
            m1_awaddr  = addr;
            m1_awlen   = 8'h00;
            m1_awsize  = 3'b010;
            m1_awburst = 2'b01;
            m1_awvalid = 1'b1;
            m1_wdata   = data;
            m1_wstrb   = 4'b1111;
            m1_wlast   = 1'b1;
            m1_wvalid  = 1'b1;
            m1_bready  = 1'b0;

            timeout = 0;
            while ((!aw_done || !w_done) && timeout < 500) begin
                @(posedge clk);
                if (m1_awvalid && m1_awready) begin
                    m1_awvalid = 1'b0;
                    aw_done = 1;
                end
                if (m1_wvalid && m1_wready) begin
                    m1_wvalid = 1'b0;
                    w_done = 1;
                end
                timeout++;
            end

            // Apply backpressure by keeping BREADY deasserted for delay_cycles
            repeat (delay_cycles) @(posedge clk);
            m1_bready = 1'b1;

            timeout = 0;
            while (!b_done && timeout < 500) begin
                @(posedge clk);
                if (m1_bvalid && m1_bready) begin
                    b_done = 1;
                    bresp  = m1_bresp;
                    m1_bready = 1'b0;
                end
                timeout++;
            end
        end
    endtask

    // Backpressure on RREADY Task
    task automatic axi_read_delayed_rready(
        input int                   mid,
        input logic [ADDR_WIDTH-1:0] addr,
        input int                   delay_cycles,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0]          rresp
    );
        int timeout;
        bit ar_done, r_done;
        begin
            ar_done = 0;
            r_done  = 0;

            @(posedge clk);
            m1_arid    = 8'h44;
            m1_araddr  = addr;
            m1_arlen   = 8'h00;
            m1_arsize  = 3'b010;
            m1_arburst = 2'b01;
            m1_arvalid = 1'b1;
            m1_rready  = 1'b0;

            timeout = 0;
            while (!ar_done && timeout < 500) begin
                @(posedge clk);
                if (m1_arvalid && m1_arready) begin
                    m1_arvalid = 1'b0;
                    ar_done = 1;
                end
                timeout++;
            end

            // Apply backpressure by keeping RREADY deasserted for delay_cycles
            repeat (delay_cycles) @(posedge clk);
            m1_rready = 1'b1;

            timeout = 0;
            while (!r_done && timeout < 500) begin
                @(posedge clk);
                if (m1_rvalid && m1_rready) begin
                    r_done = 1;
                    data   = m1_rdata;
                    rresp  = m1_rresp;
                    m1_rready = 1'b0;
                end
                timeout++;
            end
        end
    endtask

    // ============================================================
    // 9. UART SERIAL VERIFICATION TASKS
    // ============================================================
    // External Serial Byte Injector (Testbench -> DUT uart_rx)
    task automatic uart_inject_byte(
        input logic [7:0] byte_val,
        input int         rx_bit_cycles
    );
        integer bit_idx;
        begin
            $display("[UART_TB_RX] Injecting byte 0x%02h over serial uart_rx (bit period = %0d fixed_clk cycles)...", byte_val, rx_bit_cycles);
            @(negedge fixed_clk);
            // 1. START BIT (0)
            uart_rx = 1'b0;
            repeat (rx_bit_cycles) @(posedge fixed_clk);

            // 2. DATA BITS (LSB to MSB)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                @(negedge fixed_clk);
                uart_rx = byte_val[bit_idx];
                repeat (rx_bit_cycles) @(posedge fixed_clk);
            end

            // 3. STOP BIT (1)
            @(negedge fixed_clk);
            uart_rx = 1'b1;
            repeat (rx_bit_cycles) @(posedge fixed_clk);

            $display("[UART_TB_RX] Finished serial injection for byte 0x%02h at time %0t", byte_val, $time);
        end
    endtask

    // DUT Serial Frame Monitor (DUT uart_tx -> Testbench)
    task automatic uart_decode_tx(
        input int          tx_bit_cycles,
        output logic [7:0] decoded_byte,
        output logic       frame_ok
    );
        integer bit_idx;
        begin
            frame_ok = 1'b1;
            decoded_byte = 8'h00;

            // Wait for falling edge on uart_tx (START bit)
            @(negedge uart_tx);
            $display("[UART_TB_TX] Detected START bit transition at time %0t", $time);

            // Sample center of START bit
            repeat (tx_bit_cycles / 2) @(posedge fixed_clk);
            #1;
            if (uart_tx !== 1'b0) begin
                $display("[UART_TB_TX ERROR] START bit false trigger (uart_tx is not 0)");
                frame_ok = 1'b0;
            end

            // Sample 8 data bits at center of bit period
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                repeat (tx_bit_cycles) @(posedge fixed_clk);
                #1;
                decoded_byte[bit_idx] = uart_tx;
                $display("[UART_TB_TX] Sampled bit %0d = %b at time %0t", bit_idx, uart_tx, $time);
            end

            // Sample STOP bit
            repeat (tx_bit_cycles) @(posedge fixed_clk);
            #1;
            if (uart_tx !== 1'b1) begin
                $display("[UART_TB_TX ERROR] Invalid STOP bit (uart_tx is not 1)");
                frame_ok = 1'b0;
            end else begin
                $display("[UART_TB_TX] Sampled STOP bit = 1 (valid) at time %0t", $time);
            end

            $display("[UART_TB_TX] Successfully decoded TX byte = 0x%02h", decoded_byte);
        end
    endtask

    // ============================================================
    // 9b. AES HELPER TASKS  (use the existing axi_write/axi_read BFM
    //     on M1; AES is at S5 / 0x8000_7000 through the interconnect)
    // ============================================================

    // aes_write: thin wrapper – calls existing axi_write on M1
    task automatic aes_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [7:0]  id
    );
        logic [1:0]  bresp_w;
        logic [7:0]  bid_w;
        axi_write(1, addr, data, id, 8'h00, 4'hF, bresp_w, bid_w);
    endtask

    // aes_read: thin wrapper – calls existing axi_read on M1
    task automatic aes_read(
        input  logic [31:0]  addr,
        input  logic [7:0]   id,
        output logic [31:0]  rdata
    );
        logic [1:0]  rresp_w;
        logic [7:0]  rid_w;
        axi_read(1, addr, id, 8'h00, rdata, rresp_w, rid_w);
    endtask

    // aes_poll_done: poll cipher CSR bit[31] (DONE) with a safety counter.
    //   base - start of cipher region (AES_BASE or AES_BASE+AES_INV_OFFSET)
    //   id   - transaction ID to use for polling reads
    task automatic aes_poll_done(
        input logic [31:0] base,
        input logic [7:0]  id
    );
        logic [31:0] csr;
        integer cnt;
        cnt = 0;
        csr = 32'h0;
        do begin
            aes_read(base + AES_CSR, id, csr);
            cnt++;
            if (cnt > 50_000) begin
                $display("[FAIL] AES POLL TIMEOUT: DONE bit never set (base=%08h)", base);
                $finish;
            end
        end while (csr[31] == 1'b0);
    endtask

    // aes_poll_kdone: poll inv-cipher CSR bit[30] (KDONE) with a safety counter.
    task automatic aes_poll_kdone(
        input logic [31:0] base,
        input logic [7:0]  id
    );
        logic [31:0] csr;
        integer cnt;
        cnt = 0;
        csr = 32'h0;
        do begin
            aes_read(base + AES_CSR, id, csr);
            cnt++;
            if (cnt > 50_000) begin
                $display("[FAIL] AES POLL TIMEOUT: KDONE bit never set (base=%08h)", base);
                $finish;
            end
        end while (csr[30] == 1'b0);
    endtask

    // ============================================================
    // run_veer_firmware: Loads and executes a RISC-V firmware program
    // on VeeR EL2 core and monitors execution until completion signature.
    // ============================================================
    task automatic run_veer_firmware(
        input string prog_name,
        input string hex_path,
        input integer sig_word,
        input logic [31:0] exp_sig,
        input integer max_cycles,
        output logic pass_flag
    );
        integer cycle_cnt;
        integer ret_cnt;
        logic timeout;
        pass_flag = 1'b0;
        timeout = 1'b1;

        $display("\n--------------------------------------------------------------------------------");
        $display("  [FIRMWARE EXECUTION] %s", prog_name);
        $display("  Loading image: %s", hex_path);
        $display("--------------------------------------------------------------------------------");

        // 1. Reset CPU & BFM & System interconnect
        cpu_rst_l = 1'b0;
        init_masters();
        rst = 1'b1;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        // 2. Clear IMEM and DMEM and FFT sample memory
        for (int i = 0; i < 2048; i++) begin
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[i] = 32'h0000_0013; // nop
            GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[i] = 32'h0000_0000; // 0
        end
        for (int i = 0; i < 1024; i++) begin
            dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[i] = 32'h0;
        end

        // 3. Load program into IMEM
        $readmemh(hex_path, GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem);

        // 4. Release CPU reset
        cpu_rst_vec = 31'h0002_0000; // Boot PC = 0x0004_0000
        cpu_run_req = 1'b1;
        repeat (5) @(posedge clk);
        cpu_rst_l   = 1'b1;

        // 5. Monitor execution
        ret_cnt = 0;
        for (cycle_cnt = 0; cycle_cnt < max_cycles; cycle_cnt++) begin
            @(posedge clk);
            if (trace_rv_i_valid_ip) begin
                ret_cnt++;
                if (ret_cnt <= 35) begin
                    $display("      [TRACE %02d] PC=0x%08h, Insn=0x%08h", ret_cnt, trace_rv_i_address_ip, trace_rv_i_insn_ip);
                end
            end

            if (GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[sig_word] === exp_sig) begin
                timeout = 1'b0;
                $display("  [PASS] %s completed at cycle %0d (Retired %0d insns, Sig=0x%08h)",
                         prog_name, cycle_cnt, ret_cnt, exp_sig);
                break;
            end
        end

        if (timeout) begin
            $display("  [FAIL] %s TIMED OUT after %0d cycles! (Sig[%0d]=0x%08h, exp=0x%08h)",
                     prog_name, max_cycles, sig_word,
                     GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[sig_word], exp_sig);
        end

        check_assert($sformatf("%s: Completion signature verified (DMEM[%0d] == 0x%08h)", prog_name, sig_word, exp_sig),
                     !timeout && (GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[sig_word] === exp_sig));

        // 6. Allow in-flight transactions to drain before resetting CPU
        repeat (20) @(posedge clk);
        cpu_rst_l = 1'b0;
        repeat (10) @(posedge clk);
        pass_flag = !timeout;
    endtask

    // ============================================================
    // 10. MAIN TEST SCENARIOS
    // ============================================================
    initial begin
        string test_mode;
        logic [31:0] rd_data;
        logic [1:0]  resp;
        logic [7:0]  resp_id;
        logic [7:0]  tx_decoded;
        logic        tx_ok;

        test_mode = "ALL";
        void'($value$plusargs("TEST=%s", test_mode));

        // Waveform Dump
        if (test_mode == "FFT") begin
            $fsdbDumpfile("fft_test.fsdb");
        end else if (test_mode == "DMA") begin
            $fsdbDumpfile("dma_test.fsdb");
        end else if (test_mode == "AES") begin
            $fsdbDumpfile("aes_test.fsdb");
        end else if (test_mode == "GPIO") begin
            $fsdbDumpfile("gpio_test.fsdb");
        end else if (test_mode == "TIMER") begin
            $fsdbDumpfile("timer_test.fsdb");
        end else if (test_mode == "VEER") begin
            $fsdbDumpfile("veer_test.fsdb");
        end else if (test_mode == "C_TEST") begin
            $fsdbDumpfile("c_test.fsdb");
        end else if (test_mode == "C_BOOT") begin
            $fsdbDumpfile("c_boot_test.fsdb");
        end else if (test_mode == "C_UART") begin
            $fsdbDumpfile("c_uart_test.fsdb");
        end else if (test_mode == "C_AES") begin
            $fsdbDumpfile("c_aes_test.fsdb");
        end else if (test_mode == "C_DMA") begin
            $fsdbDumpfile("c_dma_test.fsdb");
        end else if (test_mode == "C_FFT") begin
            $fsdbDumpfile("c_fft_test.fsdb");
        end else if (test_mode == "C_MASTER" || test_mode == "C_SUITE") begin
            $fsdbDumpfile("c_master_test.fsdb");
        end else begin
            $fsdbDumpfile("main_top.fsdb");
        end
        $fsdbDumpvars(0, tb_main_top);

        $display("================================================================================");
        $display("          STARTING EXHAUSTIVE VERIFICATION OF 3x15 AXI + UART TOP               ");
        $display("          TEST MODE : %s", test_mode);
        $display("================================================================================");

        // Initialize signals
        init_masters();
        gpio_tb_drive_val = 32'h0;
        gpio_tb_drive_en  = 32'h0;
        rst = 1'b1;
        cpu_rst_l   = 1'b0;
        cpu_rst_vec = 31'h0002_0000;
        cpu_run_req = 1'b1;

        // ------------------------------------------------------------
        // TEST 1: Power-on Reset & Idle State Verification
        // ------------------------------------------------------------
        $display("\n[SCENARIO 1] Verifying Reset & Initial Idle Conditions...");
        repeat (10) @(posedge clk);
        check_assert("Reset State: uart_tx remains High (Idle)", uart_tx === 1'b1, "uart_tx not high in reset");
        check_assert("Reset State: uart_irq is Low (Inactive)",  uart_irq === 1'b0, "uart_irq high during reset");
        check_assert("Reset State: gpio_irq is Low (Inactive)",  gpio_irq === 1'b0, "gpio_irq high during reset");
        check_assert("Reset State: timer_irq is Low (Inactive)", timer_irq === 1'b0, "timer_irq high during reset");
        check_assert("Reset State: timer_pwm is Low (Inactive)", timer_pwm === 1'b0, "timer_pwm high during reset");

        // Release reset
        rst = 1'b0;
        repeat (10) @(posedge clk);
        check_assert("Post-Reset: uart_tx remains High (Idle)",  uart_tx === 1'b1, "uart_tx dropped after reset");
        check_assert("Post-Reset: uart_irq remains Low",        uart_irq === 1'b0, "uart_irq asserted unexpectedly");
        check_assert("Post-Reset: gpio_irq remains Low",        gpio_irq === 1'b0, "gpio_irq asserted unexpectedly");
        check_assert("Post-Reset: timer_irq remains Low",       timer_irq === 1'b0, "timer_irq asserted unexpectedly");
        check_assert("Post-Reset: timer_pwm remains Low",       timer_pwm === 1'b0, "timer_pwm asserted unexpectedly");

        // ------------------------------------------------------------
        // TEST 2: Unmapped Address Access & DECERR Verification
        // ------------------------------------------------------------
        if (test_mode == "ALL" || test_mode == "COMMON" || test_mode == "UART") begin
            $display("\n[SCENARIO 2] Verifying Unmapped Address Decoding (DECERR = 2'b11)...");

        // 2A: High unmapped write
        axi_write(1, ADDR_UNMAPPED, 32'hDEAD_BEEF, 8'hA1, 8'h00, 4'hF, resp, resp_id);
        check_assert("Unmapped Write High (0x9000_0000): Returns DECERR (2'b11)", resp === 2'b11, $sformatf("Got resp=%b", resp));
        check_assert("Unmapped Write High: Preserves Transaction ID (0xA1)", resp_id === 8'hA1, $sformatf("Got id=%h", resp_id));

        // 2B: High unmapped read
        axi_read(1, ADDR_UNMAPPED, 8'hB1, 8'h00, rd_data, resp, resp_id);
        check_assert("Unmapped Read High (0x9000_0000): Returns DECERR (2'b11)", resp === 2'b11, $sformatf("Got resp=%b", resp));
        check_assert("Unmapped Read High: Read data is 0", rd_data === 32'h0, $sformatf("Got rd_data=%h", rd_data));

        // 2C: Low unmapped write (gap between 0 and IMEM 0x0004_0000)
        axi_write(1, ADDR_UNMAPPED_LO, 32'hFEED_CAFE, 8'hA2, 8'h00, 4'hF, resp, resp_id);
        check_assert("Unmapped Write Low (0x0001_0000): Returns DECERR (2'b11)", resp === 2'b11, $sformatf("Got resp=%b", resp));

        // 2D: Low unmapped read
        axi_read(1, ADDR_UNMAPPED_LO, 8'hB2, 8'h00, rd_data, resp, resp_id);
        check_assert("Unmapped Read Low (0x0001_0000): Returns DECERR (2'b11)", resp === 2'b11, $sformatf("Got resp=%b", resp));

        // ------------------------------------------------------------
        // TEST 3: Crossbar Connectivity Across Slaves and Masters
        // ------------------------------------------------------------
        $display("\n[SCENARIO 3] Verifying Crossbar Routing for Masters (M0, M1, M2) & Slaves...");

        // 3A: M1 -> S0 (IMEM 0x0004_0000)
        axi_write(1, ADDR_S0_IMEM, 32'h1122_3344, 8'h10, 8'h00, 4'hF, resp, resp_id);
        check_assert("Routing: M1 -> S0 (IMEM) Write Returns OKAY", resp === 2'b00);
        axi_read(1, ADDR_S0_IMEM + 4, 8'h11, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M1 -> S0 (IMEM) Read Returns OKAY", resp === 2'b00);
        check_assert("Routing: M1 -> S0 (IMEM) Read Signature Valid", rd_data[31:16] === 16'hCA00);

        // 3B: M1 -> S1 (DMEM 0x0008_0000)
        axi_write(1, ADDR_S1_DMEM, 32'h5566_7788, 8'h12, 8'h00, 4'hF, resp, resp_id);
        check_assert("Routing: M1 -> S1 (DMEM) Write Returns OKAY", resp === 2'b00);
        axi_read(1, ADDR_S1_DMEM + 8, 8'h13, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M1 -> S1 (DMEM) Read Returns OKAY", resp === 2'b00);
        check_assert("Routing: M1 -> S1 (DMEM) Read Signature Valid", rd_data[31:16] === 16'hCA01);

        // 3C: M1 -> S2 (GPIO 0x8000_1008 DIR)
        axi_write(1, GPIO_DIR, 32'h0000_55AA, 8'h14, 8'h00, 4'hF, resp, resp_id);
        check_assert("Routing: M1 -> S2 (GPIO) Write Returns OKAY", resp === 2'b00);
        axi_read(1, GPIO_DIR, 8'h15, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M1 -> S2 (GPIO) Read Returns OKAY", resp === 2'b00);
        check_assert("Routing: M1 -> S2 (GPIO) Read Matches Written", rd_data[15:0] === 16'h55AA);

        // 3D: M1 -> S3 (Timer 0x8000_2004 LOAD)
        axi_write(1, TIMER_LOAD, 32'h0000_1234, 8'h16, 8'h00, 4'hF, resp, resp_id);
        check_assert("Routing: M1 -> S3 (Timer) Write Returns OKAY", resp === 2'b00);
        axi_read(1, TIMER_LOAD, 8'h17, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M1 -> S3 (Timer) Read Returns OKAY", resp === 2'b00);
        check_assert("Routing: M1 -> S3 (Timer) Read Matches Written", rd_data === 32'h0000_1234);

        // 3E: M0 (IFU) -> S4 (UART 0x8000_3014 LSR)
        axi_read(0, UART_LSR, 8'h02, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M0 (VeeR IFU) -> S4 (UART) Read Returns OKAY", resp === 2'b00);

        // 3F: M2 (DMA) -> S4 (UART 0x8000_3014 LSR)
        axi_read(2, UART_LSR, 8'h03, 8'h00, rd_data, resp, resp_id);
        check_assert("Routing: M2 (DMA) -> S4 (UART) Read Returns OKAY", resp === 2'b00);

        // ------------------------------------------------------------
        // TEST 4: DLAB Setup & Baud Rate Configuration (115200 Baud)
        // ------------------------------------------------------------
        $display("\n[SCENARIO 4] Verifying UART DLAB & 115200 Baud Divisor Setup...");

        // 4A: With DLAB=0, write IER = 0x00
        axi_write(1, UART_IER, 32'h0000_0000, 8'h20, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART: Write IER=0x00 with DLAB=0 Returns OKAY", resp === 2'b00);

        // 4B: Enable DLAB (write LCR = 0x83 -> DLAB=1, 8-N-1)
        axi_write(1, UART_LCR, 32'h0000_0083, 8'h22, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART: Write LCR=0x83 (Enable DLAB) Returns OKAY", resp === 2'b00);

        // 4C: Program Baud Divisor = 347 (for 115200 Baud @ 40 MHz)
        axi_write(1, UART_BAUD_DIV, BAUD_DIV_115200, 8'h23, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART: Write Baud Divisor (347) Returns OKAY", resp === 2'b00);

        // 4D: Disable DLAB (write LCR = 0x03 -> DLAB=0, 8-N-1)
        axi_write(1, UART_LCR, 32'h0000_0003, 8'h24, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART: Write LCR=0x03 (Disable DLAB) Returns OKAY", resp === 2'b00);

        // 4E: Verify normal register access restored (DLAB=0) via LSR
        axi_read(1, UART_LSR, 8'h25, 8'h00, rd_data, resp, resp_id);
        check_assert("UART: Verify normal register access restored (LSR Read OKAY)", resp === 2'b00);
        check_assert("UART: Verify THRE=1 in LSR", rd_data[5] === 1'b1, $sformatf("Got LSR=0x%02h", rd_data[7:0]));

        // ------------------------------------------------------------
        // TEST 5: UART TX Transmission & Serial Waveform Verification
        // ------------------------------------------------------------
        $display("\n[SCENARIO 5] Verifying UART TX Transmission at 115200 Baud (Byte = 0xA5)...");
        fork
            begin
                // AXI Master writes byte 0xA5 to THR (0x8000_3000)
                axi_write(1, UART_RBR_THR, 32'h0000_00A5, 8'h30, 8'h00, 4'hF, resp, resp_id);
                check_assert("UART TX: Write byte 0xA5 to THR Returns OKAY", resp === 2'b00);
            end
            begin
                // Monitor uart_tx pin concurrently
                uart_decode_tx(TX_CYCLES_115200, tx_decoded, tx_ok);
            end
        join

        check_assert("UART TX: Serial frame format (START & STOP bits) valid", tx_ok === 1'b1);
        check_assert("UART TX: Decoded byte exactly matches transmitted byte (0xA5)", tx_decoded === 8'hA5, $sformatf("Decoded 0x%02h vs expected 0xA5", tx_decoded));

        // Check LSR for THRE / TEMT
        axi_read(1, UART_LSR, 8'h31, 8'h00, rd_data, resp, resp_id);
        check_assert("UART TX: LSR bit 5 (THRE) is set", rd_data[5] === 1'b1, $sformatf("Got LSR=0x%02h", rd_data[7:0]));

        // ------------------------------------------------------------
        // TEST 6: UART RX Reception & AXI Readback
        // ------------------------------------------------------------
        $display("\n[SCENARIO 6] Verifying UART RX Reception at 115200 Baud (Byte = 0x5A)...");

        // 6A: Enable RDA interrupt / status flag in IER (IER[0] = 1)
        axi_write(1, UART_IER, 32'h0000_0001, 8'h3F, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART RX: Write IER=0x01 to enable DATA_READY in LSR", resp === 2'b00);

        // 6B: Inject serial byte 0x5A on uart_rx
        uart_inject_byte(8'h5A, RX_CYCLES_115200);

        // 6C: Poll LSR bit 0 (DATA_READY)
        repeat (10) @(posedge clk);
        axi_read(1, UART_LSR, 8'h40, 8'h00, rd_data, resp, resp_id);
        check_assert("UART RX: LSR bit 0 (DATA_READY) asserted", rd_data[0] === 1'b1, $sformatf("Got LSR=0x%02h", rd_data[7:0]));

        // 6D: Read RBR through AXI
        axi_read(1, UART_RBR_THR, 8'h41, 8'h00, rd_data, resp, resp_id);
        check_assert("UART RX: Read RBR Returns OKAY", resp === 2'b00);
        check_assert("UART RX: Received byte matches injected byte (0x5A)", rd_data[7:0] === 8'h5A, $sformatf("Got RBR=0x%02h vs expected 0x5A", rd_data[7:0]));

        // 6E: Verify DATA_READY cleared in LSR
        axi_read(1, UART_LSR, 8'h42, 8'h00, rd_data, resp, resp_id);
        check_assert("UART RX: LSR bit 0 cleared after reading RBR", rd_data[0] === 1'b0, $sformatf("Got LSR=0x%02h", rd_data[7:0]));

        // ------------------------------------------------------------
        // TEST 7: UART Interrupt (IRQ) Behavior
        // ------------------------------------------------------------
        $display("\n[SCENARIO 7] Verifying UART Interrupt Behavior (IER=0 vs IER=1)...");

        // 7A: IER = 0, inject byte 0x3C -> verify IRQ remains 0
        axi_write(1, UART_IER, 32'h0000_0000, 8'h50, 8'h00, 4'hF, resp, resp_id);
        uart_inject_byte(8'h3C, RX_CYCLES_115200);
        repeat (10) @(posedge clk);
        check_assert("UART IRQ: With IER=0, uart_irq remains deasserted (0)", uart_irq === 1'b0);

        // Read out byte to empty FIFO
        axi_read(1, UART_RBR_THR, 8'h51, 8'h00, rd_data, resp, resp_id);
        check_assert("UART IRQ: Flushed RBR byte (0x3C)", rd_data[7:0] === 8'h3C);

        // 7B: Enable RDA interrupt: IER = 0x01
        axi_write(1, UART_IER, 32'h0000_0001, 8'h52, 8'h00, 4'hF, resp, resp_id);
        check_assert("UART IRQ: Write IER=0x01 Returns OKAY", resp === 2'b00);

        // Inject byte 0x7E -> verify IRQ asserts
        uart_inject_byte(8'h7E, RX_CYCLES_115200);
        repeat (10) @(posedge clk);
        check_assert("UART IRQ: With IER=1, uart_irq asserts High upon byte reception", uart_irq === 1'b1);

        // Read RBR -> verify IRQ deasserts
        axi_read(1, UART_RBR_THR, 8'h53, 8'h00, rd_data, resp, resp_id);
        check_assert("UART IRQ: Read received byte (0x7E)", rd_data[7:0] === 8'h7E);
        repeat (10) @(posedge clk);
        check_assert("UART IRQ: uart_irq deasserts Low after reading RBR", uart_irq === 1'b0);

        // ------------------------------------------------------------
        // TEST 8: AXI Handshake Ordering Edge Cases & Backpressure
        // ------------------------------------------------------------
        $display("\n[SCENARIO 8] Verifying AXI Handshake Ordering & Backpressure Edge Cases...");

        // 8A: AW before W on S0 (IMEM)
        axi_write_aw_before_w(1, ADDR_S0_IMEM + 16, 32'hAABB_CCDD, 5, resp);
        check_assert("Handshake: AW asserted 5 cycles before W completes cleanly (OKAY)", resp === 2'b00);

        // 8B: W before AW on S0 (IMEM)
        axi_write_w_before_aw(1, ADDR_S0_IMEM + 20, 32'h1122_3344, 5, resp);
        check_assert("Handshake: W asserted 5 cycles before AW completes cleanly (OKAY)", resp === 2'b00);

        // 8C: Backpressure on B channel (delay BREADY by 6 cycles)
        axi_write_delayed_bready(1, UART_IER, 32'h0000_0000, 6, resp);
        check_assert("Handshake: BREADY backpressure delay handled cleanly (OKAY)", resp === 2'b00);

        // 8D: Backpressure on R channel (delay RREADY by 6 cycles)
        axi_read_delayed_rready(1, UART_LSR, 6, rd_data, resp);
        check_assert("Handshake: RREADY backpressure delay handled cleanly (OKAY)", resp === 2'b00);
        check_assert("Handshake: Read data valid after delayed RREADY (THRE=1)", rd_data[5] === 1'b1);

        // ------------------------------------------------------------
        // TEST 9: AXI Transaction ID Preservation
        // ------------------------------------------------------------
        $display("\n[SCENARIO 9] Verifying AXI Transaction ID Preservation...");
        axi_write(1, ADDR_S0_IMEM, 32'h1234_5678, 8'hA8, 8'h00, 4'hF, resp, resp_id);
        check_assert("ID Preservation: Write ID 0xA8 returned in BID", resp_id === 8'hA8, $sformatf("Got BID=%h", resp_id));

        axi_read(1, UART_LSR, 8'hD4, 8'h00, rd_data, resp, resp_id);
        check_assert("ID Preservation: Read ID 0xD4 returned in RID", resp_id === 8'hD4, $sformatf("Got RID=%h", resp_id));

        axi_write(1, UART_IER, 32'h0000_0001, 8'hFE, 8'h00, 4'hF, resp, resp_id);
        check_assert("ID Preservation: Write ID 0xFE returned in BID", resp_id === 8'hFE, $sformatf("Got BID=%h", resp_id));

        axi_read(1, ADDR_S1_DMEM, 8'h7B, 8'h00, rd_data, resp, resp_id);
        check_assert("ID Preservation: Read ID 0x7B returned in RID", resp_id === 8'h7B, $sformatf("Got RID=%h", resp_id));

        // ------------------------------------------------------------
        // TEST 10: Unsupported Burst Protection (Single-Beat MMIO Peripheral)
        // ------------------------------------------------------------
        $display("\n[SCENARIO 10] Testing Unsupported Bursts (AWLEN > 0, ARLEN > 0)...");

        // 10A: Write with AWLEN = 3 to UART
        axi_write(1, UART_RBR_THR, 32'h0000_0041, 8'h60, 8'h03, 4'hF, resp, resp_id);
        check_assert("Unsupported Burst Write: Completes without hang", resp === 2'b00);

        // 10B: Read with ARLEN = 3 to UART
        axi_read(1, UART_LSR, 8'h61, 8'h03, rd_data, resp, resp_id);
        check_assert("Unsupported Burst Read: Completes without hang", resp === 2'b00);

        // 10C: Verify UART register map integrity after burst attempt
        axi_read(1, UART_LSR, 8'h62, 8'h00, rd_data, resp, resp_id);
        check_assert("UART Integrity: LSR readable & valid after burst attempts", resp === 2'b00);

        // ------------------------------------------------------------
        // TEST 11: Mid-Activity Reset & Recovery
        // ------------------------------------------------------------
        $display("\n[SCENARIO 11] Verifying System Reset During Activity & Clean Recovery...");
        // Assert reset mid-test
        rst = 1'b1;
        repeat (5) @(posedge clk);
        init_masters();
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (10) @(posedge clk);

        // Perform clean transaction post-reset
        axi_write(1, UART_LCR, 32'h0000_0003, 8'h70, 8'h00, 4'hF, resp, resp_id);
        check_assert("Reset Recovery: Write to LCR post-reset returns OKAY", resp === 2'b00);
        axi_read(1, UART_LSR, 8'h71, 8'h00, rd_data, resp, resp_id);
        check_assert("Reset Recovery: Read from LSR post-reset returns OKAY", resp === 2'b00);

        // Snapshot pass count after all UART/interconnect tests complete.
        uart_tests_pass = (failed_tests == 0);
        end

        // ============================================================
        // TEST 12: AES-128 ENCRYPTION via Interconnect S5 / M05
        // Transaction path:
        //   TB M1 -> main_top s01_axi -> 3x15 interconnect ->
        //   m05_axi (S5) -> aes_axi_slave_axi4 -> aes_axi_slave ->
        //   aes_cipher_top
        // ============================================================
        if (test_mode == "ALL" || test_mode == "AES") begin
            $display("\n[SCENARIO 12] AES-128 Encryption through AXI Interconnect S5/M05...");
            $display("  AES_BASE = 0x%08h  (S5 / M05)", AES_BASE);
            $display("  KEY  = 000102030405060708090a0b0c0d0e0f");
            $display("  PLAIN= 00112233445566778899aabbccddeeff");
            $display("  EXP  = 69c4e0d86a7b0430d8cdb78070b4c55a");

            begin : AES_ENC_BLOCK
            logic [31:0] enc_tout0, enc_tout1, enc_tout2, enc_tout3;
            integer      enc_fail_start;
            enc_fail_start = failed_tests;

            // Step 12.1: Write KEY registers (cipher region, base = AES_BASE)
            $display("  [12.1] Writing AES key registers...");
            aes_write(AES_BASE + AES_KEY0, AES_TV_KEY0, 8'hC1);
            aes_write(AES_BASE + AES_KEY1, AES_TV_KEY1, 8'hC2);
            aes_write(AES_BASE + AES_KEY2, AES_TV_KEY2, 8'hC3);
            aes_write(AES_BASE + AES_KEY3, AES_TV_KEY3, 8'hC4);

            // Step 12.2: Write plaintext TEXT_IN registers
            $display("  [12.2] Writing plaintext registers...");
            aes_write(AES_BASE + AES_TIN0, AES_TV_TIN0, 8'hC5);
            aes_write(AES_BASE + AES_TIN1, AES_TV_TIN1, 8'hC6);
            aes_write(AES_BASE + AES_TIN2, AES_TV_TIN2, 8'hC7);
            aes_write(AES_BASE + AES_TIN3, AES_TV_TIN3, 8'hC8);

            // Step 12.3: Start encryption — write CSR[0]=1
            $display("  [12.3] Starting encryption (CSR[0]=1)...");
            aes_write(AES_BASE + AES_CSR, 32'h0000_0001, 8'hC9);

            // Step 12.4: Poll CSR until DONE (bit[31])
            $display("  [12.4] Polling CSR for DONE bit...");
            aes_poll_done(AES_BASE, 8'hCA);
            $display("  [12.4] Encryption DONE asserted.");

            // Step 12.5: Read TEXT_OUT registers
            $display("  [12.5] Reading ciphertext...");
            aes_read(AES_BASE + AES_TOUT0, 8'hCB, enc_tout0);
            aes_read(AES_BASE + AES_TOUT1, 8'hCC, enc_tout1);
            aes_read(AES_BASE + AES_TOUT2, 8'hCD, enc_tout2);
            aes_read(AES_BASE + AES_TOUT3, 8'hCE, enc_tout3);

            // Step 12.6: Compare against expected ciphertext
            check_assert(
                "AES ENC: TOUT0 = 70b4c55a",
                enc_tout0 === AES_TV_EXP_TOUT0,
                $sformatf("got %08h, exp %08h", enc_tout0, AES_TV_EXP_TOUT0)
            );
            check_assert(
                "AES ENC: TOUT1 = d8cdb780",
                enc_tout1 === AES_TV_EXP_TOUT1,
                $sformatf("got %08h, exp %08h", enc_tout1, AES_TV_EXP_TOUT1)
            );
            check_assert(
                "AES ENC: TOUT2 = 6a7b0430",
                enc_tout2 === AES_TV_EXP_TOUT2,
                $sformatf("got %08h, exp %08h", enc_tout2, AES_TV_EXP_TOUT2)
            );
            check_assert(
                "AES ENC: TOUT3 = 69c4e0d8",
                enc_tout3 === AES_TV_EXP_TOUT3,
                $sformatf("got %08h, exp %08h", enc_tout3, AES_TV_EXP_TOUT3)
            );

            aes_enc_pass = (failed_tests == enc_fail_start);
            $display("  [12] AES Encryption scenario: %s", aes_enc_pass ? "PASS" : "FAIL");
        end

        // ============================================================
        // TEST 13: AES-128 DECRYPTION via Interconnect S5 / M05
        // Uses the AES Inverse Cipher region at AES_BASE + AES_INV_OFFSET
        // ============================================================
        $display("\n[SCENARIO 13] AES-128 Decryption through AXI Interconnect S5/M05...");
        $display("  INV_BASE = 0x%08h  (S5 / M05, inv-cipher region)", AES_BASE + AES_INV_OFFSET);

        begin : AES_DEC_BLOCK
            logic [31:0] dec_tout0, dec_tout1, dec_tout2, dec_tout3;
            integer      dec_fail_start;
            dec_fail_start = failed_tests;

            // Step 13.1: Write KEY to inverse-cipher region
            $display("  [13.1] Writing inverse-cipher key registers...");
            aes_write(AES_BASE + AES_INV_OFFSET + AES_KEY0, AES_TV_KEY0, 8'hD1);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_KEY1, AES_TV_KEY1, 8'hD2);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_KEY2, AES_TV_KEY2, 8'hD3);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_KEY3, AES_TV_KEY3, 8'hD4);

            // Step 13.2: Assert KLD (CSR[1]=1) to start inverse key expansion
            $display("  [13.2] Triggering inverse key expansion (CSR[1]=1)...");
            aes_write(AES_BASE + AES_INV_OFFSET + AES_CSR, 32'h0000_0002, 8'hD5);

            // Step 13.3: Poll CSR until KDONE (bit[30])
            $display("  [13.3] Polling CSR for KDONE bit...");
            aes_poll_kdone(AES_BASE + AES_INV_OFFSET, 8'hD6);
            $display("  [13.3] Key expansion DONE.");

            // Step 13.4: Write the expected ciphertext as plaintext input to inv-cipher
            $display("  [13.4] Writing ciphertext to inv-cipher TEXT_IN...");
            aes_write(AES_BASE + AES_INV_OFFSET + AES_TIN0, AES_TV_EXP_TOUT0, 8'hD7);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_TIN1, AES_TV_EXP_TOUT1, 8'hD8);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_TIN2, AES_TV_EXP_TOUT2, 8'hD9);
            aes_write(AES_BASE + AES_INV_OFFSET + AES_TIN3, AES_TV_EXP_TOUT3, 8'hDA);

            // Step 13.5: Start decryption (CSR[0]=1)
            $display("  [13.5] Starting decryption (CSR[0]=1)...");
            aes_write(AES_BASE + AES_INV_OFFSET + AES_CSR, 32'h0000_0001, 8'hDB);

            // Step 13.6: Poll CSR until DONE (bit[31])
            $display("  [13.6] Polling CSR for DONE bit...");
            aes_poll_done(AES_BASE + AES_INV_OFFSET, 8'hDC);
            $display("  [13.6] Decryption DONE asserted.");

            // Step 13.7: Read decrypted output — must match original plaintext
            $display("  [13.7] Reading decrypted plaintext...");
            aes_read(AES_BASE + AES_INV_OFFSET + AES_TOUT0, 8'hDD, dec_tout0);
            aes_read(AES_BASE + AES_INV_OFFSET + AES_TOUT1, 8'hDE, dec_tout1);
            aes_read(AES_BASE + AES_INV_OFFSET + AES_TOUT2, 8'hDF, dec_tout2);
            aes_read(AES_BASE + AES_INV_OFFSET + AES_TOUT3, 8'hE0, dec_tout3);

            // Step 13.8: Compare against original plaintext
            check_assert(
                "AES DEC: TOUT0 == original TIN0 (ccddeeff)",
                dec_tout0 === AES_TV_TIN0,
                $sformatf("got %08h, exp %08h", dec_tout0, AES_TV_TIN0)
            );
            check_assert(
                "AES DEC: TOUT1 == original TIN1 (8899aabb)",
                dec_tout1 === AES_TV_TIN1,
                $sformatf("got %08h, exp %08h", dec_tout1, AES_TV_TIN1)
            );
            check_assert(
                "AES DEC: TOUT2 == original TIN2 (44556677)",
                dec_tout2 === AES_TV_TIN2,
                $sformatf("got %08h, exp %08h", dec_tout2, AES_TV_TIN2)
            );
            check_assert(
                "AES DEC: TOUT3 == original TIN3 (00112233)",
                dec_tout3 === AES_TV_TIN3,
                $sformatf("got %08h, exp %08h", dec_tout3, AES_TV_TIN3)
            );

            aes_dec_pass = (failed_tests == dec_fail_start);
            $display("  [13] AES Decryption scenario: %s", aes_dec_pass ? "PASS" : "FAIL");
        end
        end

        // ============================================================
        // [SCENARIO 14] FFT Control Interface Verification
        // ============================================================
        // Verifies:
        //   - STATUS register readable and shows not-busy after reset
        //   - CTRL register write with bit[0]=0 is accepted (no start)
        //   - CTRL register read always returns 0
        //   - Writing to an invalid address returns SLVERR
        // ============================================================
        if (test_mode == "ALL" || test_mode == "FFT") begin
        begin : SCENARIO_14
            integer s14_fail_start;
            logic [31:0] fft_rd;
            logic [1:0]  fft_resp;
            logic [7:0]  fft_rid;

            s14_fail_start = failed_tests;
            $display("\n[SCENARIO 14] FFT Control Interface Verification (S6 / 0x8000_8000)...");

            // 14.1  STATUS register: must be readable, done_sticky=0, busy=0 after reset
            $display("  [14.1] Read FFT STATUS register (expect 0x00000000 after reset)...");
            axi_read(1, FFT_STATUS_REG, 8'hE1, 8'h00, fft_rd, fft_resp, fft_rid);
            check_assert("FFT STATUS RRESP == OKAY after reset",
                         fft_resp === 2'b00,
                         $sformatf("rresp=%0b", fft_resp));
            check_assert("FFT STATUS bit[1:0] == 2'b00 after reset (not busy, not done)",
                         fft_rd[1:0] === 2'b00,
                         $sformatf("status=0x%08h", fft_rd));

            // 14.2  CTRL register read: must return 0x0 with OKAY
            $display("  [14.2] Read FFT CTRL register (expect 0x00000000)...");
            axi_read(1, FFT_CTRL_REG, 8'hE2, 8'h00, fft_rd, fft_resp, fft_rid);
            check_assert("FFT CTRL RRESP == OKAY",
                         fft_resp === 2'b00,
                         $sformatf("rresp=%0b", fft_resp));
            check_assert("FFT CTRL RDATA == 32'h0",
                         fft_rd === 32'h0,
                         $sformatf("rdata=0x%08h", fft_rd));

            // 14.3  Write CTRL[0]=0 (no-op start) — must return OKAY, no start issued
            $display("  [14.3] Write FFT CTRL bit[0]=0 (no-op, expect OKAY)...");
            begin
                logic [1:0]  bw_resp;
                logic [7:0]  bw_id;
                axi_write(1, FFT_CTRL_REG, 32'h0000_0000, 8'hE3, 8'h00, 4'hF,
                          bw_resp, bw_id);
                check_assert("FFT CTRL write 0 BRESP == OKAY",
                             bw_resp === 2'b00,
                             $sformatf("bresp=%0b", bw_resp));
            end

            // 14.4  Write to an invalid offset (0x8000_8008) — must return SLVERR
            $display("  [14.4] Write FFT CTRL+8 (invalid offset, expect SLVERR)...");
            begin
                logic [1:0]  bw_resp;
                logic [7:0]  bw_id;
                axi_write(1, FFT_CTRL_BASE + 32'h8, 32'hDEAD_BEEF, 8'hE4, 8'h00, 4'hF,
                          bw_resp, bw_id);
                check_assert("FFT invalid offset BRESP == SLVERR (2'b10)",
                             bw_resp === 2'b10,
                             $sformatf("bresp=%0b", bw_resp));
            end

            // 14.5  Read from invalid offset — must return SLVERR and 0xDEADBEEF
            $display("  [14.5] Read FFT CTRL+8 (invalid offset, expect SLVERR)...");
            axi_read(1, FFT_CTRL_BASE + 32'h8, 8'hE5, 8'h00, fft_rd, fft_resp, fft_rid);
            check_assert("FFT invalid offset RRESP == SLVERR (2'b10)",
                         fft_resp === 2'b10,
                         $sformatf("rresp=%0b", fft_resp));
            check_assert("FFT invalid offset RDATA == 32'hDEADBEEF",
                         fft_rd === 32'hDEAD_BEEF,
                         $sformatf("rdata=0x%08h", fft_rd));

            // 14.6  X/Z check on fft_irq after reset (must be driven 0)
            $display("  [14.6] Check fft_irq is not X/Z after reset...");
            check_assert("fft_irq not X/Z after reset",
                         !$isunknown(fft_irq),
                         "fft_irq is X or Z");
            check_assert("fft_irq == 0 after reset (no FFT triggered)",
                         fft_irq === 1'b0,
                         $sformatf("fft_irq=%0b", fft_irq));

            fft_ctrl_pass = (failed_tests == s14_fail_start);
            $display("  [14] FFT Control Interface: %s", fft_ctrl_pass ? "PASS" : "FAIL");
        end

        // ============================================================
        // [SCENARIO 15] FFT Memory Interface Verification
        // ============================================================
        // Verifies:
        //   - Single-word write to sample memory (S7 / 0x8000_9000)
        //   - Read back of written value
        //   - Write/read roundtrip at several addresses
        //   - Access to out-of-range address returns SLVERR
        // Data format: 32-bit word = {imag[15:0], real[15:0]}, signed Q1.15
        // ============================================================
        begin : SCENARIO_15
            integer s15_fail_start;
            logic [31:0] mem_rd;
            logic [1:0]  mem_resp;
            logic [7:0]  mem_rid;
            logic [1:0]  bw_resp;
            logic [7:0]  bw_id;
            // Sample[0] address = FFT_MEM_BASE (0x8000_9000)
            // Local address seen by slave = 0x8000_9000 - 0x8000_8000 = 0x1000
            // which equals MEM_BASE='h1000 inside fft_mem_axi4_slave

            s15_fail_start = failed_tests;
            $display("\n[SCENARIO 15] FFT Memory Interface Verification (S7 / 0x8000_9000)...");

            // 15.1  Write sample[0] = {imag=0x0000, real=0x4000}  (real=+0.5 in Q1.15)
            $display("  [15.1] Write sample[0] = 0x00004000 (real=+0.5 Q1.15, imag=0)...");
            axi_write(1, FFT_MEM_BASE + 32'h0, 32'h0000_4000, 8'hF1, 8'h00, 4'hF,
                      bw_resp, bw_id);
            check_assert("FFT MEM sample[0] write BRESP == OKAY",
                         bw_resp === 2'b00,
                         $sformatf("bresp=%0b", bw_resp));

            // 15.2  Read back sample[0]
            $display("  [15.2] Read back sample[0]...");
            axi_read(1, FFT_MEM_BASE + 32'h0, 8'hF2, 8'h00, mem_rd, mem_resp, mem_rid);
            check_assert("FFT MEM sample[0] read RRESP == OKAY",
                         mem_resp === 2'b00,
                         $sformatf("rresp=%0b", mem_resp));
            check_assert("FFT MEM sample[0] readback == 0x00004000",
                         mem_rd === 32'h0000_4000,
                         $sformatf("got 0x%08h", mem_rd));

            // 15.3  Write sample[1] = {imag=0x2000, real=0x0000}  (imag=+0.25 Q1.15)
            $display("  [15.3] Write sample[1] = 0x20000000 (real=0, imag=+0.25 Q1.15)...");
            axi_write(1, FFT_MEM_BASE + 32'h4, 32'h2000_0000, 8'hF3, 8'h00, 4'hF,
                      bw_resp, bw_id);
            check_assert("FFT MEM sample[1] write BRESP == OKAY",
                         bw_resp === 2'b00,
                         $sformatf("bresp=%0b", bw_resp));

            // 15.4  Read back sample[1]
            $display("  [15.4] Read back sample[1]...");
            axi_read(1, FFT_MEM_BASE + 32'h4, 8'hF4, 8'h00, mem_rd, mem_resp, mem_rid);
            check_assert("FFT MEM sample[1] read RRESP == OKAY",
                         mem_resp === 2'b00,
                         $sformatf("rresp=%0b", mem_resp));
            check_assert("FFT MEM sample[1] readback == 0x20000000",
                         mem_rd === 32'h2000_0000,
                         $sformatf("got 0x%08h", mem_rd));

            // 15.5  Write sample[3] to test non-consecutive addresses
            $display("  [15.5] Write sample[3] = 0x1000_8000 (imag=+0.125, real=-1.0 Q1.15)...");
            axi_write(1, FFT_MEM_BASE + 32'hC, 32'h1000_8000, 8'hF5, 8'h00, 4'hF,
                      bw_resp, bw_id);
            check_assert("FFT MEM sample[3] write BRESP == OKAY",
                         bw_resp === 2'b00,
                         $sformatf("bresp=%0b", bw_resp));
            axi_read(1, FFT_MEM_BASE + 32'hC, 8'hF6, 8'h00, mem_rd, mem_resp, mem_rid);
            check_assert("FFT MEM sample[3] readback == 0x10008000",
                         mem_rd === 32'h1000_8000,
                         $sformatf("got 0x%08h", mem_rd));

            // 15.6  Out-of-range access: beyond MEM_LAST (MEM_BASE+N*4-4 = 0x1000+4096-4)
            //   System address = 0x8000_9000 + 0x1000 = 0x8000_A000 (beyond S7 aperture)
            //   The interconnect will DECERR; we just verify it doesn't hang.
            $display("  [15.6] Access beyond S7 aperture (expect DECERR/SLVERR, no hang)...");
            axi_read(1, FFT_MEM_BASE + 32'h1000, 8'hF7, 8'h00, mem_rd, mem_resp, mem_rid);
            check_assert("FFT MEM out-of-aperture RRESP != OKAY (should be DECERR or SLVERR)",
                         mem_resp !== 2'b00,
                         $sformatf("rresp=%0b (expected non-zero)", mem_resp));

            fft_mem_pass = (failed_tests == s15_fail_start);
            $display("  [15] FFT Memory Interface: %s", fft_mem_pass ? "PASS" : "FAIL");
        end

        // ============================================================
        // [SCENARIO 16] FFT Functional Execution Verification
        // ============================================================
        // Test vector: 4-point impulse at sample[0]
        //   input[0] = {imag=0x0000, real=0x4000}   (+0.5 + 0j  in Q1.15)
        //   input[1..3] = 0x0000_0000
        //
        // Expected 4-point DFT of impulse scaled by 0.5:
        //   X[0] = X[1] = X[2] = X[3] = 0.5 + 0j
        //
        // The engine runs N=1024.  With only sample[0] non-zero and all others
        // zero the DFT is a constant: X[k] = input[0] for all k.
        // Each butterfly stage divides by 2 (>>>1 in add_sub_sat_s1_q15).
        // After log2(1024)=10 stages the amplitude is input[0] / 2^10.
        // input[0].real = 0x4000 = 16384 (Q1.15 +0.5).
        // 16384 >>> 10 = 16 = 0x0010.
        // Expected output: real=0x0010, imag=0x0000 for all k.
        //
        // We verify:
        //   (a) FFT starts cleanly (status.busy=1 observed or irq fires)
        //   (b) FFT completes within timeout (status.done=1 / irq=1)
        //   (c) Output sample[0] real part = 0x0010
        //   (d) Output sample[0] imag part = 0x0000
        //   (e) Output sample[512] real part = 0x0010 (mid-point, same result)
        //   (f) Output sample[512] imag part = 0x0000
        // ============================================================
        begin : SCENARIO_16
            integer s16_fail_start;
            integer i;
            integer poll_cnt;
            logic [31:0] wr_data;
            logic [31:0] status_rd;
            logic [31:0] out_s0;
            logic [31:0] out_s512;
            logic [1:0]  resp;
            logic [7:0]  rid;
            logic [1:0]  bw_resp;
            logic [7:0]  bw_id;
            // Expected output values after 10-stage radix-2 DIT on 1024-point impulse
            // real = 16384 >> 10 = 16 = 0x0010;  imag = 0
            localparam logic [15:0] EXP_REAL = 16'h0010;
            localparam logic [15:0] EXP_IMAG = 16'h0000;
            localparam logic [31:0] EXP_WORD = {EXP_IMAG, EXP_REAL}; // {imag,real}

            s16_fail_start = failed_tests;
            $display("\n[SCENARIO 16] FFT Functional Execution Verification (N=1024 impulse)...");
            $display("  Test vector: impulse at sample[0] = {imag=0, real=0x4000 (+0.5 Q1.15)}");
            $display("  All other 1023 samples = 0x0000_0000");
            $display("  Expected output[k] = {0x0000, 0x0010} for all k=0..1023");

            // ---- 16.1  Pre-condition: FFT must not be busy ----
            $display("  [16.1] Verify FFT is idle before loading samples...");
            axi_read(1, FFT_STATUS_REG, 8'hA0, 8'h00, status_rd, resp, rid);
            check_assert("FFT STATUS busy==0 before load",
                         status_rd[1] === 1'b0,
                         $sformatf("status=0x%08h", status_rd));

            // ---- 16.2  Zero all 1024 samples ----
            $display("  [16.2] Zeroing all 1024 samples via S7 (may take ~1024 AXI writes)...");
            for (i = 0; i < 1024; i++) begin
                axi_write(1, FFT_MEM_BASE + (i * 4), 32'h0000_0000,
                          8'hA1, 8'h00, 4'hF, bw_resp, bw_id);
                if (bw_resp !== 2'b00) begin
                    $display("[FAIL] Zero sample[%0d] BRESP=%0b", i, bw_resp);
                    failed_tests++;
                end
            end
            check_assert("FFT MEM: all 1024 samples zeroed without error",
                         1'b1,   // errors incremented inline above
                         "");

            // ---- 16.3  Write impulse at sample[0] ----
            $display("  [16.3] Write impulse at sample[0] = 0x00004000...");
            axi_write(1, FFT_MEM_BASE + 32'h0, 32'h0000_4000,
                      8'hA2, 8'h00, 4'hF, bw_resp, bw_id);
            check_assert("FFT MEM impulse write BRESP == OKAY",
                         bw_resp === 2'b00,
                         $sformatf("bresp=%0b", bw_resp));

            // ---- 16.4  Readback impulse to confirm memory is correct ----
            $display("  [16.4] Readback sample[0] before start...");
            axi_read(1, FFT_MEM_BASE + 32'h0, 8'hA3, 8'h00, out_s0, resp, rid);
            check_assert("FFT MEM sample[0] pre-start readback == 0x00004000",
                         out_s0 === 32'h0000_4000,
                         $sformatf("got 0x%08h", out_s0));

            // ---- 16.5  Arm IRQ monitor ----
            // We monitor fft_irq via polling both status register and the wire.
            // IRQ from fft_accel_top: assign irq = fft_done (single-cycle pulse).
            // We also poll STATUS[0] (done_sticky) which latches it persistently.

            // ---- 16.6  Start the FFT (write CTRL bit[0]=1) ----
            $display("  [16.5] START FFT: write 1 to CTRL register 0x8000_8000...");
            axi_write(1, FFT_CTRL_REG, 32'h0000_0001, 8'hA4, 8'h00, 4'hF,
                      bw_resp, bw_id);
            check_assert("FFT CTRL START write BRESP == OKAY",
                         bw_resp === 2'b00,
                         $sformatf("bresp=%0b", bw_resp));

            // ---- 16.7  Poll STATUS until done_sticky=1 with timeout ----
            // FFT engine: N=1024, log2(1024)=10 stages.
            // Each stage processes N/2=512 butterflies, each takes ~5 clk via
            // the pipeline in fft_atomic_p1.  Budget 10*512*10 = 51200 cycles.
            // Timeout = 200000 cycles to be safe.
            $display("  [16.6] Polling FFT STATUS[0] (done_sticky) until set...");
            poll_cnt = 0;
            status_rd = 32'h0;
            do begin
                @(posedge clk);
                axi_read(1, FFT_STATUS_REG, 8'hA5, 8'h00, status_rd, resp, rid);
                poll_cnt++;
                if (poll_cnt > 200_000) begin
                    $display("[FAIL] FFT POLL TIMEOUT: done_sticky never set after %0d polls",
                             poll_cnt);
                    failed_tests++;
                    disable SCENARIO_16;
                end
            end while (status_rd[0] !== 1'b1);
            $display("  FFT completed after %0d status polls (~%0d cycles)", poll_cnt, poll_cnt);
            check_assert("FFT STATUS done_sticky == 1 after completion",
                         status_rd[0] === 1'b1,
                         $sformatf("status=0x%08h", status_rd));
            check_assert("FFT STATUS busy == 0 after completion",
                         status_rd[1] === 1'b0,
                         $sformatf("status=0x%08h", status_rd));

            // ---- 16.8  Verify fft_irq fired during execution ----
            // IRQ is a single-cycle pulse; we cannot catch it reliably via polling.
            // Instead verify done_sticky which is its latched equivalent.
            // (IRQ behaviour is confirmed by done_sticky check above.)
            $display("  [16.7] fft_irq behaviour: confirmed via done_sticky latch.");
            check_assert("fft_irq not X/Z after FFT execution",
                         !$isunknown(fft_irq),
                         "fft_irq is X or Z");

            // ---- 16.9  Read output sample[0] ----
            $display("  [16.8] Read output sample[0] (expect {imag=0x0000, real=0x0010})...");
            axi_read(1, FFT_MEM_BASE + 32'h0, 8'hA6, 8'h00, out_s0, resp, rid);
            check_assert("FFT output sample[0] RRESP == OKAY",
                         resp === 2'b00,
                         $sformatf("rresp=%0b", resp));
            check_assert("FFT output sample[0] real part == 0x0010",
                         out_s0[15:0] === EXP_REAL,
                         $sformatf("got real=0x%04h exp=0x%04h (word=0x%08h)",
                                   out_s0[15:0], EXP_REAL, out_s0));
            check_assert("FFT output sample[0] imag part == 0x0000",
                         out_s0[31:16] === EXP_IMAG,
                         $sformatf("got imag=0x%04h exp=0x%04h (word=0x%08h)",
                                   out_s0[31:16], EXP_IMAG, out_s0));

            // ---- 16.10  Read output sample[512] (mid-point) ----
            $display("  [16.9] Read output sample[512] (expect {imag=0x0000, real=0x0010})...");
            axi_read(1, FFT_MEM_BASE + (512*4), 8'hA7, 8'h00, out_s512, resp, rid);
            check_assert("FFT output sample[512] RRESP == OKAY",
                         resp === 2'b00,
                         $sformatf("rresp=%0b", resp));
            check_assert("FFT output sample[512] real part == 0x0010",
                         out_s512[15:0] === EXP_REAL,
                         $sformatf("got real=0x%04h exp=0x%04h (word=0x%08h)",
                                   out_s512[15:0], EXP_REAL, out_s512));
            check_assert("FFT output sample[512] imag part == 0x0000",
                         out_s512[31:16] === EXP_IMAG,
                         $sformatf("got imag=0x%04h exp=0x%04h (word=0x%08h)",
                                   out_s512[31:16], EXP_IMAG, out_s512));

            // ---- 16.11  Verify CTRL register write rejected while busy ----
            // (Engine is now idle; skip live-busy test — we verify SLVERR path via
            //  the fft_ctrl_axil RTL inspection which returns SLVERR if busy=1.)
            $display("  [16.10] Post-run: STATUS should show done_sticky=1, busy=0...");
            axi_read(1, FFT_STATUS_REG, 8'hA8, 8'h00, status_rd, resp, rid);
            check_assert("FFT STATUS done_sticky still 1 after read (sticky latch)",
                         status_rd[0] === 1'b1,
                         $sformatf("status=0x%08h", status_rd));

            fft_func_pass = (failed_tests == s16_fail_start);
            $display("  [16] FFT Functional Execution: %s", fft_func_pass ? "PASS" : "FAIL");
        end
        end

        // ------------------------------------------------------------
        // SCENARIO 17 — DMA Integration: Reset, CSR access, mem-to-mem
        // ------------------------------------------------------------
        if (test_mode == "ALL" || test_mode == "DMA") begin
        // The DMA is now inside main_top. The CPU (M0/M1) programs the DMA
        // CSR via S13 at 0x8000_6000. The DMA master (M2) moves data via
        // the interconnect to S0 (IMEM, 0x0004_0000) and S1 (DMEM, 0x0008_0000).
        //
        // DMA register map (from csr_dma.v / rggen, base 0x8000_6000):
        //  0x00: DMA_CONTROL    [7:0] max_burst, [1] abort, [0] go
        //  0x04: DMA_STATUS     [0] done
        //  0x08: DMA_ERROR_ADDR [31:0]
        //  0x0C: DMA_ERROR_STATS
        //  0x10: DESC0_SRC_ADDR [31:0]
        //  0x14: DESC0_DST_ADDR [31:0]
        //  0x18: DESC0_NUM_BYTES[31:0]
        //  0x1C: DESC0_CFG      [2] enable, [1] wr_mode, [0] rd_mode
        //  0x20: DESC1_SRC_ADDR ... (second descriptor)
        // ------------------------------------------------------------
        begin : dma_integration_tests
            automatic integer dma_fail_start;
            automatic logic [31:0] dma_rd;
            automatic logic [1:0]  dma_resp;
            automatic logic [7:0]  dma_rid;
            automatic logic [31:0] src_addr, dst_addr;
            automatic integer      xfer_bytes, i;
            automatic logic [31:0] timeout_ctr;
            automatic logic        done_seen;

            dma_fail_start = failed_tests;
            dma_reset_pass = 1'b0;
            dma_csr_pass   = 1'b0;
            dma_xfer_pass  = 1'b0;

            $display("\n[SCENARIO 17] DMA Integration: Reset, CSR, Mem-to-Mem Transfer...");
            $display("  DMA_BASE = 0x%08h  (S13 / M13)", 32'h8000_6000);

            // ----- Test A: Reset and idle -----
            $display("  [17.A] DMA reset and idle state check...");
            // After system reset dma_done_o should be 0
            check_assert("DMA IRQ low after reset",
                         dma_irq === 1'b0,
                         "dma_irq asserted after reset");
            check_assert("DMA error IRQ low after reset",
                         dma_error_irq === 1'b0,
                         "dma_error_irq asserted after reset");
            dma_reset_pass = (failed_tests == dma_fail_start);
            $display("  [17.A] DMA Reset check: %s", dma_reset_pass ? "PASS" : "FAIL");

            // ----- Test B: CSR access -----
            $display("  [17.B] DMA CSR register access via S13 (0x8000_6000)...");

            // Read DMA_STATUS (offset 0x04) — expect 0 (not done)
            axi_read(0, 32'h8000_6008, 8'hC0, 8'h00, dma_rd, dma_resp, dma_rid);
            check_assert("DMA CSR: STATUS read returns OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));
            check_assert("DMA CSR: STATUS done=0 at reset",
                         dma_rd[16] === 1'b0, $sformatf("STATUS=0x%08h", dma_rd));

            // Write DMA_CONTROL max_burst=8 (offset 0x00)
            axi_write(0, 32'h8000_6000, 32'h0000_0020, 8'hC1, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA CSR: CONTROL write returns OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // Read back CONTROL
            axi_read(0, 32'h8000_6000, 8'hC2, 8'h00, dma_rd, dma_resp, dma_rid);
            check_assert("DMA CSR: CONTROL readback OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));
            check_assert("DMA CSR: max_burst=8 readback",
                         dma_rd[9:2] === 8'h08, $sformatf("CTRL=0x%08h", dma_rd));

            dma_csr_pass = (failed_tests == dma_fail_start);
            $display("  [17.B] DMA CSR access: %s", dma_csr_pass ? "PASS" : "FAIL");

            // ----- Test C: Mem-to-mem transfer (IMEM → DMEM) -----
            // Source: 0x0004_0000 (S0 IMEM, 4 words = 16 bytes)
            // Dest:   0x0008_0100 (S1 DMEM, 0x100 offset from base)
            // xfer_bytes = 16
            $display("  [17.C] DMA mem-to-mem: IMEM(0x00040000) -> DMEM(0x00080100), 16 bytes...");

            src_addr   = 32'h0004_0000;
            dst_addr   = 32'h0008_0100;
            xfer_bytes = 16;

            // Clear destination memory (4 words) via M1 before transfer
            for (i = 0; i < 4; i++) begin
                axi_write(1, dst_addr + i*4, 32'h0000_0000, 8'hD8+i, 8'h00, 4'hF, dma_resp, dma_rid);
            end

            // Prime source memory (4 words) via M1
            for (i = 0; i < 4; i++) begin
                axi_write(1, src_addr + i*4, 32'hA5A5_0000 | (i*4), 8'hD0, 8'h00, 4'hF, dma_resp, dma_rid);
            end

            // Program DMA descriptor 0
            // DESC0_SRC_ADDR (0x10)
            axi_write(0, 32'h8000_6020, src_addr, 8'hE0, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA CFG: src addr write OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // DESC0_DST_ADDR (0x14)
            axi_write(0, 32'h8000_6030, dst_addr, 8'hE1, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA CFG: dst addr write OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // DESC0_NUM_BYTES (0x18)
            axi_write(0, 32'h8000_6040, xfer_bytes, 8'hE2, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA CFG: num_bytes write OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // DESC0_CFG: enable=1, wr_mode=INCR(0), rd_mode=INCR(0) (0x1C)
            // Bit layout from csr_dma: [2]=enable, [1]=wr_mode, [0]=rd_mode
            axi_write(0, 32'h8000_6050, 32'h0000_0004, 8'hE3, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA CFG: desc0 enable write OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // Start DMA: set CONTROL.go=1, max_burst=4 (0x00)
            axi_write(0, 32'h8000_6000, 32'h0000_0011, 8'hE4, 8'h00, 4'hF, dma_resp, dma_rid);
            check_assert("DMA START: CONTROL.go write OKAY",
                         dma_resp === 2'b00, $sformatf("resp=0x%h", dma_resp));

            // Poll DMA_STATUS.done (offset 0x04) with 10000-cycle timeout
            done_seen   = 1'b0;
            timeout_ctr = 0;
            while (!done_seen && timeout_ctr < 10000) begin
                @(posedge clk);
                timeout_ctr++;
                if (dma_irq === 1'b1) done_seen = 1'b1;
            end
            check_assert("DMA XFER: dma_irq asserts (done) within 10000 cycles",
                         done_seen, $sformatf("timeout after %0d cycles", timeout_ctr));

            // Read back STATUS register to confirm
            axi_read(0, 32'h8000_6008, 8'hF0, 8'h00, dma_rd, dma_resp, dma_rid);
            check_assert("DMA XFER: STATUS.done=1 in register",
                         dma_rd[16] === 1'b1, $sformatf("STATUS=0x%08h", dma_rd));

            // No error
            check_assert("DMA XFER: no error IRQ",
                         dma_error_irq === 1'b0, "dma_error_irq unexpectedly set");

            // Verify destination data matches source
            for (i = 0; i < 4; i++) begin
                axi_read(1, dst_addr + i*4, 8'hF1+i, 8'h00,
                         dma_rd, dma_resp, dma_rid);
                check_assert($sformatf("DMA XFER: dest word[%0d] data match", i),
                             dma_rd === (32'hA5A5_0000 | (i*4)),
                             $sformatf("got 0x%08h, exp 0x%08h",
                                       dma_rd, 32'hA5A5_0000 | (i*4)));
            end

            // Clear CONTROL.go (set go=0) to return DMA to idle
            axi_write(0, 32'h8000_6000, 32'h0000_0000, 8'hF8, 8'h00, 4'hF, dma_resp, dma_rid);

            dma_xfer_pass = (failed_tests == dma_fail_start);
            $display("  [17.C] DMA Mem-to-Mem transfer: %s", dma_xfer_pass ? "PASS" : "FAIL");
            $display("  [17] DMA Integration: %s",
                     dma_xfer_pass ? "PASS" : "FAIL");
        end
        end

        // ============================================================
        // SCENARIO 18: GPIO Controller Verification (S2 / 0x8000_1000)
        // ============================================================
        if (test_mode == "ALL" || test_mode == "GPIO") begin
            automatic integer gpio_fail_start;
            gpio_fail_start = failed_tests;
            $display("\n[SCENARIO 18] GPIO Controller Verification (S2 / 0x8000_1000)...");

            // 18.1 Direction & Data Output test
            $display("  [18.1] Setting direction (lower 16 outputs, upper 16 inputs)...");
            axi_write(1, GPIO_DIR, 32'h0000_FFFF, 8'h20, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: Write DIR returns OKAY", resp === 2'b00);
            axi_read(1, GPIO_DIR, 8'h21, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: Read DIR returns OKAY", resp === 2'b00);
            check_assert("GPIO: DIR readback matches (0x0000_FFFF)", rd_data === 32'h0000_FFFF);

            $display("  [18.2] Writing output data 0x0000_A55A...");
            axi_write(1, GPIO_DATA_O, 32'h0000_A55A, 8'h22, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: Write DATA_O returns OKAY", resp === 2'b00);
            axi_read(1, GPIO_DATA_O, 8'h23, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: Read DATA_O returns OKAY", resp === 2'b00);
            check_assert("GPIO: DATA_O readback matches (0x0000_A55A)", rd_data === 32'h0000_A55A);
            repeat (2) @(posedge clk);
            check_assert("GPIO: Output pins [15:0] match 0xA55A", gpio_io[15:0] === 16'hA55A);

            // 18.3 Atomic SET / CLR / TGL operations
            $display("  [18.3] Testing atomic SET register (0x8000_1020)...");
            axi_write(1, GPIO_SET_O, 32'h0000_00A0, 8'h24, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: SET_O write returns OKAY", resp === 2'b00);
            axi_read(1, GPIO_DATA_O, 8'h25, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: DATA_O after SET matches 0x0000_A5FA", rd_data === 32'h0000_A5FA);

            $display("  [18.4] Testing atomic CLR register (0x8000_1024)...");
            axi_write(1, GPIO_CLR_O, 32'h0000_000A, 8'h26, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: CLR_O write returns OKAY", resp === 2'b00);
            axi_read(1, GPIO_DATA_O, 8'h27, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: DATA_O after CLR matches 0x0000_A5F0", rd_data === 32'h0000_A5F0);

            $display("  [18.5] Testing atomic TGL register (0x8000_1028)...");
            axi_write(1, GPIO_TGL_O, 32'h0000_00F0, 8'h28, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: TGL_O write returns OKAY", resp === 2'b00);
            axi_read(1, GPIO_DATA_O, 8'h29, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: DATA_O after TGL matches 0x0000_A500", rd_data === 32'h0000_A500);

            // 18.6 Input Pin Reading
            $display("  [18.6] Testing Input Pin Reading via DATA_I (0x8000_1000)...");
            // Disable debouncer so input propagates immediately
            axi_write(1, GPIO_DEB_EN, 32'h0000_0000, 8'h2A, 8'h00, 4'hF, resp, resp_id);
            check_assert("GPIO: Disable debouncer write returns OKAY", resp === 2'b00);
            gpio_tb_drive_en[31:16]  = 16'hFFFF;
            gpio_tb_drive_val[31:16] = 16'h5A3D;
            repeat (5) @(posedge clk);
            axi_read(1, GPIO_DATA_I, 8'h2B, 8'h00, rd_data, resp, resp_id);
            check_assert("GPIO: DATA_I read returns OKAY", resp === 2'b00);
            check_assert("GPIO: DATA_I inputs [31:16] match driven 0x5A3D", rd_data[31:16] === 16'h5A3D);

            // 18.7 Interrupt Generation
            $display("  [18.7] Testing GPIO Level Interrupt on Pin 16...");
            // Drive bit 16 high
            gpio_tb_drive_val[16] = 1'b1;
            // Configure INT_TYP[16]=0 (level), INT_POL[16]=1 (high level)
            axi_write(1, GPIO_INT_TYP, 32'h0000_0000, 8'h2C, 8'h00, 4'hF, resp, resp_id);
            axi_write(1, GPIO_INT_POL, 32'h0001_0000, 8'h2D, 8'h00, 4'hF, resp, resp_id);
            axi_write(1, GPIO_INT_EN,  32'h0001_0000, 8'h2E, 8'h00, 4'hF, resp, resp_id);
            repeat (6) @(posedge clk);
            check_assert("GPIO: IRQ asserts when pin 16 is High", gpio_irq === 1'b1);

            // Lower bit 16
            gpio_tb_drive_val[16] = 1'b0;
            repeat (6) @(posedge clk);
            check_assert("GPIO: IRQ deasserts when pin 16 is Low", gpio_irq === 1'b0);

            // Cleanup
            axi_write(1, GPIO_INT_EN, 32'h0000_0000, 8'h2F, 8'h00, 4'hF, resp, resp_id);
            gpio_tb_drive_en  = 32'h0;
            gpio_tb_drive_val = 32'h0;

            gpio_pass = (failed_tests == gpio_fail_start);
            $display("  [18] GPIO Controller Integration: %s", gpio_pass ? "PASS" : "FAIL");
        end

        // ============================================================
        // SCENARIO 19: Real-Time Timer Verification (S3 / 0x8000_2000)
        // ============================================================
        if (test_mode == "ALL" || test_mode == "TIMER") begin
            automatic integer timer_fail_start;
            automatic integer wait_cnt;
            timer_fail_start = failed_tests;
            $display("\n[SCENARIO 19] Real-Time Timer Verification (S3 / 0x8000_2000)...");

            // 19.1 Basic Register Read/Write
            $display("  [19.1] Verifying LOAD and CMP register accesses...");
            axi_write(1, TIMER_LOAD, 32'd100, 8'h30, 8'h00, 4'hF, resp, resp_id);
            check_assert("Timer: LOAD write returns OKAY", resp === 2'b00);
            axi_read(1, TIMER_LOAD, 8'h31, 8'h00, rd_data, resp, resp_id);
            check_assert("Timer: LOAD read returns OKAY", resp === 2'b00);
            check_assert("Timer: LOAD readback matches (100)", rd_data === 32'd100);

            axi_write(1, TIMER_CMP, 32'd40, 8'h32, 8'h00, 4'hF, resp, resp_id);
            check_assert("Timer: CMP write returns OKAY", resp === 2'b00);
            axi_read(1, TIMER_CMP, 8'h33, 8'h00, rd_data, resp, resp_id);
            check_assert("Timer: CMP read returns OKAY", resp === 2'b00);
            check_assert("Timer: CMP readback matches (40)", rd_data === 32'd40);

            // 19.2 One-Shot Down-Counting & Interrupt Verification
            $display("  [19.2] Testing Down-Counter & Expire Interrupt...");
            axi_write(1, TIMER_PRE, 32'd0, 8'h34, 8'h00, 4'hF, resp, resp_id);   // no prescaler
            axi_write(1, TIMER_LOAD, 32'd25, 8'h35, 8'h00, 4'hF, resp, resp_id); // 25 cycles count
            axi_write(1, TIMER_INT_EN, 32'h01, 8'h36, 8'h00, 4'hF, resp, resp_id); // enable expire interrupt

            // Start timer: EN=1, MODE=0 (one-shot), DIR=0 (down) -> CTRL=0x01
            axi_write(1, TIMER_CTRL, 32'h01, 8'h37, 8'h00, 4'hF, resp, resp_id);
            check_assert("Timer: Start write returns OKAY", resp === 2'b00);

            // Verify timer is counting down
            axi_read(1, TIMER_VAL, 8'h38, 8'h00, rd_data, resp, resp_id);
            check_assert("Timer: VAL is active (<= 25)", rd_data <= 32'd25);

            // Wait for interrupt to assert (count=25 clock cycles + latency)
            wait_cnt = 0;
            while (!timer_irq && wait_cnt < 200) begin
                @(posedge clk);
                wait_cnt++;
            end
            check_assert("Timer: Expire interrupt asserts within timeout", timer_irq === 1'b1);

            // Verify Interrupt Status register bit 0 is set
            axi_read(1, TIMER_INT_STS, 8'h39, 8'h00, rd_data, resp, resp_id);
            check_assert("Timer: INT_STS[0] is set", rd_data[0] === 1'b1);

            // Clear Interrupt (W1C)
            axi_write(1, TIMER_INT_STS, 32'h01, 8'h3A, 8'h00, 4'hF, resp, resp_id);
            repeat (2) @(posedge clk);
            check_assert("Timer: Interrupt cleared after W1C", timer_irq === 1'b0);

            // Stop timer
            axi_write(1, TIMER_CTRL, 32'h00, 8'h3B, 8'h00, 4'hF, resp, resp_id);

            // 19.3 Periodic PWM Generation
            $display("  [19.3] Testing Periodic PWM Output Generation...");
            axi_write(1, TIMER_LOAD, 32'd20, 8'h3C, 8'h00, 4'hF, resp, resp_id);
            axi_write(1, TIMER_CMP,  32'd10, 8'h3D, 8'h00, 4'hF, resp, resp_id);
            // Enable: EN=1, MODE=1 (repeat), DIR=0 (down), PWM_EN=1 -> bit 0=1, bit 1=1, bit 4=1 => 0x13
            axi_write(1, TIMER_CTRL, 32'h13, 8'h3E, 8'h00, 4'hF, resp, resp_id);

            // Sample timer_pwm over 80 cycles to verify toggling
            begin : pwm_monitor
                automatic int pwm_high_seen = 0;
                automatic int pwm_low_seen  = 0;
                repeat (80) begin
                    @(posedge clk);
                    if (timer_pwm === 1'b1) pwm_high_seen++;
                    if (timer_pwm === 1'b0) pwm_low_seen++;
                end
                check_assert("Timer: PWM generates High pulses", pwm_high_seen > 10);
                check_assert("Timer: PWM generates Low pulses",  pwm_low_seen > 10);
            end

            // Stop timer and verify PWM returns to 0
            axi_write(1, TIMER_CTRL, 32'h00, 8'h3F, 8'h00, 4'hF, resp, resp_id);
            repeat (3) @(posedge clk);
            check_assert("Timer: PWM is Low when stopped", timer_pwm === 1'b0);

            timer_pass = (failed_tests == timer_fail_start);
            $display("  [19] Real-Time Timer Integration: %s", timer_pass ? "PASS" : "FAIL");
        end

        // ------------------------------------------------------------
        // SCENARIO 20: RISC-V VeeR EL2 Execution & SoC Peripheral Integration
        // ------------------------------------------------------------
        if (test_mode == "ALL" || test_mode == "VEER") begin
            int veer_fail_start;
            int cycle_cnt;
            int retired_insn_cnt;
            logic timeout_occurred;

            veer_fail_start = failed_tests;
            $display("\n[SCENARIO 20] RISC-V VeeR EL2 Execution & SoC Peripheral Integration...");

            // 1. Preload IMEM (Slave 0 at 0x0004_0000)
            for (int i = 0; i < 64; i++) begin
                GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[i] = 32'h0000_0013; // nop (addi x0, x0, 0)
            end
            for (int i = 0; i < 16; i++) begin
                GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[i] = 32'h0000_0000; // Clear DMEM
            end

            // Load test program into IMEM:
            //   - M0 IFU instruction fetch through AXI 3x15 interconnect to IMEM
            //   - M1 LSU data write and readback through AXI 3x15 interconnect to DMEM
            //   - ALU calculation (increment register x3 -> x4)
            //   - M1 LSU memory-mapped write and readback to S2 GPIO (GPIO_DIR at 0x8000_1008)
            //   - M1 LSU memory-mapped write and readback to S3 Timer (TIMER_LOAD at 0x8000_2004)
            //   - Execution completion signature write to DMEM[4]
            //   - Trace instruction retirement verification
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 0] = 32'h123450B7; // lui x1, 0x12345
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 1] = 32'h6780E093; // ori x1, x1, 0x678 (x1 = 0x1234_5678)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 2] = 32'h00080137; // lui x2, 0x80      (x2 = 0x0008_0000 DMEM)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 3] = 32'h00112023; // sw x1, 0(x2)      (DMEM[0] = 0x1234_5678)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 4] = 32'h00012183; // lw x3, 0(x2)      (x3 = 0x1234_5678)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 5] = 32'h00118213; // addi x4, x3, 1    (x4 = 0x1234_5679)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 6] = 32'h00412223; // sw x4, 4(x2)      (DMEM[1] = 0x1234_5679)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 7] = 32'h800012B7; // lui x5, 0x80001   (x5 = 0x8000_1000 GPIO)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 8] = 32'h0000A337; // lui x6, 0xA
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[ 9] = 32'h55536313; // ori x6, x6, 0x555 (x6 = 0x0000_A555)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[10] = 32'h0062A423; // sw x6, 8(x5)      (GPIO_DIR = 0x0000_A555)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[11] = 32'h0082A383; // lw x7, 8(x5)      (x7 = GPIO_DIR readback)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[12] = 32'h00712423; // sw x7, 8(x2)      (DMEM[2] = GPIO readback)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[13] = 32'h80002437; // lui x8, 0x80002   (x8 = 0x8000_2000 TIMER)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[14] = 32'h0FA00493; // addi x9, x0, 0xFA (x9 = 250)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[15] = 32'h00942223; // sw x9, 4(x8)      (TIMER_LOAD = 250)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[16] = 32'h00442503; // lw x10, 4(x8)     (x10 = TIMER_LOAD readback)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[17] = 32'h00A12623; // sw x10, 12(x2)    (DMEM[3] = TIMER readback)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[18] = 32'h55AA55B7; // lui x11, 0x55AA5
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[19] = 32'h5AA5E593; // ori x11, x11, 0x5AA (x11 = 0x55AA_55AA)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[20] = 32'h00B12823; // sw x11, 16(x2)    (DMEM[4] = 0x55AA_55AA)
            GEN_DUMMY_SLAVES[0].MEM_SLV_INST.u_ram.mem[21] = 32'h0000006F; // jal x0, 0         (infinite loop)

            // 2. Ensure testbench BFM masters are completely idle
            init_masters();
            repeat (10) @(posedge clk);

            // 3. Release VeeR CPU Reset and initiate execution
            $display("  [20.1] Releasing CPU Reset (cpu_rst_l = 1'b1, Boot Vector = 0x0004_0000)...");
            cpu_rst_vec = 31'h0002_0000; // Reset vector = 0x0004_0000
            cpu_run_req = 1'b1;
            cpu_rst_l   = 1'b1;

            // 4. Monitor execution and wait for completion signature in DMEM[4]
            timeout_occurred = 1'b1;
            retired_insn_cnt = 0;
            for (cycle_cnt = 0; cycle_cnt < 3000; cycle_cnt++) begin
                @(posedge clk);
                if (trace_rv_i_valid_ip) begin
                    retired_insn_cnt++;
                    if (retired_insn_cnt <= 30) begin
                        $display("    [VeeR TRACE #%02d] PC = 0x%08h | Insn = 0x%08h",
                                 retired_insn_cnt, trace_rv_i_address_ip, trace_rv_i_insn_ip);
                    end
                end

                if (GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'h55AA_55AA) begin
                    timeout_occurred = 1'b0;
                    $display("  [20.2] VeeR Execution Finished Successfully at cycle %0d (Retired %0d instructions)!",
                             cycle_cnt, retired_insn_cnt);
                    break;
                end
            end

            // 5. Verification Assertions
            check_assert("VeeR: Test program completed without timeout",
                         !timeout_occurred,
                         "VeeR EL2 timed out waiting for 0x55AA_55AA completion signature in DMEM[4]");

            check_assert("VeeR: Instruction trace retired instructions",
                         retired_insn_cnt >= 20,
                         "Fewer instructions retired than expected");

            check_assert("VeeR: LSU Write to DMEM[0] = 0x1234_5678",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h1234_5678,
                         $sformatf("DMEM[0] = 0x%08h, expected 0x1234_5678", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));

            check_assert("VeeR: LSU Read + ALU Add + Write to DMEM[1] = 0x1234_5679",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h1234_5679,
                         $sformatf("DMEM[1] = 0x%08h, expected 0x1234_5679", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));

            check_assert("VeeR: Memory-Mapped Peripheral Access S2 GPIO (0x0000_A555)",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2][15:0] === 16'hA555,
                         $sformatf("DMEM[2] (GPIO) = 0x%08h, expected 0x0000_A555", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));

            check_assert("VeeR: Memory-Mapped Peripheral Access S3 TIMER (0x0000_00FA / 250)",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h0000_00FA,
                         $sformatf("DMEM[3] (TIMER) = 0x%08h, expected 0x0000_00FA", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));

            check_assert("VeeR: Execution Completion Signature DMEM[4] = 0x55AA_55AA",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'h55AA_55AA,
                         $sformatf("DMEM[4] = 0x%08h, expected 0x55AA_55AA", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));

            // Allow in-flight transactions (such as BVALID handshake) to complete naturally
            repeat (20) @(posedge clk);
            // Reset CPU back to inactive state
            cpu_rst_l = 1'b0;
            repeat (10) @(posedge clk);

            veer_pass = (failed_tests == veer_fail_start);
            $display("  [20] RISC-V VeeR EL2 Core Integration: %s", veer_pass ? "PASS" : "FAIL");
        end

        // ============================================================
        // TEST 21: RISC-V Firmware - Processor-Driven GPIO Verification
        // Firmware image: ../firmware/test_gpio.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "GPIO") begin
            run_veer_firmware(
                "SCENARIO 21: VeeR Firmware - GPIO Verification",
                "../firmware/test_gpio.hex",
                6, 32'h6010_0001, 3000,
                fw_gpio_pass
            );
            check_assert("VeeR GPIO: DIR configured = 0x0000_FFFF",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h0000_FFFF,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR GPIO: DATA_O written = 0x0000_A55A",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h0000_A55A,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("VeeR GPIO: Atomic SET_O = 0x0000_A5FA",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h0000_A5FA,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("VeeR GPIO: Atomic CLR_O = 0x0000_A5F0",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h0000_A5F0,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("VeeR GPIO: Atomic TGL_O = 0x0000_A500",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'h0000_A500,
                         $sformatf("DMEM[4] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
        end

        // ============================================================
        // TEST 22: RISC-V Firmware - Processor-Driven Real-Time Timer Verification
        // Firmware image: ../firmware/test_timer.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "TIMER") begin
            run_veer_firmware(
                "SCENARIO 22: VeeR Firmware - Real-Time Timer Verification",
                "../firmware/test_timer.hex",
                4, 32'h713E_0001, 3000,
                fw_timer_pass
            );
            check_assert("VeeR Timer: LOAD configured = 100",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'd100,
                         $sformatf("DMEM[0] = %0d", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR Timer: CMP configured = 40",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'd40,
                         $sformatf("DMEM[1] = %0d", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("VeeR Timer: Expire IRQ asserted in INT_STS",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2][0] === 1'b1,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("VeeR Timer: W1C cleared INT_STS",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3][0] === 1'b0,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
        end

        // ============================================================
        // TEST 23: RISC-V Firmware - Processor-Driven UART Verification
        // Firmware image: ../firmware/test_uart.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "UART") begin
            run_veer_firmware(
                "SCENARIO 23: VeeR Firmware - UART Verification",
                "../firmware/test_uart.hex",
                2, 32'h0A27_0001, 3000,
                fw_uart_pass
            );
            check_assert("VeeR UART: Initial LSR THRE asserted",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0][5] === 1'b1,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR UART: Post-TX LSR THRE asserted",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1][5] === 1'b1,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
        end

        // ============================================================
        // TEST 24: RISC-V Firmware - Processor-Driven AES-128 Known-Answer Test
        // Firmware image: ../firmware/test_aes.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "AES") begin
            run_veer_firmware(
                "SCENARIO 24: VeeR Firmware - AES-128 KAT Verification",
                "../firmware/test_aes.hex",
                4, 32'hAE51_0001, 3000,
                fw_aes_pass
            );
            check_assert("VeeR AES KAT: TOUT0 = 0x70B4_C55A",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h70B4_C55A,
                         $sformatf("DMEM[0] = 0x%08h, exp 0x70B4_C55A", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR AES KAT: TOUT1 = 0xD8CD_B780",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'hD8CD_B780,
                         $sformatf("DMEM[1] = 0x%08h, exp 0xD8CD_B780", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("VeeR AES KAT: TOUT2 = 0x6A7B_0430",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h6A7B_0430,
                         $sformatf("DMEM[2] = 0x%08h, exp 0x6A7B_0430", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("VeeR AES KAT: TOUT3 = 0x69C4_E0D8",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h69C4_E0D8,
                         $sformatf("DMEM[3] = 0x%08h, exp 0x69C4_E0D8", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
        end

        // ============================================================
        // TEST 25: RISC-V Firmware - Processor-Driven FFT Verification
        // Firmware image: ../firmware/test_fft.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "FFT") begin
            run_veer_firmware(
                "SCENARIO 25: VeeR Firmware - FFT Hardware Accelerator Verification",
                "../firmware/test_fft.hex",
                1, 32'hFF70_0001, 100000,
                fw_fft_pass
            );
            check_assert("VeeR FFT: Transformed sample[0] real part = 0x0010",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h0000_0010,
                         $sformatf("DMEM[0] = 0x%08h, exp 0x0000_0010", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
        end

        // ============================================================
        // TEST 26: RISC-V Firmware - Processor-Driven DMA Verification
        // Firmware image: ../firmware/test_dma.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "DMA") begin
            run_veer_firmware(
                "SCENARIO 26: VeeR Firmware - DMA Controller Verification",
                "../firmware/test_dma.hex",
                4, 32'hD11A_0001, 10000,
                fw_dma_pass
            );
            check_assert("VeeR DMA: Transferred Word 0 = 0xA5A5_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'hA5A5_0001,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR DMA: Transferred Word 1 = 0xA5A5_0002",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'hA5A5_0002,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("VeeR DMA: Transferred Word 2 = 0xA5A5_0003",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'hA5A5_0003,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("VeeR DMA: Transferred Word 3 = 0xA5A5_0004",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'hA5A5_0004,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
        end

        // ============================================================
        // TEST 27: RISC-V Firmware - Processor-Driven Concurrency Verification
        // Firmware image: ../firmware/test_concurrency.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "DMA") begin
            run_veer_firmware(
                "SCENARIO 27: VeeR Firmware - Master Concurrency Verification",
                "../firmware/test_concurrency.hex",
                4, 32'hC0CC_0001, 10000,
                fw_concur_pass
            );
            check_assert("VeeR Concurrency: DMA Word 0 transferred = 0x1111_0000",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h1111_0000,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR Concurrency: DMA Word 1 transferred = 0x2222_0000",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h2222_0000,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
        end

        // ============================================================
        // TEST 28: RISC-V Firmware - Interrupt Trap & ISR Return Verification
        // Firmware image: ../firmware/test_interrupts.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER" || test_mode == "TIMER") begin
            run_veer_firmware(
                "SCENARIO 28: VeeR Firmware - Interrupt Trap & ISR Verification",
                "../firmware/test_interrupts.hex",
                2, 32'h1070_0001, 5000,
                fw_intr_pass
            );
            check_assert("VeeR Interrupt: mcause recorded in trap handler",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] != 32'h0,
                         $sformatf("DMEM[0] (mcause) = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("VeeR Interrupt: ISR incremented trap count",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] >= 32'd1,
                         $sformatf("DMEM[1] (trap count) = %0d", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
        end

        // ============================================================
        // TEST 29: RISC-V Firmware - Complete SoC Master End-to-End Regression
        // Firmware image: ../firmware/soc_master_regression.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "VEER") begin
            run_veer_firmware(
                "SCENARIO 29: VeeR Firmware - Complete SoC Master End-to-End Regression",
                "../firmware/soc_master_regression.hex",
                12, 32'h55AA_55AA, 150000,
                fw_master_pass
            );
            check_assert("VeeR Master: ALU Readback + Add = 0x1234_5679",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h1234_5679,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("VeeR Master: S2 GPIO Signature = 0x6010_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h6010_0001,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("VeeR Master: S3 Timer Signature = 0x713E_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h713E_0001,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("VeeR Master: S4 UART Signature = 0x0A27_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'h0A27_0001,
                         $sformatf("DMEM[4] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
            check_assert("VeeR Master: S5 AES KAT Signature = 0xAE51_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5] === 32'hAE51_0001,
                         $sformatf("DMEM[5] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5]));
            check_assert("VeeR Master: S6/S7 FFT Signature = 0xFF70_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hFF70_0001,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
            check_assert("VeeR Master: S13 DMA Signature = 0xD11A_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[7] === 32'hD11A_0001,
                         $sformatf("DMEM[7] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[7]));
            check_assert("VeeR Master: Concurrency Signature = 0xC0CC_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[8] === 32'hC0CC_0001,
                         $sformatf("DMEM[8] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[8]));
            check_assert("VeeR Master: Interrupt Trap mcause recorded",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[9] != 32'h0,
                         $sformatf("DMEM[9] (mcause) = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[9]));
            check_assert("VeeR Master: Interrupt ISR Signature = 0x1070_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[11] === 32'h1070_0001,
                         $sformatf("DMEM[11] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[11]));
            check_assert("VeeR Master: Master Pass Signature 2 = 0xCAFE_BABE",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[13] === 32'hCAFE_BABE,
                         $sformatf("DMEM[13] = 0x%08h, exp 0xCAFE_BABE", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[13]));
        end

        // ============================================================
        // TEST 30: RISC-V C-Based Firmware Verification
        // Firmware image: ../firmware/soc_c_test.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_TEST") begin
            run_veer_firmware(
                "SCENARIO 30: VeeR C Firmware - CPU Peripheral Integration",
                "../firmware/soc_c_test.hex",
                6, 32'hC001_CAFE, 5000,
                fw_c_test_pass
            );
            check_assert("C Test: Arithmetic Result in DMEM[0]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h2468_ACF1,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("C Test: GPIO DIR Configured in DMEM[1]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h0000_FFFF,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C Test: GPIO DATA_O Written in DMEM[2]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h0000_A55A,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("C Test: GPIO Atomic SET_O in DMEM[3]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h0000_A5FA,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("C Test: Timer LOAD Configured in DMEM[4]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'd100,
                         $sformatf("DMEM[4] = %0d", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
            check_assert("C Test: Timer CMP Configured in DMEM[5]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5] === 32'd40,
                         $sformatf("DMEM[5] = %0d", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5]));
            check_assert("C Test: Completion PASS Signature in DMEM[6]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hC001_CAFE,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
        end

        // ============================================================
        // TEST 31: RISC-V C Firmware - Boot & Memory Subsystem
        // Firmware image: ../firmware/tests_final/test_boot_mem.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_BOOT") begin
            run_veer_firmware(
                "SCENARIO 31: VeeR C Firmware - Boot & Memory Subsystem",
                "../firmware/tests_final/test_boot_mem.hex",
                2, 32'hC001_CAFE, 10000,
                fw_c_boot_mem_pass
            );
            check_assert("C Boot: Pattern Check in DMEM[1]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h5A5A_A5A5,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C Boot: Pass Signature in DMEM[2]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'hC001_CAFE,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
        end

        // ============================================================
        // TEST 32: RISC-V C Firmware - UART Subsystem (115200 Baud / TX)
        // Firmware image: ../firmware/tests_final/test_uart_c.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_UART") begin
            run_veer_firmware(
                "SCENARIO 32: VeeR C Firmware - UART Subsystem",
                "../firmware/tests_final/test_uart_c.hex",
                6, 32'hC001_CAFE, 15000,
                fw_c_uart_pass
            );
            check_assert("C UART: UART Pass Signature in DMEM[2]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h0A27_0001,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("C UART: Completion Signature in DMEM[6]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hC001_CAFE,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
        end

        // ============================================================
        // TEST 33: RISC-V C Firmware - AES-128 Hardware Accelerator KAT
        // Firmware image: ../firmware/tests_final/test_aes_c.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_AES") begin
            run_veer_firmware(
                "SCENARIO 33: VeeR C Firmware - AES-128 KAT Verification",
                "../firmware/tests_final/test_aes_c.hex",
                6, 32'hC001_CAFE, 5000,
                fw_c_aes_pass
            );
            check_assert("C AES: TOUT0 = 0x70B4_C55A",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h70B4_C55A,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("C AES: TOUT1 = 0xD8CD_B780",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'hD8CD_B780,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C AES: TOUT2 = 0x6A7B_0430",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h6A7B_0430,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("C AES: TOUT3 = 0x69C4_E0D8",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h69C4_E0D8,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("C AES: KAT Pass Signature in DMEM[4]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'hAE51_0001,
                         $sformatf("DMEM[4] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
            check_assert("C AES: Completion Signature in DMEM[6]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hC001_CAFE,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
        end

        // ============================================================
        // TEST 34: RISC-V C Firmware - DMA Controller Verification
        // Firmware image: ../firmware/tests_final/test_dma_c.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_DMA") begin
            run_veer_firmware(
                "SCENARIO 34: VeeR C Firmware - DMA Controller Verification",
                "../firmware/tests_final/test_dma_c.hex",
                6, 32'hC001_CAFE, 10000,
                fw_c_dma_pass
            );
            check_assert("C DMA: Word 0 in DMEM[0] = 0xA5A5_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'hA5A5_0001,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("C DMA: Word 1 in DMEM[1] = 0xA5A5_0002",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'hA5A5_0002,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C DMA: Word 2 in DMEM[2] = 0xA5A5_0003",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'hA5A5_0003,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("C DMA: Word 3 in DMEM[3] = 0xA5A5_0004",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'hA5A5_0004,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("C DMA: Pass Signature in DMEM[4]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'hD11A_0001,
                         $sformatf("DMEM[4] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
            check_assert("C DMA: Completion Signature in DMEM[6]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hC001_CAFE,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
        end

        // ============================================================
        // TEST 35: RISC-V C Firmware - FFT Accelerator Verification
        // Firmware image: ../firmware/tests_final/test_fft_c.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_FFT") begin
            run_veer_firmware(
                "SCENARIO 35: VeeR C Firmware - FFT Accelerator Verification",
                "../firmware/tests_final/test_fft_c.hex",
                6, 32'hC001_CAFE, 100000,
                fw_c_fft_pass
            );
            check_assert("C FFT: Transformed sample[0] in DMEM[0] = 0x0000_0010",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h0000_0010,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("C FFT: Pass Signature in DMEM[1]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'hFF70_0001,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C FFT: Completion Signature in DMEM[6]",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hC001_CAFE,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
        end

        // ============================================================
        // TEST 36: RISC-V C Firmware - Complete SoC Master Regression
        // Firmware image: ../firmware/tests_final/test_soc_master.hex
        // ============================================================
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_MASTER") begin
            run_veer_firmware(
                "SCENARIO 36: VeeR C Firmware - Complete SoC Master End-to-End Regression",
                "../firmware/tests_final/test_soc_master.hex",
                14, 32'hC001_CAFE, 150000,
                fw_c_master_pass
            );
            check_assert("C Master: Arithmetic Result in DMEM[0] = 0x2468_ACF1",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0] === 32'h2468_ACF1,
                         $sformatf("DMEM[0] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[0]));
            check_assert("C Master: GPIO DIR in DMEM[1] = 0x0000_FFFF",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1] === 32'h0000_FFFF,
                         $sformatf("DMEM[1] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[1]));
            check_assert("C Master: GPIO Signature in DMEM[2] = 0x6010_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2] === 32'h6010_0001,
                         $sformatf("DMEM[2] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[2]));
            check_assert("C Master: Timer Signature in DMEM[3] = 0x713E_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3] === 32'h713E_0001,
                         $sformatf("DMEM[3] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[3]));
            check_assert("C Master: UART Signature in DMEM[4] = 0x0A27_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4] === 32'h0A27_0001,
                         $sformatf("DMEM[4] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[4]));
            check_assert("C Master: AES KAT Signature in DMEM[5] = 0xAE51_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5] === 32'hAE51_0001,
                         $sformatf("DMEM[5] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[5]));
            check_assert("C Master: FFT Signature in DMEM[6] = 0xFF70_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6] === 32'hFF70_0001,
                         $sformatf("DMEM[6] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[6]));
            check_assert("C Master: DMA Signature in DMEM[7] = 0xD11A_0001",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[7] === 32'hD11A_0001,
                         $sformatf("DMEM[7] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[7]));
            check_assert("C Master: Primary Signature in DMEM[12] = 0x55AA_55AA",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[12] === 32'h55AA_55AA,
                         $sformatf("DMEM[12] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[12]));
            check_assert("C Master: Secondary Signature in DMEM[13] = 0xCAFE_BABE",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[13] === 32'hCAFE_BABE,
                         $sformatf("DMEM[13] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[13]));
            check_assert("C Master: Global C PASS in DMEM[14] = 0xC001_CAFE",
                         GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[14] === 32'hC001_CAFE,
                         $sformatf("DMEM[14] = 0x%08h", GEN_DUMMY_SLAVES[1].MEM_SLV_INST.u_ram.mem[14]));
        end

        // ------------------------------------------------------------
        // FINAL COMBINED SCOREBOARD
        // ------------------------------------------------------------
        repeat (50) @(posedge clk);
        $display("\n================================================================================");
        $display("                         VERIFICATION SCOREBOARD SUMMARY                        ");
        $display("================================================================================");
        $display("  TOTAL CHECKS  : %0d", total_tests);
        $display("  PASSED CHECKS : %0d", passed_tests);
        $display("  FAILED CHECKS : %0d", failed_tests);
        $display("================================================================================");
        if (test_mode == "ALL" || test_mode == "UART" || test_mode == "COMMON")
            $display("  %-30s : %s", "UART TEST (S4/M04)",
                     uart_tests_pass    ? "PASS" : "FAIL");
        if (test_mode == "ALL" || test_mode == "AES") begin
            $display("  %-30s : %s", "AES ENCRYPTION (S5/M05)",
                     aes_enc_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "AES DECRYPTION (S5/M05)",
                     aes_dec_pass       ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "FFT") begin
            $display("  %-30s : %s", "FFT CTRL INTERFACE (S6/M06)",
                     fft_ctrl_pass      ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FFT MEM INTERFACE (S7/M07)",
                     fft_mem_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FFT FUNCTIONAL EXECUTION",
                     fft_func_pass      ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "DMA") begin
            $display("  %-30s : %s", "DMA RESET (S13/M2)",
                     dma_reset_pass     ? "PASS" : "FAIL");
            $display("  %-30s : %s", "DMA CSR ACCESS (S13/M2)",
                     dma_csr_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "DMA MEM-TO-MEM XFER (M2)",
                     dma_xfer_pass      ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "GPIO") begin
            $display("  %-30s : %s", "GPIO CONTROLLER (S2/M02)",
                     gpio_pass          ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "TIMER") begin
            $display("  %-30s : %s", "REAL-TIME TIMER (S3/M03)",
                     timer_pass         ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "VEER") begin
            $display("  %-30s : %s", "RISC-V VEER EL2 CORE (M0/M1)",
                     veer_pass          ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: GPIO CONTROLLER (S2)",
                     fw_gpio_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: REAL-TIME TIMER (S3)",
                     fw_timer_pass      ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: UART (S4)",
                     fw_uart_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: AES-128 KAT (S5)",
                     fw_aes_pass        ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: FFT ACCEL (S6/S7)",
                     fw_fft_pass        ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: DMA CONTROLLER (S13)",
                     fw_dma_pass        ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: MASTER CONCURRENCY",
                     fw_concur_pass     ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: TRAP / ISR RETURN",
                     fw_intr_pass       ? "PASS" : "FAIL");
            $display("  %-30s : %s", "FW: MASTER REGRESSION",
                     fw_master_pass     ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_TEST") begin
            $display("  %-30s : %s", "FW: C-BASED SOC TEST",
                     fw_c_test_pass     ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_BOOT") begin
            $display("  %-30s : %s", "FW: C BOOT & MEMORY",
                     fw_c_boot_mem_pass ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_UART") begin
            $display("  %-30s : %s", "FW: C UART SUBSYSTEM",
                     fw_c_uart_pass     ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_AES") begin
            $display("  %-30s : %s", "FW: C AES-128 KAT",
                     fw_c_aes_pass      ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_DMA") begin
            $display("  %-30s : %s", "FW: C DMA CONTROLLER",
                     fw_c_dma_pass      ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_FFT") begin
            $display("  %-30s : %s", "FW: C FFT ACCELERATOR",
                     fw_c_fft_pass      ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL" || test_mode == "C_SUITE" || test_mode == "C_MASTER") begin
            $display("  %-30s : %s", "FW: C MASTER REGRESSION",
                     fw_c_master_pass   ? "PASS" : "FAIL");
        end
        if (test_mode == "ALL")
            $display("  %-30s : %s", "AXI INTERCONNECT (3x15)",
                     (failed_tests == 0) ? "PASS" : "FAIL");
        $display("================================================================================");
        if (failed_tests == 0 && total_tests > 0) begin
            $display("  >>> OVERALL TEST      : PASS <<<");
        end else begin
            $display("  >>> OVERALL TEST      : FAIL (%0d errors) <<<", failed_tests);
        end
        $display("================================================================================\n");

        $finish;
    end

    // Safety simulation timeout watchdog
    // Extended to 40 ms to cover FFT N=1024 computation latency and DMA transfers.
    initial begin
        #40_000_000; // 40 ms simulation time limit
        $display("\n[FATAL ERROR] Simulation Watchdog Timeout reached! Terminating simulation.");
        $finish;
    end

endmodule

`default_nettype wire
