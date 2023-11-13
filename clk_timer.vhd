library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity clk_timer is
	generic (
		CNT : integer;
		CSIZE : integer
	);
	port (
		clk : in std_logic;
		rst : in std_logic;
		alm : out std_logic
	);
end clk_timer;

architecture rtl of clk_timer is
	constant const_zero_vector : std_logic_vector(CSIZE - 1 downto 0) := std_logic_vector(to_unsigned(0, CSIZE));
	constant const_init_vector : std_logic_vector(CSIZE - 1 downto 0 ) := std_logic_vector(to_unsigned(CNT - 1, CSIZE));
	signal reg_counter : std_logic_vector(CSIZE - 1 downto 0);
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				reg_counter <=const_init_vector;
			else
				if reg_counter = const_zero_vector then
					reg_counter <= const_init_vector;
				else
					reg_counter <= reg_counter - 1;
				end if;
			end if;
		end if;
	end process;
	process(reg_counter)
	begin
		alm <= '0';
		if reg_counter = const_zero_vector then
			alm <= '1';
		end if;
	end process;
end rtl;

