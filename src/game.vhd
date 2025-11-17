library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game is
    port (
        clk_50   : in  std_logic;       -- 50 MHz base clock
        reset_n  : in  std_logic;
		  goal_led	:	out	std_logic;	 -- Led to indicate goal

        -- Player movement buttons (active low)
        btn_up    : in std_logic;
        btn_down  : in std_logic;
        btn_left  : in std_logic;
        btn_right : in std_logic;

        -- HDMI transmitter (ADV7513)
        hdmi_clk  : out std_logic;
        hdmi_hs   : out std_logic;
        hdmi_vs   : out std_logic;
        hdmi_de   : out std_logic;
        hdmi_r    : out std_logic_vector(7 downto 0);
        hdmi_g    : out std_logic_vector(7 downto 0);
        hdmi_b    : out std_logic_vector(7 downto 0);
		  
		  -- 7-segment display
		  display0	: out std_logic_vector (0 to 6);
		  display1	: out std_logic_vector (0 to 6);
		  display2	: out std_logic_vector (0 to 6);
		  display3	: out std_logic_vector (0 to 6)
		  
		  
    );
end entity;

architecture rtl of game is

    -- VGA 640x480 @ 60Hz parameters
    constant H_ACTIVE  : integer := 640;
    constant H_FP      : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BP      : integer := 48;
    constant H_TOTAL   : integer := H_ACTIVE + H_FP + H_SYNC + H_BP; -- 800

    constant V_ACTIVE  : integer := 480;
    constant V_FP      : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BP      : integer := 33;
    constant V_TOTAL   : integer := V_ACTIVE + V_FP + V_SYNC + V_BP; -- 525

    signal pix_clk     : std_logic;
    signal x, y        : integer range 0 to H_TOTAL-1 := 0;
	 
    signal player_x    : integer range 0 to H_ACTIVE-1 := 200;
    signal player_y    : integer range 0 to V_ACTIVE-1 := 200;
    signal player_size : integer := 15; -- Player is a 15x15 square
    signal hsync, vsync, de : std_logic;
	 signal counter_stop	:	integer := 0;
	 signal goal	:	integer := 0;

    signal move_counter : unsigned(25 downto 0) := (others => '0');
	 signal display0_counter : unsigned(25 downto 0) := (others => '0');

	 
	 signal displayed_number	:	std_logic_vector (11 downto 0);	-- This is the displayed number
	 signal LED_BIN0	:	std_logic_vector (3 downto 0);
	 signal LED_BIN1	:	std_logic_vector (3 downto 0);
	 signal LED_BIN2	:	std_logic_vector (3 downto 0);
	 signal LED_BIN3	:	std_logic_vector (3 downto 0);
	 signal counters	:	std_logic_vector (19 downto 9);
	 
	 -- Create goal integer
	 --constant goal : integer;

    -- Create wall boundaries
    constant WALL_THICKNESS : integer := 20;

    constant WALL1_Y_MIN : integer := 70;
    constant WALL1_Y_MAX : integer := 90;
    constant WALL1_X_MIN : integer := 80;
    constant WALL1_X_MAX : integer := H_ACTIVE;

    constant WALL2_Y_MIN : integer := 170;
    constant WALL2_Y_MAX : integer := 190;
    constant WALL2_X_MIN : integer := 0;
    constant WALL2_X_MAX : integer := 500;

    constant WALL3_Y_MIN : integer := 270;
    constant WALL3_Y_MAX : integer := 290;
    constant WALL3_X_MIN : integer := 80;
    constant WALL3_X_MAX : integer := H_ACTIVE;

    constant WALL4_Y_MIN : integer := 370;
    constant WALL4_Y_MAX : integer := 390;
    constant WALL4_X_MIN : integer := 0;
    constant WALL4_X_MAX : integer := 500;
	 
	 constant GOAL_Y_MIN : integer := 390;
	 constant GOAL_Y_MAX : integer := 480;
	 constant GOAL_X_MIN : integer := 0;
	 constant GOAL_X_MAX : integer := 90;




begin

    ------------------------------------------------------------------------
    -- Pixel Clock (divide 50 MHz by 2 -> 25 MHz)
    ------------------------------------------------------------------------
    process(clk_50)
        variable div : std_logic := '0';
    begin
        if rising_edge(clk_50) then
            div := not div;
            pix_clk <= div;
        end if;
    end process;

    hdmi_clk <= pix_clk;

    ------------------------------------------------------------------------
    -- Horizontal and Vertical Counters
    ------------------------------------------------------------------------
    process(pix_clk, reset_n)
    begin
        if reset_n = '0' then
            x <= 0;
            y <= 0;
        elsif rising_edge(pix_clk) then
            if x = H_TOTAL-1 then
                x <= 0;
                if y = V_TOTAL-1 then
                    y <= 0;
                else
                    y <= y + 1;
                end if;
            else
                x <= x + 1;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Generate Syncs and DE
    ------------------------------------------------------------------------
    hsync <= '0' when (x >= (H_ACTIVE + H_FP) and x < (H_ACTIVE + H_FP + H_SYNC)) else '1';
    vsync <= '0' when (y >= (V_ACTIVE + V_FP) and y < (V_ACTIVE + V_FP + V_SYNC)) else '1';
    de    <= '1' when (x < H_ACTIVE and y < V_ACTIVE) else '0';

    hdmi_hs <= hsync;
    hdmi_vs <= vsync;
    hdmi_de <= de;

    ------------------------------------------------------------------------
    -- Player, wall and goal rendering
    ------------------------------------------------------------------------
    process(x, y, de, player_x, player_y, player_size)
        variable r, g, b : std_logic_vector(7 downto 0);
    begin
        if de = '1' then
            if (y > player_y - player_size and y < player_y + player_size) and
               (x > player_x - player_size and x < player_x + player_size) then
                r := (others => '1');
                g := (others => '1');
                b := (others => '0');
					 
				-- Create maze path walls
				elsif y > WALL1_Y_MIN and y < WALL1_Y_MAX and x > WALL1_X_MIN then
					r := "00000000"; g := "00000000"; b := "11111110";
				elsif y > WALL2_Y_MIN and y < WALL2_Y_MAX and x < WALL2_X_MAX then
					r := "00000000"; g := "00000000"; b := "11111110";
				elsif y > WALL3_Y_MIN and y < WALL3_Y_MAX and x > WALL3_X_MIN then
					r := "00000000"; g := "00000000"; b := "11111110";
				elsif y > WALL4_Y_MIN and y < WALL4_Y_MAX and x < WALL4_X_MAX then
					r := "00000000"; g := "00000000"; b := "11111110";
					
				-- Create goal
				elsif y > GOAL_Y_MIN and y < GOAL_Y_MAX and x < GOAL_X_MAX then
					r := "00000000"; g := "11111110"; b := "00000000";
					
            else
                r := (others => '0');
                g := (others => '0');
                b := (others => '0');
            end if;
        else
            r := (others => '0');
            g := (others => '0');
            b := (others => '0');
        end if;

        hdmi_r <= r;
        hdmi_g <= g;
        hdmi_b <= b;
    end process;

    ------------------------------------------------------------------------
    -- Player movement and COLLISION DETECTION
    ------------------------------------------------------------------------
    process(clk_50, reset_n)
        variable next_player_x : integer range 0 to H_ACTIVE-1;
        variable next_player_y : integer range 0 to V_ACTIVE-1;
        variable collision : boolean;
		  
    begin
        if reset_n = '0' then
            move_counter <= (others => '0');
            player_x <= 620;
            player_y <= 20;
			   goal_led <= '0';
				counter_stop <= 1;
				goal <= 0;

        elsif rising_edge(clk_50) then
            move_counter <= move_counter + 1;

				-- counter used for player movement is divided by 100k so that the movement speed is reasonable
            if move_counter = 100000 then 
                move_counter <= (others => '0');

                -- Store current position as the base for the next position check
                next_player_x := player_x;
                next_player_y := player_y;
					 
					 -- Depending on the button pressed, it will store the next location of the player and use that to determine if it can move there or not

                -- Check horizontal movement and boundaries
                if btn_left = '0' then
						  counter_stop <= 0;
                    next_player_x := player_x - 1;
                elsif btn_right = '0' then
						  counter_stop <= 0;
                    next_player_x := player_x + 1;
                end if;

                -- Check vertical movement and boundaries
                if btn_up = '0' then
						  counter_stop <= 0;
                    next_player_y := player_y - 1;
                elsif btn_down = '0' then
						  counter_stop <= 0;
                    next_player_y := player_y + 1;
                end if;
					 

                -- Check screen boundaries first
                collision := FALSE;
					 --goal_led <= '0';
                if next_player_x < player_size or next_player_x > H_ACTIVE - player_size or
                   next_player_y < player_size or next_player_y > V_ACTIVE - player_size then
                    collision := TRUE;
                end if;
					 
					 -- If next position is inside wall, collision is true

                -- Check against Wall 1
                if not collision and 
                   next_player_y + player_size > WALL1_Y_MIN and next_player_y - player_size < WALL1_Y_MAX and		
                   next_player_x + player_size > WALL1_X_MIN then 
                    collision := TRUE;
                end if;
                
                -- Check against Wall 2
                if not collision and
                   next_player_y + player_size > WALL2_Y_MIN and next_player_y - player_size < WALL2_Y_MAX and
                   next_player_x - player_size < WALL2_X_MAX then
                    collision := TRUE;
                end if;

                -- Check against Wall 3
                if not collision and
                   next_player_y + player_size > WALL3_Y_MIN and next_player_y - player_size < WALL3_Y_MAX and
                   next_player_x + player_size > WALL3_X_MIN then
                    collision := TRUE;
                end if;

                -- Check against Wall 4
                if not collision and
                   next_player_y + player_size > WALL4_Y_MIN and next_player_y - player_size < WALL4_Y_MAX and
                   next_player_x - player_size < WALL4_X_MAX then
                    collision := TRUE;
                end if;
					 
					 -- Check goal
                if not collision and
                   next_player_y + player_size > GOAL_Y_MIN and next_player_y - player_size < GOAL_Y_MAX and
                   next_player_x - player_size < GOAL_X_MAX then
							goal_led <= '1';
							counter_stop <= 1;
							goal <= 1;
							--LED_BIN0 <= "0001";
                end if;
                
                -- Update player position only if no collision is detected
                if not collision then
                    player_x <= next_player_x;
                    player_y <= next_player_y;
                end if;
					 
            end if;
        end if;
    end process;
	 
	 ------------------------------------------------------------------------
    -- 7-Segment display write
    ------------------------------------------------------------------------
	 process(LED_BIN0, LED_BIN1, LED_BIN2, LED_BIN3)
	 begin
	 
		-- When LED_BIN0 is for example 0001, process sends signal to 7-segment display to turn on the required leds for the number.
		case LED_BIN0 is
		when "0000" => display0 <= "0000001"; -- "0"     
		when "0001" => display0 <= "1001111"; -- "1" 	
		when "0010" => display0 <= "0010010"; -- "2" 
		when "0011" => display0 <= "0000110"; -- "3" 
		when "0100" => display0 <= "1001100"; -- "4" 
		when "0101" => display0 <= "0100100"; -- "5" 
		when "0110" => display0 <= "0100000"; -- "6" 
		when "0111" => display0 <= "0001111"; -- "7" 
		when "1000" => display0 <= "0000000"; -- "8"     
		when "1001" => display0 <= "0000100"; -- "9"
		when others => display0 <= "1111111"; -- "null"
		end case;
		
		case LED_BIN1 is
		when "0000" => display1 <= "0000001"; -- "0"     
		when "0001" => display1 <= "1001111"; -- "1" 
		when "0010" => display1 <= "0010010"; -- "2" 
		when "0011" => display1 <= "0000110"; -- "3" 
		when "0100" => display1 <= "1001100"; -- "4" 
		when "0101" => display1 <= "0100100"; -- "5" 
		when "0110" => display1 <= "0100000"; -- "6" 
		when "0111" => display1 <= "0001111"; -- "7" 
		when "1000" => display1 <= "0000000"; -- "8"     
		when "1001" => display1 <= "0000100"; -- "9"
		when others => display1 <= "1111111"; -- "null"
		end case;
		
		case LED_BIN2 is
		when "0000" => display2 <= "0000001"; -- "0"     
		when "0001" => display2 <= "1001111"; -- "1" 
		when "0010" => display2 <= "0010010"; -- "2" 
		when "0011" => display2 <= "0000110"; -- "3" 
		when "0100" => display2 <= "1001100"; -- "4" 
		when "0101" => display2 <= "0100100"; -- "5" 
		when "0110" => display2 <= "0100000"; -- "6" 
		when "0111" => display2 <= "0001111"; -- "7" 
		when "1000" => display2 <= "0000000"; -- "8"     
		when "1001" => display2 <= "0000100"; -- "9"
		when others => display2 <= "1111111"; -- "null"
		end case;
		
		case LED_BIN3 is
		when "0000" => display3 <= "0000001"; -- "0"     
		when "0001" => display3 <= "1001111"; -- "1" 
		when "0010" => display3 <= "0010010"; -- "2" 
		when "0011" => display3 <= "0000110"; -- "3" 
		when "0100" => display3 <= "1001100"; -- "4" 
		when "0101" => display3 <= "0100100"; -- "5" 
		when "0110" => display3 <= "0100000"; -- "6" 
		when "0111" => display3 <= "0001111"; -- "7" 
		when "1000" => display3 <= "0000000"; -- "8"     
		when "1001" => display3 <= "0000100"; -- "9"
		when others => display3 <= "1111111"; -- "null"
		end case;
		
    end process;
	 
	 ------------------------------------------------------------------------
    -- 7-Segment display timer
    ------------------------------------------------------------------------
	process(clk_50, reset_n)
		begin
			-- As default all 7-segment numbers are set to 0
			if reset_n = '0' then							
            display0_counter <= (others => '0');
				LED_BIN0 <= "0000";
				LED_BIN1 <= "0000";
				LED_BIN2 <= "0000";
				LED_BIN3 <= "0000";
				
			-- When counter_stop variable is set to 0, the timer starts
			elsif rising_edge(clk_50) and counter_stop = 0 and goal = 0 then	
            display0_counter <= display0_counter + 1;

				-- The first display shows 1000ms accuracy, this is achieved by dividing the 50MHz clock by 500k so we get 100Hz.
            if display0_counter = 500000 then 						
                display0_counter <= (others => '0');				
					 LED_BIN0 <= std_logic_vector(unsigned(LED_BIN0) + 1);
					 
					 -- When the first 100Hz display reaches 9, second display increases by 1. This way we get a 10Hz accuracy display.
					 if LED_BIN0 = "1001" then								
						LED_BIN0 <= "0000";
						LED_BIN1 <= std_logic_vector(unsigned(LED_BIN1) + 1);
						
						-- When the 10Hz accuracy display reaches 9, the third display increases by 1. This way we get a 10ms accuracy display.
						if LED_BIN1 = "1001" then							
						LED_BIN1 <= "0000";
						LED_BIN2 <= std_logic_vector(unsigned(LED_BIN2) + 1);
						
							if LED_BIN2 = "1001" then							
							LED_BIN2 <= "0000";
							LED_BIN3 <= std_logic_vector(unsigned(LED_BIN3) + 1);
							end if;
						end if;	
					 end if;
 				end if;
			end if;
			
	end process;
	 
end architecture;
