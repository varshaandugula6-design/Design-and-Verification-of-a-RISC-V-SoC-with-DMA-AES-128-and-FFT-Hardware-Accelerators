verdiWindowResize -win $_Verdi_1 "340" "92" "900" "700"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
verdiWindowResize -win $_Verdi_1 "340" "92" "900" "700"
debLoadSimResult /home/student/Documents/hon_121/pro_dir/tb_top.fsdb
verdiSetActWin -win $_nWave2
wvSelectGroup -win $_nWave2 {G1}
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_top"
wvSetPosition -win $_nWave2 {("G1" 42)}
wvSetPosition -win $_nWave2 {("G1" 42)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_top/clk} \
{/tb_top/m00_axi_araddr\[31:0\]} \
{/tb_top/m00_axi_awaddr\[31:0\]} \
{/tb_top/m00_axi_rdata\[31:0\]} \
{/tb_top/m00_axi_wdata\[31:0\]} \
{/tb_top/m01_axi_araddr\[31:0\]} \
{/tb_top/m01_axi_awaddr\[31:0\]} \
{/tb_top/m01_axi_rdata\[31:0\]} \
{/tb_top/m01_axi_wdata\[31:0\]} \
{/tb_top/m02_axi_araddr\[31:0\]} \
{/tb_top/m02_axi_awaddr\[31:0\]} \
{/tb_top/m02_axi_rdata\[31:0\]} \
{/tb_top/m02_axi_wdata\[31:0\]} \
{/tb_top/m03_axi_araddr\[31:0\]} \
{/tb_top/m03_axi_awaddr\[31:0\]} \
{/tb_top/m03_axi_rdata\[31:0\]} \
{/tb_top/m03_axi_wdata\[31:0\]} \
{/tb_top/m04_axi_araddr\[31:0\]} \
{/tb_top/m04_axi_awaddr\[31:0\]} \
{/tb_top/m04_axi_rdata\[31:0\]} \
{/tb_top/m04_axi_wdata\[31:0\]} \
{/tb_top/m05_axi_araddr\[31:0\]} \
{/tb_top/m05_axi_awaddr\[31:0\]} \
{/tb_top/m05_axi_rdata\[31:0\]} \
{/tb_top/m05_axi_wdata\[31:0\]} \
{/tb_top/m06_axi_araddr\[31:0\]} \
{/tb_top/m06_axi_awaddr\[31:0\]} \
{/tb_top/m06_axi_rdata\[31:0\]} \
{/tb_top/m06_axi_wdata\[31:0\]} \
{/tb_top/rst} \
{/tb_top/s00_axi_araddr\[31:0\]} \
{/tb_top/s00_axi_awaddr\[31:0\]} \
{/tb_top/s00_axi_rdata\[31:0\]} \
{/tb_top/s00_axi_wdata\[31:0\]} \
{/tb_top/s01_axi_araddr\[31:0\]} \
{/tb_top/s01_axi_awaddr\[31:0\]} \
{/tb_top/s01_axi_rdata\[31:0\]} \
{/tb_top/s01_axi_wdata\[31:0\]} \
{/tb_top/s02_axi_araddr\[31:0\]} \
{/tb_top/s02_axi_awaddr\[31:0\]} \
{/tb_top/s02_axi_rdata\[31:0\]} \
{/tb_top/s02_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
           18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 \
           40 41 42 )} 
wvSetPosition -win $_nWave2 {("G1" 42)}
wvSetPosition -win $_nWave2 {("G1" 42)}
wvSetPosition -win $_nWave2 {("G1" 42)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_top/clk} \
{/tb_top/m00_axi_araddr\[31:0\]} \
{/tb_top/m00_axi_awaddr\[31:0\]} \
{/tb_top/m00_axi_rdata\[31:0\]} \
{/tb_top/m00_axi_wdata\[31:0\]} \
{/tb_top/m01_axi_araddr\[31:0\]} \
{/tb_top/m01_axi_awaddr\[31:0\]} \
{/tb_top/m01_axi_rdata\[31:0\]} \
{/tb_top/m01_axi_wdata\[31:0\]} \
{/tb_top/m02_axi_araddr\[31:0\]} \
{/tb_top/m02_axi_awaddr\[31:0\]} \
{/tb_top/m02_axi_rdata\[31:0\]} \
{/tb_top/m02_axi_wdata\[31:0\]} \
{/tb_top/m03_axi_araddr\[31:0\]} \
{/tb_top/m03_axi_awaddr\[31:0\]} \
{/tb_top/m03_axi_rdata\[31:0\]} \
{/tb_top/m03_axi_wdata\[31:0\]} \
{/tb_top/m04_axi_araddr\[31:0\]} \
{/tb_top/m04_axi_awaddr\[31:0\]} \
{/tb_top/m04_axi_rdata\[31:0\]} \
{/tb_top/m04_axi_wdata\[31:0\]} \
{/tb_top/m05_axi_araddr\[31:0\]} \
{/tb_top/m05_axi_awaddr\[31:0\]} \
{/tb_top/m05_axi_rdata\[31:0\]} \
{/tb_top/m05_axi_wdata\[31:0\]} \
{/tb_top/m06_axi_araddr\[31:0\]} \
{/tb_top/m06_axi_awaddr\[31:0\]} \
{/tb_top/m06_axi_rdata\[31:0\]} \
{/tb_top/m06_axi_wdata\[31:0\]} \
{/tb_top/rst} \
{/tb_top/s00_axi_araddr\[31:0\]} \
{/tb_top/s00_axi_awaddr\[31:0\]} \
{/tb_top/s00_axi_rdata\[31:0\]} \
{/tb_top/s00_axi_wdata\[31:0\]} \
{/tb_top/s01_axi_araddr\[31:0\]} \
{/tb_top/s01_axi_awaddr\[31:0\]} \
{/tb_top/s01_axi_rdata\[31:0\]} \
{/tb_top/s01_axi_wdata\[31:0\]} \
{/tb_top/s02_axi_araddr\[31:0\]} \
{/tb_top/s02_axi_awaddr\[31:0\]} \
{/tb_top/s02_axi_rdata\[31:0\]} \
{/tb_top/s02_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
           18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 \
           40 41 42 )} 
wvSetPosition -win $_nWave2 {("G1" 42)}
wvGetSignalClose -win $_nWave2
verdiDockWidgetMaximize -dock windowDock_nWave_2
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
wvZoom -win $_nWave2 8990788.014549 9280786.240241
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
verdiCaptureWindow -dock windowDock_nWave_2
verdiCloseDialog -win $_Verdi_1 -widget capturePreview
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
wvZoomIn -win $_nWave2
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
