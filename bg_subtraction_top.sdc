create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
# OV7670 PCLK is driven from the camera.  With 25 MHz XCLK this constraint is conservative.
create_clock -name CAM_PCLK -period 40.000 [get_ports {CAM_PCLK}]
create_generated_clock -name CLK25 -source [get_ports {CLOCK_50}] -divide_by 2 [get_registers {*|clk25}]
derive_clock_uncertainty
set_clock_groups -asynchronous -group {CAM_PCLK} -group {CLOCK_50 CLK25}
