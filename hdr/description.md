UART Packet Header Generator with CRC8
Overview

This project implements a UART-based packet transmission system with an integrated CRC-8 error detection mechanism.

At its core, the design builds a structured packet (header + metadata + CRC), feeds it byte-by-byte into a UART transmitter, and computes the CRC in parallel as the data flows through the system.

Think of it like an assembly line:

One worker packs bytes (FSM)
One computes checksum (CRC)
One ships them out (UART)

All synchronized, no chaos.

Top-Level Module: hdr
Purpose

Generates and transmits a 16-byte packet over UART, including:

Addressing
Protocol metadata
Parameters
Data length
CRC checksum
Packet Structure
Byte Index	Field	Description
0	logical_address	Device address (default: 0xFE)
1	protocol	Protocol identifier
2	subprotocol	Sub-category
3	packet_nr	Packet sequence number
4–11	param0–param7	Payload parameters
12	data_length[7:0]	Length (LSB)
13	data_length[15:8]	Length
14	data_length[23:16]	Length (MSB)
15	crc_out	CRC-8 checksum
Inputs / Outputs
Inputs
clk — System clock
reset — Global reset
start_send — Triggers packet transmission
Metadata inputs:
protocol, subprotocol, packet_nr
Parameters:
param0 to param7
data_length (24-bit)
Output
UART_TX — Serial transmit line
Internal Architecture
1. FSM Controller

States:

IDLE — Waits for start_send
SEND — Streams bytes sequentially
DONE — Cleans up and resets
Key Mechanism

The FSM uses:

uart_busy and uart_busy_prev
Detects falling edge of busy signal to move to next byte

This ensures:

No overwrite of UART buffer
Clean byte-by-byte transmission
2. UART Transmission (uart_tx)
Features:
Configurable baud rate (default: 9600)
Standard frame:
1 start bit
8 data bits
1 stop bit
Internal FSM:
IDLE → START → SEND → STOP
Key Concept:

Timing is derived from:

CYCLES_PER_BIT = CLK_HZ / BIT_RATE

So the UART is basically a metronome counting clock cycles to decide when to shift bits.

3. CRC Engine (crc8_generator)
Features:
Table-based CRC (fast, no polynomial math during runtime)
Uses:
next_crc = CRC_TABLE[crc_reg ^ data_in]
Behavior:
Reset → CRC = 0
On data_valid → updates CRC
Runs in parallel with UART transmission
Important Detail:
CRC is computed for bytes 0–14
Byte 15 transmits final CRC
Data Flow
start_send goes high
FSM enters SEND
For each byte:
Send to UART (data_in_uart)
Feed into CRC (data_in_crc)
CRC accumulates in background
Final byte = crc_out
FSM transitions to DONE → IDLE