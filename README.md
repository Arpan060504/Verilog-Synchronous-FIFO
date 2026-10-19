# Parameterized Synchronous FIFO in SystemVerilog

A single-clock, parameterized FIFO designed in SystemVerilog, with a self-checking verification environment and a completed OpenROAD physical-design run using the Nangate45 platform.

The project covers RTL design, corner-case handling, regression-based verification, synthesis, static timing analysis, and physical implementation.

## Project Highlights

- **Parameterized RTL:** configurable data width and FIFO depth.
- **Defined simultaneous read/write behavior:** explicit policy at empty, full, and intermediate occupancy.
- **Self-checking verification:** directed tests plus randomized stimulus checked against a golden reference model.
- **Functional corner tracking:** counters for full/empty states, almost-full/almost-empty states, rejected requests, idle cycles, and simultaneous reads/writes.
- **Physical design:** synthesized and implemented through OpenROAD-flow-scripts with Nangate45, with timing and area reports included in the repository.

## Repository Layout

```text
.
├── rtl/
│   ├── fifo.sv
│   └── fifo.v
├── tb/
│   ├── fifo_directed_tb.sv
│   ├── fifo_random_tb.sv
│   ├── fifo_coverage_model.sv
│   └── fifo_tb.v
├── waveform/
│   ├── fifo_waveform.png
│   ├── fifo_waveform2.png
│   └── fifo_waveform3.png
└── physical_design/
    ├── config.mk
    ├── 6_final.gds
    ├── reports/
    │   ├── synthesis_summary.txt
    │   ├── timing_summary.txt
    │   └── physical_design_summary.txt
    └── screenshots/
        ├── layout.png
        └── timing_path.png
```

## Architecture and Interface

Default configuration: `DATA_WIDTH = 8`, `DEPTH = 16`. The data storage is a depth-by-width memory array with read and write pointers, an occupancy counter, and status/control outputs.

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Single clock |
| `reset` | Input | Synchronous, active-high reset |
| `data_in` | Input | Input word, `DATA_WIDTH` bits |
| `write_request` | Input | Requests a write |
| `read_request` | Input | Requests a read |
| `data_out` | Output | Registered output word |
| `empty` / `full` | Output | FIFO empty/full status |
| `almost_empty` / `almost_full` | Output | Early-warning occupancy flags |
| `data_valid` | Output | One-cycle pulse when a new output word is read |
| `overflow` / `underflow` | Output | One-cycle indication that a standalone write/read request was rejected |
| `fifo_count` | Output | Current number of stored words |

### Parameters

| Parameter | Default | Purpose |
|---|---:|---|
| `DATA_WIDTH` | 8 | Width of each stored word |
| `DEPTH` | 16 | Number of words the FIFO can store |
| `ALMOST_FULL_MARGIN` | 2 | Almost-full threshold margin |
| `ALMOST_EMPTY_MARGIN` | 2 | Almost-empty threshold margin |

The RTL is intended for positive, power-of-two FIFO depths because the pointer width is derived using `$clog2(DEPTH)` and the pointers wrap naturally at that width. For a non-power-of-two depth, explicit pointer wrap logic would be needed. Parameter margins should also be chosen consistently with the configured depth.

## Read/Write Behavior

The FIFO uses the following policy when both requests are asserted in the same cycle:

| Occupancy before the clock edge | Read action | Write action | Occupancy effect |
|---|---|---|---|
| Empty | Rejected/not performed | Accepted | Increases by one |
| Full | Accepted | Not performed | Decreases by one |
| Neither empty nor full | Accepted | Accepted | Unchanged |

For standalone requests, a write is accepted only when the FIFO is not full, and a read is accepted only when the FIFO is not empty. A standalone write while full pulses `overflow`; a standalone read while empty pulses `underflow`. These indications are not raised merely because one side is suppressed under the simultaneous-request policy described above.

The reset is synchronous and active-high. The output data is registered and `data_valid` pulses when a read operation supplies a fresh word.

## Verification

Two runnable regressions are included. The randomized testbench maintains a software-style queue as a golden reference and compares the DUT's observable behavior against that model.

### Directed regression

The directed testbench covers basic FIFO behavior, filling and draining, back-to-back operations, boundary conditions, rejected requests, and simultaneous read/write behavior at empty, full, and intermediate occupancy. It is self-checking and reports a failure if any check fails.

### Randomized regression

The randomized testbench drives read/write requests over 4,000 cycles. It checks DUT outputs against the reference model and tracks functional coverage counters for key scenarios.

**Recorded regression result: 4,000 cycles, 4,000 checks, 0 errors.**

| Coverage counter | Recorded hits |
|---|---:|
| Full asserted | 127 |
| Empty asserted | 152 |
| Almost-full asserted | 639 |
| Almost-empty asserted | 593 |
| Idle cycles | 834 |
| Write rejected while full | 32 |
| Read rejected while empty | 35 |
| Simultaneous read/write at normal occupancy | 1,077 |
| Simultaneous read/write at full | 39 |
| Simultaneous read/write at empty | 40 |

These counts are from the recorded run in this repository; they are not a guarantee that every random seed will produce identical counts.

### Run the testbenches

Install Icarus Verilog with `iverilog` and `vvp`. From the repository root, run:

```bash
# Compile and run the directed testbench
iverilog -g2012 -o directed.vvp rtl/fifo.sv tb/fifo_directed_tb.sv
vvp directed.vvp

# Compile and run the randomized self-checking testbench
iverilog -g2012 -o random.vvp rtl/fifo.sv tb/fifo_random_tb.sv
vvp random.vvp
```

If your local checkout includes a Makefile, its targets can be used instead. Generated simulation executables and waveform dumps should not be committed unless they are deliberately being shared as artifacts.

### Coverage-model note

`tb/fifo_coverage_model.sv` documents a class/constraint/covergroup-style approach for a simulator with more complete SystemVerilog coverage support. It is supplementary; the Icarus-compatible randomized regression is the runnable self-checking test.

## Synthesis and Physical Design

The repository includes a physical-design configuration, final layout screenshot, timing-path screenshot, GDS output, and summary reports from an OpenROAD-flow-scripts run targeting **Nangate45**.

| Metric | Reported result |
|---|---:|
| Mapped standard-cell area after synthesis | 1,660.9 µm² |
| Final standard-cell area | 1,647.6 µm² |
| Core area | 2,911.1 µm² |
| Die area | 3,243.87 µm² |
| Standard-cell utilization | 56.60% |
| Clock constraint | 1.0 ns |
| Reported final critical-path delay | 0.7333 ns |
| Setup slack | 0.3377 ns |
| Hold slack | 0.0997 ns |
| Setup / hold violations | 0 / 0 |
| Final routing DRC violations | 0* |
| Estimated total power | 3.877 mW |

`* `The reported detailed-routing run had zero final DRC violations. EDA results are flow- and library-dependent estimates, not silicon measurements; power in particular depends on activity and modeling assumptions. The physical-design summary reports one warning, so the run should not be described as warning-free.

Artifacts: [physical-design reports](physical_design/reports/), [layout screenshot](physical_design/screenshots/layout.png), [timing-path screenshot](physical_design/screenshots/timing_path.png), and [GDS](physical_design/6_final.gds).

## Tools

- SystemVerilog
- Icarus Verilog (`iverilog` / `vvp`) for simulation
- Yosys for synthesis
- OpenROAD-flow-scripts and OpenROAD for physical implementation and timing analysis
- Nangate45 standard-cell platform

## Potential Next Steps

- Add explicit pointer wrap logic and tests for non-power-of-two depths.
- Add formal checks for occupancy bounds, flag consistency, and accepted read/write transactions.
- Add a dual-clock asynchronous FIFO with Gray-coded pointers and synchronizers as a separate CDC-focused extension.
- Add a reproducible script or CI workflow that compiles and runs both regressions automatically.

## License

No license is specified in this README. Add a `LICENSE` file if you intend to grant others explicit reuse rights.
