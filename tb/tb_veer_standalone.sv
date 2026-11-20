// ==============================================================================
// Testbench: tb_veer_standalone
// Project  : RISC-V VeeR EL2 Processor Standalone Integration Test
// Description:
//   Verifies VeeR EL2 processor standalone execution with the AXI 64-to-32
//   adapters:
//     1. Preloads IMEM at 0x0004_0000 with a RISC-V program:
//        - lui x1, 1; ori x1, x1, 0x234  -> x1 = 0x0000_1234
//        - lui x2, 0x80                  -> x2 = 0x0008_0000 (DMEM base)
//        - sw  x1, 0(x2)                 -> store 0x0000_1234 to 0x0008_0000
//        - lw  x3, 0(x2)                 -> load from 0x0008_0000 into x3
//        - addi x4, x3, 1                -> x4 = 0x0000_1235
//        - sw  x4, 4(x2)                 -> store 0x0000_1235 to 0x0008_0004
//        - loop: j loop
//     2. Releases reset at boot vector 0x0004_0000.
//     3. Verifies that IFU fetches instructions via M0 (32-bit AXI),
//        LSU executes store and load to DMEM via M1 (32-bit AXI),
//        and values in DMEM match expectations.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_veer_standalone;

    logic clk;
    logic rst_l;
    logic [31:1] rst_vec;

    // Clock generation (100 MHz, 10ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Simple 32-bit AXI Memory Model for IMEM (S0) and DMEM (S1)
    // ------------------------------------------------------------
    logic [31:0] imem [0:1023]; // 4KB IMEM at 0x0004_0000
    logic [31:0] dmem [0:1023]; // 4KB DMEM at 0x0008_0000

    // M0 (IFU) wires
    wire [7:0]   m0_awid, m0_arid, m0_bid, m0_rid;
    wire [31:0]  m0_awaddr, m0_araddr, m0_wdata, m0_rdata;
    wire [7:0]   m0_awlen, m0_arlen;
    wire [2:0]   m0_awsize, m0_arsize;
    wire [1:0]   m0_awburst, m0_arburst, m0_bresp, m0_rresp;
    wire [3:0]   m0_wstrb, m0_awcache, m0_arcache, m0_awqos, m0_arqos, m0_awregion, m0_arregion;
    wire [2:0]   m0_awprot, m0_arprot;
    wire         m0_awlock, m0_arlock, m0_awvalid, m0_awready, m0_wvalid, m0_wready, m0_wlast;
    wire         m0_bvalid, m0_bready, m0_arvalid, m0_arready, m0_rvalid, m0_rready, m0_rlast;

    // M1 (LSU) wires
    wire [7:0]   m1_awid, m1_arid, m1_bid, m1_rid;
    wire [31:0]  m1_awaddr, m1_araddr, m1_wdata, m1_rdata;
    wire [7:0]   m1_awlen, m1_arlen;
    wire [2:0]   m1_awsize, m1_arsize;
    wire [1:0]   m1_awburst, m1_arburst, m1_bresp, m1_rresp;
    wire [3:0]   m1_wstrb, m1_awcache, m1_arcache, m1_awqos, m1_arqos, m1_awregion, m1_arregion;
    wire [2:0]   m1_awprot, m1_arprot;
    wire         m1_awlock, m1_arlock, m1_awvalid, m1_awready, m1_wvalid, m1_wready, m1_wlast;
    wire         m1_bvalid, m1_bready, m1_arvalid, m1_arready, m1_rvalid, m1_rready, m1_rlast;

    // Trace signals
    wire [31:0]  trace_rv_i_insn_ip;
    wire [31:0]  trace_rv_i_address_ip;
    wire         trace_rv_i_valid_ip;
    wire         trace_rv_i_exception_ip;
    wire [4:0]   trace_rv_i_ecause_ip;
    wire         trace_rv_i_interrupt_ip;
    wire [31:0]  trace_rv_i_tval_ip;
    wire         o_cpu_halt_status;

    // DUT
    veer_wrapper_axi32 dut (
        .clk                    (clk),
        .rst_l                  (rst_l),
        .rst_vec                (rst_vec),

        .uart_irq               (1'b0),
        .gpio_irq               (1'b0),
        .timer_irq              (1'b0),
        .fft_irq                (1'b0),
        .dma_irq                (1'b0),
        .dma_error_irq          (1'b0),

        .mpc_reset_run_req      (1'b1),

        .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
        .trace_rv_i_address_ip  (trace_rv_i_address_ip),
        .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
        .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
        .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
        .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
        .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),
        .o_cpu_halt_status      (o_cpu_halt_status),

        // M0 IFU AXI
        .m0_axi_awid            (m0_awid),
        .m0_axi_awaddr          (m0_awaddr),
        .m0_axi_awlen           (m0_awlen),
        .m0_axi_awsize          (m0_awsize),
        .m0_axi_awburst         (m0_awburst),
        .m0_axi_awlock          (m0_awlock),
        .m0_axi_awcache         (m0_awcache),
        .m0_axi_awprot          (m0_awprot),
        .m0_axi_awqos           (m0_awqos),
        .m0_axi_awregion        (m0_awregion),
        .m0_axi_awvalid         (m0_awvalid),
        .m0_axi_awready         (m0_awready),
        .m0_axi_wdata           (m0_wdata),
        .m0_axi_wstrb           (m0_wstrb),
        .m0_axi_wlast           (m0_wlast),
        .m0_axi_wvalid          (m0_wvalid),
        .m0_axi_wready          (m0_wready),
        .m0_axi_bid             (m0_bid),
        .m0_axi_bresp           (m0_bresp),
        .m0_axi_bvalid          (m0_bvalid),
        .m0_axi_bready          (m0_bready),
        .m0_axi_arid            (m0_arid),
        .m0_axi_araddr          (m0_araddr),
        .m0_axi_arlen           (m0_arlen),
        .m0_axi_arsize          (m0_arsize),
        .m0_axi_arburst         (m0_arburst),
        .m0_axi_arlock          (m0_arlock),
        .m0_axi_arcache         (m0_arcache),
        .m0_axi_arprot          (m0_arprot),
        .m0_axi_arqos           (m0_arqos),
        .m0_axi_arregion        (m0_arregion),
        .m0_axi_arvalid         (m0_arvalid),
        .m0_axi_arready         (m0_arready),
        .m0_axi_rid             (m0_rid),
        .m0_axi_rdata           (m0_rdata),
        .m0_axi_rresp           (m0_rresp),
        .m0_axi_rlast           (m0_rlast),
        .m0_axi_rvalid          (m0_rvalid),
        .m0_axi_rready          (m0_rready),

        // M1 LSU AXI
        .m1_axi_awid            (m1_awid),
        .m1_axi_awaddr          (m1_awaddr),
        .m1_axi_awlen           (m1_awlen),
        .m1_axi_awsize          (m1_awsize),
        .m1_axi_awburst         (m1_awburst),
        .m1_axi_awlock          (m1_awlock),
        .m1_axi_awcache         (m1_awcache),
        .m1_axi_awprot          (m1_awprot),
        .m1_axi_awqos           (m1_awqos),
        .m1_axi_awregion        (m1_awregion),
        .m1_axi_awvalid         (m1_awvalid),
        .m1_axi_awready         (m1_awready),
        .m1_axi_wdata           (m1_wdata),
        .m1_axi_wstrb           (m1_wstrb),
        .m1_axi_wlast           (m1_wlast),
        .m1_axi_wvalid          (m1_wvalid),
        .m1_axi_wready          (m1_wready),
        .m1_axi_bid             (m1_bid),
        .m1_axi_bresp           (m1_bresp),
        .m1_axi_bvalid          (m1_bvalid),
        .m1_axi_bready          (m1_bready),
        .m1_axi_arid            (m1_arid),
        .m1_axi_araddr          (m1_araddr),
        .m1_axi_arlen           (m1_arlen),
        .m1_axi_arsize          (m1_arsize),
        .m1_axi_arburst         (m1_arburst),
        .m1_axi_arlock          (m1_arlock),
        .m1_axi_arcache         (m1_arcache),
        .m1_axi_arprot          (m1_arprot),
        .m1_axi_arqos           (m1_arqos),
        .m1_axi_arregion        (m1_arregion),
        .m1_axi_arvalid         (m1_arvalid),
        .m1_axi_arready         (m1_arready),
        .m1_axi_rid             (m1_rid),
        .m1_axi_rdata           (m1_rdata),
        .m1_axi_rresp           (m1_rresp),
        .m1_axi_rlast           (m1_rlast),
        .m1_axi_rvalid          (m1_rvalid),
        .m1_axi_rready          (m1_rready)
    );

    // ------------------------------------------------------------
    // M0 Slave Memory Model (handles IFU reads from IMEM)
    // ------------------------------------------------------------
    assign m0_awready = 1'b0;
    assign m0_wready  = 1'b0;
    assign m0_bvalid  = 1'b0;
    assign m0_bresp   = 2'b00;
    assign m0_bid     = 8'h0;

    reg        m0_rvalid_q;
    reg [31:0] m0_rdata_q;
    reg [7:0]  m0_rid_q;

    assign m0_arready = !m0_rvalid_q || m0_rready;
    assign m0_rvalid  = m0_rvalid_q;
    assign m0_rdata   = m0_rdata_q;
    assign m0_rid     = m0_rid_q;
    assign m0_rresp   = 2'b00;
    assign m0_rlast   = 1'b1;

    always @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            m0_rvalid_q <= 1'b0;
            m0_rdata_q  <= 32'h0;
            m0_rid_q    <= 8'h0;
        end else begin
            if (m0_rvalid_q && m0_rready)
                m0_rvalid_q <= 1'b0;

            if (m0_arvalid && m0_arready) begin
                m0_rvalid_q <= 1'b1;
                m0_rid_q    <= m0_arid;
                // Offset into IMEM (0x0004_0000)
                m0_rdata_q  <= imem[(m0_araddr - 32'h0004_0000) >> 2];
            end
        end
    end

    // ------------------------------------------------------------
    // M1 Slave Memory Model (handles LSU reads/writes to DMEM)
    // ------------------------------------------------------------
    reg        m1_awready_q;
    reg        m1_wready_q;
    reg        m1_bvalid_q;
    reg [7:0]  m1_bid_q;
    reg [31:0] m1_saved_awaddr;

    assign m1_awready = !m1_bvalid_q;
    assign m1_wready  = !m1_bvalid_q;
    assign m1_bvalid  = m1_bvalid_q;
    assign m1_bid     = m1_bid_q;
    assign m1_bresp   = 2'b00;

    reg        m1_rvalid_q;
    reg [31:0] m1_rdata_q;
    reg [7:0]  m1_rid_q;

    assign m1_arready = !m1_rvalid_q || m1_rready;
    assign m1_rvalid  = m1_rvalid_q;
    assign m1_rdata   = m1_rdata_q;
    assign m1_rid     = m1_rid_q;
    assign m1_rresp   = 2'b00;
    assign m1_rlast   = 1'b1;

    always @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            m1_bvalid_q <= 1'b0;
            m1_bid_q    <= 8'h0;
            m1_rvalid_q <= 1'b0;
            m1_rdata_q  <= 32'h0;
            m1_rid_q    <= 8'h0;
            m1_saved_awaddr <= 32'h0;
        end else begin
            // Write Channel
            if (m1_bvalid && m1_bready)
                m1_bvalid_q <= 1'b0;

            if (m1_awvalid && m1_awready && m1_wvalid && m1_wready) begin
                m1_bvalid_q <= 1'b1;
                m1_bid_q    <= m1_awid;
                // Write into DMEM
                if (m1_wstrb[0]) dmem[(m1_awaddr - 32'h0008_0000) >> 2][7:0]   <= m1_wdata[7:0];
                if (m1_wstrb[1]) dmem[(m1_awaddr - 32'h0008_0000) >> 2][15:8]  <= m1_wdata[15:8];
                if (m1_wstrb[2]) dmem[(m1_awaddr - 32'h0008_0000) >> 2][23:16] <= m1_wdata[23:16];
                if (m1_wstrb[3]) dmem[(m1_awaddr - 32'h0008_0000) >> 2][31:24] <= m1_wdata[31:24];
            end

            // Read Channel
            if (m1_rvalid_q && m1_rready)
                m1_rvalid_q <= 1'b0;

            if (m1_arvalid && m1_arready) begin
                m1_rvalid_q <= 1'b1;
                m1_rid_q    <= m1_arid;
                m1_rdata_q  <= dmem[(m1_araddr - 32'h0008_0000) >> 2];
            end
        end
    end

    // ------------------------------------------------------------
    // Test Scenario
    // ------------------------------------------------------------
    int cycle_cnt;
    bit test_pass;

    initial begin
        $display("================================================================================");
        $display("          VeeR EL2 STANDALONE PROCESSOR INTEGRATION TEST                        ");
        $display("================================================================================");

        // Preload IMEM at 0x0004_0000
        for (int i = 0; i < 1024; i++) begin
            imem[i] = 32'h0000_0013; // nop (addi x0, x0, 0)
            dmem[i] = 32'h0000_0000;
        end

        // Program:
        // 0x0004_0000: lui x1, 1              (32'h000010B7)
        // 0x0004_0004: ori x1, x1, 0x234      (32'h2340E093) -> x1 = 0x0000_1234
        // 0x0004_0008: lui x2, 0x80           (32'h00080137) -> x2 = 0x0008_0000 (DMEM base)
        // 0x0004_000C: sw  x1, 0(x2)          (32'h00112023) -> DMEM[0] = 0x0000_1234
        // 0x0004_0010: lw  x3, 0(x2)          (32'h00012183) -> x3 = 0x0000_1234
        // 0x0004_0014: addi x4, x3, 1         (32'h00118213) -> x4 = 0x0000_1235
        // 0x0004_0018: sw  x4, 4(x2)          (32'h00412223) -> DMEM[1] = 0x0000_1235
        // 0x0004_001C: loop: j loop           (32'h0000006F)
        imem[0] = 32'h000010B7; // lui x1, 1
        imem[1] = 32'h2340E093; // ori x1, x1, 0x234
        imem[2] = 32'h00080137; // lui x2, 0x80
        imem[3] = 32'h00112023; // sw x1, 0(x2)
        imem[4] = 32'h00012183; // lw x3, 0(x2)
        imem[5] = 32'h00118213; // addi x4, x3, 1
        imem[6] = 32'h00412223; // sw x4, 4(x2)
        imem[7] = 32'h0000006F; // j loop

        rst_l   = 1'b0;
        rst_vec = 31'h0002_0000; // Reset PC = 0x0004_0000

        repeat (10) @(posedge clk);
        $display("[TB] Deasserting reset at cycle %0d...", cycle_cnt);
        rst_l = 1'b1;

        // Monitor execution
        test_pass = 0;
        for (cycle_cnt = 0; cycle_cnt < 2000; cycle_cnt++) begin
            @(posedge clk);
            if (trace_rv_i_valid_ip) begin
                $display("[TRACE] PC=0x%08h, Insn=0x%08h", trace_rv_i_address_ip, trace_rv_i_insn_ip);
            end

            // Check if DMEM[0] and DMEM[1] have received the expected writes
            if (dmem[0] === 32'h0000_1234 && dmem[1] === 32'h0000_1235) begin
                $display("[PASS] DMEM[0] contains expected value 0x0000_1234");
                $display("[PASS] DMEM[1] contains expected value 0x0000_1235");
                $display("[PASS] VeeR EL2 processor standalone execution SUCCESSFUL at cycle %0d!", cycle_cnt);
                test_pass = 1;
                break;
            end
        end

        if (!test_pass) begin
            $display("[FAIL] Timeout waiting for expected DMEM values!");
            $display("       DMEM[0] = 0x%08h (expected 0x0000_1234)", dmem[0]);
            $display("       DMEM[1] = 0x%08h (expected 0x0000_1235)", dmem[1]);
            $fatal(1, "VeeR standalone test failed!");
        end

        $finish;
    end

endmodule
`default_nettype wire
