library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity uart_rx is
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
end uart_rx;

architecture rtl of uart_rx is
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
	type rx_state is (STATE_RST1, STATE_RST2, STATE_IDLE, STATE_WAITFORMIDBIT, STATE_RECEIVING);
	signal state : rx_state;
	signal next_state : rx_state;
	signal reg_clkcnt : std_logic_vector(CSIZE - 1 downto 0);
	signal next_clkcnt : std_logic_vector(CSIZE - 1 downto 0);
	signal ce_rst : std_logic;
	signal sreg_ce : std_logic;
	signal sreg_set : std_logic;
	signal sreg_pin : std_logic_vector(DSIZE + 1 downto 0);
	signal sreg_pout : std_logic_vector(DSIZE + 1 downto 0);
begin
	inst_uart_rx_clk_timer : clk_timer
		generic map(
			CNT => CNT,
			CSIZE => CSIZE
		)
		port map(
			clk => clk,
			rst => ce_rst,
			alm => sreg_ce
		);
	inst_uart_rx_shift_registers: shift_registers
		generic map(
			SIZE => DSIZE + 2 -- DATA + stop/start bits
		)
		port map(
			clk => clk,
			ce => sreg_ce,
			set => sreg_set,
			sin => rxd,
			pin => sreg_pin,
			pout => sreg_pout
		);
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				reg_clkcnt <= (others => '0');
				state <= STATE_RST1;
			else
				reg_clkcnt <= next_clkcnt;
				state <= next_state;
			end if;
		end if;
	end process;
	rx_state_machine : process(state, sreg_ce, rxd, reg_clkcnt, sreg_pout)
		variable uartframe : std_logic_vector (DSIZE + 1 downto 0);
	begin
		uartframe := sreg_pout;
		sreg_pin <= uartframe;
		sreg_set <= '0';
		data <= uartframe(DSIZE downto 1);
		ce_rst <= '0';
		next_clkcnt <= reg_clkcnt;
		rdy <= '0';
		case state is
			when STATE_RST1 =>
				ce_rst <= '1';
				next_state <= STATE_RST2;
			when STATE_RST2 =>
				if sreg_ce = '1' then
					sreg_pin <= const_idle_frame;
					sreg_set <= '1';
					next_state <= STATE_IDLE;
				else
					next_state <= STATE_RST2;
				end if;
			when STATE_IDLE =>
				if rxd = '1' then
					ce_rst <= '1';
					next_clkcnt <= std_logic_vector(to_unsigned(CNT/2, next_clkcnt'length));
					next_state <= STATE_WAITFORMIDBIT;
				else
					next_state <= STATE_IDLE;
				end if;
			when STATE_WAITFORMIDBIT =>
				if reg_clkcnt = std_logic_vector(to_unsigned(0, reg_clkcnt'length)) then
					next_state <= STATE_RECEIVING;
				else
					next_clkcnt <= reg_clkcnt - 1;
					next_state <= STATE_WAITFORMIDBIT;
				end if;
			when STATE_RECEIVING =>
				next_state <= STATE_RECEIVING;
				if sreg_ce = '1' then
					if uartframe(0) = '0' then -- start bit is arrived at the tail of the shift registers?
						if uartframe(DSIZE + 1) = '1' then -- stop bit is arrived at the head of the shift registers.
							sreg_pin <= rxd & const_idle_frame(DSIZE downto 0);
							sreg_set <= '1';
							rdy <= '1';
							if rxd = '0' then -- receivd next frame
								next_state <= STATE_RECEIVING;
							else
								next_state <= STATE_IDLE;
							end if;
						else -- corrupted signal?
							sreg_pin <= const_idle_frame;
							sreg_set <= '1';
							rdy <= '0';
							next_state <= STATE_IDLE;
						end if;
					end if; -- all uart frame has not recieved yet.
				end if;
			when others =>
				next_state <= STATE_IDLE;
		end case;
	end process;
end rtl;

