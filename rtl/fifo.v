module fifo(clk , reset , data_in   , read_request , write_request,  data_out , empty , full);
parameter DATA_WIDTH = 8;
parameter DEPTH = 16;

localparam M = $clog2(DEPTH);

input clk, reset;
input read_request, write_request;
input [DATA_WIDTH-1:0] data_in;

output reg [DATA_WIDTH-1:0] data_out;
output full, empty;

reg [M-1:0] read_pointer;
reg [M-1:0] write_pointer;

reg [M:0] count;

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

assign empty = (count == 0);
assign full  = (count == DEPTH);

always @(posedge clk ) 
begin
    if(reset)
    begin
        read_pointer <= 0;
        write_pointer <=  0;
        count <= 0;
        data_out <=  0;
    end
    else
    begin
        if(write_request == 1 && read_request == 0 && full!= 1)
        begin
            mem[write_pointer] <= data_in;
            write_pointer <= write_pointer +1 ;
            count <= count + 1 ;
        end

        else if(read_request == 1 && write_request == 0  && empty!= 1)
        begin
            data_out <= mem[read_pointer];
            read_pointer <= read_pointer +1 ;
            count <= count - 1 ;
        end
        
        else if(read_request == 1 && write_request == 1)
        begin
            if(empty)
            begin
                mem[write_pointer] <= data_in;
                write_pointer <= write_pointer + 1;
                count <= count + 1;
            end
            else if(full)
            begin
                data_out <= mem[read_pointer];
                read_pointer <= read_pointer + 1;
                count <= count - 1;
            end
            else  
            begin  
                mem[write_pointer] <= data_in;
                write_pointer <= write_pointer + 1;
                data_out <= mem[read_pointer];
                read_pointer <= read_pointer + 1;
            end
        end

    end    
end
endmodule