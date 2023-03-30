module elasticFifoInner #(parameter INPUTS = 1, OUTPUTS = 1, DATA_IN_SIZE = 32, DATA_OUT_SIZE = 32, FIFO_DEPTH = 8) (
    input clk, rst, 
    input [DATA_IN_SIZE - 1 : 0] data_in, input valid_in, output ready_in,
    output [DATA_OUT_SIZE - 1 : 0] data_out, output valid_out, input ready_out 
);
    wire ReadEn, WriteEn;
    reg[$clog2(FIFO_DEPTH) - 1 : 0] Head = 0, Tail = 0;
    reg Full = 1, Empty = 0, fifo_valid = 0;
    
    reg [DATA_IN_SIZE - 1 : 0] Memory [0 : FIFO_DEPTH];
    
    assign ready_in = ~Full | ready_out;    //Ready if there is space in FIFO or output can be received
    assign ReadEn = ready_out & valid_out; //Read on a legit handshake
    assign valid_out = ~Empty;
    assign data_out = Memory[Head];
    assign WriteEn = valid_in & ready_in; //Write on a legit handshake
    
    always @(posedge clk)begin
        if(rst)
            fifo_valid <= 0;
        else if(ReadEn)
            fifo_valid <= 1;
        else if(ready_out)
            fifo_valid <= 0;
    end 
    
    always @(posedge clk) begin
        if(rst)begin end
        else if(WriteEn)
            Memory[Tail] <= data_in;
    end
    
    //Tail Update
    always@(posedge clk)begin
        if(rst)
            Tail <= 0;
        else if(WriteEn)begin
            if (Tail == FIFO_DEPTH)
                Tail <= 0;
            else
                Tail <= Tail + 1;
            //Tail <= (Tail + 1) % FIFO_DEPTH;
            end
    end
    
    //Head Update
    always@(posedge clk)begin
        if(rst)
            Head <= 0;
        else if(ReadEn) begin
            if (Head == FIFO_DEPTH)
                Head <= 0;
            else
                Head <= Head + 1;
            //Head <= (Head + 1) % FIFO_DEPTH;
            end
    end
    
    //Full Update
    always@(posedge clk)begin
        if(rst)
            Full <= 0;
        else if(WriteEn & ~ReadEn)begin
            if (Tail == FIFO_DEPTH) begin
                if (Head == 0)
                    Full <= 1;
            end else begin
                if ((Tail + 1) == Head)
                    Full <= 1;
            end
            //if((Tail + 1) % FIFO_DEPTH == Head)
            //  Full <= 1;
            end
             else if(~WriteEn & ReadEn)
                    Full <= 0;
    end
    
    //Empty Update
    always@(posedge clk)begin
        if(rst)
            Empty <= 1;
        else if(~WriteEn & ReadEn)begin
            if (Head == FIFO_DEPTH) begin
                if (Tail == 0)
                    Full <= 1;
            end else begin
                if ((Head + 1) == Tail)
                    Full <= 1;
            end
            //if((Head + 1) % FIFO_DEPTH == Tail)
            //  Empty <= 1;
            end
             else if(WriteEn & ~ReadEn)
                    Empty <= 0;
    end
    
endmodule