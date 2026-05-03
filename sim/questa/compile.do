transcript file ../logs/compile.log

if [file exists work] {
    vdel -lib work -all
}

vlib work
vmap work work

vlog -sv -f ../../filelists/rtl.f
vlog -sv -f ../../filelists/tb.f

transcript file ""