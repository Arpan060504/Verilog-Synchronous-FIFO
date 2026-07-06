# Parameterized Synchronous FIFO in Verilog

A parameterized synchronous FIFO (First-In, First-Out) buffer designed in Verilog RTL and verified using a directed self-checking testbench.

The design uses a single clock domain, circular read/write pointers, occupancy tracking, full and empty status generation, and explicit handling of simultaneous read and write requests.

## Overview

A FIFO stores data in the same order in which it is received:

```text
First In -> First Out
```

This project implements a synchronous FIFO in which all read and write operations occur with respect to the same clock.

The default configuration is:

```text
Data Width : 8 bits
Depth      : 16 entries
```

The RTL is parameterized so that the data width and FIFO depth can be configured for different instances.

## Features

- Parameterized data width
- Parameterized FIFO depth
- Single-clock synchronous operation
- Circular read pointer
- Circular write pointer
- Occupancy counter
- Empty flag generation
- Full flag generation
- Overflow protection
- Underflow protection
- Simultaneous read/write handling
- Directed self-checking testbench
- Waveform verification using GTKWave

## FIFO Architecture

The FIFO consists of:

- Memory array for data storage
- Write pointer for the next write location
- Read pointer for the next read location
- Occupancy counter for tracking stored entries
- Full and empty status logic

Conceptually:

```text
                 +----------------------+
data_in -------->|                      |
                 |      FIFO Memory     |
write_request -->|                      |-----> data_out
                 |                      |
read_request --->|                      |
                 +----------------------+
                      ^            ^
                      |            |
                write_pointer  read_pointer

                 Occupancy Counter
                    |        |
                    v        v
                  empty     full
```

## Parameterization

The FIFO provides default parameters:

```verilog
parameter DATA_WIDTH = 8;
parameter DEPTH = 16;
```

The pointer width can be derived internally from the configured depth:

```verilog
localparam M = $clog2(DEPTH);
```

A parent or wrapper module can override the FIFO configuration during instantiation.

Example:

```verilog
fifo #(
    .DATA_WIDTH(16),
    .DEPTH(32)
) fifo_inst (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .read_request(read_request),
    .write_request(write_request),
    .data_out(data_out),
    .empty(empty),
    .full(full)
);
```

This creates a FIFO with:

```text
Data Width = 16 bits
Depth      = 32 entries
```

The current circular pointer implementation is intended for power-of-two FIFO depths.

## FIFO Operation

### Write Only

When a write request is asserted and the FIFO is not full:

```text
write_request = 1
read_request  = 0
full          = 0
```

The input data is stored at the current write pointer location.

The write pointer advances and the occupancy count increases.

### Read Only

When a read request is asserted and the FIFO is not empty:

```text
read_request  = 1
write_request = 0
empty         = 0
```

The oldest stored entry is transferred to `data_out`.

The read pointer advances and the occupancy count decreases.

### Simultaneous Read and Write

When both requests are asserted during normal occupancy:

```text
read_request  = 1
write_request = 1
```

One entry is read and one entry is written during the same clock cycle.

Therefore:

```text
Occupancy before = N
Occupancy after  = N
```

### Simultaneous Requests While Empty

The implemented boundary policy performs a write-only operation when both requests are asserted while the FIFO is empty.

```text
EMPTY + READ + WRITE -> WRITE ONLY
```

### Simultaneous Requests While Full

The implemented boundary policy performs a read-only operation when both requests are asserted while the FIFO is full.

```text
FULL + READ + WRITE -> READ ONLY
```

## Full and Empty Detection

The occupancy counter tracks the number of valid entries stored in the FIFO.

Empty condition:

```verilog
assign empty = (count == 0);
```

Full condition:

```verilog
assign full = (count == DEPTH);
```

## Overflow Protection

A write-only request is rejected when the FIFO is full.

The testbench fills the FIFO to its configured depth, attempts an additional write using `8'hFF`, and then drains the FIFO while checking the complete expected sequence.

The rejected value does not appear in the drained data sequence.

## Underflow Protection

A read request is rejected when the FIFO is empty.

The testbench verifies that an empty read does not cause the FIFO to leave its empty state.

## Verification

The project includes a directed self-checking Verilog testbench.

The testbench verifies:

- Reset behavior
- Basic write operations
- Basic read operations
- FIFO ordering
- Simultaneous read/write operation
- Full flag assertion
- Write rejection while full
- Complete FIFO drain
- Empty flag assertion
- Read rejection while empty
- Simultaneous read/write request while empty
- Data readback after the empty-boundary case
- Circular pointer wraparound through extended write/read activity

Example simulation output:

```text
PASS: Expected A1, Received a1
PASS: Expected A2, Received a2
PASS: Simultaneous R/W produced A3
PASS: FIFO full flag asserted
PASS: FIFO remained full after rejected write
PASS: Expected A4, Received a4
PASS: Expected A5, Received a5
PASS: Expected A6, Received a6
PASS: Expected B1, Received b1
PASS: Expected C0, Received c0
PASS: Expected C1, Received c1
PASS: Expected C2, Received c2
PASS: Expected C3, Received c3
PASS: Expected C4, Received c4
PASS: Expected C5, Received c5
PASS: Expected C6, Received c6
PASS: Expected C7, Received c7
PASS: Expected C8, Received c8
PASS: Expected C9, Received c9
PASS: Expected CA, Received ca
PASS: Expected CB, Received cb
PASS: FIFO empty flag asserted
PASS: Empty read correctly rejected
PASS: Simultaneous R/W at empty performed write
PASS: Expected D5, Received d5
```

## Project Structure

```text
Verilog-Synchronous-FIFO/
│
├── rtl/
│   └── fifo.v
│
├── tb/
│   └── fifo_tb.v
│
├── docs/
│   └── fifo_waveform.png
│
├── README.md
│
└── .gitignore
```

## Simulation

### Requirements

- Icarus Verilog
- GTKWave

### Compile

From the repository root:

```bash
iverilog -o fifo_sim rtl/fifo.v tb/fifo_tb.v
```

### Run

```bash
vvp fifo_sim
```

The simulation generates:

```text
fifo_test.vcd
```

### Open Waveform

```bash
gtkwave fifo_test.vcd
```

## Waveform

Add the GTKWave screenshot to:

```text
docs/fifo_waveform.png
```

Then display it here:

```markdown
![Synchronous FIFO Waveform](docs/fifo_waveform.png)
```

## Tools Used

- Verilog HDL
- Icarus Verilog
- GTKWave
- Visual Studio Code

## Future Improvements

Possible extensions include:

- Reusable task-based verification
- Randomized transaction generation
- Reference-model scoreboard
- Pass/fail counters
- Almost-full and almost-empty flags
- Configurable threshold flags
- SystemVerilog assertions
- Functional coverage
- Asynchronous FIFO implementation for clock-domain crossing

## Author

**Arpan**

Electrical Engineering undergraduate interested in RTL design, digital hardware, and VLSI.
