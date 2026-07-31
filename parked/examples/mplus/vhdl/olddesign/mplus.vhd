  
--------------------------------------------------------------------------------
-- Company:        The OS-9 Project
-- Engineer:       Edouard Forler
-- Create Date:    11:08:17 11/07/2022
-- Design Name:    Extension Musique Plus
-- Module Name:    Controller - Behavioral
-- Project Name:   Extension Musique Plus
-- Target Devices: XC9572XL VQFP-64
-- Tool versions:  ISE 8.1 and later
--
-- Description:
--   Controller for the Musique Plus extension card.
--
-- Dependencies:
--   None.
--
-- Revision:
--   Revision 0.1 - Basic features implemented, not tested.
--
-- Additional Comments:
--   in ISE, edit process properties and use the implementation template named
--   "optimize density", otherwise the design will not fit
--   disable global Clocks, global Output Enables, global Set/Reset
--
-- Register map :
--   x7F0-F1 : Ext3 - for future use
--   x7F2-F3 : Ext2 - MIDI (EF6850)
--   x7F4-F5 : MPlus Timer period
--   x7F6    : MPlus Ctrl.
--   x7F7    : SN76489 (TI)
--   x7F8-FB : Ext4 - for future use
--   x7FC-FD : YM2413 (YM)
--   x7FE-FF : Ext1 - MEA8000
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity controller is
  Port (   Thm_E     : in    STD_LOGIC;                      -- E from Thomson bus
           Thm_RW    : in    STD_LOGIC;                      -- R/W# from Thomson bus
           Thm_Reset : in    STD_LOGIC;                      -- Reset# from Thomson bus
                     
           Thm_Exxx  : in    STD_LOGIC;                      -- Exxx# from Thomson bus
           Thm_FFDx  : in    STD_LOGIC;                      -- FFDx# from Thomson bus
           Thm_Adr   : in    STD_LOGIC_VECTOR (11 downto 0); -- A0..A11 from Thomson bus
           Thm_D     : inout STD_LOGIC_VECTOR (7 downto 0);  -- D0..D7 from Thomson bus
                     
           Thm_IRQ   : out   STD_LOGIC;                      -- IRQ from Thomson bus
           Thm_FIRQ  : out   STD_LOGIC;                      -- FIRQ from Thomson bus
                     
           XCK       : in    STD_LOGIC;                      -- 3.579545MHz clock
                     
           CK_TI     : out   STD_LOGIC;                      -- TI chip clock
           CE_TI     : out   STD_LOGIC;                      -- TI chip enable
           RDY_TI    : in    STD_LOGIC;                      -- TI chip ready
           D_TI      : out   STD_LOGIC_VECTOR (7 downto 0);  -- D0..D7 to TI chip
                     
           CE_YM     : out   STD_LOGIC;                      -- YM chip enable
                     
           CE_Ext1   : out   STD_LOGIC;                      -- Ext1 chip enable
           CE_Ext2   : out   STD_LOGIC;                      -- Ext2 chip enable
           CE_Ext3   : out   STD_LOGIC;                      -- Ext3 chip enable
           CE_Ext4   : out   STD_LOGIC;                      -- Ext4 chip enable
           CE_Ext5   : out   STD_LOGIC                       -- Ext5 chip enable
       );
end controller;

architecture Behavioral of controller is

  signal ctrl_reg : std_logic_vector (4 downto 0);         -- Control/status register
                                                           --   Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
                                                           --          -W Timer - reset timer by reloading period to counter
                                                           --   Bit 6: -------  - Unused
                                                           --   Bit 5: -------  - Unused
                                                           --   Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
                                                           --   Bit 3: RW Timer - (F)IRQ (0=disabled, 1=enabled)
                                                           --   Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                                                           --   Bit 1: RW Timer - countdown of timer (0=disabled, 1=enabled)
                                                           --   Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
                                                           --   Notes : - Timer F/IRQ ack by CPU is done by reading this control register
                                                           --           - TI clock enable will be effective only after the first write to TI data register

  signal base_address    : std_logic;                      -- Address decoder
  signal base_address_mb : std_logic;                      -- Address decoder for main board
  signal write_enable    : std_logic;                      -- Write enable on register
  signal ti_auto_enable  : std_logic;                      -- TI auto enable at first write
  signal ti_data         : std_logic_vector (7 downto 0);  -- TI Transparent D Latch
  signal counter         : std_logic_vector (15 downto 0); -- Counter register
  signal counter_reset   : std_logic;                      -- Counter reset requested by user
  signal timer_per       : std_logic_vector (15 downto 0); -- Period register
  signal clock           : std_logic;                      -- Timer clock selection
  signal int_timer_ack   : std_logic;                      -- Timer interruption ack flag

begin

    -- Address decoding
    base_address <= '0'    when Thm_Exxx = '0' and Thm_Adr(11 downto 4) = "01111111" else '1';
    base_address_mb <= '0' when base_address = '0' and Thm_Adr(3 downto 2) = "01" else '1';
    write_enable <= '0'    when base_address_mb = '0' and Thm_RW = '0' else '1';

    -- Main Board - Audio chips ------------------------------------------------

    -- TI - Chip enable
    CE_TI <= '0' when (Thm_E = '1' and write_enable = '0' and Thm_Adr(1 downto 0) = "11") or RDY_TI = '0' else '1';

    -- TI - Write Transparent D Latch
    ti_data <= Thm_D when RDY_TI = '1' and Thm_E = '1' and write_enable = '0' and Thm_Adr(1 downto 0) = "11" else ti_data;
    D_TI <= ti_data;

    -- TI - auto enable Flip Flops
    process (Thm_Reset, Thm_E)
    begin
      if Thm_Reset = '0' then
        ti_auto_enable <= '0';
      else
        if Thm_E'event and Thm_E = '1' then
          if write_enable = '0' and Thm_Adr(1 downto 0) = "11" then
            ti_auto_enable <= '1';
          end if;
        end if;
      end if;
    end process;

    -- TI - Enable or disable clock
    CK_TI <= XCK when ctrl_reg(0) = '0' and ti_auto_enable = '1' else '0';

    -- YM - Chip enable
    CE_YM <= '0' when Thm_Exxx = '0' and Thm_Adr(11 downto 1) = "01111111110" and Thm_E = '1' else '1';

    -- Main Board - Timer ------------------------------------------------------

    -- Timer - Select internal or external clock
    clock <= Thm_E when ctrl_reg(2) = '0' else XCK;

    -- Timer - Main logic
    process (Thm_Reset, clock)
    begin
      if Thm_Reset = '0' then
        ctrl_reg(4 downto 0) <= (others=> '0');
        int_timer_ack <= '0';
      else
        if clock'event and clock='1' then

          -- Countdown
          if counter = 0 or counter_reset = '1' then
            counter <= timer_per; 
            int_timer_ack <= '1';
            counter_reset <= '0';
          else
            if ctrl_reg(1) = '1' then
              counter <= counter - 1;
            end if;
          end if;

          if Thm_E = '1' and Thm_Exxx = '0' and Thm_Adr(11 downto 2) = "0111111101" then
       
            -- Read or Write Period Register
            if Thm_Adr(1) = '0' then
              if Thm_Adr(0) = '0' then
                if Thm_RW = '1' then
                  Thm_D <= counter(15 downto 8);
                else
                  timer_per(15 downto 8) <= Thm_D(7 downto 0);
                end if;
              else
                if Thm_RW = '1' then
                  Thm_D <= counter( 7 downto 0);
                else
                  timer_per(7 downto 0) <= Thm_D(7 downto 0);
                  counter_reset <= '1';
                end if;
              end if;
            else
        
              -- Read or Write Control Register
              if Thm_Adr(0) = '0' then
                if Thm_RW = '1' then
                  Thm_D <= int_timer_ack & "00" & ctrl_reg(4 downto 0);
                  int_timer_ack <= '0'; -- INT acknowledge
                else
                  ctrl_reg(4 downto 0) <= Thm_D(4 downto 0);
                  counter_reset <= Thm_D(7);
                  if Thm_D(3) = '0' then
                    int_timer_ack <= '0'; -- clear remaining int request if int are disabled
                  end if;
                end if;
              else
                -- Read TI data
                if Thm_RW = '1' then
                  Thm_D <= ti_data;
                end if;
              end if;
            end if;
			 else
            Thm_D <= (others=> 'Z');
          end if;       
        end if;
      end if;
    end process;

    -- Timer - Interrupts
    Thm_IRQ  <= '0' when int_timer_ack = '1' and ctrl_reg(3) = '1' and ctrl_reg(4) = '0' else 'Z';
    Thm_FIRQ <= '0' when int_timer_ack = '1' and ctrl_reg(3) = '1' and ctrl_reg(4) = '1' else 'Z';

    -- Daughter board
    CE_Ext1 <= '0' when base_address = '0' and Thm_Adr(3 downto 1) = "001" and Thm_E = '1' else '1'; -- MIDI    : $x7F2-F3
    CE_Ext2 <= '0' when base_address = '0' and Thm_Adr(3 downto 1) = "111" and Thm_E = '1' else '1'; -- MEA8000 : $x7FE-FF
    CE_Ext3 <= '0' when base_address = '0' and Thm_Adr(3 downto 1) = "000" and Thm_E = '1' else '1'; -- Unknown : $x7F0-F1
    CE_Ext4 <= '0' when base_address = '0' and Thm_Adr(3 downto 2) = "10"  and Thm_E = '1' else '1'; -- Unknown : $x7F8-FB

end Behavioral;