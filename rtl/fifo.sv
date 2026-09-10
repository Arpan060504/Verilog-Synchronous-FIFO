//==========================================================================
// fifo.sv
// Synchronous, single-clock FIFO
//
// Policy for simultaneous read_request + write_request (same cycle):
//   - FIFO empty  -> perform WRITE only (nothing to read yet)
//   - FIFO full   -> perform READ only  (drain to make room)
//   - otherwise   -> perform BOTH (count stays the same)
//
// Extra status outputs beyond a "textbook" FIFO:
//   almost_full / almost_empty : early-warning flags, margin is parameterized
//   data_valid                 : pulses for one cycle when data_out is fresh
//   overflow / underflow       : pulses for one cycle when a request is
//                                 rejected (write while full / read while empty)
//   fifo_count                 : live occupancy, handy for debug/monitors
//==========================================================================
module fifo #(
    parameter int DATA_WIDTH        = 8,
    parameter int DEPTH             = 16,
    parameter int ALMOST_FULL_MARGIN  = 2,   // almost_full when count >= DEPTH-MARGIN
    parameter int ALMOST_EMPTY_MARGIN = 2    // almost_empty when count <= MARGIN
) (
    input  logic                   clk,
    input  logic                   reset,          // synchronous, active-high
    input  logic [DATA_WIDTH-1:0]  data_in,
    input  logic                   read_request,
    input  logic                   write_request,

    output logic [DATA_WIDTH-1:0]  data_out,
    output logic                   empty,
    output logic                   full,
    output logic                   almost_empty,
    output logic                   almost_full,
    output logic                   data_valid,
    output logic                   overflow,
    output logic                   underflow,
    output logic [$clog2(DEPTH):0] fifo_count
);

    localparam int PTR_W = $clog2(DEPTH);

    logic [PTR_W-1:0]      read_pointer, write_pointer;
    logic [PTR_W:0]        count;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic do_write, do_read;

    // ---------------- status flags (combinational) ----------------
    assign empty       = (count == 0);
    assign full         = (count == DEPTH);
    assign almost_empty = !empty && (count <= ALMOST_EMPTY_MARGIN[PTR_W:0]);
    assign almost_full  = !full  && (count >= (DEPTH - ALMOST_FULL_MARGIN));
    assign fifo_count   = count;

    // ---------------- action decode ----------------
    // Mirrors the read/write arbitration policy described above.
    always_comb begin
        do_write = 1'b0;
        do_read  = 1'b0;

        if (write_request && !read_request) begin
            do_write = !full;
        end else if (read_request && !write_request) begin
            do_read = !empty;
        end else if (read_request && write_request) begin
            if (empty) begin
                do_write = 1'b1;
            end else if (full) begin
                do_read = 1'b1;
            end else begin
                do_write = 1'b1;
                do_read  = 1'b1;
            end
        end
    end

    // ---------------- sequential logic ----------------
    always_ff @(posedge clk) begin
        if (reset) begin
            read_pointer  <= '0;
            write_pointer <= '0;
            count         <= '0;
            data_out      <= '0;
            data_valid    <= 1'b0;
            overflow      <= 1'b0;
            underflow     <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            overflow   <= 1'b0;
            underflow  <= 1'b0;

            if (do_write) begin
                mem[write_pointer] <= data_in;
                write_pointer      <= write_pointer + 1'b1;
            end

            if (do_read) begin
                data_out     <= mem[read_pointer];
                read_pointer <= read_pointer + 1'b1;
                data_valid   <= 1'b1;
            end

            case ({do_write, do_read})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count; // 00 (idle) or 11 (simultaneous, net zero)
            endcase

            // A request is "rejected" only in the pure single-request case;
            // the simultaneous full->read-only / empty->write-only cases are
            // by design, not errors.
            if (write_request && !read_request && full)  overflow  <= 1'b1;
            if (read_request  && !write_request && empty) underflow <= 1'b1;
        end
    end

endmodule