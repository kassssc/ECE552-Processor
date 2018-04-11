module cpu_ptb();
  

   wire [15:0] PC;
   wire [15:0] Inst;           /* This should be the 15 bits of the FF that
                                  stores instructions fetched from instruction memory
                               */
   wire        RegWrite;       /* Whether register file is being written to */
   wire [3:0]  WriteRegister;  /* What register is written */
   wire [15:0] WriteData;      /* Data */
   wire        MemWrite;       /* Similar as above but for memory */
   wire        MemRead;
   wire [15:0] MemAddress;
   wire [15:0] MemDataIn;	/* Read from Memory */
   wire [15:0] MemDataOut;	/* Written to Memory */

   wire        Halt;         /* Halt executed and in Memory or writeback stage */
        
   integer     inst_count;
   integer     cycle_count;

   integer     trace_file;
   integer     sim_log_file;

   reg clk; /* Clock input */
   reg rst_n; /* (Active low) Reset input */

     

   cpu DUT(.clk(clk), .rst_n(rst_n), .pc_out(PC), .hlt(Halt)); /* Instantiate your processor */
   





   /* Setup */
   initial begin
      $display("Hello world...simulation starting");
      $display("See verilogsim.plog and verilogsim.ptrace for output");
      inst_count = 0;
      trace_file = $fopen("verilogsim.ptrace");
      sim_log_file = $fopen("verilogsim.plog");
      
   end





  /* Clock and Reset */
// Clock period is 100 time units, and reset length
// to 201 time units (two rising edges of clock).

   initial begin
      $dumpvars;
      cycle_count = 0;
      rst_n = 0; /* Intial reset state */
      clk = 1;
      #201 rst_n = 1; // delay until slightly after two clock periods
    end

    always #50 begin   // delay 1/2 clock period each time thru loop
      clk = ~clk;
    end
	
    always @(posedge clk) begin
    	cycle_count = cycle_count + 1;
	if (cycle_count > 100000) begin
		$display("hmm....more than 100000 cycles of simulation...error?\n");
		$finish;
	end
    end








  /* Stats */
   always @ (posedge clk) begin
      if (rst_n) begin
         if (Halt || RegWrite || MemWrite) begin
            inst_count = inst_count + 1;
         end
         $fdisplay(sim_log_file, "SIMLOG:: Cycle %d PC: %8x I: %8x R: %d %3d %8x M: %d %d %8x %8x %8x",
                  cycle_count,
                  PC,
                  Inst,
                  RegWrite,
                  WriteRegister,
                  WriteData,
                  MemRead,
                  MemWrite,
                  MemAddress,
                  MemDataIn,
		  MemDataOut);
         if (RegWrite) begin
            $fdisplay(trace_file,"REG: %d VALUE: 0x%04x",
                      WriteRegister,
                      WriteData );            
         end
         if (MemRead) begin
            $fdisplay(trace_file,"LOAD: ADDR: 0x%04x VALUE: 0x%04x",
                      MemAddress, MemDataOut );
         end

         if (MemWrite) begin
            $fdisplay(trace_file,"STORE: ADDR: 0x%04x VALUE: 0x%04x",
                      MemAddress, MemDataIn  );
         end
         if (Halt) begin
            $fdisplay(sim_log_file, "SIMLOG:: Processor halted\n");
            $fdisplay(sim_log_file, "SIMLOG:: sim_cycles %d\n", DUT.S_out);
            $fdisplay(sim_log_file, "SIMLOG:: inst_count %d\n", inst_count);

            $fclose(trace_file);
            $fclose(sim_log_file);
	    #5;
            $finish;
         end 

         /*$display("ID_RegWrite: %b", DUT.ID_RegWrite);
         $display("EX_RegWrite: %b", DUT.EX_RegWrite);
         $display("WB_RegWrite: %b", DUT.WB_RegWrite);
		 $display("EX_RegWrite: %b", DUT.EX_RegWrite);
         $display("MEM_RegWrite: %b", DUT.MEM_RegWrite);

         $display("ID_reg_write_select: %b", DUT.ID_reg_write_select);
         $display("EX_reg_write_select: %b", DUT.EX_reg_write_select);
         $display("WB_reg_write_select: %b", DUT.WB_reg_write_select);
         $display("MEM_reg_write_select: %b", DUT.MEM_reg_write_select);
		 
		 
		 $display("flush: %b", DUT.flush);
         $display("stall: %b", DUT.stall);
         $display("rst: %b", DUT.rst);
         $display("ID_instr: %b", DUT.ID_instr);
		 $display("ex_pc: %b", DUT.EX_pc);
		 $display("does it pass: %b", DUT.ID_instr);
		 $display("EX_Branch_current: %b", DUT.EX_Branch_current);
		 $display("EX_pc_branch_target: %b", DUT.EX_pc_branch_target);
		 $display("pc_plus_2: %b", DUT.pc_plus_2);
		 */
		 $display("data_hazard: %b", DUT.data_hazard);
		 $display("data_hazard_out1: %b", DUT.data_hazard_out1);
		 $display("data_hazard_out2: %b", DUT.data_hazard_out2);
		 
		 $display("if_id_rs: %b", DUT.if_id_rs_out);
		 $display("if_id_rt: %b", DUT.if_id_rt_out);
		 $display("id_ex_rt: %b", DUT.id_ex_rt_out);
		 $display("idmemtoreg: %b", DUT.ID_MemToReg);
		 $display("exmemtoreg: %b", DUT.EX_MemToReg);
		 

      end      

   end
   /* Assign internal signals to top level wires
      The internal module names and signal names will vary depending
      on your naming convention and your design */

   // Edit the example below. You must change the signal
   // names on the right hand side
    
//   assign PC = DUT.fetch0.pcCurrent; //You won't need this because it's part of the main cpu interface
   
//   assign Halt = DUT.memory0.halt; //You won't need this because it's part of the main cpu interface
   // Is processor halted (1 bit signal)
   

   assign Inst = DUT.IF_instr;
   //Instruction fetched in the current cycle
   
   assign RegWrite = DUT.WB_RegWrite;
   // Is register file being written to in this cycle, one bit signal (1 means yes, 0 means no)
  
   assign WriteRegister = DUT.WB_reg_write_select;
   // If above is true, this should hold the name of the register being written to. (4 bit signal)
   
   assign WriteData = DUT.WB_reg_write_data;
   // If above is true, this should hold the Data being written to the register. (16 bits)
   
   assign MemRead =  DUT.MEM_MemToReg;
   // Is memory being read from, in this cycle. one bit signal (1 means yes, 0 means no)
   
   assign MemWrite = DUT.MEM_MemWrite;
   // Is memory being written to, in this cycle (1 bit signal)
   
   assign MemAddress = DUT.MEM_mem_addr;
   // If there's a memory access this cycle, this should hold the address to access memory with (for both reads and writes to memory, 16 bits)
   
   assign MemDataIn = DUT.MEM_ALU_in_2;
   // If there's a memory write in this cycle, this is the Data being written to memory (16 bits)
   
   assign MemDataOut = DUT.mem_read_out;
   // If there's a memory read in this cycle, this is the data being read out of memory (16 bits)



   /* Add anything else you want here */

   
endmodule
