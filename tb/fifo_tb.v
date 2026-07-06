module fifo_tb;

parameter DATA_WIDTH = 8;
parameter DEPTH = 16;

reg clk, reset;
reg read_request, write_request;
reg [DATA_WIDTH-1:0] data_in;

wire [DATA_WIDTH-1:0] data_out;
wire full, empty;


// DUT
fifo fifo_test (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .read_request(read_request),
    .write_request(write_request),
    .data_out(data_out),
    .empty(empty),
    .full(full)
);

// Clock
initial
begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial
begin
    reset         = 1;
    read_request  = 0;
    write_request = 0;
    data_in       = 0;

    #12;
    reset = 0;

    // TEST 1: WRITE A1 TO A6
    #10;
    write_request = 1;
    data_in = 8'hA1;

    #10; data_in = 8'hA2;
    #10; data_in = 8'hA3;
    #10; data_in = 8'hA4;
    #10; data_in = 8'hA5;
    #10; data_in = 8'hA6;

    #10;
    write_request = 0;
    // ------------------------------------------------
    // TEST 2: READ FIRST DATA -> EXPECT A1
    // ------------------------------------------------
    #10;
    read_request = 1;
    #10;
    read_request = 0;
    if(data_out == 8'hA1)
        $display("PASS: Expected A1, Received %h", data_out);
    else
        $display("FAIL: Expected A1, Received %h", data_out);


    // ------------------------------------------------
    // TEST 3: READ SECOND DATA -> EXPECT A2
    // ------------------------------------------------
    #10;
    read_request = 1;

    #10;
    read_request = 0;
    if(data_out == 8'hA2)
        $display("PASS: Expected A2, Received %h", data_out);
    else
        $display("FAIL: Expected A2, Received %h", data_out);


    // ------------------------------------------------
    // TEST 4: SIMULTANEOUS READ + WRITE
    //
    // Current FIFO contains:
    // A3 A4 A5 A6
    //
    // Read should produce A3
    // Write should insert B1
    // Count should remain unchanged
    // ------------------------------------------------
    #10;
    data_in       = 8'hB1;
    read_request  = 1;
    write_request = 1;

    #10;
    read_request  = 0;
    write_request = 0;

    if(data_out == 8'hA3)
        $display("PASS: Simultaneous R/W produced A3");
    else
        $display("FAIL: Simultaneous R/W expected A3, Received %h",
                 data_out);


    // ------------------------------------------------
    // TEST 5: FILL FIFO TO FULL
    //
    // Current occupancy = 4
    // Current data:
    // A4 A5 A6 B1
    //
    // Need 12 more writes to reach DEPTH = 16
    // ------------------------------------------------
    #10;  write_request = 1; data_in = 8'hC0;
    #10; data_in = 8'hC1;
    #10; data_in = 8'hC2;
    #10; data_in = 8'hC3;
    #10; data_in = 8'hC4;
    #10; data_in = 8'hC5;
    #10; data_in = 8'hC6;
    #10; data_in = 8'hC7;
    #10; data_in = 8'hC8;
    #10; data_in = 8'hC9;
    #10; data_in = 8'hCA;
    #10; data_in = 8'hCB;

    #10;
    write_request = 0;

    // Check FULL flag
    if(full == 1'b1)
        $display("PASS: FIFO full flag asserted");
    else
        $display("FAIL: FIFO full flag not asserted");

    // TEST 6: WRITE ATTEMPT WHILE FULL
    //
    // FF must be rejected
    // ------------------------------------------------
    #10;
    data_in       = 8'hFF;
    write_request = 1;
    #10;
    write_request = 0;

    if(full == 1'b1)
        $display("PASS: FIFO remained full after rejected write");
    else
        $display("FAIL: FIFO full flag changed after overflow attempt");


    // ------------------------------------------------
    // TEST 7: DRAIN FIFO
    //
    // Expected remaining order:
    //
    // A4 A5 A6 B1
    // C0 C1 C2 C3
    // C4 C5 C6 C7
    // C8 C9 CA CB
    //
    // ------------------------------------------------

    #10;
    read_request = 1;

    #10;
    if(data_out == 8'hA4)
        $display("PASS: Expected A4, Received %h", data_out);
    else
        $display("FAIL: Expected A4, Received %h", data_out);

    #10;
    if(data_out == 8'hA5)
        $display("PASS: Expected A5, Received %h", data_out);
    else
        $display("FAIL: Expected A5, Received %h", data_out);

    #10;
    if(data_out == 8'hA6)
        $display("PASS: Expected A6, Received %h", data_out);
    else
        $display("FAIL: Expected A6, Received %h", data_out);

    #10;
    if(data_out == 8'hB1)
        $display("PASS: Expected B1, Received %h", data_out);
    else
        $display("FAIL: Expected B1, Received %h", data_out);

    #10;
    if(data_out == 8'hC0)
        $display("PASS: Expected C0, Received %h", data_out);
    else
        $display("FAIL: Expected C0, Received %h", data_out);

    #10;
    if(data_out == 8'hC1)
        $display("PASS: Expected C1, Received %h", data_out);
    else
        $display("FAIL: Expected C1, Received %h", data_out);

    #10;
    if(data_out == 8'hC2)
        $display("PASS: Expected C2, Received %h", data_out);
    else
        $display("FAIL: Expected C2, Received %h", data_out);

    #10;
    if(data_out == 8'hC3)
        $display("PASS: Expected C3, Received %h", data_out);
    else
        $display("FAIL: Expected C3, Received %h", data_out);

    #10;
    if(data_out == 8'hC4)
        $display("PASS: Expected C4, Received %h", data_out);
    else
        $display("FAIL: Expected C4, Received %h", data_out);

    #10;
    if(data_out == 8'hC5)
        $display("PASS: Expected C5, Received %h", data_out);
    else
        $display("FAIL: Expected C5, Received %h", data_out);

    #10;
    if(data_out == 8'hC6)
        $display("PASS: Expected C6, Received %h", data_out);
    else
        $display("FAIL: Expected C6, Received %h", data_out);

    #10;
    if(data_out == 8'hC7)
        $display("PASS: Expected C7, Received %h", data_out);
    else
        $display("FAIL: Expected C7, Received %h", data_out);

    #10;
    if(data_out == 8'hC8)
        $display("PASS: Expected C8, Received %h", data_out);
    else
        $display("FAIL: Expected C8, Received %h", data_out);

    #10;
    if(data_out == 8'hC9)
        $display("PASS: Expected C9, Received %h", data_out);
    else
        $display("FAIL: Expected C9, Received %h", data_out);

    #10;
    if(data_out == 8'hCA)
        $display("PASS: Expected CA, Received %h", data_out);
    else
        $display("FAIL: Expected CA, Received %h", data_out);

    #10;
    if(data_out == 8'hCB)
        $display("PASS: Expected CB, Received %h", data_out);
    else
        $display("FAIL: Expected CB, Received %h", data_out);

    #10;
    read_request = 0;


    // ------------------------------------------------
    // TEST 8: CHECK EMPTY FLAG
    // ------------------------------------------------
    if(empty == 1'b1)
        $display("PASS: FIFO empty flag asserted");
    else
        $display("FAIL: FIFO empty flag not asserted");


    // ------------------------------------------------
    // TEST 9: READ ATTEMPT WHILE EMPTY
    // ------------------------------------------------
    #10;
    read_request = 1;

    #10;
    read_request = 0;

    if(empty == 1'b1)
        $display("PASS: Empty read correctly rejected");
    else
        $display("FAIL: FIFO changed state after empty read");


    // ------------------------------------------------
    // TEST 10: BOTH HIGH WHILE EMPTY
    //
    // Your RTL policy:
    // EMPTY + READ + WRITE -> WRITE ONLY
    // ------------------------------------------------
    #10;
    data_in       = 8'hD5;
    read_request  = 1;
    write_request = 1;

    #10;
    read_request  = 0;
    write_request = 0;

    if(empty == 1'b0)
        $display("PASS: Simultaneous R/W at empty performed write");
    else
        $display("FAIL: Simultaneous R/W at empty failed");


    // Read back D5
    #10;
    read_request = 1;

    #10;
    read_request = 0;

    if(data_out == 8'hD5)
        $display("PASS: Expected D5, Received %h", data_out);
    else
        $display("FAIL: Expected D5, Received %h", data_out);


    // ------------------------------------------------
    // FINAL RESULT
    // ------------------------------------------------
    #20;

    $display("----------------------------------------");
    $display("FIFO DIRECTED TESTBENCH FINISHED");
    $display("----------------------------------------");

    $finish;
end


// Waveform dump
initial
begin
    $dumpfile("fifo_test.vcd");
    $dumpvars(0, fifo_tb);
end


// Monitor
initial
begin
    $monitor(
        "T=%0t | reset=%b | WR=%b RD=%b | din=%h dout=%h | empty=%b full=%b",
        $time,
        reset,
        write_request,
        read_request,
        data_in,
        data_out,
        empty,
        full
    );
end

endmodule