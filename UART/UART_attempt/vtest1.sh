#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./vtest.sh [filename.v]"
    exit 1
fi

INPUT_FILE=$1
BASE_NAME=$(basename "$INPUT_FILE" .v)
VCD_NAME="${BASE_NAME}_data_dump.vcd"
VVP_NAME="${BASE_NAME}.vvp"

echo "--- Arch Linux Verilog Automator ---"
echo "Cleaning old simulation files..."

# --- Conflict Resolution ---
# Removes existing output files so iverilog/vvp starts fresh
rm -f "$VVP_NAME" "$VCD_NAME"

echo "Target: $VCD_NAME"

# Compiling with SystemVerilog 2012 support
iverilog -g2012 -o "$VVP_NAME" -DVCD_FILE="\"$VCD_NAME\"" *.v

if [ $? -eq 0 ]; then
    vvp "$VVP_NAME"
    
    if [ -f "$VCD_NAME" ]; then
        echo "Opening $VCD_NAME in GTKWave..."
        gtkwave "$VCD_NAME" &
        
        # Optional: Clean up the compiled vvp binary after running
        # rm -f "$VVP_NAME"
    else
        echo "Error: $VCD_NAME was not created. Check your testbench for \$dumpfile calls."
    fi
else
    echo "Compilation failed."
    # Clean up the failed vvp stub if it exists
    rm -f "$VVP_NAME"
fi