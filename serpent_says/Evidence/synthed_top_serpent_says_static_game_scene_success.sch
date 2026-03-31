# File saved with Nlview 7.7.1 2023-07-26 3bc4126617 VDI=43 GEI=38 GUI=JA:21.0 threadsafe
# 
# non-default properties - (restore without -noprops)
property -colorscheme classic
property attrcolor #000000
property attrfontsize 8
property autobundle 1
property backgroundcolor #ffffff
property boxcolor0 #000000
property boxcolor1 #000000
property boxcolor2 #000000
property boxinstcolor #000000
property boxpincolor #000000
property buscolor #008000
property closeenough 5
property createnetattrdsp 2048
property decorate 1
property elidetext 40
property fillcolor1 #ffffcc
property fillcolor2 #dfebf8
property fillcolor3 #f0f0f0
property gatecellname 2
property instattrmax 30
property instdrag 15
property instorder 1
property marksize 12
property maxfontsize 12
property maxzoom 5
property netcolor #19b400
property objecthighlight0 #ff00ff
property objecthighlight1 #ffff00
property objecthighlight2 #00ff00
property objecthighlight3 #0095ff
property objecthighlight4 #8000ff
property objecthighlight5 #ffc800
property objecthighlight7 #00ffff
property objecthighlight8 #ff00ff
property objecthighlight9 #ccccff
property objecthighlight10 #0ead00
property objecthighlight11 #cefc00
property objecthighlight12 #9e2dbe
property objecthighlight13 #ba6a29
property objecthighlight14 #fc0188
property objecthighlight15 #02f990
property objecthighlight16 #f1b0fb
property objecthighlight17 #fec004
property objecthighlight18 #149bff
property objecthighlight19 #eb591b
property overlaycolor #19b400
property pbuscolor #000000
property pbusnamecolor #000000
property pinattrmax 20
property pinorder 2
property pinpermute 0
property portcolor #000000
property portnamecolor #000000
property ripindexfontsize 4
property rippercolor #000000
property rubberbandcolor #000000
property rubberbandfontsize 12
property selectattr 0
property selectionappearance 2
property selectioncolor #0000ff
property sheetheight 44
property sheetwidth 68
property showmarks 1
property shownetname 0
property showpagenumbers 1
property showripindex 1
property timelimit 1
#
module new top_serpent_says work:top_serpent_says:NOFILE -nosplit
load symbol BUFG hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol IBUF hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol OBUF hdi_primitives BUF pin O output pin I input fillcolor 1
load symbol clk_divider work:clk_divider:NOFILE HIERBOX pin CLK input.left pin div_cnt_reg[0]_0 input.left pinBus Q output.right [0:0] boxcolor 1 fillcolor 2 minwidth 13%
load symbol vga_controller work:vga_controller:NOFILE HIERBOX pin CPU_RESETN output.right pin CPU_RESETN_IBUF input.left pin VGA_HS_OBUF output.right pin VGA_VS_OBUF output.right pin clk_pix_BUFG input.left pinBus VGA_B_OBUF output.right [1:0] pinBus VGA_G_OBUF output.right [1:0] pinBus VGA_R_OBUF output.right [1:0] boxcolor 1 fillcolor 2 minwidth 13%
load port CLK100MHZ input -pg 1 -lvl 0 -x 0 -y 420
load port CPU_RESETN input -pg 1 -lvl 0 -x 0 -y 530
load port VGA_HS output -pg 1 -lvl 7 -x 1610 -y 600
load port VGA_VS output -pg 1 -lvl 7 -x 1610 -y 670
load portBus VGA_B output [3:0] -attr @name VGA_B[3:0] -pg 1 -lvl 7 -x 1610 -y 40
load portBus VGA_G output [3:0] -attr @name VGA_G[3:0] -pg 1 -lvl 7 -x 1610 -y 320
load portBus VGA_R output [3:0] -attr @name VGA_R[3:0] -pg 1 -lvl 7 -x 1610 -y 740
load inst CLK100MHZ_IBUF_BUFG_inst BUFG hdi_primitives -attr @cell(#000000) BUFG -pg 1 -lvl 2 -x 250 -y 420
load inst CLK100MHZ_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 1 -x 40 -y 420
load inst CPU_RESETN_IBUF_inst IBUF hdi_primitives -attr @cell(#000000) IBUF -pg 1 -lvl 4 -x 770 -y 530
load inst VGA_B_OBUF[0]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 40
load inst VGA_B_OBUF[1]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 110
load inst VGA_B_OBUF[2]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 180
load inst VGA_B_OBUF[3]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 250
load inst VGA_G_OBUF[0]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 320
load inst VGA_G_OBUF[1]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 390
load inst VGA_G_OBUF[2]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 460
load inst VGA_G_OBUF[3]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 530
load inst VGA_HS_OBUF_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 600
load inst VGA_R_OBUF[0]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 740
load inst VGA_R_OBUF[1]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 810
load inst VGA_R_OBUF[2]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 880
load inst VGA_R_OBUF[3]_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 950
load inst VGA_VS_OBUF_inst OBUF hdi_primitives -attr @cell(#000000) OBUF -pg 1 -lvl 6 -x 1410 -y 670
load inst clk_pix_BUFG_inst BUFG hdi_primitives -attr @cell(#000000) BUFG -pg 1 -lvl 4 -x 770 -y 600
load inst u_clk_divider clk_divider work:clk_divider:NOFILE -autohide -attr @cell(#000000) clk_divider -pinBusAttr Q @name Q -pg 1 -lvl 3 -x 620 -y 410
load inst u_vga_controller vga_controller work:vga_controller:NOFILE -autohide -attr @cell(#000000) vga_controller -pinBusAttr VGA_B_OBUF @name VGA_B_OBUF[1:0] -pinBusAttr VGA_G_OBUF @name VGA_G_OBUF[1:0] -pinBusAttr VGA_R_OBUF @name VGA_R_OBUF[1:0] -pg 1 -lvl 5 -x 1130 -y 530
load net CLK100MHZ -port CLK100MHZ -pin CLK100MHZ_IBUF_inst I
netloc CLK100MHZ 1 0 1 NJ 420
load net CLK100MHZ_IBUF -pin CLK100MHZ_IBUF_BUFG_inst I -pin CLK100MHZ_IBUF_inst O
netloc CLK100MHZ_IBUF 1 1 1 NJ 420
load net CLK100MHZ_IBUF_BUFG -pin CLK100MHZ_IBUF_BUFG_inst O -pin u_clk_divider CLK
netloc CLK100MHZ_IBUF_BUFG 1 2 1 NJ 420
load net CPU_RESETN -port CPU_RESETN -pin CPU_RESETN_IBUF_inst I
netloc CPU_RESETN 1 0 4 NJ 530 NJ 530 NJ 530 NJ
load net CPU_RESETN_IBUF -pin CPU_RESETN_IBUF_inst O -pin u_vga_controller CPU_RESETN_IBUF
netloc CPU_RESETN_IBUF 1 4 1 980J 530n
load net VGA_B[0] -attr @rip 0 -port VGA_B[0] -pin VGA_B_OBUF[0]_inst O
load net VGA_B[1] -attr @rip 1 -port VGA_B[1] -pin VGA_B_OBUF[1]_inst O
load net VGA_B[2] -attr @rip 2 -port VGA_B[2] -pin VGA_B_OBUF[2]_inst O
load net VGA_B[3] -attr @rip 3 -port VGA_B[3] -pin VGA_B_OBUF[3]_inst O
load net VGA_B_OBUF[0] -attr @rip VGA_B_OBUF[0] -pin VGA_B_OBUF[0]_inst I -pin u_vga_controller VGA_B_OBUF[0]
load net VGA_B_OBUF[1] -attr @rip VGA_B_OBUF[1] -pin VGA_B_OBUF[1]_inst I -pin VGA_B_OBUF[2]_inst I -pin VGA_B_OBUF[3]_inst I -pin u_vga_controller VGA_B_OBUF[1]
load net VGA_G[0] -attr @rip 0 -port VGA_G[0] -pin VGA_G_OBUF[0]_inst O
load net VGA_G[1] -attr @rip 1 -port VGA_G[1] -pin VGA_G_OBUF[1]_inst O
load net VGA_G[2] -attr @rip 2 -port VGA_G[2] -pin VGA_G_OBUF[2]_inst O
load net VGA_G[3] -attr @rip 3 -port VGA_G[3] -pin VGA_G_OBUF[3]_inst O
load net VGA_G_OBUF[0] -attr @rip VGA_G_OBUF[0] -pin VGA_G_OBUF[0]_inst I -pin u_vga_controller VGA_G_OBUF[0]
load net VGA_G_OBUF[1] -attr @rip VGA_G_OBUF[1] -pin VGA_G_OBUF[1]_inst I -pin VGA_G_OBUF[2]_inst I -pin VGA_G_OBUF[3]_inst I -pin u_vga_controller VGA_G_OBUF[1]
load net VGA_HS -port VGA_HS -pin VGA_HS_OBUF_inst O
netloc VGA_HS 1 6 1 NJ 600
load net VGA_HS_OBUF -pin VGA_HS_OBUF_inst I -pin u_vga_controller VGA_HS_OBUF
netloc VGA_HS_OBUF 1 5 1 NJ 600
load net VGA_R[0] -attr @rip 0 -port VGA_R[0] -pin VGA_R_OBUF[0]_inst O
load net VGA_R[1] -attr @rip 1 -port VGA_R[1] -pin VGA_R_OBUF[1]_inst O
load net VGA_R[2] -attr @rip 2 -port VGA_R[2] -pin VGA_R_OBUF[2]_inst O
load net VGA_R[3] -attr @rip 3 -port VGA_R[3] -pin VGA_R_OBUF[3]_inst O
load net VGA_R_OBUF[0] -attr @rip VGA_R_OBUF[0] -pin VGA_R_OBUF[0]_inst I -pin u_vga_controller VGA_R_OBUF[0]
load net VGA_R_OBUF[1] -attr @rip VGA_R_OBUF[1] -pin VGA_R_OBUF[1]_inst I -pin VGA_R_OBUF[2]_inst I -pin VGA_R_OBUF[3]_inst I -pin u_vga_controller VGA_R_OBUF[1]
load net VGA_VS -port VGA_VS -pin VGA_VS_OBUF_inst O
netloc VGA_VS 1 6 1 NJ 670
load net VGA_VS_OBUF -pin VGA_VS_OBUF_inst I -pin u_vga_controller VGA_VS_OBUF
netloc VGA_VS_OBUF 1 5 1 1330J 640n
load net clk_pix -attr @rip Q[0] -pin clk_pix_BUFG_inst I -pin u_clk_divider Q[0]
netloc clk_pix 1 3 1 730 420n
load net clk_pix_BUFG -pin clk_pix_BUFG_inst O -pin u_vga_controller clk_pix_BUFG
netloc clk_pix_BUFG 1 4 1 NJ 600
load net u_vga_controller_n_1 -pin u_clk_divider div_cnt_reg[0]_0 -pin u_vga_controller CPU_RESETN
netloc u_vga_controller_n_1 1 2 4 490 480 NJ 480 NJ 480 1330
load netBundle @VGA_B 4 VGA_B[3] VGA_B[2] VGA_B[1] VGA_B[0] -autobundled
netbloc @VGA_B 1 6 1 1590 40n
load netBundle @VGA_G 4 VGA_G[3] VGA_G[2] VGA_G[1] VGA_G[0] -autobundled
netbloc @VGA_G 1 6 1 1590 320n
load netBundle @VGA_R 4 VGA_R[3] VGA_R[2] VGA_R[1] VGA_R[0] -autobundled
netbloc @VGA_R 1 6 1 1590 740n
load netBundle @VGA_B_OBUF 2 VGA_B_OBUF[1] VGA_B_OBUF[0] -autobundled
netbloc @VGA_B_OBUF 1 5 1 1350 40n
load netBundle @VGA_G_OBUF 2 VGA_G_OBUF[1] VGA_G_OBUF[0] -autobundled
netbloc @VGA_G_OBUF 1 5 1 1370 320n
load netBundle @VGA_R_OBUF 2 VGA_R_OBUF[1] VGA_R_OBUF[0] -autobundled
netbloc @VGA_R_OBUF 1 5 1 1370 620n
levelinfo -pg 1 0 40 250 620 770 1130 1410 1610
pagesize -pg 1 -db -bbox -sgen -150 0 1740 990
show
fullfit
#
# initialize ictrl to current module top_serpent_says work:top_serpent_says:NOFILE
ictrl init topinfo |
