module cpu(
	input clk,
	input rst_n,
	output hlt,
	output [15:0] pc
);

wire rst, stall, flush;
wire [1:0] fwd_alu_A, fwd_alu_B;
wire WB_RegWrite;
wire [15:0] WB_reg_write_data, WB_reg_write_select;
wire EX_Branch;
assign rst = ~rst_n;
assign flush = EX_Branch;

wire [15:0] EX_pc_branch_target;
wire [15:0] EX_reg_write_data;
wire [15:0] EX_ALU_src_2;

wire [15:0] ID_pc_plus_2;
wire [15:0] ID_instr;

wire [2:0] flag_current, flag_new, flag_write_enable;
wire [15:0] lhb_out, llb_out, ALU_out;
wire ALUop, BranchImm, BranchReg;
wire [15:0] ALU_in_1, EX_ALU_in_2;

// Data output from Registers file
wire [15:0] ID_reg_data_1;
wire [15:0] ID_reg_data_2;
wire ID_MemWrite, ID_MemToReg, ID_RegWrite;

// Reg select signals, decoded to 1-hot
wire [3:0] reg_read_select_1;
wire [3:0] reg_read_select_2;
// Register to write to, decoded to 1-hot
wire [3:0] reg_write_select;

wire RegToMem;
assign RegToMem = ID_instr[15] & ~ID_instr[14] & ~ID_instr[13] & ID_instr[12];

//
// Interpret Instruction Bits
//

wire [15:0] EX_pc_plus_2;
wire [15:0] EX_reg_data_1;
wire [15:0] EX_reg_data_2;
wire [15:0] EX_instr;
wire [15:0] EX_reg_write_select;
wire EX_RegWrite, EX_ALUimm, EX_MemWrite, EX_MemToReg;

wire MEM_RegWrite, MEM_MemToReg, MEM_MemWrite;
wire [15:0] MEM_mem_addr, MEM_reg_write_data, MEM_reg_write_select, MEM_ALU_in_2;

wire MemEnable;
assign MemEnable = MEM_MemToReg | MEM_MemWrite;

wire [15:0] mem_read_out;
assign MEM_reg_write_data = MEM_MemToReg? mem_read_out[15:0] : MEM_reg_write_data[15:0];


//------------------------------------------------------------------------------
// IF: INSTRUCTION FETCH STAGE
//------------------------------------------------------------------------------
wire [15:0] IF_pc_curr;
wire [15:0] IF_pc_new;
wire [15:0] IF_pc_plus_2;
wire [15:0] IF_instr;

// branch signal from ID stage
assign IF_pc_new = EX_Branch? EX_pc_branch_target : IF_pc_plus_2;
assign pc = IF_pc_new;

state_reg pc_reg (
	.pc_new(IF_pc_new[15:0]),
	.clk(clk),
	.rst(rst),
	.wen(~stall),
	.pc_current(IF_pc_curr[15:0])
);
CLA_16b pc_adder (
	.A(IF_pc_curr[15:0]),
	.B(16'h0002),
	.sub(1'b0),
	.S(IF_pc_plus_2[15:0]),
	.ovfl(),
	.neg()
);
memory1c instr_mem (
	.data_out(IF_instr[15:0]),
	.data_in({16{1'b0}}),
	.addr(IF_pc_curr[15:0]),
	.enable(1'b1),
	.wr(1'b0),
	.clk(clk),
	.rst(rst)
);

//------------------------------------------------------------------------------
// IF-ID State Reg
//------------------------------------------------------------------------------


IF_ID IFID(
	.pc_plus_2_new(IF_pc_plus_2[15:0]),
	.instr_new(IF_instr[15:0]),
	.clk(clk),
	.rst(flush | rst),
	.wen(~stall),
	.pc_plus_2_curr(ID_pc_plus_2[15:0]),
	.instr_curr(ID_instr[15:0])
);

//------------------------------------------------------------------------------
// ID: INSTRUCTION DECODE STAGE
//------------------------------------------------------------------------------

// make write register always the first reg in instruction
wire [3:0] ID_reg_write_select;
assign ID_reg_write_select = ID_instr[11:8];
assign reg_read_select_1 = RegToMem? ID_instr[11:8] : ID_instr[7:4];
assign reg_read_select_2 = BranchReg? ID_instr[7:4] : ID_instr[3:0];

wire MemWrite, MemToReg, RegWrite, ALUimm;
CTRL_UNIT control_unit (
	.instr(ID_instr[15:12]),
	.MemWrite(MemWrite),
	.MemToReg(MemToReg),
	.RegWrite(RegWrite),
	.ALUimm(ALUimm)
);

assign ID_MemWrite = flush? 1'b0 : MemWrite;
assign ID_MemToReg = flush? 1'b0 : MemToReg;
assign ID_RegWrite = flush? 1'b0 : RegWrite;
assign ID_ALUimm = flush? 1'b0 : ALUimm;

RegisterFile register_file (
	.clk(clk),
	.rst(rst),
	.SrcReg1(reg_read_select_1[3:0]),
	.SrcReg2(reg_read_select_2[3:0]),
	.DstReg(WB_reg_write_select[3:0]),
	.WriteReg(WB_RegWrite),
	.DstData(WB_reg_write_data[15:0]),
	.SrcData1(ID_reg_data_1[15:0]),
	.SrcData2(ID_reg_data_2[15:0])
);

//------------------------------------------------------------------------------
// ID_EX State Reg
//------------------------------------------------------------------------------

ID_EX IDEX (
	.pc_new(ID_pc_plus_2[15:0]),
	.data1_new(ID_reg_data_1[15:0]),
	.data2_new(ID_reg_data_2[15:0]),
	.instr_new(ID_instr[15:0]),
	.regwrite_new(ID_RegWrite),
	.reg_write_select_new(ID_reg_write_select[3:0]),
	.alusrc_new(ID_ALUimm),
	.memtoreg_new(ID_MemToReg),
	.memwrite_new(ID_MemWrite),
	.clk(clk),
	.rst(flush | rst | stall),
	.wen(1'b1),
	.pc_current(EX_pc_plus_2[15:0]),
	.data1_current(EX_reg_data_1[15:0]),
	.data2_current(EX_reg_data_2[15:0]),
	.instr_current(EX_instr[15:0]),
	.regwrite_current(EX_RegWrite),
	.reg_write_select_current(EX_reg_write_select[3:0]),
	.alusrc_current(EX_ALUimm),
	.memtoreg_current(EX_MemToReg),
	.memwrite_current(EX_MemWrite)
);

//------------------------------------------------------------------------------
// EX: EXECUTION STAGE
//------------------------------------------------------------------------------
wire lhb, llb;
wire [15:0]EX_mem_addr;
assign ALUop = ~EX_instr[3];
assign BranchImm = EX_instr[3] & EX_instr[2] & ~EX_instr[1] & ~EX_instr[0];
assign BranchReg = EX_instr[3] & EX_instr[2] & ~EX_instr[1] &  EX_instr[0];
assign lhb = EX_instr[3] & ~EX_instr[2] & EX_instr[1] & ~EX_instr[0];
assign llb = EX_instr[3] & ~EX_instr[2] & EX_instr[1] &  EX_instr[0];
// MUX select ALU source 2
wire [15:0] EX_imm_signextend;
assign EX_imm_signextend = {{12{EX_instr[3]}}, EX_instr[3:0]};
assign ALU_src_2 = (EX_ALUimm)? EX_imm_signextend[15:0] : EX_reg_data_2[15:0];

assign lhb_out = {EX_instr[7:0], EX_reg_data_1[7:0]};
assign llb_out = {EX_reg_data_1[15:8], EX_instr[7:0]};

// Mem stage will choose between this and mem read output
assign EX_reg_write_data = (ALUop)? ALU_out[15:0] :
						   (lhb)? lhb_out[15:0] :
						   (llb)? llb_out[15:0] :
						   EX_pc_plus_2[15:0];

assign ALU_in_1 = (~fwd_alu_A[0] & ~fwd_alu_A[1])? EX_reg_data_1[15:0] :
				  fwd_alu_A[1]? MEM_reg_write_data[15:0] :
				  WB_reg_write_data[15:0];
assign EX_ALU_in_2 = (~fwd_alu_B[0] & ~fwd_alu_B[1])? EX_ALU_src_2[15:0] :
				  fwd_alu_B[1]? MEM_reg_write_data[15:0] :
				  WB_reg_write_data[15:0];

ALU alu (
	.ALU_in1(ALU_in_1[15:0]),
	.ALU_in2(EX_ALU_in_2[15:0]),
	.op(EX_instr[14:12]),
	.ALU_out(ALU_out[15:0]),
	.flag(flag_current[2:0]),
	.flag_write(flag_write_enable[2:0])
);
FLAG_REG flag_reg(
	.flag_new(flag_new[2:0]),
	.wen(flag_write_enable[2:0]),
	.clk(clk),
	.rst(flush | rst),
	.flag_current(flush? 3'b000 : flag_current[2:0])
);
BRANCH_CTRL branch_control (
	.pc_plus_2(EX_pc_plus_2[15:0]),
	.BranchImm(BranchImm),
	.BranchReg(BranchReg),
	.imm(EX_instr[8:0]),
	.cc(EX_instr[11:9]),
	.flag(flag_current[2:0]),
	.branch_reg_data(EX_reg_data_2[15:0]),
	.Branch(EX_Branch),
	.pc_out(EX_pc_branch_target[15:0])
);
CLA_16b mem_addr_adder (
	.A(EX_reg_data_2[15:0] & 16'hFFFE),
	.B({{11{EX_instr[3]}}, EX_instr[3:0], 1'b0}),
	.sub(1'b0),
	.Sum(EX_mem_addr[15:0]),
	.ovfl(),
	.neg()
);

//------------------------------------------------------------------------------
// EX_MEM State Reg
//------------------------------------------------------------------------------

EX_MEM EXMEM (
	.regwrite_new(EX_RegWrite),
	.memtoreg_new(EX_MemToReg),
	.memwrite_new(EX_MemWrite),
	.mem_addr_new(EX_mem_addr[15:0]),
	.reg_write_data_new(EX_reg_write_data[15:0]),
	.reg_write_select_new(EX_reg_write_select[3:0]),
	.alu_source_2_new(EX_ALU_in_2[15:0]),
	.clk(clk),
	.wen(~stall),
	.rst(flash | rst),
	.regwrite_current(MEM_RegWrite),
	.memtoreg_current(MEM_MemToReg),
	.memwrite_current(MEM_MemWrite),
	.mem_addr_current(MEM_mem_addr[15:0]),
	.reg_write_data_current(MEM_reg_write_data[15:0]),
	.reg_write_select_current(MEM_reg_write_select[3:0]),
	.alu_source_2_current(MEM_ALU_in_2[15:0])
);

//------------------------------------------------------------------------------
// MEM: MEMORY STAGE
//------------------------------------------------------------------------------

memory1c data_mem(
	.data_out(mem_read_out[15:0]),
	.data_in(MEM_ALU_in_2[15:0]),
	.addr(MEM_mem_addr[15:0]),
	.enable(MemEnable),
	.wr(MEM_MemWrite),
	.clk(clk),
	.rst(rst)
);

//------------------------------------------------------------------------------
// MEM_WB State Reg
//------------------------------------------------------------------------------
MEMWB MEMWB (
	.regwrite_new(MEM_RegWrite),
	.reg_write_data_new(MEM_reg_write_data[15:0]),
	.reg_write_select_new(MEM_reg_write_select[15:0]),
	.clk(clk),
	.wen(1'b1),
	.rst(rst),
	.regwrite_current(WB_RegWrite),
	.reg_write_data_current(WB_reg_write_data[15:0]),
	.reg_write_select_current(WB_reg_write_select[15:0])
);

//------------------------------------------------------------------------------
// WB: WRITEBACK STAGE
//------------------------------------------------------------------------------

hazard_detection hazards (
	.if_id_instr(IF_instr[15:0]),
	.id_ex_instr(ID_instr[15:0]),
	.id_ex_memread(EX_MemToReg),
	.stall(stall)
);

forward forwarder (

);
endmodule




