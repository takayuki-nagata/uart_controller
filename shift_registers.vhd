library ieee;
use ieee.std_logic_1164.all;

entity shift_registers is
	generic (
		SIZE : integer
	);
	port (
		clk : in std_logic;
		ce : in std_logic;
		set : in std_logic;
		sin : in std_logic;
		pin : in std_logic_vector(SIZE - 1 downto 0);
		sout : out std_logic;
		pout : out std_logic_vector(SIZE - 1 downto 0)
	);
end shift_registers;

architecture rtl of shift_registers is
	signal sregs : std_logic_vector(SIZE - 1 downto 0);
begin
	process(clk)
	begin
		if rising_edge(clk) and ce = '1' then
			if set = '1' then
				sregs <= pin;
			else
				sregs <= sin & sregs(SIZE - 1 downto 1);
			end if;
		end if;
	end process;
	pout <= sregs;
	sout <= sregs(0);
end rtl;

