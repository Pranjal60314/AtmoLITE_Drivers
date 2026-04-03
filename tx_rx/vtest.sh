#!/bin/bash

# --- 1. Variable Setup ---
if [ -z "$1" ]; then
    echo "Usage: ./vtest.sh [filename.v]"
    exit 1
fi

INPUT_FILE=$1
BASE_NAME=$(basename "$INPUT_FILE" .v)
VCD_NAME="${BASE_NAME}_data_dump.vcd"
VVP_NAME="${BASE_NAME}.vvp"
LOG_FILE="full_terminal_log.txt"

echo "--- Arch Linux Verilog Automator ---"
echo "Cleaning old simulation files..."

# Remove old files to ensure the log and simulation are fresh
rm -f "$VVP_NAME" "$VCD_NAME" "$LOG_FILE"

echo "Target: $VCD_NAME"
echo "Log:    $LOG_FILE"
echo "------------------------------------"

# --- 2. Compilation Phase ---
# '2>&1' captures compiler errors. 'tee -a' writes to screen and log file.
echo "Compiling..." | tee -a "$LOG_FILE"
iverilog -g2012 -Wall -o "$VVP_NAME" -DVCD_FILE="\"$VCD_NAME\"" *.v 2>&1 | tee -a "$LOG_FILE"

# --- 3. Simulation Phase ---
if [ -f "$VVP_NAME" ]; then
    echo "Starting Simulation..." | tee -a "$LOG_FILE"
    
    # 'stdbuf -oL' forces line-buffering so you see display statements immediately.
    # We use 'tee -a' so the simulation output is appended to the compilation log.
    stdbuf -oL vvp "$VVP_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    echo "------------------------------------" | tee -a "$LOG_FILE"
    
    # --- 4. Waveform Phase ---
    if [ -f "$VCD_NAME" ]; then
        echo "Opening $VCD_NAME in GTKWave..."
        # Launch GTKWave in the background and detach it
        gtkwave "$VCD_NAME" > /dev/null 2>&1 &
        disown
    else
        echo "Error: $VCD_NAME was not created. Check your \$dumpfile call." | tee -a "$LOG_FILE"
    fi
else
    echo "Compilation failed. Check $LOG_FILE for errors."
fi