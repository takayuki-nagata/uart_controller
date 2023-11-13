library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity test_uart_controller is
end test_uart_controller;

architecture behavior of test_uart_controller is
	component uart_controller
		generic (
			CNT : integer; -- for clock divider for uart clock
			CSIZE : integer -- should begger than log2(DIV)
		);
		port(
			clk : in std_logic;
			rst : in std_logic;
			wdata : in std_logic_vector(7 downto 0);
			rdata : out std_logic_vector(7 downto 0);
			re : in std_logic;
			we : in std_logic;
			empty : out std_logic;
			full : out std_logic;
			txd : out std_logic;
			rxd : in std_logic
		);
	end component;
	signal clk : std_logic;
	signal rst : std_logic;
	signal wdata : std_logic_vector(7 downto 0);
	signal rdata : std_logic_vector(7 downto 0);
	signal re : std_logic;
	signal we : std_logic;
	signal empty : std_logic;
	signal full : std_logic;
	signal rxd_to_txd : std_logic;
	constant clk_period : time := 20 ns;
begin
	uut : uart_controller
		generic map(
			CNT => 434, -- Tsr/Tcl = (1/115200)/(1/(50*10^6)) = 434 for baud rate 115200 bit/s
			CSIZE => 9  -- 2^9 = 512 < 434
		)
		port map (
          clk => clk,
          rst => rst,
          wdata => wdata,
          rdata => rdata,
          re => re,
          we => we,
          empty => empty,
          full => full,
          txd => rxd_to_txd,
          rxd => rxd_to_txd
        );

	clk_process : process
	begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	end process;

	rst_process : process
	begin
		rst <= '1';
      wait for 100 ns;
		rst <= '0';
      wait;
	end process;

	write_process : process
	begin
		we <= '0';
		wait until rst = '0';
		wait for clk_period*434*4; -- wait for stabling txd
		for i in 0 to 300 loop
			if full = '1' then
				wait until full= '0';
			end if;
			wdata <= std_logic_vector(to_unsigned(i, wdata'length));
			we <= '1';
			wait for clk_period;
			we <= '0';
			wait for clk_period;
		end loop;
      wait;
   end process;

	read_process : process
	begin
		re <= '0';
		for i in 0 to 255 loop
			wait until empty = '0';
			re <= '1';
			wait for clk_period;
			assert (rdata = std_logic_vector(to_unsigned(i, rdata'length))) report "rdata failure" severity failure;
			re <= '0';
			wait for clk_period;
		end loop;
		report "rdata verification succeeded";
		finish;
	end process;
end;
