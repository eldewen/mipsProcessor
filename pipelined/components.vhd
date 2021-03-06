library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;
use ieee.std_logic_textio.all;

package COMPONENTS is
    ---TYPES-------------------------------------------------------- {{{1

    subtype byte is std_logic_vector(7 downto 0);
    subtype word is std_logic_vector(31 downto 0);
    subtype address is word;

    subtype reg_address is std_logic_vector(4 downto 0);
    subtype op_func is std_logic_vector(5 downto 0);
    subtype opcode is std_logic_vector(5 downto 0);

    type mux_mem_t is (
        MEM_NA, -- Bypass memory (for non-load/store instructions)

        MEM_SB,
        MEM_SH,
        MEM_SW,

        MEM_LB,
        MEM_LBU,
        MEM_LH,
        MEM_LHU,
        MEM_LW

        -- MEM_SWL, -- TODO implement load/store left/right words
        -- MEM_SWR,
        -- MEM_LWR,
        -- MEM_LWL
    );

    ---PIPELINE REGISTER TYPES-------------------------------------- {{{1


    -- IF Instruction Fetch stage
    type if_in is record
        enable_delta_pc : boolean;
        delta_pc        : word;
            -- Adds delta_pc to incremented PC (for branches)

        disable_pc_incr : boolean;
            -- Prevents PC from being incremented (for stalls)
    end record;

    type if_out is record
        pc          : address; -- The PC associated with `instruction`
        instruction : word;
    end record;

    -- ID Instruction Decode stage
    type id_in is record
        pc : address;
            -- Used to forward pc to $31 during bal/jal
        instruction : word;

        enable_ext_br_data : std_logic;
        ext_br_data : word;
            -- Forwarded data for branching. It's the responsibility of the CPU 
            -- entity to determine data/branch hazards and present the 
            -- appropriate data here.
    end record;

    type id_out is record
        val_a       : word;
        val_b       : word;
        alu_op      : op_func;
        sh_amnt     : std_logic_vector(4 downto 0);

        enable_delta_pc : boolean;
        delta_pc    : word;

        addr_a      :reg_address;
        addr_b      :reg_address;
            -- These are used in hazard detection/resolution

        wb_reg_addr : reg_address;
            -- Dictates which register the result is written to during WB. If 
            -- this is register zero, nothing is written.
        reg_to_mem : word;
            -- The data for stores and load left/right
        mux_mem : mux_mem_t;
            -- When MEM_W, the result from the ALU represents a memory address 
            -- and should be written to memory. This represents a store.
            -- When MEM_R, the result from the ALU represents a memory address, 
            -- whose contents should then be written to register wb_reg_addr.  
            -- This represents a load.
    end record;

    -- EX Execute stage
    type ex_in is record
        val_a : word;
        val_b : word;
        alu_op : op_func;
        sh_amnt : std_logic_vector(4 downto 0);

        nop : boolean;
            -- When nop is true, the contents of this stage are discarded, 
            -- regardless of their content (useful during stalls to discard 
            -- redundantly-fetched instructions)

        reg_to_mem   : word;

        wb_reg_addr : reg_address;
        mux_mem : mux_mem_t;
    end record;

    type ex_out is record
        alu_result   : word;
            -- The result of the ALU operation. This will be fed into the 
            -- memory stage either as an address (for load/store) or the result 
            -- to store in register wb_reg_addr
        reg_to_mem   : word;
            -- On a store, this will be the data (register contents) to write 
            -- to memory PLAN: just add zero to the value in the ALU to pass it 
            -- through (the CPU module should be able to figure this one out 
            -- for stores?)

        wb_reg_addr : reg_address;
        mux_mem : mux_mem_t;
    end record;

    -- MEM Memory stage
    type mem_in is record
        alu_result   : word;
        reg_to_mem   : word;

        wb_reg_addr : reg_address;
        mux_mem : mux_mem_t;
    end record;

    type mem_out is record
        val_f       : word;
        wb_reg_addr : reg_address;
    end record;

    -- WB Writeback stage
    type wb_in is record
        wb_data     : word;
        wb_reg_addr : reg_address;
            -- Represents the address to write wb_data to. If zero (register 
            -- r0), wb_data is ignored.
    end record;

    -- DEBUG

    type pipeline_registers is record
        if_in   : if_in;
        if_out  : if_out;
        id_in   : id_in;
        id_out  : id_out;
        ex_in   : ex_in;
        ex_out  : ex_out;
        mem_in  : mem_in;
        mem_out : mem_out;
        wb_in   : wb_in;
    end record;

    ---CONSTANTS---------------------------------------------------- {{{1


    constant MEM_DLY : time := 0.5 ns;
    constant CLK_T : time := 10 ns;

    constant R_0  : reg_address := "00000"; -- $0, read-only zero
    constant R_31 : reg_address := "11111"; -- $ra, return address

    -- These opcodes are mostly from Hennessy/Patterson Figure A.10.2 (MIPS 
    -- opcode map)
    constant F_SLL   : op_func := "000000";

    constant F_SRL   : op_func := "000010";
    constant F_SRA   : op_func := "000011";
    constant F_SLLV  : op_func := "000100";

    constant F_SRLV  : op_func := "000110";
    constant F_SRAV  : op_func := "000101";

    constant F_JR    : op_func := "001000";
    constant F_JALR  : op_func := "001001";

    constant F_MULT  : op_func := "011000";
    constant F_MULTU : op_func := "011001";
    constant F_DIV   : op_func := "011010";
    constant F_DIVU  : op_func := "011011";

    constant F_ADD   : op_func := "100000";
    constant F_ADDU  : op_func := "100001";
    constant F_SUB   : op_func := "100010";
    constant F_SUBU  : op_func := "100011";
    constant F_AND   : op_func := "100100";
    constant F_OR    : op_func := "100101";
    constant F_XOR   : op_func := "100110";
    constant F_NOR   : op_func := "100111";

    constant F_SLT   : op_func := "101010";
    constant F_SLTU  : op_func := "101011";

    constant OPCODE_SPECIAL : opcode := "000000"; -- Rest of opcode in func
    constant OPCODE_REGIMM  : opcode := "000001"; -- Single-reg branch tests
    constant OPCODE_J       : opcode := "000010";
    constant OPCODE_JAL     : opcode := "000011";
    constant OPCODE_BEQ     : opcode := "000100";
    constant OPCODE_BNE     : opcode := "000101";
    constant OPCODE_BLEZ    : opcode := "000110";
    constant OPCODE_BGTZ    : opcode := "000111";
    constant OPCODE_ADDI    : opcode := "001000";
    constant OPCODE_ADDIU   : opcode := "001001";
    constant OPCODE_SLTI    : opcode := "001010";
    constant OPCODE_SLTIU   : opcode := "001011";
    constant OPCODE_ANDI    : opcode := "001100";
    constant OPCODE_ORI     : opcode := "001101";
    constant OPCODE_XORI    : opcode := "001110";
    constant OPCODE_LUI     : opcode := "001111";

    constant OPCODE_LB      : opcode := "100000";
    constant OPCODE_LH      : opcode := "100001";
    constant OPCODE_LWL     : opcode := "100010";
    constant OPCODE_LW      : opcode := "100011";
    constant OPCODE_LBU     : opcode := "100100";
    constant OPCODE_LHU     : opcode := "100101";
    constant OPCODE_LWR     : opcode := "100110";

    constant OPCODE_SB      : opcode := "101000";
    constant OPCODE_SH      : opcode := "101001";
    constant OPCODE_SWL     : opcode := "101010";
    constant OPCODE_SW      : opcode := "101011";

    constant RT_BLTZ   : reg_address := "00001";
    constant RT_BGEZ   : reg_address := "00010";
    constant RT_BLTZAL : reg_address := "10000";
    constant RT_BGEZAL : reg_address := "10001";

    ---COMPONENTS--------------------------------------------------- {{{1

    component MIPS_IMEM is
        generic (imem_filename : string);
        port (
            data_addr : in  address;
            data_out  : out word
        );
    end component;

    component MIPS_REG is
        port (
            clk       : in  std_logic;
            addr_a    : in  reg_address;
            addr_b    : in  reg_address;
            data_a    : out word;
            data_b    : out word;
            wr_enable : in  std_logic;
            wr_addr   : in  reg_address;
            wr_data   : in  word
        );
    end component;

    component MIPS_ALU is
        port (
            alu_op  :   in  op_func;
            sh_amnt :   in  std_logic_vector (4 downto 0);
            a       :   in  word;
            b       :   in  word;
            f       :   out word
        );
    end component;

    component MIPS_DMEM is
        generic (
            dmem_init_filename : string := "data/data_mem_init.txt";
            dmem_filename      : string := "data/mem_trans.txt"
        );
        port (
            clk       : in  std_logic;
            addr      : in  address;
            wr_enable : in  std_logic;
            wr_data   : in  word;
            data_size : in  std_logic_vector(1 downto 0);
                -- Number of bytes (1-4) to read/write. Warning: likely gotcha: 
                -- this is implemented as number of bytes-1, not number of 
                -- bytes!
            data_out  : out word
        );
    end component;

    ---PIPELINE STAGES---------------------------------------------- {{{1

    component MIPS_IF is
        generic (imem_filename : string);
        port (
            clk    : in  std_logic;
            p_if_in  : in  if_in;
            p_if_out : out if_out
        );
    end component;

    component MIPS_ID_WB is
        port (
            clk    : in  std_logic;
            p_id_in  : in  id_in;
            p_id_out : out id_out;
            p_wb_in  : in  wb_in
        );
    end component;

    component MIPS_EX is
        port (
            clk    : in  std_logic;
            p_ex_in  : in  ex_in;
            p_ex_out : out ex_out
        );
    end component;

    component MIPS_MEM is
        generic (
            dmem_init_filename : string;
            dmem_filename      : string
        );
        port (
            clk    : in  std_logic;
            p_mem_in  : in  mem_in;
            p_mem_out : out mem_out
        );
    end component;

    component MIPS_NO_HAZARDS is
        generic (
            imem_filename      : string;
            dmem_init_filename : string;
            dmem_filename      : string
        );
        port (
            clk : in std_logic;
            reg_debug : out pipeline_registers
        );
    end component;

    component MIPS_DATA_HAZARDS is
        generic (
            imem_filename      : string;
            dmem_init_filename : string;
            dmem_filename      : string
        );
        port (
            clk : in std_logic;
            reg_debug : out pipeline_registers
        );
    end component;

    ---FUNCTIONS---------------------------------------------------- {{{1

    procedure print_word (p_addr : in address; p_word : in word);
    procedure puts (str : in string);
end package;

package body COMPONENTS is
    procedure print_word (p_addr : in address; p_word : in word) is
        variable buf: line;
    begin
        write(buf, now);
        write(buf, string'(": "));
        write(buf, string'("0x"));
        hwrite(buf, p_addr);
        write(buf, string'("-> 0x"));
        hwrite(buf, p_word);
        writeline(OUTPUT, buf);
    end procedure;

    procedure puts (str : in string) is
        variable buf: line;
    begin
        write(buf, now);
        write(buf, string'(": "));
        write(buf, str);
        writeline(OUTPUT, buf);
    end procedure;

end package body;
