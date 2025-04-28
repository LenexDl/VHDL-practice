library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity top_level_tb is
	generic
	(	
		-- Разрядности шины данных (ячейки памяти) и шины адреса
		g_DATA_WIDTH   : natural := 16;
		g_ADDR_WIDTH   : natural := 21;
		-- Параметр UART'а, `
		g_CLKS_PER_BIT : natural := 250;
		-- Разрядность шины данных (ячейки памяти) в байтах, округлять в сторону большего целого  
		g_CELL_BYTES   : natural := 2;
		g_ADDR_BYTES   : natural := 3;
		
		g_TIMERS_NUM : natural := 5;
		
		g_RES_WIDTH : natural := 26;
		g_RES_BYTES : natural := 4
	);
		  
end entity;


architecture abrakadabra of top_level_tb is

component top_level is
generic
	(	
		-- Разрядности шины данных (ячейки памяти) и шины адреса
		g_DATA_WIDTH   : natural := 16;
		g_ADDR_WIDTH   : natural := 21;
		-- Параметр UART'а, `
		g_CLKS_PER_BIT : natural := 250;
		-- Разрядность шины данных (ячейки памяти) в байтах, округлять в сторону большего целого  
		g_CELL_BYTES   : natural := 2;
		g_ADDR_BYTES   : natural := 3;
		
		g_TIMERS_NUM : natural := 5;

		g_RES_BYTES : natural := 4
	);
			  
	port
	(
		i_Clk       : in    std_logic;
		
		io_Data_bus : inout std_logic_vector(g_DATA_WIDTH-1 downto 0);
		o_Addr_bus  : out unsigned(g_ADDR_WIDTH-1 downto 0);
		
		i_RX_Serial : in  std_logic;
		o_TX_Serial : out std_logic;
		
		o_SRAM_OE : out std_logic;
		o_SRAM_WE : out std_logic;
		o_SRAM_CE : out std_logic
		
	);
end component top_level;

signal	i_Clk : std_logic := '0';
		
signal	io_Data_bus : std_logic_vector(g_DATA_WIDTH-1 downto 0);
signal	o_Addr_bus  : unsigned(g_ADDR_WIDTH-1 downto 0);
		
signal	i_RX_Serial : std_logic := '1';
signal	o_TX_Serial : std_logic := '1';
		
signal	o_SRAM_OE : std_logic;
signal	o_SRAM_WE : std_logic;
signal   o_SRAM_CE : std_logic;


constant clk_period : time := 20 ns;
constant pll_clk_period : time := 4 ns;
		
begin
					 
	uut: top_level
	generic map
	(	
		g_DATA_WIDTH   => g_DATA_WIDTH, 
		g_ADDR_WIDTH   => g_ADDR_WIDTH,
		g_CLKS_PER_BIT => g_CLKS_PER_BIT, 
		g_CELL_BYTES   => g_CELL_BYTES,
		g_ADDR_BYTES   => g_ADDR_BYTES,
		g_TIMERS_NUM   => g_TIMERS_NUM,
		g_RES_BYTES    => g_RES_BYTES
	)
	port map
	(
		i_Clk => i_Clk,
		
		io_Data_bus => io_Data_bus,
		o_Addr_bus => o_Addr_bus,
		
		i_RX_Serial => i_RX_Serial,
		o_TX_Serial => o_TX_Serial,
		
		o_SRAM_OE => o_SRAM_OE,
		o_SRAM_WE => o_SRAM_WE, 
		o_SRAM_CE => o_SRAM_CE
		
	);

	io_Data_bus <= "0101010101010101";
	-----------------------------------------------------------------
	p_CLK: process
	begin
		i_Clk <= '0';
		wait for clk_period/2;
		i_Clk <= '1';
		wait for clk_period/2;
	end process p_CLK;
	
	
	p_Test: process

	variable com_TimerInit  : std_logic_vector(7 downto 0) := "11110000";
	variable com_TimerInit0 : std_logic_vector(7 downto 0) := "00000110";
	variable com_TimerInit1 : std_logic_vector(7 downto 0) := "00000000";
	variable com_TimerInit2 : std_logic_vector(7 downto 0) := "00000011";
	variable com_TimerInit3 : std_logic_vector(7 downto 0) := "00000100";
	variable com_TimerInit4 : std_logic_vector(7 downto 0) := "00000000";
	
	variable com_SetA : std_logic_vector(7 downto 0) := "10100100";
	variable com_SetB : std_logic_vector(7 downto 0) := "10111000";
	
	variable com_Read : std_logic_vector(7 downto 0) := "11111001";					
	variable com_Read_d1 : std_logic_vector(7 downto 0) := "01010101";	
	variable com_Read_d2 : std_logic_vector(7 downto 0) := "01010101";	
	variable com_Read_sa1 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Read_sa2 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Read_sa3 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Read_fa1 : std_logic_vector(7 downto 0) := "00011111";
	variable com_Read_fa2 : std_logic_vector(7 downto 0) := "11111111";
	variable com_Read_fa3 : std_logic_vector(7 downto 0) := "11111111";
	
	variable com_Write : std_logic_vector(7 downto 0) := "11110101";					
	variable com_Write_d1 : std_logic_vector(7 downto 0) := "01010101";	
	variable com_Write_d2 : std_logic_vector(7 downto 0) := "01010101";	
	variable com_Write_sa1 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Write_sa2 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Write_sa3 : std_logic_vector(7 downto 0) := "00000000";	
	variable com_Write_fa1 : std_logic_vector(7 downto 0) := "00011111";
	variable com_Write_fa2 : std_logic_vector(7 downto 0) := "11111111";
	variable com_Write_fa3 : std_logic_vector(7 downto 0) := "11111111";
	

	begin
		i_RX_Serial <= '1';
		wait for 1 us;
		--com_TimerInit
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_TimerInit0
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit0(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_TimerInit1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_TimerInit2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_TimerInit3
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit3(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_TimerInit4
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_TimerInit4(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		
		--com_SetA
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_SetA(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_SetB
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_SetB(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		
		
		--com_Read
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_d1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_d1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_d2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_d2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_sa1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_sa1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_sa2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_sa2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_sa3
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_sa3(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_fa1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_fa1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_fa2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_fa2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Read_fa3
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Read_fa3(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		
		
		wait for 150 ms;
		--com_Write
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_d1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_d1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_d2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_d2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_sa1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_sa1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_sa2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_sa2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_sa3
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_sa3(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_fa1
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_fa1(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_fa2
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_fa2(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		--com_Write_fa3
		i_RX_Serial <= '0';
		wait for pll_clk_period*g_CLKS_PER_BIT;
		for i in 0 to 7 loop
			i_RX_Serial <= com_Write_fa3(i);
			wait for pll_clk_period*g_CLKS_PER_BIT;
		end loop;
		i_RX_Serial <= '1';
		wait for pll_clk_period*2*g_CLKS_PER_BIT;
		wait;
	end process p_Test;
	

end architecture;