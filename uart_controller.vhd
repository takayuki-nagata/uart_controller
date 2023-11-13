library ieee;
use ieee.std_logic_1164.all;

-- Specification: 8 data bits, no parity, 1 stop bit, no flow controll
-- CNT = Tsr/Tcl = (1/115200)/(1/(clk MHz*10^6)) for 115200 bit/s
entity uart_controller is
	generic (
		CNT : integer; -- clock timer count for uart bound rate
		CSIZE : integer -- should begger than log2(CNT)
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
end uart_controller;

architecture rtl of uart_controller is
	component uart_tx is
	generic(
		DSIZE : integer := 8;
		CNT : integer;
		CSIZE : integer
	);
	port (
		clk : in std_logic;
		rst : in std_logic;
		data : in std_logic_vector(DSIZE - 1 downto 0);
		we : in std_logic;
		busy : out std_logic;
		txd : out std_logic
	);
	end component;
	component uart_rx is
	generic(
		DSIZE : integer := 8;
		CNT : integer;
		CSIZE : integer
	);
	port (
		clk : in std_logic;
		rst : in std_logic;
		data : out std_logic_vector(DSIZE - 1 downto 0);
		rdy : out std_logic;
		rxd : in std_logic
	);
	end component;
	component fifo_sync is
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
	end component;
	signal tx_wdata : std_logic_vector(7 downto 0);
	signal tx_we : std_logic;
	signal tx_rdata : std_logic_vector(7 downto 0);
	signal tx_re : std_logic;
	signal tx_full : std_logic;
	signal tx_empty : std_logic;
	signal txdata : std_logic_vector(7 downto 0);
	signal uart_we : std_logic;
	signal uart_busy : std_logic;
	signal rx_wdata : std_logic_vector(7 downto 0);
	signal rx_we : std_logic;
	signal rx_rdata : std_logic_vector(7 downto 0);
	signal rx_re : std_logic;
	signal rx_full : std_logic;
	signal rx_empty : std_logic;
	signal rxdata : std_logic_vector(7 downto 0);
	signal uart_rdy : std_logic;
begin
	tx_fifo : fifo_sync
		generic map(
			WIDTH => 8,
			LOG_DEPTH => 8 -- 2^7 = 128
		)
		port map(
			clk => clk,
			rst => rst,
			wdata => tx_wdata,
			we => tx_we,
			rdata => tx_rdata,
			re => tx_re,
			full => tx_full,
			empty => tx_empty
		);
	inst_uart_tx : uart_tx
		generic map(
			CNT => CNT,
			CSIZE => CSIZE
		)
		port map(
			clk => clk,
			rst => rst,
			data => txdata,
			we => uart_we,
			busy => uart_busy,
			txd => txd
		);
	tx_wdata <= wdata;
	txdata <= tx_rdata;
	write_to_tx_fifo : process(we, tx_full)
	begin
		if we = '1' and tx_full = '0' then
			tx_we <= '1';
		else
			tx_we <= '0';
		end if;
	end process;
	tx_fifo_to_uart_tx : process(tx_empty, uart_busy)
	begin
		if tx_empty = '0' and uart_busy = '0' then
			tx_re <= '1';
			uart_we <= '1';
		else
			tx_re <= '0';
			uart_we <= '0';
		end if;
	end process;
	inst_uart_rx : uart_rx
		generic map(
			CNT => CNT,
			CSIZE => CSIZE
		)
		port map(
			clk => clk,
			rst => rst,
			data => rxdata,
			rdy => uart_rdy,
			rxd => rxd
		);
	rx_fifo : fifo_sync
		generic map(
			WIDTH => 8,
			LOG_DEPTH => 8
		)
		port map(
			clk => clk,
			rst => rst,
			wdata => rx_wdata,
			we => rx_we,
			rdata => rx_rdata,
			re => rx_re,
			full => rx_full,
			empty => rx_empty
		);
	rx_wdata <= rxdata;
	rdata <= rx_rdata;
	uart_rx_to_rx_fifo : process(uart_rdy, rx_full)
	begin
		if uart_rdy = '1' and rx_full = '0' then
			rx_we <= '1';
		else
			rx_we <= '0';
		end if;
	end process;
	read_from_rx_fifo : process(re, rx_empty)
	begin
		if re = '1' and rx_empty = '0' then
			rx_re <= '1';
		else
			rx_re <= '0';
		end if;
	end process;
	full <= tx_full;
	empty <= rx_empty;
end rtl;

