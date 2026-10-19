# Parameterized Synchronous FIFO in SystemVerilog

A single-clock, parameterized FIFO implemented in SystemVerilog and verified with directed and randomized testbenches. The repository also includes recorded synthesis, timing, and physical-design results from an OpenROAD-flow-scripts run using the Nangate45 standard-cell platform.

## Highlights

- Parameterized data width and FIFO depth.
- Synchronous, active-high reset and registered output data.
- Full, empty, almost-full, and almost-empty status flags.
- `data_valid`, `overflow`, `underflow`, and occupancy outputs.
- Explicit simultaneous read/write behavior at empty, full, and intermediate occupancy.
- Directed testing and a randomized regression checked against a queue-based reference model.
- OpenROAD physical-design artifacts, reports, a final GDS, and layout screenshots.

## Architecture

Default configuration: `DATA_WIDTH = 8`, `DEPTH = 16`.

The FIFO uses a memory array, read and write pointers, and an occupancy counter. Reset is synchronous and active-high. The data output is registered and `data_valid` pulses when a read is performed.

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Single clock |
| `reset` | Input | Synchronous, active-high reset |
| `data_in` | Input | Input word, `DATA_WIDTH` bits wide |
| `write_request` | Input | Requests a write |
| `read_request` | Input | Requests a read |
| `data_out` | Output | Registered output word |
| `empty`, `full` | Output | FIFO occupancy status |
| `almost_empty`, `almost_full` | Output | Early-warning occupancy flags |
| `data_valid` | Output | Indicates a valid read result |
| `overflow`, `underflow` | Output | Indicates rejected standalone write/read requests |
| `fifo_count` | Output | Current stored-word count |

### Parameters

| Parameter | Default | Purpose |
|---|---:|---|
| `DATA_WIDTH` | 8 | Width of each stored word |
| `DEPTH` | 16 | FIFO capacity in words |
| `ALMOST_FULL_MARGIN` | 2 | Margin used for the almost-full threshold |
| `ALMOST_EMPTY_MARGIN` | 2 | Margin used for the almost-empty threshold |

The current pointer implementation is intended for positive power-of-two depths. For non-power-of-two depths, explicit pointer wrap logic is needed. Choose threshold margins consistently with the configured depth.

### Simultaneous read/write policy

When both requests are asserted in the same cycle, the FIFO applies this policy based on the occupancy before the active clock edge:

| Pre-edge occupancy | Read | Write | Occupancy effect |
|---|---|---|---|
| Empty | Not performed | Accepted | Increases by one |
| Full | Accepted | Not performed | Decreases by one |
| Neither empty nor full | Accepted | Accepted | Unchanged |

A standalone write while full is rejected and pulses `overflow`. A standalone read while empty is rejected and pulses `underflow`. The simultaneous-request cases at empty and full follow the policy above and do not raise those standalone-request error indications.

## Repository layout

```text
.
├── README.md
├── rtl/
│   └── fifo.sv
├── tb/
│   ├── fifo_tb.sv
│   ├── fifo_directed_tb.sv
│   ├── fifo_random_tb.sv
│   ├── fifo_coverage_model.sv
│   └── results/
│       ├── fifo_directed.log
│       └── fifo_random.log
├── waveform/
│   ├── fifo_waveform.png
│   ├── fifo_waveform2.png
│   └── fifo_waveform3.png
└── physical_design/
    ├── 6_final.gds
    ├── config.mk
    ├── reports/
    │   ├── synthesis_summary.txt
    │   ├── timing_summary.txt
    │   └── physical_design_summary.txt
    └── screenshots/
        ├── layout.png
        └── timing_path.png
```

## Verification

The recorded regressions are available under [`tb/results/`](tb/results/).

### Directed regression

Use `tb/fifo_tb.sv` as the canonical directed testbench. It tracks failed checks, prints a final result, and calls `$fatal` if a check fails. `tb/fifo_directed_tb.sv` is an older version retained in the repository; it is not the testbench used by the command below.

With Icarus Verilog installed, run these commands from the repository root:

```bash
iverilog -g2012 -Wall -s fifo_tb -o directed.vvp rtl/fifo.sv tb/fifo_tb.sv
vvp directed.vvp
```

Recorded result: **25 failure conditions tracked, 0 failures**. See [`fifo_directed.log`](tb/results/fifo_directed.log).

### Randomized regression

The randomized testbench uses weighted read/write stimulus and a queue-based golden reference model. It checks FIFO count, status flags, valid-data behavior, and read data; it also records manual functional coverage counters.

```bash
iverilog -g2012 -Wall -s fifo_random_tb -o random.vvp rtl/fifo.sv tb/fifo_random_tb.sv
vvp random.vvp
```

Recorded result: **4,000 cycles, 4,000 cycle-level checks, 0 reported errors**. See [`fifo_random.log`](tb/results/fifo_random.log).

The cycle-level check count is not the total number of individual comparisons: several assertions and comparisons can be performed during each cycle. Randomized coverage counts may vary between runs.

| Coverage counter | Hits in recorded run |
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

### SystemVerilog coverage-model file

[`tb/fifo_coverage_model.sv`](tb/fifo_coverage_model.sv) shows a class/constraint/covergroup-based coverage approach for simulators with SystemVerilog coverage support. It is supplementary and is not part of the Icarus Verilog commands above; Icarus Verilog does not support all of the constructs used by that file.

## Synthesis and physical design

The repository contains a physical-design configuration fragment, the final GDS, summary reports, and screenshots from a recorded OpenROAD-flow-scripts run using Nangate45.

| Metric | Reported result |
|---|---:|
| Technology platform | Nangate45 |
| Mapped standard-cell instances after synthesis | 988 |
| Mapped synthesis area | 1,660.9 µm² |
| Final standard-cell area | 1,647.6 µm² |
| Core area | 2,911.1 µm² |
| Die area | 3,243.87 µm² |
| Standard-cell utilization | 56.60% |
| Clock constraint | 1.0 ns |
| Reported critical-path delay | 0.7333 ns |
| Reported setup slack | +0.3377 ns |
| Reported hold slack | +0.0997 ns |
| Final setup / hold violations | 0 / 0 |
| Final detailed-routing DRC violations | 0 |
| Estimated total power | 3.877 mW |

Supporting artifacts:

- [Synthesis summary](physical_design/reports/synthesis_summary.txt)
- [Timing summary](physical_design/reports/timing_summary.txt)
- [Physical-design summary](physical_design/reports/physical_design_summary.txt)
- [Final layout screenshot](physical_design/screenshots/layout.png)
- [Timing-path screenshot](physical_design/screenshots/timing_path.png)
- [Final GDS](physical_design/6_final.gds)

These are EDA flow results, not silicon measurements. Power is an estimate that depends on the activity data and modeling assumptions. The physical-design summary records one flow warning; the run should not be described as warning-free. Review the original timing reports when comparing the critical-path delay and slack, since their definitions and analysis contexts may differ.

### Reproducing the physical-design run

`physical_design/config.mk` is an OpenROAD-flow-scripts configuration fragment, not a standalone flow. Its paths expect the RTL and constraint file to be staged in the locations defined by the ORFS design environment.

**Reproduction note:** the constraint file referenced by this configuration is not currently included in this repository. To reproduce the physical-design run, provide the matching `constraint.sdc`, place the RTL and configuration in the expected ORFS design directory, and use a compatible ORFS/Nangate45 environment. Until that constraint file and setup instructions are committed, the reports and GDS should be treated as recorded results rather than a fully self-contained, one-command reproduction package.

## Tools

- SystemVerilog
- Icarus Verilog (`iverilog` / `vvp`) for simulation
- Yosys for synthesis
- OpenROAD-flow-scripts and OpenROAD for physical implementation and timing analysis
- Nangate45 standard-cell platform

## Potential extensions

- Add explicit pointer-wrap logic and tests for non-power-of-two FIFO depths.
- Add formal properties for occupancy bounds, status flags, and accepted read/write transactions.
- Add automated regression scripts or CI that fail when either regression fails.
- Build a separate asynchronous FIFO using Gray-coded pointers and synchronizers to explore clock-domain crossing.

## License

No license file is currently included. Without a license, the repository does not explicitly grant others permission to reuse or redistribute the code. Add a license if you intend to grant those rights.
