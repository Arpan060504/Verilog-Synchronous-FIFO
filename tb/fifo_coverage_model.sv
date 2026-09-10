//==========================================================================
// fifo_coverage_model.sv
//
// NOTE: This file is provided for documentation / portfolio purposes.
// It demonstrates a "real" UVM-style coverage/randomization model using
// SystemVerilog classes, constrained-random `rand` fields, and a
// `covergroup`. Icarus Verilog (used for the runnable regressions in this
// repo) does not implement classes, constraint blocks, or covergroups, so
// this file will NOT compile with `iverilog`.
//
// To actually run it, use a full IEEE1800-2017 simulator such as
// Questa, VCS, Xcelium, or (for partial support) Verilator + a coverage
// front end.
//
// tb/fifo_random_tb.sv is the equivalent, fully-runnable version of this
// idea, using plain $urandom_range() and manual coverage-bin counters so
// it works with the open-source toolchain.
//==========================================================================

class fifo_txn #(int DATA_WIDTH = 8);
    rand bit [DATA_WIDTH-1:0] data;
    rand bit                  write_request;
    rand bit                  read_request;

    // bias toward exercising both requests together and each alone,
    // rather than uniform random (which under-samples simultaneous R/W)
    constraint c_mix {
        write_request dist { 1'b1 := 55, 1'b0 := 45 };
        read_request  dist { 1'b1 := 55, 1'b0 := 45 };
    }
endclass

class fifo_coverage #(int DEPTH = 16);
    int unsigned count;
    bit empty, full, almost_empty, almost_full;
    bit write_request, read_request;

    covergroup cg_fifo;
        cp_count: coverpoint count {
            bins low    = {[0:2]};
            bins mid    = {[3:DEPTH-3]};
            bins high   = {[DEPTH-2:DEPTH]};
        }
        cp_full:  coverpoint full;
        cp_empty: coverpoint empty;
        cp_almost_full:  coverpoint almost_full;
        cp_almost_empty: coverpoint almost_empty;

        cp_req: coverpoint {write_request, read_request} {
            bins idle       = {2'b00};
            bins write_only = {2'b10};
            bins read_only  = {2'b01};
            bins both       = {2'b11};
        }

        // cross the request type against occupancy corners - this is the
        // interesting part: did we ever do simultaneous R/W while full,
        // while empty, and in the normal middle case?
        cross_req_state: cross cp_req, cp_count {
            bins simul_at_full  = binsof(cp_req.both) && binsof(cp_count.high);
            bins simul_at_empty = binsof(cp_req.both) && binsof(cp_count.low);
            bins simul_normal   = binsof(cp_req.both) && binsof(cp_count.mid);
        }
    endgroup

    function new();
        cg_fifo = new();
    endfunction

    function void sample_from(int unsigned count_i, bit empty_i, bit full_i,
                               bit almost_empty_i, bit almost_full_i,
                               bit wr_i, bit rd_i);
        count          = count_i;
        empty          = empty_i;
        full           = full_i;
        almost_empty   = almost_empty_i;
        almost_full    = almost_full_i;
        write_request  = wr_i;
        read_request   = rd_i;
        cg_fifo.sample();
    endfunction
endclass

// Sketch of how this would be wired into an environment on a full
// simulator (driver loop omitted for brevity):
//
//   fifo_txn        txn = new();
//   fifo_coverage    cov = new();
//   ...
//   forever begin
//     void'(txn.randomize());
//     drive_to_dut(txn);
//     @(posedge clk);
//     cov.sample_from(dut.fifo_count, dut.empty, dut.full,
//                      dut.almost_empty, dut.almost_full,
//                      txn.write_request, txn.read_request);
//   end
//   $display("Coverage: %0.2f%%", cov.cg_fifo.get_coverage());