module forward (
	input ex_mem_regwrite,
	input mem_wb_regwrite,
	input [3:0] ex_mem_regdest,
	input [3:0] mem_wb_regdest,
	input [3:0] id_ex_regrs,
	input [3:0] id_ex_regrt,
	output [1:0] forwardA,
	output [1:0] forwardB
);

wire ex_rs_mem_rd_same, ex_rt_mem_rd_same, ex_rs_wb_rd_same, ex_rt_wb_rd_same;
wire ex_rd_zero, mem_rd_zero;
wire ex_need_mem_hazard_a, ex_need_mem_hazard_b, ex_need_wb_hazard_a, ex_need_wb_hazard_b;

// if two are same, wire will be 1
assign ex_rs_mem_rd_same = ~|(ex_mem_regdest ^ id_ex_regrs);
assign ex_rt_mem_rd_same = ~|(ex_mem_regdest ^ id_ex_regrt);
assign ex_rs_wb_rd_same = ~|(mem_wb_regdest ^ id_ex_regrs);
assign ex_rt_wb_rd_same = ~|(mem_wb_regdest ^ id_ex_regrt);

// if reg dest is zero, wire will be 1
assign ex_rd_zero = ~|(ex_mem_regdest | 4'b0000);
assign mem_rd_zero = ~|(mem_wb_regdest | 4'b0000);

// if hazard happens, wire will be 1
assign ex_need_mem_hazard_a = ex_mem_regwrite & ~ex_rd_zero & ex_rs_mem_rd_same;
assign ex_need_mem_hazard_b = ex_mem_regwrite & ~ex_rd_zero & ex_rt_mem_rd_same;
assign ex_need_wb_hazard_a = mem_wb_regwrite & ~mem_rd_zero & ex_rs_wb_rd_same & ~(ex_mem_regwrite & ~ex_rd_zero & ex_rs_mem_rd_same);
assign ex_need_wb_hazard_b = mem_wb_regwrite & ~mem_rd_zero & ex_rt_wb_rd_same & ~(ex_mem_regwrite & ~ex_rd_zero & ex_rt_mem_rd_same);

assign forwardA = ex_need_mem_hazard_a ? 2'b10 : (ex_need_wb_hazard_a ? 2'b01 : 2'b00);
assign forwardB = ex_need_mem_hazard_b ? 2'b10 : (ex_need_wb_hazard_b ? 2'b01 : 2'b00);

endmodule // forward

/*
1. EX hazard:

if (EX/MEM.RegWrite
and (EX/MEM.RegisterRd ≠ 0)
and (EX/MEM.RegisterRd = ID/EX.RegisterRs)) ForwardA = 10

if (EX/MEM.RegWrite
and (EX/MEM.RegisterRd ≠ 0)
and (EX/MEM.RegisterRd = ID/EX.RegisterRt)) ForwardB = 10

2. MEM hazard:

if (MEM/WB.RegWrite
and (MEM/WB.RegisterRd = 0)
and not(EX/MEM.RegWrite 
		and EX/MEM.RegDest != 0
		and (EX/MEM.RegRd == ID/EX.RegRs)
		)
and (MEM/WB.RegisterRd = ID/EX.RegisterRs)) ForwardA = 01

if (MEM/WB.RegWrite
and (MEM/WB.RegisterRd = 0)
and not(EX/MEM.RegWrite 
		and EX/MEM.RegDest != 0	
		and (EX/MEM.RegRd == ID/EX.RegRt)
		)
and (MEM/WB.RegisterRd = ID/EX.RegisterRt)) ForwardB = 01
*/
