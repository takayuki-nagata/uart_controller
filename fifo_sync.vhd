library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity fifo_sync is
	generic (
		WIDTH : integer;
		LOG_DEPTH : integer
	);
	port (
		clk : in std_logic;
		rst : in std_logic;
		wdata : in std_logic_vector(WIDTH -1 downto 0);
		we : in std_logic;
		rdata : out std_logic_vector(WIDTH - 1 downto 0);
		re : in std_logic;
		full : out std_logic;
		empty : out std_logic
	);
end fifo_sync;

architecture rtl of fifo_sync is
	type ram_type is array (2**LOG_DEPTH - 1 downto 0) of std_logic_vector(WIDTH - 1 downto 0);
	signal RAM : ram_type;
	signal waddr : std_logic_vector(LOG_DEPTH - 1 downto 0);
	signal raddr : std_logic_vector(LOG_DEPTH - 1 downto 0);
begin
	rdata <= RAM(to_integer(unsigned(raddr)));
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				waddr <= (others => '0');
				raddr <= (others => '0');
			else
				if we = '1' then
					RAM(to_integer(unsigned(waddr))) <= wdata;
					waddr <= waddr + 1;
				elsif re = '1' then
					raddr <= raddr + 1;
				end if;
			end if;
		end if;
	end process;
	process(waddr, raddr)
	begin
		if waddr = raddr then
			empty <= '1';
		else
			empty <= '0';
		end if;
		if waddr + 1 = raddr then
			full <= '1';
		else
			full <= '0';
		end if;
	end process;
end rtl;

