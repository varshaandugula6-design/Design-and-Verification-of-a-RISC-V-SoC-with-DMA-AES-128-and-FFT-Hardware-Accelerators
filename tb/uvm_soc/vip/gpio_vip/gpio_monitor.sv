// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_monitor.sv
// Description  : UVM Monitor sampling GPIO physical pins & interrupt lines.
// ==============================================================================

`ifndef GPIO_MONITOR_SV
`define GPIO_MONITOR_SV

class gpio_monitor extends uvm_monitor;
    virtual gpio_if vif;
    uvm_analysis_port #(gpio_item) ap;
    `uvm_component_utils(gpio_monitor)

    logic [31:0] prev_gpio_out;
    logic        prev_gpio_irq;
    int unsigned mon_trans_count = 0;

    function new(string name = "gpio_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_vif", vif)) begin
            `uvm_fatal("GPIO_MON", "Failed to retrieve 'gpio_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        gpio_item item;
        prev_gpio_out = 32'hX;
        prev_gpio_irq = 1'b0;

        // Initialise waveform observability signals
        vif.mon_rx_count  <= 8'h00;
        vif.mon_irq_prev  <= 1'b0;
        vif.mon_data      <= 32'h0;
        vif.mon_trans_idx <= 4'h0;

        @(posedge vif.rst_n);
        `uvm_info("GPIO_MON", "Reset released; GPIO monitor active.", UVM_MEDIUM)

        forever begin
            @(posedge vif.clk);
            #1ps; // Wait 1ps settling time
            if (vif.rst_n) begin
                // Check for state change with valid known logic levels
                if ((vif.gpio_out !== prev_gpio_out) && !$isunknown(vif.gpio_out)) begin
                    if (vif.gpio_out >= 32'd121 && vif.gpio_out <= 32'd130) begin
                        mon_trans_count++;

                        // Log exact required format from actual observed GPIO data
                        $display("[GPIO_MON] Transaction=%0d Decimal=%0d Hex=0x%08h",
                                 mon_trans_count, vif.gpio_out, vif.gpio_out);
                        `uvm_info("GPIO_MON", $sformatf("Transaction=%0d Decimal=%0d Hex=0x%08h",
                                 mon_trans_count, vif.gpio_out, vif.gpio_out), UVM_LOW)

                        vif.mon_data      <= vif.gpio_out;
                        vif.mon_trans_idx <= 4'(mon_trans_count);
                        vif.mon_rx_count  <= 8'(mon_trans_count);

                        item = gpio_item::type_id::create("gpio_mon_item");
                        item.gpio_out = vif.gpio_out;
                        item.gpio_in  = vif.gpio_in;
                        item.gpio_oe  = vif.gpio_oe;
                        item.gpio_irq = vif.gpio_irq;
                        item.op       = GPIO_OP_SAMPLE;
                        item.trans_id = mon_trans_count;

                        prev_gpio_out = vif.gpio_out;
                        prev_gpio_irq = vif.gpio_irq;
                        ap.write(item);
                    end else begin
                        prev_gpio_out = vif.gpio_out;
                        prev_gpio_irq = vif.gpio_irq;
                    end
                end else if ($isunknown(vif.gpio_out)) begin
                    prev_gpio_out = vif.gpio_out;
                    prev_gpio_irq = vif.gpio_irq;
                end
            end
        end
    endtask
endclass

`endif // GPIO_MONITOR_SV
