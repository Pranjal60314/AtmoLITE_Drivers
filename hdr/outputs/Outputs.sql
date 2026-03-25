[pythonofapollo@archlinux hdr]$ ./vtest1.sh hdr_tb.v
--- Arch Linux Verilog Automator ---
Cleaning old simulation files...
Target: hdr_tb_data_dump.vcd
CRC_TABLE LOADED
CRC_OUT --   x
VCD info: dumpfile hdr_tb_data_dump.vcd opened for output.
Simulation Started. Monitoring UART_TX...

--- NEW BYTE DETECTED AT            208450000 ---
DATA BITS: 0 1 1 1 1 1 1 1 
STOP BIT : 1
HEX VALUE: 0xfe
---------------------------------

--- NEW BYTE DETECTED AT           1458370000 ---
DATA BITS: 0 1 0 1 0 1 0 1 
STOP BIT : 1
HEX VALUE: 0xaa
---------------------------------

--- NEW BYTE DETECTED AT           2708290000 ---
DATA BITS: 1 1 0 1 1 1 0 1 
STOP BIT : 1
HEX VALUE: 0xbb
---------------------------------

--- NEW BYTE DETECTED AT           3958210000 ---
DATA BITS: 1 0 0 0 0 0 0 0 
STOP BIT : 1
HEX VALUE: 0x01
---------------------------------

--- NEW BYTE DETECTED AT           5208130000 ---
DATA BITS: 1 0 0 0 1 0 0 0 
STOP BIT : 1
HEX VALUE: 0x11
---------------------------------

--- NEW BYTE DETECTED AT           6458050000 ---
DATA BITS: 0 1 0 0 0 1 0 0 
STOP BIT : 1
HEX VALUE: 0x22
---------------------------------

--- NEW BYTE DETECTED AT           7707970000 ---
DATA BITS: 1 1 0 0 1 1 0 0 
STOP BIT : 1
HEX VALUE: 0x33
---------------------------------

--- NEW BYTE DETECTED AT           8957890000 ---
DATA BITS: 0 0 1 0 0 0 1 0 
STOP BIT : 1
HEX VALUE: 0x44
---------------------------------

--- NEW BYTE DETECTED AT          10207810000 ---
DATA BITS: 1 0 1 0 1 0 1 0 
STOP BIT : 1
HEX VALUE: 0x55
---------------------------------

--- NEW BYTE DETECTED AT          11457730000 ---
DATA BITS: 0 1 1 0 0 1 1 0 
STOP BIT : 1
HEX VALUE: 0x66
---------------------------------

--- NEW BYTE DETECTED AT          12707650000 ---
DATA BITS: 1 1 1 0 1 1 1 0 
STOP BIT : 1
HEX VALUE: 0x77
---------------------------------

--- NEW BYTE DETECTED AT          13957570000 ---
DATA BITS: 0 0 0 1 0 0 0 1 
STOP BIT : 1
HEX VALUE: 0x88
---------------------------------

--- NEW BYTE DETECTED AT          15207490000 ---
DATA BITS: 0 0 0 0 0 0 0 0 
STOP BIT : 1
HEX VALUE: 0x00
---------------------------------

--- NEW BYTE DETECTED AT          16457410000 ---
DATA BITS: 1 0 0 0 0 0 0 0 
STOP BIT : 1
HEX VALUE: 0x01
---------------------------------

--- NEW BYTE DETECTED AT          17707330000 ---
DATA BITS: 1 1 0 0 0 1 0 0 
STOP BIT : 1
HEX VALUE: 0x23
---------------------------------

--- NEW BYTE DETECTED AT          18957250000 ---
DATA BITS: 0 1 0 1 0 1 0 1 
STOP BIT : 1
HEX VALUE: 0xaa
---------------------------------
Simulation Finished.
hdr_tb.v:42: $finish called at 20050100000 (1ps)
Opening hdr_tb_data_dump.vcd in GTKWave...
[pythonofapollo@archlinux hdr]$ 
(process:12279): Gtk-WARNING **: 21:06:14.986: Locale not supported by C library.
        Using the fallback 'C' locale.

GTKWave Analyzer v3.3.126 (w)1999-2026 BSI

[0] start time.
[20050100000] end time.
WM Destroy