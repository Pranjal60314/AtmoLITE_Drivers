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
echo "Target: $VCD_NAME"

iverilog -o "$VVP_NAME" -DVCD_FILE="\"$VCD_NAME\"" "$INPUT_FILE"

if [ $? -eq 0 ]; then
    vvp "$VVP_NAME"
    if [ -f "$VCD_NAME" ]; then
        echo "Opening $VCD_NAME in GTKWave..."
        gtkwave "$VCD_NAME" &

    else
        echo "Error: $VCD_NAME was not created."

    fi
else
    echo "Compilation failed."

fi