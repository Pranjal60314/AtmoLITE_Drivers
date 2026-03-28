[pythonofapollo@archlinux hdr]$ ./vtest1.sh hdr_tb.v
--- Arch Linux Verilog Automator ---
Cleaning old simulation files...
Target: hdr_tb_data_dump.vcd
CRC_TABLE LOADED
CRC_OUT --   x
VCD info: dumpfile hdr_tb_data_dump.vcd opened for output.
Simulation Started. Monitoring UART_TX...
[TIME            989930000ime] Receiver byte: 0xfe
[TIME           2031810000ime] Receiver byte: 0xaa
[TIME           3073670000ime] Receiver byte: 0xbb
[TIME           4115530000ime] Receiver byte: 0x01
[TIME           5157390000ime] Receiver byte: 0x11
[TIME           6199250000ime] Receiver byte: 0x22
[TIME           7241110000ime] Receiver byte: 0x33
[TIME           8282970000ime] Receiver byte: 0x44
[TIME           9324830000ime] Receiver byte: 0x55
[TIME          10366690000ime] Receiver byte: 0x66
[TIME          11408550000ime] Receiver byte: 0x77
[TIME          12450410000ime] Receiver byte: 0x88
[TIME          13492270000ime] Receiver byte: 0x00
[TIME          14534130000ime] Receiver byte: 0x01
[TIME          15575990000ime] Receiver byte: 0x23
[TIME          16617850000ime] Receiver byte: 0x35
[TIME          17659710000ime] Receiver byte: 0xfe
[TIME          18701570000ime] Receiver byte: 0xaa
[TIME          19743430000ime] Receiver byte: 0xbb
Simulation Finished.
hdr_tb.v:72: $finish called at 20050100000 (1ps)
Opening hdr_tb_data_dump.vcd in GTKWave...
[pythonofapollo@archlinux hdr]$ 
(process:17931): Gtk-WARNING **: 19:40:26.821: Locale not supported by C library.
        Using the fallback 'C' locale.

GTKWave Analyzer v3.3.126 (w)1999-2026 BSI

[0] start time.
[20050100000] end time.
WM Destroy