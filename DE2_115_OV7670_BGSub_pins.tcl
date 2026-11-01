package require ::quartus::project

proc ap {sig pin std} {
    set_location_assignment PIN_$pin -to $sig
    set_instance_assignment -name IO_STANDARD $std -to $sig
}
set STD33 "3.3-V LVTTL"
set STD25 "2.5 V"

ap CLOCK_50 Y2 $STD33

ap {KEY[0]} M23 $STD25
ap {KEY[1]} M21 $STD25

foreach {s p} {
    {SW[0]} AB28 {SW[1]} AC28 {SW[2]} AC27 {SW[3]} AD27 {SW[4]} AB27
    {SW[5]} AC26 {SW[6]} AD26 {SW[7]} AB26 {SW[8]} AC25 {SW[9]} AB25
} { ap $s $p $STD25 }

foreach {s p} {
    {LEDG[0]} E21 {LEDG[1]} E22 {LEDG[2]} E25 {LEDG[3]} E24 {LEDG[4]} H21
    {LEDG[5]} G20 {LEDG[6]} G22 {LEDG[7]} G21 {LEDG[8]} F17
} { ap $s $p $STD25 }

foreach {s p} {
    {VGA_R[0]} E12 {VGA_R[1]} E11 {VGA_R[2]} D10 {VGA_R[3]} F12
    {VGA_R[4]} G10 {VGA_R[5]} J12 {VGA_R[6]} H8 {VGA_R[7]} H10
    {VGA_G[0]} G8 {VGA_G[1]} G11 {VGA_G[2]} F8 {VGA_G[3]} H12
    {VGA_G[4]} C8 {VGA_G[5]} B8 {VGA_G[6]} F10 {VGA_G[7]} C9
    {VGA_B[0]} B10 {VGA_B[1]} A10 {VGA_B[2]} C11 {VGA_B[3]} B11
    {VGA_B[4]} A11 {VGA_B[5]} C12 {VGA_B[6]} D11 {VGA_B[7]} D12
    VGA_BLANK_N F11 VGA_CLK A12 VGA_HS G13 VGA_SYNC_N C10 VGA_VS C13
} { ap $s $p $STD33 }

# Camera wiring already used on the board:
# D0..D7 = JP5 1..8, PCLK=9, HREF=10, VSYNC=13, XCLK=14,
# SIOC=15, SIOD=16, RESET=17, PWDN=18.
foreach {s p} {
    {CAM_D[0]} AB22 {CAM_D[1]} AC15 {CAM_D[2]} AB21 {CAM_D[3]} Y17
    {CAM_D[4]} AC21 {CAM_D[5]} Y16 {CAM_D[6]} AD21 {CAM_D[7]} AE16
    CAM_PCLK AD15 CAM_HREF AE15 CAM_VSYNC AC19 CAM_XCLK AF16
    CAM_SIOC AD19 CAM_SIOD AF15 CAM_RESET_N AF24 CAM_PWDN AE21
} { ap $s $p $STD33 }

set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to CAM_SIOD
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to CAM_SIOC

set_global_assignment -name SDC_FILE bg_subtraction_top.sdc
set_global_assignment -name TOP_LEVEL_ENTITY bg_subtraction_top
export_assignments
puts "FINAL V2 OV7670 background-subtraction pin assignments applied."
