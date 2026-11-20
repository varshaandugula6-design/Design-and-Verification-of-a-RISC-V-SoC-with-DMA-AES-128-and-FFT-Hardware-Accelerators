srcSourceCodeView
wvCreateWindow
wvOpenFile -win $_nWave2 {gpio_data_121_to_130.fsdb}
wvSetPosition -win $_nWave2 {(G1 0)}
wvAddSignal -win $_nWave2 "/tb_soc_uvm_top/clk" \
                         "/tb_soc_uvm_top/rst_n" \
                         "/tb_soc_uvm_top/dut/gpio_io\[31:0\]" \
                         "/tb_soc_uvm_top/dut/u_gpio_axi/gpio_i\[31:0\]" \
                         "/tb_soc_uvm_top/dut/u_gpio_axi/s_axi_rdata\[31:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/drv_trans_idx\[3:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/drv_data\[31:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/mon_trans_idx\[3:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/mon_data\[31:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/sb_expected_out\[31:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/sb_actual_out\[31:0\]" \
                         "/tb_soc_uvm_top/u_gpio_if/sb_match"
wvSetRadix -win $_nWave2 -format UDec { (G1 3) }
wvSetRadix -win $_nWave2 -format UDec { (G1 4) }
wvSetRadix -win $_nWave2 -format UDec { (G1 5) }
wvSetRadix -win $_nWave2 -format UDec { (G1 6) }
wvSetRadix -win $_nWave2 -format UDec { (G1 7) }
wvSetRadix -win $_nWave2 -format UDec { (G1 8) }
wvSetRadix -win $_nWave2 -format UDec { (G1 9) }
wvSetRadix -win $_nWave2 -format UDec { (G1 10) }
wvSetRadix -win $_nWave2 -format UDec { (G1 11) }
wvZoom -win $_nWave2 400000 1750000
wvSetCursor -win $_nWave2 475000
