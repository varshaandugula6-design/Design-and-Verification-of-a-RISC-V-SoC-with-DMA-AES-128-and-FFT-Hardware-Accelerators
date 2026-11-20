#!/bin/bash
# Shell script to open Synopsys Verdi with KDB database and preloaded GPIO waveform signals

source /home/student/Documents/honours_121/CBP/tb/uvm_soc/setup_env.sh
cd /home/student/Documents/honours_121/CBP/tb/uvm_soc

echo "[INFO] Launching Synopsys Verdi with KDB database and GPIO signals 121..130..."
verdi -dbdir simv_uvm_fsdb.daidir \
      -ssf gpio_data_121_to_130.fsdb \
      -sswr gpio_signals_121_to_130.rc
