library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_control_unit is
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
		i_StatusCE   : in    std_logic; --Between operations: '1' HIGH, '0' LOW
		i_StatusOE   : in    std_logic;
		
		i_Addr       : in    unsigned(g_ADDR_WIDTH-1 downto 0); -- Addr from MAIN that should be readed/writed e.t.c.
		o_Addr       : out   unsigned(g_ADDR_WIDTH-1 downto 0); -- Addr BUS to device
		i_Data       : in    std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data form MAIN 
		io_Data      : inout std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data io BUS to device
		o_Data       : out   std_logic_vector(g_DATA_WIDTH-1 downto 0); -- Data to MAIN
		
		o_WE_n 	     : out   std_logic;
		o_OE_n        : out   std_logic;
		o_CE_n       : out   std_logic;
		
		i_TimerID    : in    natural range 0 to 7; --[0: tAA, 1: tSA, 2: tHZWE, 3: tSD, 4: tHD]
		i_TimerValue : in    unsigned(7 downto 0)
	); 
		
end sram_control_unit;


architecture abrakadabra of sram_control_unit is


type t_State is (s_Idle, s_TimerInit, s_Read1, s_Read2, s_Write1, s_Write2, s_Write3, s_Write4);
signal r_State: t_State := s_Idle;

signal r_Addr : unsigned(g_ADDR_WIDTH-1 downto 0) := (others => '0');

signal r_Data_from : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
signal r_Data_to : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '1');
signal r_WE_n, r_OE_n, r_CE_n : std_logic := '1';


type t_TimerArray is array(0 to 7) of unsigned(7 downto 0);
signal r_TimerArray : t_TimerArray;
signal r_TimerCntr : t_TimerArray;
begin
	p_cu_SM: process(i_Clk, i_Reset)
	begin
		if i_Reset = '1' then
			o_Active <= '0';
			o_Done <= '0';
			r_Addr <= (others => '0');
			io_Data <= (others => 'Z');
			r_State <= s_Idle;

		elsif (rising_edge(i_Clk)) then
			case r_State is
				when s_Idle =>
					o_Active <= '0';
					o_Done <= '0';
					
					r_TimerCntr(0) <= (others => '0');
					r_TimerCntr(1) <= (others => '0');
					r_TimerCntr(2) <= (others => '0');
					r_TimerCntr(3) <= (others => '0');
					r_TimerCntr(4) <= (others => '0');
					r_TimerCntr(5) <= (others => '0');
					r_TimerCntr(6) <= (others => '0');
					r_TimerCntr(7) <= (others => '0');
					if i_Control = "00" then
						r_Addr <= (others => '0');
						io_Data <= (others => 'Z');
					end if;
					
					if i_Start = '1' then
						r_Data_to <= i_Data;
						r_Addr <= i_Addr;
						if i_Control = "01" then
							r_State <= s_Read1;
							o_Active <= '1';
						elsif i_Control = "10" then
							r_State <= s_Write1;
							o_Active <= '1';
						elsif i_Control = "11" then
							r_State <= s_TimerInit;
							o_Active <= '1';
						else
							r_State <= s_Idle;
						end if;
					else
						r_State <= s_Idle;
					end if;
					
				--SET TIMINGS
				when s_TimerInit =>
					if i_Control = "11" then
						r_TimerArray(i_TimerID) <= i_TimerValue;
						r_State <= s_TimerInit;
					else
						r_State <= s_Idle;
					end if;
					
				--READ OPERATION	
				when s_Read1 =>
					if r_TimerCntr(0) < r_TimerArray(0) then --tAA
						r_TimerCntr(0) <= r_TimerCntr(0) + 1;
						r_State <= s_Read1;							
					else
						r_Data_from <= io_Data;
						r_State <= s_Read2;					
					end if;
					
				when s_Read2 =>
					o_Done <= '1';
					r_State <= s_Idle;
				
				--WRITE OPERATION
				when s_Write1 =>
					if r_TimerCntr(1) < r_TimerArray(1) then --tSA
						r_TimerCntr(1) <= r_TimerCntr(1) + 1;
						r_State <= s_Write1;
					else
						r_State <= s_Write2;
					end if;
					
				when s_Write2 =>
					if r_TimerCntr(2) < r_TimerArray(2) then --tHZWE
						r_TimerCntr(2) <= r_TimerCntr(2) + 1;
						r_State <= s_Write2;
					else
						io_Data <= r_Data_to;
						r_State <= s_Write3;
					end if;
					
				when s_Write3 =>
					if r_TimerCntr(3) < r_TimerArray(3) then --tSD
						r_TimerCntr(3) <= r_TimerCntr(3) + 1;
						r_State <= s_Write3;
					else
						r_State <= s_Write4;
					end if;

				when s_Write4 =>
					if r_TimerCntr(4) < r_TimerArray(4) then	--tHD					
						r_TimerCntr(4) <= r_TimerCntr(4) + 1;
						r_State <= s_Write4;
					else
						r_State <= s_Idle;
						o_Done <= '1';
					end if;

				when others =>

				end case;
		end if;
	end process p_cu_SM;
	
	p_output: process(r_State, i_StatusCE, i_StatusOE)
	begin
		r_CE_n <= '1';
		r_OE_n <= '1';
		r_WE_n <= '1';
		case r_State is
			when s_Idle => 
				r_CE_n <= '1' and i_StatusCE;
				r_OE_n <= '1' and i_StatusOE;
				r_WE_n <= '1';
		
			when s_TimerInit =>
				r_CE_n <= '1' and i_StatusCE;
				r_OE_n <= '1';
				r_WE_n <= '1';
				
			when s_Read1 =>
				r_CE_n <= '0';
				r_OE_n <= '0';
				r_WE_n <= '1';
			when s_Read2 => 
				r_CE_n <= '0';
				r_OE_n <= '0';
				r_WE_n <= '1';
				
			when s_Write1 =>
				r_CE_n <= '0';
				r_OE_n <= '1';
				r_WE_n <= '1';
			when s_Write2 =>
				r_CE_n <= '0';
				r_OE_n <= '1';
				r_WE_n <= '0';
			when s_Write3 => 
				r_CE_n <= '0';
				r_OE_n <= '1';
				r_WE_n <= '0';
			when s_Write4 =>
				r_CE_n <= '0';
				r_OE_n <= '1';
				r_WE_n <= '1';
		end case;
	end process;
	
	o_CE_n <= r_CE_n;
	o_WE_n <= r_WE_n;
	o_OE_n <= r_OE_n when i_Control = "01" else '1';
	
	
	o_Addr <= r_Addr;
	
	o_Data <= r_Data_from;
	

end architecture;
