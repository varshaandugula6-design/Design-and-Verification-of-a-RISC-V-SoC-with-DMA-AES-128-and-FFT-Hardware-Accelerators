#!/bin/bash
# Synopsys EDA Environment Configuration for Bash

export SNPSLMD_LICENSE_FILE=27021@14.139.1.126
export VCS_LIC=27021@14.139.1.126
export VERDI_LIC=27021@14.139.1.126

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export NOVAS_HOME=$VERDI_HOME

export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH
export LD_LIBRARY_PATH=$VERDI_HOME/share/PLI/VCS/linux64:${LD_LIBRARY_PATH:-}

echo "[INFO] Synopsys VCS & Verdi environment configured successfully."
