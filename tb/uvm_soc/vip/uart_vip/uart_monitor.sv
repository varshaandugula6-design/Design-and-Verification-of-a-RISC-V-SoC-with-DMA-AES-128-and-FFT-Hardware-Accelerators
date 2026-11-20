// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_monitor.sv
// Description  : UVM Monitor capturing and deserializing serial UART TX stream.
// ==============================================================================

`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

class uart_monitor extends uvm_monitor;
    virtual uart_if vif;
    uvm_analysis_port #(uart_item) ap;
    `uvm_component_utils(uart_monitor)

    int unsigned bit_cycles = 347; // 115200 Baud @ 40 MHz clock

    function new(string name = "uart_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif)) begin
            `uvm_fatal("UART_MON", "Failed to retrieve 'uart_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        uart_item item;
        int bit_idx;
        logic [7:0] rx_byte;
        bit framing_err;

        // Initialise waveform observability signals
        vif.mon_capturing    <= 1'b0;
        vif.mon_shift_reg    <= 8'h00;
        vif.mon_bit_index    <= 4'hF;  // 0xF = idle sentinel
        vif.mon_decoded_byte <= 8'h00;
        vif.mon_framing_error<= 1'b0;
        vif.mon_rx_count     <= 8'h00;

        @(posedge vif.rst_n);
        `uvm_info("UART_MON", "Reset released; UART monitor active.", UVM_MEDIUM)

        forever begin
            // 1. Wait for falling edge on uart_tx_o (START bit transition)
            @(negedge vif.uart_tx_o);
            vif.mon_capturing <= 1'b1;
            vif.mon_bit_index <= 4'hE; // 0xE = start bit

            // 2. Wait to center of START bit
            repeat (bit_cycles / 2) @(posedge vif.fixed_clk);
            #1;
            if (vif.uart_tx_o !== 1'b0) begin
                `uvm_warning("UART_MON", "False START bit detected on uart_tx_o line; ignoring glitch.")
                vif.mon_capturing <= 1'b0;
                vif.mon_bit_index <= 4'hF;
                continue;
            end

            rx_byte = 8'h00;
            framing_err = 1'b0;
            vif.mon_shift_reg <= 8'h00;

            // 3. Sample 8 data bits at center of bit period
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                repeat (bit_cycles) @(posedge vif.fixed_clk);
                #1;
                rx_byte[bit_idx]   = vif.uart_tx_o;
                vif.mon_bit_index <= 4'(bit_idx);
                vif.mon_shift_reg <= rx_byte; // Update shift reg as bits accumulate
            end

            // 4. Sample STOP bit
            vif.mon_bit_index <= 4'hD; // 0xD = stop bit sentinel
            repeat (bit_cycles) @(posedge vif.fixed_clk);
            #1;
            if (vif.uart_tx_o !== 1'b1) begin
                framing_err = 1'b1;
                `uvm_error("UART_MON", "Framing error detected: STOP bit is not logic 1")
            end

            item = uart_item::type_id::create("uart_mon_item");
            item.data = rx_byte;
            item.dir = UART_DIR_TX_MON;
            item.bit_cycles = bit_cycles;
            item.framing_error = framing_err;

            // Update observability signals with final decoded result
            vif.mon_decoded_byte  <= rx_byte;
            vif.mon_framing_error <= framing_err;
            vif.mon_rx_count      <= vif.mon_rx_count + 8'h01;
            vif.mon_capturing     <= 1'b0;
            vif.mon_bit_index     <= 4'hF; // idle

            `uvm_info("UART_MON", $sformatf("Captured TX byte from DUT: 0x%02h ('%c'), framing_err=%b",
                                    rx_byte, ((rx_byte >= 32 && rx_byte <= 126) ? rx_byte : "."), framing_err), UVM_MEDIUM)

            ap.write(item);
        end
    endtask
endclass

`endif // UART_MONITOR_SV
