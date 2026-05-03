.PHONY: compile sim clean

compile:
	cd sim/questa && vsim -c -do compile.do

sim:
	cd sim/questa && vsim -c -do "do compile.do; do run.do; quit"

clean:
	powershell -ExecutionPolicy Bypass -File scripts/clean.ps1