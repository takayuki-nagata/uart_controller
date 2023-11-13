library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity uart_tx is
	generic(
		DSIZE : integer := 8;
		SENTCNT_SIZE : integer := 4;
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
end uart_tx;

architecture rtl of uart_tx is
	component clk_timer is
		generic (
			CNT : integer;
			CSIZE : integer
		);
		port (
			clk : in std_logic;
			rst : in std_logic;
			alm : out std_logic
		);
	end component;
	component shift_registers
		generic(
			SIZE : integer
		);
		port(
			clk : in std_logic;
			ce : in std_logic;
			set : in std_logic;
			sin : in std_logic;
			pin : in std_logic_vector(SIZE - 1 downto 0);
			sout : out std_logic;
			pout : out std_logic_vector(SIZE - 1 downto 0)
		);
	end component;
	constant const_idle_frame : std_logic_vector (DSIZE + 1 downto 0) := std_logic_vector(to_signed(-1, DSIZE +2));
	type tx_state is (STATE_RST, STATE_IDLE, STATE_SET, STATE_SENDING);
	signal state : tx_state;
	signal next_state : tx_state;
	signal reg_uartframe : std_logic_vector(DSIZE + 1 downto 0);
	signal reg_sentcnt : std_logic_vector(SENTCNT_SIZE -1 downto 0);
	signal next_sentcnt : std_logic_vector(SENTCNT_SIZE -1 downto 0);
	signal sreg_ce : std_logic;
	signal sreg_set : std_logic;
begin
	inst_uart_tx_clk_timer : clk_timer
		generic map(
			CNT => CNT,
			CSIZE => CSIZE
		)
		port map(
			clk => clk,
			rst => rst,
			alm => sreg_ce
		);
	inst_uart_tx_shift_registers: shift_registers
		generic map(
			SIZE => DSIZE + 2 -- data + stop  and start bits
		)
		port map(
			clk => clk,
			ce => sreg_ce,
			set => sreg_set,
			sin => '1',
			pin => reg_uartframe,
			sout => txd
		);
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= STATE_RST;
				reg_uartframe <= const_idle_frame;
				reg_sentcnt <= (others => '0');
			else
				if we = '1' then
					reg_uartframe <= '1' & data & '0'; -- Stop bit|Data bits|Start bit
				end if;
				reg_sentcnt <= next_sentcnt;
				state <= next_state;
			end if;
		end if;
	end process;
	tx_state_machine : process(state, sreg_ce, we, data, reg_sentcnt)
	begin
		busy <= '0';
		sreg_set <= '0';
		next_sentcnt <= reg_sentcnt;
		case state is
			when STATE_RST =>
				busy <= '1';
				if sreg_ce = '1' then
					sreg_set <= '1';
					next_state <= STATE_IDLE;
				else
					next_state <= STATE_RST;
				end if;
			when STATE_IDLE =>
				if we = '1' then
					next_state <= STATE_SET;
				else
					next_state <= STATE_IDLE;
				end if;
			when STATE_SET =>
				busy <= '1';
				if sreg_ce = '1' then
					sreg_set <= '1';
					next_state <= STATE_SENDING;
				else
					next_state <= STATE_SET;
				end if;
			when STATE_SENDING =>
				busy <= '1';
				if reg_sentcnt = std_logic_vector(to_unsigned(10, reg_sentcnt'length)) then
					next_state <= STATE_IDLE;
					next_sentcnt <= (others => '0');
				else
					if sreg_ce = '1' then
						next_sentcnt <= reg_sentcnt + 1;
					end if;
					next_state <= STATE_SENDING;
				end if;
			when others =>
				next_state <= STATE_IDLE;
		end case;
	end process;
end rtl;

