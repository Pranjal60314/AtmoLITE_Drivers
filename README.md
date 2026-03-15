# AtmoLITE Drivers

This repository contains the early driver structure for the **AtmoLITE interface** and related experiments for implementing parts of the system in hardware.

## Overview

`AtmoLITE_driver_v0.1.c` contains the initial software driver structure that serves as the reference implementation. The long-term goal of this project is to translate critical parts of this functionality into **Verilog modules** so they can run directly in hardware for improved efficiency and integration.

Development is being carried out by gradually analyzing each feature in the driver and recreating its behavior as a hardware module.

## Reference Document

The implementation is based on the specification document:

**AtmoLITE_UDP_IS3_v0.1**

This document defines the communication format, packet structure, and operational requirements that the driver and hardware modules must follow.

## CRC8 Implementation

The repository also contains an experimental CRC8 implementation used for packet verification. Both software and hardware (Verilog) versions are included so their behavior can be tested and compared.

## Running the Tests

Testbenches and verification scripts are provided in the repository.

To run the Verilog tests, use the provided scripts rather than invoking the simulator manually. The scripts handle compilation and execution of the testbench automatically.

Example:

```
./scripts/vtest.sh <test_bench_filename.v>
```

Additional helper scripts are located in the `Scripts` directory.

## Project Goal

The broader objective of this project is to move from a **software-only driver model** to a **hardware-assisted architecture**, where packet handling, CRC computation, and protocol logic can be executed directly in digital hardware.

This approach improves determinism, reduces CPU overhead, and allows the system to scale more effectively in embedded or FPGA-based environments.
