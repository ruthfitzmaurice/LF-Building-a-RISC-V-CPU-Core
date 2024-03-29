\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   m4_asm(ADD, x14, x13, x14)           // Incremental summation
   m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_asm_end()
   m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;

   // Program counter logic
   
   $pc[31:0] = >>1$next_pc;
   $next_pc[31:0] = $reset ? 0 : ($pc + 4);

   // Instruction memory logic

   `READONLY_MEM($pc, $$instr[31:0])

   // Decoding the IMem instruction in the decoder (Instruction Type)

   $is_j_instr = $instr[6:2] == 5'b11011;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_r_instr = $instr[6:2] == 5'b01011 ||$instr[6:2] == 5'b01100 ||$instr[6:2] == 5'b10100 ||$instr[6:2] == 5'b01110;
   $is_u_instr = $instr[6:2] == 5'b00101 ||$instr[6:2] == 5'b01101;
   $is_i_instr = $instr[6:2] == 5'b00000 ||$instr[6:2] == 5'b00001 ||$instr[6:2] == 5'b00100 ||$instr[6:2] == 5'b00110 ||$instr[6:2] == 5'b11001;
   $is_s_instr = $instr[6:2] == 5'b01000||$instr[6:2] == 5'b01001;
   
   
   // Decoding the instruction fields

   $opcode[6:0] = $instr[6:0]; 
   $rd[4:0] = $instr[11:7];
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   
   // Setting instruction fields valid depending on instruction type
   
   $rs2_valid = $is_r_instr || 
                $is_s_instr || 
                $is_b_instr; 
                
   $rs1_valid = $is_r_instr || 
                $is_i_instr || 
                $is_b_instr|| 
                $is_s_instr; 
                
   $funct3_valid = $is_r_instr || 
                   $is_i_instr || 
                   $is_b_instr|| 
                   $is_s_instr; 
                   
   $rd_valid = $is_r_instr || 
               $is_i_instr || 
               $is_u_instr|| 
               $is_j_instr; 
               
   $imm_valid = $is_j_instr || 
                $is_u_instr || 
                $is_b_instr|| 
                $is_s_instr || 
                $is_i_instr;
   
   // Immediate instruction field decoding
   
   $imm[31:0] = $is_i_instr ? {  {21{$instr[31]}},  $instr[30:20]  } :
                $is_s_instr ? {{21{$instr[31]}}, $instr[30:25], $instr[11:8],$instr[7] } :
                $is_b_instr ? {  {20{$instr[31]}},  $instr[7], $instr[30:25], $instr[11:8], 1'b0   } :
                $is_u_instr ? {  $instr[31], $instr[30:20], $instr[19:12], 12'b0 } :
                $is_j_instr ? {  $instr[31:20], $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0 } :
                32'b0;  // Default

   // Instruction decoding
   
   // Concatenating the relevent fields needed for instruction identification into a single bit vector 
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};  
   
   // Identifying which instruction the set of bits is
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt  = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;

   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = 1'b0;
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Register File Read implemented. 
   // Here we are using a macro to instantiate a 32 entry, 32 bit wide register file array. 
   // The fields of the macro are explained below: 
   
   // 1.) 32 entry
   // 2.) 32 bit wide register file
   // 3.) Reset signal
   // 4.) Write enable
   // 5.) Write index
   //  6.) Write data
   // 7.) Read 1 enable
   // 8.) Read 1 index
   // 9.) Read 1 data
   // 10.) Read 2 enable
   // 11.) Read 2 index
   // 12.) Read 2 data
   
   // The fields of the macro have been populated using the correct signals from the instruction decode
   // logic written above.

  m4+rf(32, 32, $reset, $rd != 5'b00000 ? $rd_valid : 1'b0, $rd, $wr_data[31:0], $rs1_valid, $rs1, $src1_value , $rs2_valid, $rs2, $src2_value )

   
   
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule