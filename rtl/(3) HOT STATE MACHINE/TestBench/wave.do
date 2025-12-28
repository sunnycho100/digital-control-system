onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Segway_tb/iPHYS/clk
add wave -noupdate -color Magenta /Segway_tb/iPHYS/rider_lean
add wave -noupdate -color Magenta /Segway_tb/iDUT/OVR_I_lft
add wave -noupdate -color Magenta /Segway_tb/iDUT/OVR_I_rght
add wave -noupdate -color Magenta /Segway_tb/iDUT/lft_ld
add wave -noupdate -color Magenta /Segway_tb/iDUT/rght_ld
add wave -noupdate -color Magenta -radix unsigned /Segway_tb/iDUT/batt
add wave -noupdate -color Magenta /Segway_tb/iDUT/steer_pot
add wave -noupdate /Segway_tb/iDUT/norm_mode
add wave -noupdate /Segway_tb/iDUT/PWM1_lft
add wave -noupdate /Segway_tb/iDUT/PWM2_lft
add wave -noupdate /Segway_tb/iDUT/PWM1_rght
add wave -noupdate /Segway_tb/iDUT/PWM2_rght
add wave -noupdate -radix decimal /Segway_tb/iDUT/iBAL/pid_inst/I_term
add wave -noupdate -color Magenta /Segway_tb/iDUT/en_steer
add wave -noupdate -color Magenta /Segway_tb/iDUT/rider_off
add wave -noupdate -color {Orange Red} /Segway_tb/iDUT/batt_low
add wave -noupdate -color Magenta /Segway_tb/iDUT/too_fast
add wave -noupdate -color Magenta /Segway_tb/iDUT/pwr_up
add wave -noupdate -color Magenta /Segway_tb/iDUT/iBUZZ/state
add wave -noupdate -format Analog-Step -height 74 -max 31.0 -min -16.0 -radix decimal /Segway_tb/iDUT/iBAL/ptch
add wave -noupdate -color Magenta /Segway_tb/iDUT/iBAL/steer_pot
add wave -noupdate -color Magenta /Segway_tb/iDUT/iBAL/too_fast
add wave -noupdate /Segway_tb/iDUT/iBAL/ss_tmr
add wave -noupdate -color {Spring Green} -format Analog-Step -height 74 -max 9081.9999999999982 -min -4466.0 -radix decimal /Segway_tb/iPHYS/theta_platform
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {89380789450 ps} 0} {{Cursor 2} {273373385050 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 244
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {20739000630 ps} {331119263130 ps}
