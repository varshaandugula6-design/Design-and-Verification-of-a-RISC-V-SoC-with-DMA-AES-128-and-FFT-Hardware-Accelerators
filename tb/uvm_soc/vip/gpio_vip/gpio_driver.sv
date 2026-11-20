// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : GPIO UVM VIP (Corrected & Enhanced VIP)
// File         : gpio_driver.sv
// Description  : UVM Driver applying GPIO pin stimulus via virtual interface.
// ==============================================================================

`ifndef GPIO_DRIVER_SV
`define GPIO_DRIVER_SV

class gpio_driver extends uvm_driver #(gpio_item);
    virtual gpio_if vif;
    `uvm_component_utils(gpio_driver)

    int unsigned drv_trans_count = 0;

    function new(string name = "gpio_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_vif", vif)) begin
            `uvm_fatal("GPIO_DRV", "Failed to retrieve 'gpio_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        // Initialize lines to Hi-Z (passive listening)
        vif.gpio_oe       <= 32'h0;
        vif.gpio_in       <= 32'h0;

        // Initialise waveform observability signals
        vif.drv_active    <= 1'b0;
        vif.drv_op        <= 2'b00;
        vif.drv_tx_count  <= 8'h00;
        vif.drv_data      <= 32'h0;
        vif.drv_trans_idx <= 4'h0;

        @(posedge vif.rst_n);
        `uvm_info("GPIO_DRV", "Reset released; GPIO driver active.", UVM_MEDIUM)

        forever begin
            seq_item_port.get_next_item(req);

            case (req.op)
                GPIO_OP_DRIVE: begin
                    drv_trans_count++;

                    // Log exact required format from driver transaction data
                    $display("[GPIO_DRV] Transaction=%0d Decimal=%0d Hex=0x%08h",
                             drv_trans_count, req.gpio_in, req.gpio_in);
                    `uvm_info("GPIO_DRV", $sformatf("Transaction=%0d Decimal=%0d Hex=0x%08h",
                             drv_trans_count, req.gpio_in, req.gpio_in), UVM_LOW)

                    @(posedge vif.clk);
                    vif.drv_active    <= 1'b1;
                    vif.drv_op        <= req.op;
                    vif.gpio_in       <= req.gpio_in;
                    vif.gpio_oe       <= req.gpio_oe;
                    vif.drv_data      <= req.gpio_in;
                    vif.drv_trans_idx <= 4'(drv_trans_count);
                    vif.drv_tx_count  <= 8'(drv_trans_count);

                    repeat (req.hold_cycles) @(posedge vif.clk);
                    vif.drv_active    <= 1'b0;
                end

                GPIO_OP_RELEASE: begin
                    @(posedge vif.clk);
                    vif.gpio_oe    <= 32'h0;
                    vif.gpio_in    <= 32'h0;
                    vif.drv_active <= 1'b0;
                    repeat (req.hold_cycles) @(posedge vif.clk);
                end

                GPIO_OP_SAMPLE: begin
                    repeat (req.hold_cycles) @(posedge vif.clk);
                end
            endcase

            seq_item_port.item_done();
        end
    endtask
endclass

`endif // GPIO_DRIVER_SV
