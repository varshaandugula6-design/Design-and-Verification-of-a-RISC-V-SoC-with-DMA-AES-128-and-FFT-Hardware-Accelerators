// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_item.sv
// Description  : Sequence item containing measured PWM waveform timing parameters.
// ==============================================================================

`ifndef PWM_ITEM_SV
`define PWM_ITEM_SV

class pwm_item extends uvm_sequence_item;

    // Measured timing parameters (in nanoseconds)
    real period_ns;
    real high_time_ns;
    real low_time_ns;

    // Derived electrical metrics
    real duty_cycle_pct;
    real frequency_hz;

    // Status flags
    bit  is_active;

    `uvm_object_utils_begin(pwm_item)
        `uvm_field_real(period_ns,      UVM_ALL_ON)
        `uvm_field_real(high_time_ns,   UVM_ALL_ON)
        `uvm_field_real(low_time_ns,    UVM_ALL_ON)
        `uvm_field_real(duty_cycle_pct, UVM_ALL_ON)
        `uvm_field_real(frequency_hz,   UVM_ALL_ON)
        `uvm_field_int(is_active,       UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "pwm_item");
        super.new(name);
        period_ns      = 0.0;
        high_time_ns   = 0.0;
        low_time_ns    = 0.0;
        duty_cycle_pct = 0.0;
        frequency_hz   = 0.0;
        is_active      = 0;
    endfunction

    virtual function string convert2string();
        return $sformatf("period=%.2f ns, high=%.2f ns, low=%.2f ns, duty=%.2f%%, freq=%.2f kHz",
                        period_ns, high_time_ns, low_time_ns, duty_cycle_pct, frequency_hz / 1000.0);
    endfunction

endclass

`endif // PWM_ITEM_SV
