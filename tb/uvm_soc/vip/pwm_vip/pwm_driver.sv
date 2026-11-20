// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_driver.sv
// Description  : UVM Driver for PWM VIP (Passive monitor-only architecture).
// ==============================================================================

`ifndef PWM_DRIVER_SV
`define PWM_DRIVER_SV

class pwm_driver extends uvm_driver #(pwm_item);
    virtual pwm_if vif;
    `uvm_component_utils(pwm_driver)

    function new(string name = "pwm_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pwm_if)::get(this, "", "pwm_vif", vif)) begin
            `uvm_fatal("PWM_DRV", "Failed to retrieve 'pwm_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        // PWM is an output from the SoC timer, hence driver remains passive.
        `uvm_info("PWM_DRV", "PWM VIP is passive monitor-only; driver quiescent.", UVM_MEDIUM)
    endtask
endclass

`endif // PWM_DRIVER_SV
