library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

-- Read-only (instruction) memory, 1K x 32-bit words
entity MEM_RO_1K is
    port (
        CLK:  in  std_logic;
        ADDR: in  std_logic_vector(9 downto 0);
        DATA: out std_logic_vector(31 downto 0)
    );
end entity;

architecture impl1 of MEM_RO_1K is
    type WORD_ARR is array(1023 downto 0) of std_logic_vector(31 downto 0); 
    signal mem: WORD_ARR := (others => (others => '0'));
begin
    -- Enter the program (opcodes) here
    mem(  0) <= x"00000010";
    mem(  1) <= x"00000010";
    mem(  2) <= x"00000010";
    mem(  3) <= x"00000010";
    mem(  4) <= x"00000010";
    mem(  5) <= x"00000010";

    p1: process
    begin
        if rising_edge(CLK) then
            DATA <= mem(conv_integer(ADDR));
        end if;
    end process;
end;
