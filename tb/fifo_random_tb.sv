//==========================================================================
// fifo_random_tb.sv
//
// Self-checking, randomized regression for the fifo DUT.
//
// Strategy:
//   - A behavioral "golden model" (a SystemVerilog queue, mem_model[$])
//     mirrors the exact arbitration policy of the DUT.
//   - Every cycle we randomly drive read_request/write_request/data_in
//     with weighted probabilities, then update the golden model the same
//     way the DUT is expected to, and compare after each clock edge.
//   - Functional coverage is tracked manually (bin counters) since Icarus
//     Verilog does not implement SystemVerilog covergroups/constraints.
//     See tb/fifo_coverage_model.sv for the "real" covergroup version,
//     written for simulators with full IEEE1800 support (Questa/VCS/Xcelium).
//   - Immediate assertions catch protocol violations (count out of range,
//     full+empty simultaneously, data mismatch) as soon as they occur.
//==========================================================================
`timescale 1ns/1ps

module fifo_random_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int NUM_CYCLES = 4000;

    logic                   clk, reset;
    logic                   read_request, write_request;
    logic [DATA_WIDTH-1:0]  data_in;

    logic [DATA_WIDTH-1:0]  data_out;
    logic                   empty, full, almost_empty, almost_full;
    logic                   data_valid, overflow, underflow;
    logic [$clog2(DEPTH):0] fifo_count;

    int  errors       = 0;
    int  checks       = 0;
    int  writes_done   = 0;
    int  reads_done    = 0;

    // ---- manual functional coverage bins -----------------------------
    int cov_full          = 0;
    int cov_empty         = 0;
    int cov_almost_full   = 0;
    int cov_almost_empty  = 0;
    int cov_simul_normal  = 0;  // simultaneous R/W, neither full nor empty
    int cov_simul_at_full = 0;  // simultaneous R/W while full
    int cov_simul_at_empty= 0;  // simultaneous R/W while empty
    int cov_rej_write     = 0;  // write rejected (full)
    int cov_rej_read      = 0;  // read rejected (empty)
    int cov_idle          = 0;  // neither request asserted

    // reference model
    bit [DATA_WIDTH-1:0] mem_model [$];

    // DUT
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk), .reset(reset),
        .data_in(data_in), .read_request(read_request), .write_request(write_request),
        .data_out(data_out), .empty(empty), .full(full),
        .almost_empty(almost_empty), .almost_full(almost_full),
        .data_valid(data_valid), .overflow(overflow), .underflow(underflow),
        .fifo_count(fifo_count)
    );

    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- stimulus + scoreboard ----------------------------------------
    initial begin
        bit expect_write, expect_read;
        bit [DATA_WIDTH-1:0] expected_data_out;
        bit expect_valid;

        reset         = 1;
        read_request  = 0;
        write_request = 0;
        data_in       = 0;
        mem_model.delete();

        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk); // let reset settle one more edge before driving

        for (int cyc = 0; cyc < NUM_CYCLES; cyc++) begin
            // ---- weighted random stimulus ----
            // ~55% write-leaning, ~55% read-leaning (independent), so
            // idle / write-only / read-only / simultaneous all occur often,
            // and full/empty corners get hit naturally over many cycles.
            write_request = ($urandom_range(0, 99) < 55);
            read_request  = ($urandom_range(0, 99) < 55);
            data_in       = $urandom_range(0, (1 << DATA_WIDTH) - 1);

            // ---- predict golden-model action (mirrors DUT policy) ----
            expect_write = 1'b0;
            expect_read  = 1'b0;
            if (write_request && !read_request) begin
                expect_write = (mem_model.size() < DEPTH);
            end else if (read_request && !write_request) begin
                expect_read = (mem_model.size() != 0);
            end else if (read_request && write_request) begin
                if (mem_model.size() == 0) expect_write = 1'b1;
                else if (mem_model.size() == DEPTH) expect_read = 1'b1;
                else begin
                    expect_write = 1'b1;
                    expect_read  = 1'b1;
                end
            end

            // ---- coverage bookkeeping (sampled pre-edge, on current state) ----
            if (full)                                   cov_full++;
            if (empty)                                  cov_empty++;
            if (almost_full)                             cov_almost_full++;
            if (almost_empty)                            cov_almost_empty++;
            if (!write_request && !read_request)         cov_idle++;
            if (write_request && !read_request && full)  cov_rej_write++;
            if (read_request && !write_request && empty) cov_rej_read++;
            if (read_request && write_request) begin
                if (mem_model.size() == 0)        cov_simul_at_empty++;
                else if (mem_model.size() == DEPTH) cov_simul_at_full++;
                else                                cov_simul_normal++;
            end

            expected_data_out = expect_read ? mem_model[0] : data_out;
            expect_valid      = expect_read;

            // ---- apply predicted action to the golden model ----
            if (expect_write) begin
                mem_model.push_back(data_in);
                writes_done++;
            end
            if (expect_read) begin
                void'(mem_model.pop_front());
                reads_done++;
            end

            @(posedge clk);
            #1; // let non-blocking assignments settle

            checks++;

            // ---- compare DUT vs golden model ----
            if (fifo_count !== mem_model.size()) begin
                errors++;
                $display("[%0t] ERROR: count mismatch. DUT=%0d MODEL=%0d",
                          $time, fifo_count, mem_model.size());
            end
            if (empty !== (mem_model.size() == 0)) begin
                errors++;
                $display("[%0t] ERROR: empty flag mismatch", $time);
            end
            if (full !== (mem_model.size() == DEPTH)) begin
                errors++;
                $display("[%0t] ERROR: full flag mismatch", $time);
            end
            if (data_valid !== expect_valid) begin
                errors++;
                $display("[%0t] ERROR: data_valid mismatch. DUT=%0b expected=%0b",
                          $time, data_valid, expect_valid);
            end
            if (expect_valid && (data_out !== expected_data_out)) begin
                errors++;
                $display("[%0t] ERROR: data_out mismatch. DUT=%0h expected=%0h",
                          $time, data_out, expected_data_out);
            end

            // ---- immediate assertions: protocol invariants ----
            assert (!(full && empty))
                else begin errors++; $display("[%0t] ASSERTION FAIL: full and empty both asserted", $time); end
            assert (fifo_count <= DEPTH)
                else begin errors++; $display("[%0t] ASSERTION FAIL: count %0d exceeds DEPTH", $time, fifo_count); end
        end

        // ---- final report ----
        $display("==========================================================");
        $display(" RANDOM REGRESSION COMPLETE");
        $display(" Cycles run        : %0d", NUM_CYCLES);
        $display(" Checks performed  : %0d", checks);
        $display(" Writes committed  : %0d", writes_done);
        $display(" Reads committed   : %0d", reads_done);
        $display(" Errors            : %0d", errors);
        $display("----------------------------------------------------------");
        $display(" FUNCTIONAL COVERAGE (cycle counts, manual bins)");
        $display("   full asserted             : %0d", cov_full);
        $display("   empty asserted            : %0d", cov_empty);
        $display("   almost_full asserted      : %0d", cov_almost_full);
        $display("   almost_empty asserted     : %0d", cov_almost_empty);
        $display("   idle cycles               : %0d", cov_idle);
        $display("   write rejected (full)     : %0d", cov_rej_write);
        $display("   read rejected (empty)     : %0d", cov_rej_read);
        $display("   simul R/W (normal)        : %0d", cov_simul_normal);
        $display("   simul R/W (at full)       : %0d", cov_simul_at_full);
        $display("   simul R/W (at empty)      : %0d", cov_simul_at_empty);
        $display("==========================================================");

        if (errors == 0) $display("RESULT: ALL CHECKS PASSED");
        else              $display("RESULT: %0d ERRORS FOUND", errors);

        $finish;
    end

    // safety timeout
    initial begin
        #(NUM_CYCLES * 20 + 1000);
        $display("ERROR: TIMEOUT - simulation did not finish");
        $finish;
    end

endmodule