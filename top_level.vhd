library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
------------------------------------------------------------
entity top_level is
	generic
	(	
		-- Разрядности шины данных (ячейки памяти) и шины адреса
		g_DATA_WIDTH   : natural := 16;
		g_ADDR_WIDTH   : natural := 21;
		-- Параметр UART'а, `
		g_CLKS_PER_BIT : natural := 250;
		-- Разрядность шины данных (ячейки памяти) в байтах, округлять в сторону большего целого  
		g_DATA_BYTES   : natural := 2;
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
		
		o_SRAM_OE  : out std_logic;
		o_SRAM_WE  : out std_logic;
		o_SRAM_CE : out std_logic;
		
		o_LED_statusMAIN : out std_logic_vector(2 downto 0)
		
	);
		  
end entity;


architecture abrakadabra of top_level is

component PLL_reconf is
	port
	(
		areset		: in STD_LOGIC  := '0';
		inclk0		: in STD_LOGIC  := '0';
		c0		      : out STD_LOGIC 
	);
end component PLL_reconf;


component UART_RX is
	generic(g_CLKS_PER_BIT : natural);
	
	port
	(
		i_Clk       : in  std_logic;
		i_RX_Serial : in  std_logic;
		o_RX_DV     : out std_logic;
		o_RX_Byte   : out std_logic_vector(7 downto 0)
	);
		  
end component UART_RX;

component UART_TX is
	generic(g_CLKS_PER_BIT : natural);
	
	port
	(
		i_Clk       : in  std_logic;
		i_TX_DV     : in  std_logic;
		i_TX_Byte   : in  std_logic_vector(7 downto 0);
		o_TX_Active : out std_logic;
		o_TX_Serial : out std_logic;
		o_TX_Done   : out std_logic
	);
		  
end component UART_TX;

component sram_control_unit is
	generic
	(
		g_DATA_WIDTH : natural := 16;
		g_ADDR_WIDTH : natural := 21
	);
	port
	(
		i_Clk        : in    std_logic;
		i_Reset      : in    std_logic;
		o_Active     : out   std_logic;
		o_Done       : out   std_logic;
		i_Control    : in    std_logic_vector(1 downto 0);
		i_Start      : in    std_logic;
		i_StatusCE   : in 	std_logic; --Between operations: '1' HIGH, '0' LOW
		i_StatusOE   : in	   std_logic;
		
		i_Addr       : in    unsigned(g_ADDR_WIDTH-1 downto 0); -- Addr from MAIN that should be readed/writed e.t.c.
		o_Addr       : out   unsigned(g_ADDR_WIDTH-1 downto 0); -- Addr BUS to device
		i_Data       : in    std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data form MAIN 
		io_Data      : inout std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data io BUS to device
		o_Data       : out   std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data to MAIN
		
		o_WE_n 		 : out   std_logic;
		o_OE_n       : out   std_logic;
		o_CE_n       : out   std_logic;
		
		i_TimerID    : in    natural range 0 to 7; --[0: tAA, 1: tSA, 2: tHZWE, 3: tSD, 4: tHD]
		i_TimerValue : in    unsigned(7 downto 0)

	); 
end component sram_control_unit;

component main_control_unit is
	generic
	(
		g_DATA_BYTES : natural;
		g_ADDR_BYTES : natural;
		g_DATA_WIDTH : natural;
		g_ADDR_WIDTH : natural;
		g_RES_BYTES : natural;
		g_TIMERS_NUM : natural  --5
	);
	port
	(	
		i_Clk   : in std_logic;
		i_Reset : in std_logic;
		
		i_RX_DV   : in std_logic;
		i_RX_Byte : in std_logic_vector(7 downto 0);
		
		o_TX_DV     : out std_logic;
		o_TX_Byte   : out std_logic_vector(7 downto 0);
		i_TX_Active : in  std_logic;
		i_TX_Done   : in  std_logic;
		
		i_CU_Active   : in  std_logic;
		i_CU_Done     : in  std_logic;
		o_CU_Start    : out std_logic;
		o_CU_Control  : out std_logic_vector(1 downto 0); --00-Idle, 01-Read, 10-Write, 11-TimerInit;
		o_CU_Reset    : out std_logic;
		o_CU_StatusCE : out std_logic;
		o_CU_StatusOE : out std_logic;
		
		i_CU_Data_from : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
		o_CU_Data_to   : out std_logic_vector(g_DATA_WIDTH-1 downto 0);
		o_CU_Addr      : out  unsigned(g_ADDR_WIDTH-1 downto 0);
		
		o_CU_TimerID    : out natural range 0 to 7;
		o_CU_TimerValue : out unsigned(7 downto 0);
		
		o_LED_statusMAIN : out std_logic_vector(2 downto 0)

	);
end component main_control_unit;


signal w_RX_DV : std_logic := '0';
signal w_RX_Byte : std_logic_vector(7 downto 0) := (others => '0');

signal w_TX_DV, w_TX_Active, w_TX_Done : std_logic := '0';
signal w_TX_Byte : std_logic_vector(7 downto 0) := (others => '1');

signal w_MAIN_Reset, w_CU_Reset, w_CU_Active, w_CU_Done, w_CU_Start, w_CU_StatusCE, w_CU_StatusOE : std_logic;
signal w_CU_Control : std_logic_vector(1 downto 0);

signal w_Addr_MAIN_to_CU : unsigned(g_ADDR_WIDTH-1 downto 0);  
signal w_Data_MAIN_to_CU : std_logic_vector(g_DATA_WIDTH-1 downto 0);
signal w_Data_CU_to_MAIN : std_logic_vector(g_DATA_WIDTH-1 downto 0); 

signal w_TimerID     : natural range 0 to 7; 
signal w_TimerValue  : unsigned(7 downto 0);

signal w_GLCLK : std_logic;


signal PLL_reset : std_logic;
		
begin

	PLL_rec: PLL_reconf	
	port map
	(
		areset => PLL_reset,
		inclk0 => i_Clk,
		c0	    => w_GLCLK
	);

	RX: UART_RX
		generic map (g_CLKS_PER_BIT => g_CLKS_PER_BIT)
		port map 
		(
			i_Clk => w_GLCLK,  
			i_RX_Serial => i_RX_Serial,
			o_RX_DV => w_RX_DV,
			o_RX_Byte => w_RX_Byte
		);
					 
	TX: UART_TX
		generic map (g_CLKS_PER_BIT => g_CLKS_PER_BIT)
		port map 
		(
			i_Clk => w_GLCLK, 
			o_TX_Serial => o_TX_Serial,
			i_TX_DV => w_TX_DV,
			i_TX_Byte => w_TX_Byte,
			o_TX_Active => w_TX_Active, 
			o_TX_Done => w_TX_Done
		);
					 
	SRAM_CU: sram_control_unit
		generic map 
		(
			g_DATA_WIDTH => g_DATA_WIDTH,
			g_ADDR_WIDTH => g_ADDR_WIDTH 
		)
		port map 
		(
			i_Clk      => w_GLCLK,
			i_Reset    => w_CU_Reset,
			o_Active   => w_CU_Active,
			o_Done     => w_CU_Done,
			i_Control  => w_CU_Control,
			i_Start    => w_CU_Start,
			i_StatusCE => w_CU_StatusCE,
			i_StatusOE => w_CU_StatusOE,
			
			i_Addr   => w_Addr_MAIN_to_CU,
			o_Addr   => o_Addr_bus,
			i_Data   => w_Data_MAIN_to_CU, 
			io_Data  => io_Data_bus, --
			o_Data   => w_Data_CU_to_MAIN,
		
			o_WE_n => o_SRAM_WE,
			o_OE_n => o_SRAM_OE,
			o_CE_n => o_SRAM_CE,
			
			i_TimerID    => w_TimerID,
			i_TimerValue => w_TimerValue
		);
		
	MAIN_CU: main_control_unit
		generic map
		(
			g_DATA_BYTES => g_DATA_BYTES,
			g_ADDR_BYTES => g_ADDR_BYTES,
			g_DATA_WIDTH => g_DATA_WIDTH,
			g_ADDR_WIDTH => g_ADDR_WIDTH,
			g_TIMERS_NUM => g_TIMERS_NUM,
			g_RES_BYTES => g_RES_BYTES
		)
		port map
		(
			i_Clk   => w_GLCLK,
			i_Reset => w_MAIN_Reset,
		
			i_RX_DV   => w_RX_DV,
			i_RX_Byte => w_RX_Byte,
		
			o_TX_DV     => w_TX_DV,
			o_TX_Byte   => w_TX_Byte,
			i_TX_Active => w_TX_Active,
			i_TX_Done   => w_TX_Done,
		
			i_CU_Active   => w_CU_Active,
			i_CU_Done     => w_CU_Done,
			o_CU_Start    => w_CU_Start,
			o_CU_Control  => w_CU_Control,
			o_CU_Reset    => w_CU_Reset,
			o_CU_StatusCE => w_CU_StatusCE,
			o_CU_StatusOE => w_CU_StatusOE,
		
			i_CU_Data_from => w_Data_CU_to_MAIN,
			o_CU_Data_to   => w_Data_MAIN_to_CU,
			o_CU_Addr      => w_Addr_MAIN_to_CU,
		
			o_CU_TimerID    => w_TimerID,
			o_CU_TimerValue => w_TimerValue,
			
			o_LED_statusMAIN => o_LED_statusMAIN
		);


		w_MAIN_Reset <= '0';
		PLL_reset <= '0';


end architecture;