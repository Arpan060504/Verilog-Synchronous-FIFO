# Synchronous FIFO — RTL Design & Verification

A parameterizable, single-clock FIFO in SystemVerilog with a two-tier
verification environment: a directed regression and a self-checking
randomized regression backed by a golden reference model.

## Why this project

A basic FIFO is one of the most common "first project" designs, so what
differentiates this one is the verification approach, not just the RTL:
a golden-model scoreboard, weighted-random stimulus that naturally hits
every corner case (full, empty, simultaneous read/write in all three
occupancy regions, rejected writes/reads), and manual functional coverage
tracking — the same methodology used in industry testbenches, adapted to
run on the open-source Icarus Verilog toolchain.

## Architecture

```
rtl/fifo.sv                 - DUT: parameterizable sync FIFO
tb/fifo_directed_tb.sv       - original hand-written directed regression (24 checks)
tb/fifo_random_tb.sv         - self-checking randomized regression (golden model + coverage)
tb/fifo_coverage_model.sv    - documentation-only: class/covergroup version for full SV sims
Makefile                     - `make directed`, `make random`, `make all`
```

### DUT interface

| Port            | Dir | Width          | Description                                   |
|------------------|-----|-----------------|------------------------------------------------|
| clk, reset       | in  | 1               | synchronous, active-high reset                 |
| data_in          | in  | DATA_WIDTH      | write data                                     |
| write_request    | in  | 1               | write enable                                   |
| read_request     | in  | 1               | read enable                                    |
| data_out         | out | DATA_WIDTH      | read data (registered)                         |
| empty / full     | out | 1               | standard status flags                          |
| almost_empty/full| out | 1               | early-warning flags (parameterizable margin)   |
| data_valid       | out | 1               | pulses one cycle when `data_out` is fresh      |
| overflow         | out | 1               | pulses when a write is rejected (FIFO full)    |
| underflow        | out | 1               | pulses when a read is rejected (FIFO empty)    |
| fifo_count       | out | $clog2(DEPTH)+1 | live occupancy                                 |

Parameters: `DATA_WIDTH` (default 8), `DEPTH` (default 16),
`ALMOST_FULL_MARGIN` / `ALMOST_EMPTY_MARGIN` (default 2).

### Simultaneous read + write policy

| FIFO state | Action on read_request & write_request together |
|---|---|
| empty      | write only (nothing valid to read yet) |
| full       | read only (drains to make room) |
| otherwise  | both — one word out, one word in, occupancy unchanged |

## Verification

### 1. Directed regression (`tb/fifo_directed_tb.sv`)
24 hand-written checks: fill, drain, back-to-back reads, simultaneous R/W
at empty/full/normal occupancy, overflow/underflow rejection.

### 2. Randomized self-checking regression (`tb/fifo_random_tb.sv`)
- Drives `write_request`/`read_request` with independent weighted
  probabilities (55%) each cycle for 4000 cycles, so idle, write-only,
  read-only, and simultaneous cycles all occur frequently.
- A SystemVerilog queue (`mem_model[$]`) acts as a golden reference model,
  implementing the same arbitration policy as the DUT.
- After every clock edge, DUT outputs (`fifo_count`, `empty`, `full`,
  `data_valid`, `data_out`) are compared against the model and any
  mismatch is reported with a cycle-accurate error message.
- Immediate assertions check protocol invariants every cycle (`full` and
  `empty` never both true, `fifo_count` never exceeds `DEPTH`).
- Manual functional-coverage bin counters track how many cycles hit each
  interesting corner (full, empty, almost-full/empty, idle, rejected
  write/read, simultaneous R/W at empty/full/normal).

Latest run (4000 cycles):

```
Errors            : 0
full asserted             : 127
empty asserted            : 152
almost_full asserted      : 639
almost_empty asserted     : 593
idle cycles               : 834
write rejected (full)     : 32
read rejected (empty)     : 35
simul R/W (normal)        : 1077
simul R/W (at full)       : 39
simul R/W (at empty)      : 40
```

Every interesting corner case is hit organically by the weighted-random
stimulus, with zero scoreboard/assertion failures.

### 3. `tb/fifo_coverage_model.sv` — bonus, documentation only
A class-based, constrained-random transaction generator plus a real
`covergroup` with a cross-coverage bin for "simultaneous R/W at each
occupancy corner." **This does not compile under Icarus Verilog** —
Icarus does not implement SystemVerilog classes, `constraint` blocks, or
`covergroup`. It's included to show the equivalent methodology as it
would be written for Questa/VCS/Xcelium, since `fifo_random_tb.sv` is a
functional (if lower-level) stand-in for what that file would do.

## Running it

```bash
# requires Icarus Verilog (iverilog/vvp), e.g. `apt install iverilog`
make directed   # 24-check directed regression
make random     # 4000-cycle randomized regression with scoreboard + coverage
make all         # both
make waves       # generates fifo_test.vcd, view with gtkwave
make clean
```

## Possible extensions

- **Async (dual-clock) FIFO**: Gray-coded read/write pointers with 2-flop
  synchronizers for clock-domain crossing — the natural "part 2" of this
  project and a stronger signal of CDC understanding for interviews.
- **Formal verification**: the invariants already checked by immediate
  assertions (`count <= DEPTH`, `!(full && empty)`) are good candidates
  for SymbiYosys/formal property proofs instead of simulation-only checks.
- Port `fifo_random_tb.sv`'s golden-model idea into a real
  class/covergroup UVM environment once a full SV simulator is available.
