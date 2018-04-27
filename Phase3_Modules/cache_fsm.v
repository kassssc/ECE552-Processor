module cache_fill_FSM (
	input clk,
	input rst,
	input miss_detected, // active high when tag match logic detects a miss
	input memory_data_valid, // active high indicates valid data returning on memory bus
	input[15:0] miss_addr, // address that missed the cache

	output write_tag_array, // write enable to cache tag array to write tag and valid bit once all words are filled in to data array
	output fsm_busy, // asserted while FSM is busy handling the miss (can be used as pipeline stall signal)

	output mem_read,
	output[15:0] mem_read_addr, // address to read from memory

	output write_data_array, // write enable to cache data array to signal when filling with memory_data
	output[3:0] cache_write_block_offset, // offsets from miss addr

	output[15:0] base_addr
);

wire [3:0] read_block_offset_new, read_block_offset_curr, cache_write_block_offset_new, cache_write_block_offset_curr;
wire [3:0] block_offset_curr, block_offset_new;
wire [15:0] read_block_offset_16b;
wire finish_cache_write, finish_mem_read;
wire [15:0] base_address;
wire fsm_busy_curr;

assign base_addr = base_address;

// Is it currently busy? if yes and not finished waitinf for mem latency, it stays busy, otherwise busy if cache miss
assign fsm_busy_new = fsm_busy_curr? (~finish_cache_write) : miss_detected;
// Store the current state of the cache "is it busy transferring data from mem?"
dff state_fsm_busy (
	.d(fsm_busy_new),
	.q(fsm_busy_curr),
	.wen(1'b1),
	.clk(clk),
	.rst(rst)
);

// Stores the base address of the block, the offset adds to this address
reg_16b mem_addr (
	.reg_new(miss_addr[15:0]),
	.reg_current(base_address[15:0]),
	.wen(~fsm_busy_curr & miss_detected),
	.clk(clk),
	.rst(rst | finish_cache_write)
);

//******************************************************************************
// READ FROM MEM ADDR
//******************************************************************************
// sign extend block offset to 16b
assign read_block_offset_16b = {{12{1'b0}}, read_block_offset_curr[3:0]};
// Persistent storage of the current offset being added to the base addr when transferring data
reg_4b read_block_offset_counter (
	.reg_new(read_block_offset_new[3:0]),
	.reg_current(read_block_offset_curr[3:0]),
	.wen(fsm_busy_curr & ~finish_mem_read),
	.clk(clk),
	.rst(rst | finish_cache_write)// reset when data transfer done
);
// Adds 2 to the block offset every cycle, reset to 0 when data transfer done
full_adder_4b block_offset_adder (
	.A(block_offset_curr[3:0]),	.B(4'b0010), .cin(1'b0),
	.S(block_offset_new[3:0]),	.cout(finish_mem_read)
);
// adds the offset to the base block addr
CLA_16b addsub_16b (
	.A(base_address[15:0]),		.B(read_block_offset_16b[15:0]),	.sub(1'b0),
	.S(mem_read_addr[15:0]),	.ovfl(), .neg()
);
assign mem_read = ~finish_mem_read;

//******************************************************************************
// WRITE TO CACHE INDEX
//******************************************************************************
// Persistent storage of the current offset being added to the base addr when transferring data
reg_4b cache_write_block_offset_counter (
	.reg_new(cache_write_block_offset_new[3:0]),
	.reg_current(cache_write_block_offset_curr[3:0]),
	.wen(write_data_array),
	.clk(clk),
	.rst(rst | finish_cache_write)// reset when data transfer done
);
// Adds 2 to the block offset every cycle, reset to 0 when data transfer done
full_adder_4b write_cache_block_offset_adder (
	.A(cache_write_block_offset_curr[3:0]),	.B(4'b0010), .cin(1'b0),
	.S(cache_write_block_offset_new[3:0]),	.cout(finish_cache_write)
);

assign cache_write_block_offset = cache_write_block_offset_curr[3:0];

assign fsm_busy = fsm_busy_curr;
assign write_data_array = fsm_busy_curr & memory_data_valid;
assign write_tag_array = fsm_busy_curr & finish_cache_write;

endmodule