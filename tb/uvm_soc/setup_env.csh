#!/bin/csh
# Synopsys EDA Environment Configuration for C-Shell (csh / tcsh)

setenv SNPSLMD_LICENSE_FILE 27021@14.139.1.126
setenv VCS_LIC 27021@14.139.1.126
setenv VERDI_LIC 27021@14.139.1.126

setenv VCS_HOME /home/student/snps_tools_target/vcs/U-2023.03
setenv VERDI_HOME /home/student/snps_tools_target/verdi/U-2023.03-SP1
setenv NOVAS_HOME $VERDI_HOME

setenv PATH ${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
if ($?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH ${VERDI_HOME}/share/PLI/VCS/linux64:${LD_LIBRARY_PATH}
else
    setenv LD_LIBRARY_PATH ${VERDI_HOME}/share/PLI/VCS/linux64
endif

echo "[INFO] Synopsys VCS & Verdi environment configured successfully."
