// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : UART UVM VIP (Corrected & Enhanced VIP)
// File         : uart_driver.sv
// Description  : UVM Driver generating serial 8-N-1 UART frames into DUT uart_rx.
// ==============================================================================

`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

class uart_driver extends uvm_driver #(uart_item);
    virtual uart_if vif;
    `uvm_component_utils(uart_driver)

    function new(string name = "uart_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif)) begin
            `uvm_fatal("UART_DRV", "Failed to retrieve 'uart_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        int bit_idx;
        vif.uart_rx_i     <= 1'b1; // Idle line high

        // Initialise waveform observability signals
        vif.drv_active    <= 1'b0;
        vif.drv_tx_data   <= 8'h00;
        vif.drv_bit_index <= 4'hF;  // 0xF = idle sentinel
        vif.drv_state     <= 2'b00; // IDLE
        vif.drv_tx_count  <= 8'h00;

        @(posedge vif.rst_n);
        `uvm_info("UART_DRV", "Reset released; UART driver active (idle high).", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(req);

            `uvm_info("UART_DRV", $sformatf("Serializing byte 0x%02h ('%c') onto uart_rx_i (bit period = %0d fixed_clk cycles)...",
                                    req.data, ((req.data >= 32 && req.data <= 126) ? req.data : "."), req.bit_cycles), UVM_MEDIUM)

            // ---- Latch transaction data for Verdi visibility ----
            vif.drv_active  <= 1'b1;
            vif.drv_tx_data <= req.data;

            // 1. START BIT (0)
            vif.drv_state     <= 2'b01; // START
            vif.drv_bit_index <= 4'hE;  // 0xE = start bit sentinel
            @(negedge vif.fixed_clk);
            vif.uart_rx_i <= 1'b0;
            repeat (req.bit_cycles) @(posedge vif.fixed_clk);

            // 2. DATA BITS (LSB first: data[0] .. data[7])
            vif.drv_state <= 2'b10; // DATA
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                vif.drv_bit_index <= 4'(bit_idx);
                @(negedge vif.fixed_clk);
                vif.uart_rx_i <= req.data[bit_idx];
                repeat (req.bit_cycles) @(posedge vif.fixed_clk);
            end

            // 3. STOP BIT (1)
            vif.drv_state     <= 2'b11; // STOP
            vif.drv_bit_index <= 4'hD;  // 0xD = stop bit sentinel
            @(negedge vif.fixed_clk);
            vif.uart_rx_i <= 1'b1;
            repeat (req.bit_cycles) @(posedge vif.fixed_clk);

            // Guard interval between consecutive frames
            repeat (req.bit_cycles / 2) @(posedge vif.fixed_clk);

            // ---- Update frame counter, return to IDLE ----
            vif.drv_tx_count  <= vif.drv_tx_count + 8'h01;
            vif.drv_active    <= 1'b0;
            vif.drv_state     <= 2'b00; // IDLE
            vif.drv_bit_index <= 4'hF;

            seq_item_port.item_done();
        end
    endtask
endclass

`endif // UART_DRIVER_SV
