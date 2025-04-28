library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main_control_unit is
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
end entity;

architecture abrakadabra of main_control_unit is

constant c_MESSAGE_BYTES : natural := g_ADDR_BYTES + g_DATA_BYTES;

signal r_MAIN_Settings_A : std_logic_vector(3 downto 0) := "0100";
signal r_MAIN_Settings_B : std_logic_vector(3 downto 0) := "0000";
-- A0'bit - SEND ADDR? '0' - NO, '1' - YES;
-- A1'bit - SEND DATA? '0' - NO, '1' - YES;
-- A2'bit - READ MODE: '0' - Slow, read one cell -. send -> repeat, '1' - Fast, read all -> count -> send errors num;
-- A3'bit - SEND MODE: '0' - only when error occurs, '1' - everything;

-- B0'bit - 
-- B1'bit - 
-- B2'bit - OE_n behavior: '1' - Normal, '0' - LOW always;
-- B3'bit - CS_n (CE_n) state while inactive: '1' - HIGH, '0' - LOW;
type t_Operation is (op_Idle, op_Read, op_Write, op_TimerInit);
signal r_Operation : t_Operation := op_Idle;

type t_State is (s_Idle, s_Preparation, s_Preparation_dec, s_StartCU, s_WaitCU_Done, s_CountErr1, s_CountErr2, s_CountErr3, s_ChooseOption, s_CheckLastAddr, s_AddrInc, s_SendToPC, s_TX, s_StartTX, s_WaittTX_Done, s_TimerInit_Recieving, s_TimerInit_Initialazing, s_TimerInit_CntrDecrment);
signal r_StateMAIN : t_State := s_Idle;
signal r_BytesToTransmit : natural range 0 to 255 := 0;
signal r_BytesToRecieve : natural range 0 to 255 := 0;
signal r_RecievedBytes : std_logic_vector(8*(g_DATA_BYTES + 2*g_ADDR_BYTES)-1 downto 0) := (others => '0');
signal r_CU_Data_from, r_CU_Data_to : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
signal r_Data_to_TX : std_logic_vector(8*c_MESSAGE_BYTES-1 downto 0) := (others => '0');


type t_mem_res is array(0 to g_DATA_WIDTH-1) of unsigned(8*g_RES_BYTES-1 downto 0);
signal r_temp : t_mem_res;
signal r_ZerosFiller_Oper : std_logic_vector(8*g_RES_BYTES-2 downto 0) := (others => '0');
signal r_Operand : std_logic_vector(g_DATA_WIDTH-1 downto 0);
signal r_Errs_OneCell : unsigned(8*g_RES_BYTES-1 downto 0) := (others => '0');
signal r_Errs_AllCells : unsigned(8*g_RES_BYTES-1 downto 0) := (others => '0');
signal r_ErrFlag : std_logic := '0';

signal r_ZerosFiller_Addr : std_logic_vector(8*g_ADDR_BYTES-g_ADDR_WIDTH-1 downto 0) := (others => '0');
signal r_LastAddr  : unsigned(g_ADDR_WIDTH-1 downto 0) := (others => '1');
signal r_CurrentAddr : unsigned(g_ADDR_WIDTH-1 downto 0) := (others => '0');
signal r_AddrPtr : unsigned(g_ADDR_WIDTH-1 downto 0) := (others => '0');

signal r_TimerID : natural range 0 to g_TIMERS_NUM; --[0: tAA, 1: tSA, 2: tHZWE, 3: tSD, 4: tHD]


begin

	p_com_SM: process(i_Clk, i_Reset)
	begin
		if i_Reset = '1' then
			r_StateMAIN <= s_Idle;
			o_CU_Reset <= '1';
			r_CurrentAddr <= (others => '0');
			r_BytesToRecieve <= 0;
		elsif rising_edge(i_Clk) then
			case r_StateMAIN is
				when  s_Idle =>
					o_CU_Reset <= '0';
					o_CU_Start <= '0';
					r_Operation <= op_Idle;
					o_TX_DV <= '0';
					r_CurrentAddr <= (others => '0');
					r_Errs_AllCells <= (others => '0');
					r_Data_to_TX <= (others => '0');
					--WAIT FOR COMMAND----------------------------------------------------------------------------
					if (i_RX_DV = '1') and (i_RX_Byte = "11111001") then -- F9 - READ
						r_StateMAIN <= s_Preparation;
						r_Operation <= op_Read;
						o_CU_Reset <= '0';
						r_BytesToRecieve <= g_DATA_BYTES + 2*g_ADDR_BYTES; --
					elsif (i_RX_DV = '1') and (i_RX_Byte = "11110101") then -- F5 - WRITE
						r_StateMAIN <= s_Preparation;
						r_Operation <= op_Write;
						o_CU_Reset <= '0';
						r_BytesToRecieve <= g_DATA_BYTES + 2*g_ADDR_BYTES; 
					elsif (i_RX_DV = '1') and (i_RX_Byte = "11110000") then -- F0 - Timing init
						r_TimerID <= 0;
						r_StateMAIN <= s_TimerInit_Recieving;
					elsif (i_RX_DV = '1') and (i_RX_Byte(7 downto 4) = "1010") then -- Set A register
						r_MAIN_Settings_A <= i_RX_Byte(3 downto 0);
						r_StateMAIN <= s_Idle;
					elsif (i_RX_DV = '1') and (i_RX_Byte(7 downto 4) = "1011") then -- Set B register
						r_MAIN_Settings_B <= i_RX_Byte(3 downto 0);
						r_StateMAIN <= s_Idle;
					else
						r_StateMAIN <= s_Idle;
					end if;
				--TIMER INIT------------------------------------------------------------------------------------
				when s_TimerInit_Recieving =>
					if (r_TimerID < g_TIMERS_NUM) and (i_RX_DV = '1') then
						r_StateMAIN <= s_TimerInit_Initialazing;
					elsif (r_TimerID < g_TIMERS_NUM) and (i_RX_DV = '0') then
						r_StateMAIN <= s_TimerInit_Recieving;
					else
						r_StateMAIN <= s_Idle;
					end if;
				when s_TimerInit_Initialazing =>
					o_CU_Start <= '1';
					r_Operation <= op_TimerInit;
					o_CU_TimerID <= r_TimerID;
					o_CU_TimerValue <= unsigned(i_RX_Byte);
					if i_CU_Active = '1' then
						o_CU_Start <= '0';
						r_Operation <= op_Idle;
						r_StateMAIN <= s_TimerInit_CntrDecrment;
					else 
						r_StateMAIN <= s_TimerInit_Initialazing;
					end if;
				when s_TimerInit_CntrDecrment =>
					r_TimerID <= r_TimerID + 1;
					r_StateMAIN <= s_TimerInit_Recieving;
				
					
				--MAIN CYCLE-------------------------------------------------------------------------------------
				when s_Preparation =>
					if  r_BytesToRecieve > 0 then
						if i_RX_DV = '1' then
							r_RecievedBytes(8*r_BytesToRecieve-1 downto 8*(r_BytesToRecieve-1)) <= i_RX_Byte;
							r_StateMAIN <= s_Preparation_dec;
						else 
							r_StateMAIN <= s_Preparation;
						end if;
					else
						r_CU_Data_to <= r_RecievedBytes(8*(g_DATA_BYTES + 2*g_ADDR_BYTES)-1 downto 8*(2*g_ADDR_BYTES));
						r_CurrentAddr <= unsigned(r_RecievedBytes(8*g_ADDR_BYTES+g_ADDR_WIDTH-1 downto 8*g_ADDR_BYTES));
						r_LastAddr <= unsigned(r_RecievedBytes(g_ADDR_WIDTH-1 downto 0));
						r_StateMAIN <= s_StartCU;
					end if;
				when s_Preparation_dec =>
					r_BytesToRecieve <= r_BytesToRecieve - 1;
					r_StateMAIN <= s_Preparation;
				---------------------------------------------
				when s_StartCU =>
					if i_CU_Active = '1' then
						r_StateMAIN <= s_WaitCU_Done;
					else
						o_CU_Start <= '1';
						r_StateMAIN <= s_StartCU;
					end if;
				when s_WaitCU_Done =>
					o_CU_Start <= '0';
					if i_CU_Done = '1' then
						if r_Operation = op_Read then
							r_CU_Data_from <= i_CU_Data_from;
							r_StateMAIN <= s_CountErr1;
						else
							r_StateMAIN <= s_CheckLastAddr;
						end if;
					else
						r_StateMAIN <= s_WaitCU_Done;
					end if;
					
				when s_CountErr1 =>
					r_Operand <= r_CU_Data_from XOR r_CU_Data_to;
					r_Errs_OneCell <= (others => '0');
					r_StateMAIN <= s_CountErr2;
				when s_CountErr2 =>
					r_Errs_OneCell <= r_temp(g_DATA_WIDTH-1);
					r_StateMAIN <= s_CountErr3;
				when s_CountErr3 =>
					if r_Errs_OneCell = 0 then 
						r_ErrFlag <= '0';
					else 
						r_ErrFlag <= '1';
					end if;
					r_Errs_AllCells <= r_Errs_AllCells +  r_Errs_OneCell;
					r_StateMAIN <= s_ChooseOption;
				

				when s_ChooseOption =>
					if r_MAIN_Settings_A(2) = '1' then
						r_StateMAIN <= s_CheckLastAddr;
					elsif (r_MAIN_Settings_B(1) = '0') then
						r_StateMAIN <= s_SendToPC;
					else
						r_StateMAIN <= s_CheckLastAddr;
					end if;
				
				when s_CheckLastAddr =>
					if r_CurrentAddr >= r_LastAddr then -- Last addr already proceed
						if r_Operation = op_Read and (r_MAIN_Settings_A(2) = '1') then
							r_StateMAIN <= s_SendToPC;
							r_Operation <= op_Idle;
						else
							r_StateMAIN <= s_Idle;
						end if;
					else
						r_StateMAIN <= s_AddrInc;
					end if;
				when s_AddrInc =>
					r_CurrentAddr <= r_CurrentAddr + 1;
					r_StateMAIN <= s_StartCU;
				
					
				when s_SendToPC =>
					if r_MAIN_Settings_A(2) = '1' then
						r_Data_to_TX(8*g_RES_BYTES-1 downto 0) <= std_logic_vector(r_Errs_AllCells);
						r_BytesToTransmit <= g_RES_BYTES;
						r_StateMAIN <= s_TX;
					elsif r_MAIN_Settings_B(1) = '0' and (r_MAIN_Settings_A(3) = '1' or (r_MAIN_Settings_A(3) = '0' and r_ErrFlag = '1')) then 
						if r_MAIN_Settings_A(0) = '0' and r_MAIN_Settings_A(1) = '0' then	
							r_BytesToTransmit <= 0;
							r_Data_to_TX <= (others => '0');
							
						elsif r_MAIN_Settings_A(0) = '0' and r_MAIN_Settings_A(1) = '1' then	
							r_BytesToTransmit <= g_DATA_BYTES;
							r_Data_to_TX(8*g_DATA_BYTES-1 downto 0) <= r_CU_Data_from;
							
						elsif r_MAIN_Settings_A(0) = '1' and r_MAIN_Settings_A(1) = '0' then	
							r_BytesToTransmit <= g_ADDR_BYTES;
							r_Data_to_TX(8*g_ADDR_BYTES-1 downto 0) <= r_ZerosFiller_Addr & std_logic_vector(r_CurrentAddr);
							
						else
							r_BytesToTransmit <= g_ADDR_BYTES + g_DATA_BYTES;
							r_Data_to_TX <= r_ZerosFiller_Addr & std_logic_vector(r_CurrentAddr) & r_CU_Data_from;
						end if;
						r_StateMAIN <= s_TX;
					else
						r_StateMAIN <= s_CheckLastAddr;
					end if;
					
				when s_TX =>
					if r_BytesToTransmit > 0 then
						o_TX_Byte <= r_Data_to_TX(8*r_BytesToTransmit-1 downto 8*(r_BytesToTransmit-1));
						r_StateMAIN <= s_StartTX;
					else
						if r_MAIN_Settings_A(2) = '1' then
							r_StateMAIN <= s_Idle;
						else
							r_StateMAIN <= s_CheckLastAddr;
						end if;
					end if;
				when s_StartTX =>
					o_TX_DV <= '1';
					r_StateMAIN <= s_WaittTX_Done;
				when s_WaittTX_Done =>
					o_TX_DV <= '0';
					if i_TX_Done = '1' then
						r_BytesToTransmit <= r_BytesToTransmit - 1;
						r_StateMAIN <= s_TX;
					else
						r_StateMAIN <= s_WaittTX_Done;
					end if;
					
				--------------------------------------------
								
			end case;
		end if;		
	end process p_com_SM;
	
	process(r_Operation)
	begin
		case r_Operation is
			when op_Idle => o_CU_Control <= "00";
			when op_Read =>	o_CU_Control <= "01";
			when op_Write => o_CU_Control <= "10";
			when op_TimerInit => o_CU_Control <= "11";
			when others => o_CU_Control <= "00";
		end case;
	end process;
	
	process(r_Operation)
	begin
		case r_Operation is
			when op_Idle => o_LED_statusMAIN <= not("000");
			when op_Read =>	o_LED_statusMAIN <= not("001");
			when op_Write => o_LED_statusMAIN <= not("010");
			when op_TimerInit => o_LED_statusMAIN <= not("011");
			when others =>  o_LED_statusMAIN <= not("101");
		end case;
	end process;
	
	-- Count errors in single cell 
	gen_CascadeAsyncCellErrCntr_1: 
	for i in 0 to g_DATA_WIDTH-1 generate
		r_temp(0) <= unsigned(r_ZerosFiller_Oper & r_Operand(0));
		gen_CascadeAsyncCellErrCntr_2:
		if i /= 0 generate
			r_temp(i) <= r_temp(i-1) + unsigned(r_ZerosFiller_Oper & r_Operand(i));
		end generate;
	end generate;
	
	-- Misc
	r_ZerosFiller_Oper <= (others => '0');
	r_ZerosFiller_Addr <= (others => '0');
	
	-- Output 
	o_CU_Addr <= r_CurrentAddr;
	o_CU_StatusCE <= r_MAIN_Settings_B(3);
	o_CU_StatusOE <= r_MAIN_Settings_B(2);
	o_CU_Data_to <= r_CU_Data_to;
	-----------------------------------------------------
	
end architecture;
