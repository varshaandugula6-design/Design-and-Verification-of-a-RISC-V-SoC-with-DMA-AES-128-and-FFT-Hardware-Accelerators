// ==============================================================================
// Project      : RISC-V SoC with DMA, AES-128 & FFT Hardware Accelerators
// VIP Name     : PWM UVM VIP (Corrected & Enhanced VIP)
// File         : pwm_monitor.sv
// Description  : UVM Monitor measuring PWM waveform edges, period, and duty cycle.
// ==============================================================================

`ifndef PWM_MONITOR_SV
`define PWM_MONITOR_SV

class pwm_monitor extends uvm_monitor;
    virtual pwm_if vif;
    uvm_analysis_port #(pwm_item) ap;
    `uvm_component_utils(pwm_monitor)

    function new(string name = "pwm_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pwm_if)::get(this, "", "pwm_vif", vif)) begin
            `uvm_fatal("PWM_MON", "Failed to retrieve 'pwm_vif' from uvm_config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        realtime t_rise1, t_fall, t_rise2;
        pwm_item item;

        // Initialise waveform observability signals
        vif.mon_measuring        <= 1'b0;
        vif.mon_cycle_count      <= 8'h00;
        vif.mon_period_ns_int    <= 32'h0;
        vif.mon_high_time_ns_int <= 32'h0;
        vif.mon_duty_pct_int     <= 7'h0;

        @(posedge vif.rst_n);
        `uvm_info("PWM_MON", "Reset released; PWM monitor active.", UVM_MEDIUM)

        forever begin
            // 1. Detect rising edge of PWM output
            @(posedge vif.pwm_out_o);
            t_rise1 = $realtime;
            vif.mon_measuring <= 1'b1;

            // 2. Detect falling edge
            @(negedge vif.pwm_out_o);
            t_fall = $realtime;

            // 3. Detect subsequent rising edge (one complete cycle)
            @(posedge vif.pwm_out_o);
            t_rise2 = $realtime;

            item = pwm_item::type_id::create("pwm_mon_item");
            item.high_time_ns   = t_fall - t_rise1;
            item.low_time_ns    = t_rise2 - t_fall;
            item.period_ns      = t_rise2 - t_rise1;
            if (item.period_ns > 0.0) begin
                item.duty_cycle_pct = (item.high_time_ns / item.period_ns) * 100.0;
                item.frequency_hz   = 1.0e9 / item.period_ns;
                item.is_active      = 1'b1;
            end

            // Drive waveform observability signals
            vif.mon_period_ns_int    <= 32'($rtoi(item.period_ns));
            vif.mon_high_time_ns_int <= 32'($rtoi(item.high_time_ns));
            vif.mon_duty_pct_int     <= 7'($rtoi(item.duty_cycle_pct));
            vif.mon_cycle_count      <= vif.mon_cycle_count + 8'h01;
            vif.mon_measuring        <= 1'b0;

            `uvm_info("PWM_MON", $sformatf("Measured PWM cycle: Period=%.2f ns, High=%.2f ns, Low=%.2f ns, Duty=%.2f%%, Freq=%.2f kHz",
                                    item.period_ns, item.high_time_ns, item.low_time_ns,
                                    item.duty_cycle_pct, item.frequency_hz / 1000.0), UVM_MEDIUM)

            ap.write(item);
        end
    endtask
endclass

`endif // PWM_MONITOR_SV
