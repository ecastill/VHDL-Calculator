library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
------------------------------------------------------------------------------------
--
--
entity left_right_leds is
	generic (
		bus_width : integher := 8;
	);
    Port (             led : out std_logic_vector(7 downto 0);
                  rotary_a : in std_logic;
                  rotary_b : in std_logic;
              rotary_press : in std_logic;
                       clk : in std_logic;
                       PB  : in std_logic_vector(3 downto 0);
                       SW  : in std_logic
                      );
    end left_right_leds;
--
------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture Behavioral of left_right_leds is
--
------------------------------------------------------------------------------------
--
-- Signals used to interface to rotary encoder
--
signal      rotary_a_in : std_logic;
signal      rotary_b_in : std_logic;
signal  rotary_press_in : std_logic;
signal        rotary_in : std_logic_vector(1 downto 0);
signal        rotary_q1 : std_logic;
signal        rotary_q2 : std_logic;
signal  delay_rotary_q1 : std_logic;
signal     rotary_event : std_logic;
signal      rotary_left : std_logic;
--
-- Signals to represent registers
--
signal               R1 : std_logic_vector(bus_width-1 downto 0) := (others => '0');
signal               R2 : std_logic_vector(bus_width-1 downto 0) := (others => '0');
signal               R3 : std_logic_vector(bus_width-1 downto 0) := (others => '1');
signal               CNT: std_logic_vector(bus_width-1 downto 0) := (others => '0');
signal               AC_PART: std_logic_vector(bus_width-1 downto 0) := (others => '0');
signal 				 ACC: std_logic_vector(bus_width*2-1 downto 0) := (others => '0');
signal 				 FF : std_logic;
signal 		      start : std_logic;
alias 				  M : std_logic is ACC(0);
signal            state : integer range 0 to (bus_width + 1) * 2 := 0;

--
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--
-- Start of circuit description
--
begin
  --
  ----------------------------------------------------------------------------------------------------------------------------------
  -- Interface to rotary encoder.
  -- Detection of movement and direction.
  ----------------------------------------------------------------------------------------------------------------------------------
  --
  -- The rotary switch contacts are filtered using their offset (one-hot) style to  
  -- clean them. Circuit concept by Peter Alfke.
  -- Note that the clock rate is fast compared with the switch rate.

  rotary_filter: process(clk)
  begin
    if clk'event and clk='1' then

      --Synchronise inputs to clock domain using flip-flops in input/output blocks.
      rotary_a_in <= rotary_a;
      rotary_b_in <= rotary_b;
      rotary_press_in <= rotary_press;

      --concatinate rotary input signals to form vector for case construct.
      rotary_in <= rotary_b_in & rotary_a_in;

      case rotary_in is

        when "00" => rotary_q1 <= '0';         
                     rotary_q2 <= rotary_q2;
 
        when "01" => rotary_q1 <= rotary_q1;
                     rotary_q2 <= '0';

        when "10" => rotary_q1 <= rotary_q1;
                     rotary_q2 <= '1';

        when "11" => rotary_q1 <= '1';
                     rotary_q2 <= rotary_q2; 

        when others => rotary_q1 <= rotary_q1; 
                       rotary_q2 <= rotary_q2; 
      end case;

    end if;
  end process rotary_filter;
  --
  -- The rising edges of 'rotary_q1' indicate that a rotation has occurred and the 
  -- state of 'rotary_q2' at that time will indicate the direction. 
  --
  direction: process(clk)
  begin
    if clk'event and clk='1' then

      delay_rotary_q1 <= rotary_q1;
      if rotary_q1='1' and delay_rotary_q1='0' then
        rotary_event <= '1';
        rotary_left <= rotary_q2;
       else
        rotary_event <= '0';
        rotary_left <= rotary_left;
      end if;

    end if;
  end process direction;
	--
	--  
	----------------------------------------------------------------------------------------------------------------------------------
	-- Register control.
	----------------------------------------------------------------------------------------------------------------------------------
	reg_control: process(clk)
	begin
		if clk'event and clk='1' then
			if rotary_event = '1' then
				if PB = "1000" then
					if rotary_left = '1' then
						R1 <= R1 - '1';
					else 
						R1 <= R1 + '1';
					end if;
				elsif PB = "0100" then 		
					if rotary_left = '1' then
						R2 <= R2 - '1';
					else 
						R2 <= R2 + '1';
					end if;
				elsif PB = "1100" then 		
					if rotary_left = '1' then
						R3 <= R3 - '1';
					else 
						R3 <= R3 + '1';
					end if;	
				else 
					-- Ignore rotary events
					if rotary_left = '1' then	
						AC_PART <= ACC(7 downto 0);
					else 
						AC_PART <= ACC(15 downto 8);
					end if;
				end if;
			end if;			
		end if;
	end process reg_control;
  
	--
	--
	----------------------------------------------------------------------------------------------------------------------------------
	-- LED control.
	----------------------------------------------------------------------------------------------------------------------------------
	--
	--~ counter: process(clk)
	--~ begin
	--~ if clk'event and clk='1' then
		--~ CNT <= CNT + '1';
	--~ end process counter;
	CNT <= CNT + '1' when rising_edge(clk);
	--
	led_display: process(clk)
	begin
		if clk'event and clk='1' then
			if CNT < R3 then
				if PB = "1000" then
					led <= R1;
				elsif PB = "0100" then 		
					led <= R2;
				elsif PB = "1100" then 		
					led <= R3;			
				else 
					led <= AC_PART;
				end if;
			else 
				led <= AC_PART;
			end if;
		end if;
	end process led_display;
	--
	--
	start_detector: process(clk) is begin
		if rising_edge(clk) then
			FF <= rotary_press;
			start <= '0';
			if rotary_press = '1' and FF = '0' then
				start <= '1';
			end if;
		end if;
	end process start_detector;
	--
	--
	FSM: process(clk) is begin
		if rising_edge(clk) then
			RDY <= '0';
			case state is
				when 0 =>
					if start = '1' then
						state <= 1;
						ACC <= (7 downto 0 => R2, others => '0');
					end if;
				when 1 | 3 |5 | 7 | 9 | 11 | 13 |15 =>
					if M = '1' then
						ACC(16 downto 8) <= '0' & ACC(15 downto 8) +_R1;
						State <= State + 1;
					else
						ACC <= '0' & ACC(16 downto 1); --shift accumulator right
						state<= state+2;
					end if;
				when 2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 =>	--just shift
					ACC<='0' & ACC(16 downto 1);	--right shift	
					state<= state + 1;
				when 17 => 
					RDY <= '1';
			end case;
		end if;
	end process FSM;
	
  
end Behavioral;




------------------------------------------------------------------------------------------------------------------------------------
--
-- END OF FILE left_right_leds.vhd
--
------------------------------------------------------------------------------------------------------------------------------------

