# Скрипт для запуска симуляции 
vlib work
vlog rtl/apb_master.sv rtl/apb_alu_slave.sv tb/tb.sv
vsim -c TB -do "run -all; quit -f"