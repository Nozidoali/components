//----------------------------------------------------------------------- 
//-- BranchGen, version 0.0
//-----------------------------------------------------------------------
//data_out_bus is organized as {out(n), out(n-1), .... out2, out1}
//data_in_bus is organized as {condition, data_in}
module branchGen_node #(parameter INPUTS = 2,
		parameter OUTPUTS = 8,
		parameter DATA_IN_SIZE = 32,
		parameter DATA_OUT_SIZE = 32,
		parameter COND_SIZE = 3)
	(
		input clk,
		input rst,
		input [INPUTS * (DATA_IN_SIZE)- 1 : 0]data_in_bus,
		input [INPUTS - 1 : 0]valid_in_bus,
		output [INPUTS - 1 : 0] ready_in_bus,
		
		output [OUTPUTS * (DATA_OUT_SIZE) - 1 : 0]data_out_bus,
		output reg [OUTPUTS - 1 : 0]valid_out_bus = 0,
		input 	[OUTPUTS - 1 : 0] ready_out_bus
);
	
	integer i = 0;
	
	wire [COND_SIZE - 1 : 0]cond;
	assign cond = data_in_bus[DATA_IN_SIZE +: COND_SIZE];
	
	assign data_out_bus = {(OUTPUTS){data_in_bus[0 * DATA_IN_SIZE +: DATA_IN_SIZE]}};
	
	wire join_valid;
	wire join_ready;
	
	joinC #(.N(2)) join_branch(.valid_in(valid_in_bus), .ready_in(ready_in_bus), 
				    .valid_out(join_valid), .ready_out(join_ready));
					 
	always @(*)begin
		for(i = 0; i < OUTPUTS; i = i + 1)begin
			valid_out_bus[i] = cond == i[COND_SIZE - 1 : 0] ? join_valid : 0;
		end
	end
	
	assign join_ready = ready_out_bus[cond];
	
endmodule


//----------------------------------------------------------------------- 
//-- Distributor, version 0.0
//-----------------------------------------------------------------------

module merge_one_hot #(parameter INPUTS = 3,
		parameter OUTPUTS = 1,
		parameter DATA_IN_SIZE = 32,
		parameter DATA_OUT_SIZE = 32)
		(
		input clk,
		input rst,
		input [INPUTS * (DATA_IN_SIZE)- 1 : 0]data_in_bus,
		input [INPUTS - 1 : 0]valid_in_bus,
		output reg [INPUTS - 1 : 0] ready_in_bus = 0,
		
		output [OUTPUTS * (DATA_OUT_SIZE) - 1 : 0]data_out_bus,
		output [OUTPUTS - 1 : 0]valid_out_bus,
		input 	[OUTPUTS - 1 : 0] ready_out_bus
);
	
	integer i, j;
	
	reg [DATA_IN_SIZE	 - 1 : 0] tehb_data_in = 0;
	reg [DATA_OUT_SIZE - 1 : 0] temp_data_out = 0;
	reg tehb_valid_in, temp_valid_out;
	wire tehb_ready;
	
	always @(*)begin
		temp_data_out = data_in_bus[0 * DATA_IN_SIZE +: DATA_IN_SIZE];
		temp_valid_out = 0;
		
		for(i = INPUTS - 1; i >= 0; i = i - 1)begin
			if(valid_in_bus[i])begin
				temp_data_out = data_in_bus[i * DATA_IN_SIZE +: DATA_IN_SIZE];
				temp_valid_out = 1;
			end
		end
		
		tehb_data_in = temp_data_out;
		tehb_valid_in = temp_valid_out;
	end
	
	reg some_input_valid = 0;
	always @(tehb_ready, valid_in_bus)begin
		some_input_valid = 0;
		for(j = 0; j < INPUTS; j = j + 1)begin
			ready_in_bus[j] = tehb_ready & ~some_input_valid;
			if(valid_in_bus[j])
				some_input_valid = 1;
		end
	end
	
	TEHB #(.INPUTS(1), .OUTPUTS(1), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE)) tehb_merge_one_hot
	(.clk(clk), .rst(rst), .valid_in_bus(tehb_valid_in), .ready_in_bus(tehb_ready), .data_in_bus(tehb_data_in),
								  .valid_out_bus(valid_out_bus), .ready_out_bus(ready_out_bus), .data_out_bus(data_out_bus));
	
endmodule


//data_out_bus is organized as {out(n), out(n-1), .... out2, out1}
//data_in_bus is organized as {condition, data_in}
module distributor_node #(parameter INPUTS = 2,
		parameter OUTPUTS = 8,
		parameter DATA_IN_SIZE = 32,
		parameter DATA_OUT_SIZE = 32,
		parameter COND_SIZE = 3)
	(
		input clk,
		input rst,
		input [INPUTS * (DATA_IN_SIZE)- 1 : 0]data_in_bus,
		input [INPUTS - 1 : 0]valid_in_bus,
		output [INPUTS - 1 : 0] ready_in_bus,
		
		output [OUTPUTS * (DATA_OUT_SIZE) - 1 : 0]data_out_bus,
		output [OUTPUTS - 1 : 0]valid_out_bus,
		input 	[OUTPUTS - 1 : 0] ready_out_bus
);

	wire [DATA_OUT_SIZE * OUTPUTS - 1 : 0] branch_data_out;
	wire [OUTPUTS - 1 : 0] branch_valid_out, branch_ready_out;
	
	branchGen_node #(.INPUTS(INPUTS), .OUTPUTS(OUTPUTS), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE), .COND_SIZE(COND_SIZE)) branchGen_distributor
	(.clk(clk), .rst(rst),
		.valid_in_bus(valid_in_bus), .ready_in_bus(ready_in_bus), .data_in_bus(data_in_bus),
		.valid_out_bus(branch_valid_out), .ready_out_bus(branch_ready_out), .data_out_bus(branch_data_out));

		genvar i;
		generate
			for(i = 0; i < OUTPUTS; i = i + 1)begin : distributor_tehb_generator
				TEHB #(.INPUTS(1), .OUTPUTS(1), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE)) tehb_distributor
		(.clk(clk), .rst(rst), .valid_in_bus(branch_valid_out[i]), .ready_in_bus(branch_ready_out[i]), .data_in_bus(branch_data_out[i * DATA_IN_SIZE +: DATA_IN_SIZE]),
									  .valid_out_bus(valid_out_bus[i]), .ready_out_bus(ready_out_bus[i]), .data_out_bus(data_out_bus[i * DATA_OUT_SIZE +: DATA_OUT_SIZE]));
			end
		endgenerate
endmodule


//----------------------------------------------------------------------- 
//-- selector, version 0.0
//-----------------------------------------------------------------------

module bypassFIFO #(parameter INPUTS = 1,
		parameter OUTPUTS = 1,
		parameter DATA_IN_SIZE = 32,
		parameter DATA_OUT_SIZE = 32,
		parameter FIFO_DEPTH = 128)
	(
		input clk,
		input rst,
		input [INPUTS * (DATA_IN_SIZE)- 1 : 0]data_in_bus,
		input [INPUTS - 1 : 0]valid_in_bus,
		output [INPUTS - 1 : 0] ready_in_bus,
		
		output [OUTPUTS * (DATA_OUT_SIZE) - 1 : 0]data_out_bus,
		output [OUTPUTS - 1 : 0]valid_out_bus,
		input 	[OUTPUTS - 1 : 0] ready_out_bus
);

	wire forwarding;
	wire fifo_valid;
	wire [DATA_IN_SIZE - 1 : 0] fifo_out;
	
	//Forwarding logic
	assign forwarding = ~fifo_valid & valid_in_bus[0];
	assign valid_out_bus[0] = forwarding ? valid_in_bus[0] : fifo_valid;
	assign data_out_bus[0 * DATA_OUT_SIZE +: DATA_OUT_SIZE] = forwarding ? data_in_bus[0 * DATA_IN_SIZE +: DATA_IN_SIZE] : fifo_out;
	
	transpFIFO_node #(.INPUTS(1), .OUTPUTS(1), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE), .FIFO_DEPTH(FIFO_DEPTH)) bypassFIFO_transpFIFO
		(.clk(clk), .rst(rst),
		 .valid_in_bus(valid_in_bus), .ready_in_bus(ready_in_bus), .data_in_bus(data_in_bus), 
		 .valid_out_bus(fifo_valid), .ready_out_bus(ready_out_bus), .data_out_bus(fifo_out));

endmodule


module input_selector #(parameter AMOUNT_OF_BB_IDS = 1, 
								BB_ID_INFO_SIZE = 1,
								BB_COUNT_INFO_SIZE = 1,
								AMOUNT_OF_SHARED_COMPONENT = 1,
								SHARED_COMPONENT_ID_SIZE = 1)
								
							(input clk, rst,  
							input ready_out_bus,
							output valid_out_bus,
							output [SHARED_COMPONENT_ID_SIZE - 1 : 0] data_out_bus,
							//ordering for each BB, constants
							input [AMOUNT_OF_BB_IDS * AMOUNT_OF_SHARED_COMPONENT * SHARED_COMPONENT_ID_SIZE - 1 : 0] bbOrderingData,
							 //info (id and amount) for each B. From MSB to LSB the order is max_amount and then ID
							input [AMOUNT_OF_BB_IDS * (BB_ID_INFO_SIZE  + BB_COUNT_INFO_SIZE) - 1 : 0] bbInfoData,
							input [AMOUNT_OF_BB_IDS - 1 : 0] bbInfoPValid,
							output [AMOUNT_OF_BB_IDS - 1 : 0] bbInfoReady
);

	localparam BB_INFO_SIZE = BB_ID_INFO_SIZE + BB_COUNT_INFO_SIZE;
	
	 wire transaction_at_output;
    wire last_index_reached;
    wire ordering_traversed;

    wire [BB_ID_INFO_SIZE    - 1 : 0] bb_index;
    wire [BB_COUNT_INFO_SIZE - 1 : 0] max_elem_index;

    wire merge_output_valid_array;
    wire merge_output_ready_array;
    wire [BB_INFO_SIZE - 1 : 0] merge_output_data_array;

    wire fifo_output_valid_array;
    wire fifo_output_ready_array;
    wire[BB_INFO_SIZE - 1 : 0] fifo_output_data_array;

    reg [BB_COUNT_INFO_SIZE - 1 : 0]reg_current_index = 0;

	assign transaction_at_output = valid_out_bus & ready_out_bus;
	assign last_index_reached = reg_current_index == max_elem_index;
	assign ordering_traversed = last_index_reached & transaction_at_output;
	
	assign bb_index = fifo_output_data_array[BB_ID_INFO_SIZE - 1 : 0];
	assign max_elem_index = fifo_output_data_array[(BB_INFO_SIZE - 1) : (BB_INFO_SIZE - BB_COUNT_INFO_SIZE)];
	
	assign valid_out_bus = fifo_output_valid_array;
	assign data_out_bus = bbOrderingData[SHARED_COMPONENT_ID_SIZE * AMOUNT_OF_SHARED_COMPONENT * bb_index + SHARED_COMPONENT_ID_SIZE * reg_current_index +: SHARED_COMPONENT_ID_SIZE];
	assign fifo_output_ready_array = ordering_traversed;
	
	always @(posedge clk, posedge rst)begin
		if(rst)
			reg_current_index <= 0;
		else begin
			if(ordering_traversed)
				reg_current_index <= 0;
			else if(transaction_at_output)
				reg_current_index <= reg_current_index + 1;
		end
	end
	
	merge_one_hot #(.INPUTS(AMOUNT_OF_BB_IDS), .OUTPUTS(1), .DATA_IN_SIZE(BB_INFO_SIZE), .DATA_OUT_SIZE(BB_INFO_SIZE)) merge_comp
		(.clk(clk), .rst(rst),
		 .valid_in_bus(bbInfoPValid), .ready_in_bus(bbInfoReady), .data_in_bus(bbInfoData),
		 .valid_out_bus(merge_output_valid_array), .ready_out_bus(merge_output_ready_array), .data_out_bus(merge_output_data_array));
	
	bypassFIFO #(.INPUTS(1), .OUTPUTS(1), .DATA_IN_SIZE(BB_INFO_SIZE), .DATA_OUT_SIZE(BB_INFO_SIZE), .FIFO_DEPTH(128)) fifo_comp
		(.clk(clk), .rst(rst),
		 .valid_in_bus(merge_output_valid_array), .ready_in_bus(merge_output_ready_array), .data_in_bus(merge_output_data_array),
		 .valid_out_bus(fifo_output_valid_array), .ready_out_bus(fifo_output_ready_array), .data_out_bus(fifo_output_data_array));
	
endmodule



module selector_node #(parameter INPUTS = 8, OUTPUTS = 3, COND_SIZE = 3, DATA_IN_SIZE = 32, DATA_OUT_SIZE = 32,
									 AMOUNT_OF_BB_IDS = 2, AMOUNT_OF_SHARED_COMPONENT = 2, BB_ID_INFO_SIZE = 1, BB_COUNT_INFO_SIZE = 1)
						(input clk,
						input rst,
						input [INPUTS * (DATA_IN_SIZE)- 1 : 0]data_in_bus,
						input [INPUTS - 1 : 0]valid_in_bus,
						output reg [INPUTS - 1 : 0] ready_in_bus = 0,
						
						output [OUTPUTS * (DATA_OUT_SIZE) - 1 : 0]data_out_bus,//Condition is merged with data_out_array
						output [OUTPUTS - 1 : 0]valid_out_bus,
						input 	[OUTPUTS - 1 : 0] ready_out_bus,
						
						//ordering for each BB, constants
						input [AMOUNT_OF_BB_IDS * AMOUNT_OF_SHARED_COMPONENT * COND_SIZE - 1 : 0] bbOrderingData,
					       //info (id and amount) for each B. From MSB to LSB the order is max_amount and then ID
						input [AMOUNT_OF_BB_IDS * (BB_ID_INFO_SIZE  + BB_COUNT_INFO_SIZE) - 1 : 0] bbInfoData,
						input [AMOUNT_OF_BB_IDS - 1 : 0] bbInfoPValid,
						output [AMOUNT_OF_BB_IDS - 1 : 0] bbInfoReady
						);

			 wire nReadyArray_input_selector;
			 wire validArray_input_selector;
			 wire [COND_SIZE - 1 : 0] dataOutArray_input_selector;

			 wire [2 : 0]nReadyArray_fork; //Why hardcoded?
			 wire [2 : 0]validArray_fork;
			 wire [3 * COND_SIZE - 1 : 0] dataOutArray_fork;

			 reg [(INPUTS / 2) * DATA_IN_SIZE - 1 : 0] dataInArray_left_mux = 0;
			 wire [COND_SIZE - 1 : 0] condition_left_mux;
			 wire [(INPUTS / 2) : 0] readyArray_left_mux;
			 reg [(INPUTS / 2) : 0] pValidArray_left_mux = 0;

			 reg [(INPUTS / 2) * DATA_IN_SIZE - 1 : 0] dataInArray_right_mux = 0;
			 wire [COND_SIZE - 1 : 0] condition_right_mux;
			 wire [(INPUTS / 2) : 0]readyArray_right_mux;
			 reg [(INPUTS / 2) : 0]pValidArray_right_mux = 0;
			 
			 wire [COND_SIZE - 1 : 0] condition;

			//Carmine 07.04.22 the conditon inputs should be padded with 0s when given to the muxes
			 wire [DATA_IN_SIZE - COND_SIZE - 1 : 0] cond_remaining_pins = 0;

			 integer i;
			
		always @(*)
			for(i = 0; i < INPUTS / 2; i = i + 1)begin
				dataInArray_left_mux[i * DATA_IN_SIZE +: DATA_IN_SIZE] = data_in_bus[2 * i * DATA_IN_SIZE +: DATA_IN_SIZE];
				pValidArray_left_mux[i + 1] = valid_in_bus[2 * i];
				ready_in_bus[2 * i] = readyArray_left_mux[i + 1];
				pValidArray_left_mux[0] = validArray_fork[0];
				
				dataInArray_right_mux[i * DATA_IN_SIZE +: DATA_IN_SIZE] = data_in_bus[(2*i + 1) * DATA_IN_SIZE +: DATA_IN_SIZE];
				pValidArray_right_mux[i + 1] = valid_in_bus[2 * i + 1];
				ready_in_bus[2 * i + 1] = readyArray_right_mux[i + 1];
				pValidArray_right_mux[0] = validArray_fork[1];
			end
		

		assign condition_left_mux = dataOutArray_fork[0 * COND_SIZE +: COND_SIZE];
		assign nReadyArray_fork[0] = readyArray_left_mux[0];
		
		assign condition_right_mux = dataOutArray_fork[1 * COND_SIZE +: COND_SIZE];
		assign nReadyArray_fork[1] = readyArray_right_mux[0];
		
		assign condition = dataOutArray_fork[2 * COND_SIZE +: COND_SIZE];
		assign valid_out_bus[2] = validArray_fork[2];
		assign nReadyArray_fork[2] = ready_out_bus[2];
		assign data_out_bus[(OUTPUTS - 1) * DATA_OUT_SIZE +: DATA_OUT_SIZE] = condition;
		
		input_selector #(.AMOUNT_OF_BB_IDS(AMOUNT_OF_BB_IDS), .BB_ID_INFO_SIZE(BB_ID_INFO_SIZE), .BB_COUNT_INFO_SIZE(BB_COUNT_INFO_SIZE), .AMOUNT_OF_SHARED_COMPONENT(AMOUNT_OF_SHARED_COMPONENT), .SHARED_COMPONENT_ID_SIZE(COND_SIZE)) input_selector_selector
			(.clk(clk), .rst(rst),
			 .valid_out_bus(validArray_input_selector), .ready_out_bus(nReadyArray_input_selector), .data_out_bus(dataOutArray_input_selector),
			 .bbOrderingData(bbOrderingData),
			 .bbInfoData(bbInfoData),
			 .bbInfoPValid(bbInfoPValid),
			 .bbInfoReady(bbInfoReady)
			 );
		
		fork_node #(.INPUTS(1), .OUTPUTS(3), .DATA_IN_SIZE(COND_SIZE), .DATA_OUT_SIZE(COND_SIZE)) selector_fork
			(.clk(clk), .rst(rst),
			 .valid_in_bus(validArray_input_selector), .ready_in_bus(nReadyArray_input_selector), .data_in_bus(dataOutArray_input_selector),
			 .valid_out_bus(validArray_fork), .ready_out_bus(nReadyArray_fork), .data_out_bus(dataOutArray_fork)
			);
			
		mux_node #(.INPUTS(INPUTS / 2 + 1), .OUTPUTS(1), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE), .COND_SIZE(COND_SIZE)) left_mux
			(.clk(clk), .rst(rst),
			 .data_in_bus({cond_remaining_pins, condition_left_mux, dataInArray_left_mux}), .valid_in_bus(pValidArray_left_mux), .ready_in_bus(readyArray_left_mux),
			 .data_out_bus(data_out_bus[0 * DATA_OUT_SIZE +: DATA_OUT_SIZE]), .valid_out_bus(valid_out_bus[0]), .ready_out_bus(ready_out_bus[0])
			);

			
		mux_node #(.INPUTS(INPUTS / 2 + 1), .OUTPUTS(1), .DATA_IN_SIZE(DATA_IN_SIZE), .DATA_OUT_SIZE(DATA_OUT_SIZE), .COND_SIZE(COND_SIZE)) right_mux
			(.clk(clk), .rst(rst),
			 .data_in_bus({cond_remaining_pins, condition_right_mux, dataInArray_left_mux}), .valid_in_bus(pValidArray_right_mux), .ready_in_bus(readyArray_right_mux),
			 .data_out_bus(data_out_bus[1 * DATA_OUT_SIZE +: DATA_OUT_SIZE]), .valid_out_bus(valid_out_bus[1]), .ready_out_bus(ready_out_bus[1])
			);
endmodule











