module ex(
	input aluop_new,
	input regdst_new,
	input alusrc_new,
	input clk,
	input rst, 
	input wen,
	output aluop_current,
	output regdst_current,
	output alusrc_current
);

dff aluop(
	.d(aluop_new), 
	.q(aluop_current), 
	.wen(wen), 
	.clk(clk), 
	.rst(rst)
);

dff regdst(
	.d(regdst_new), 
	.q(regdst_current), 
	.wen(wen), 
	.clk(clk), 
	.rst(rst)
);

dff alusrc(
	.d(alusrc_new), 
	.q(alusrc_current), 
	.wen(wen), 
	.clk(clk), 
	.rst(rst)
);

endmodule