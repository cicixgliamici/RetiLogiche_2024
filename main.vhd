library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
    port (
        i_clk   : in std_logic;  -- Main clock signal
        i_rst   : in std_logic;  -- Reset signal (reinitializes state machine)
        i_start : in std_logic;  -- Start processing trigger
        i_add   : in std_logic_vector(15 downto 0);  -- Starting memory address
        i_k     : in std_logic_vector(9 downto 0);   -- Number of words to process
        
        o_done  : out std_logic;  -- Completion signal
        
        o_mem_addr : out std_logic_vector(15 downto 0);  -- Memory address bus
        i_mem_data : in std_logic_vector(7 downto 0);     -- Memory data input
        o_mem_data : out std_logic_vector(7 downto 0);    -- Memory data output
        o_mem_we   : out std_logic;  -- Write enable (1=Write, 0=Read)
        o_mem_en   : out std_logic   -- Memory enable (active high)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
-- State Machine Definition
type state_type is (
    rst,   -- Reset state
    s0,    -- Initial processing state
    s1,    -- Data read evaluation
    s2,    -- Handle non-zero value
    sX,    -- Address increment after write
    s3,    -- Prepare next address
    s4,    -- Handle zero value (write previous value)
    sZ,    -- Credibility calculation state
    s5,    -- Write credibility value
    sY,    -- Prepare for next operation
    s6,    -- Handle initial zero case
    s7,    -- Skip double address
    s8,    -- Decrement counter
    fnl    -- Final completion state
);
signal state: state_type;

-- Internal Signals
signal decounter: integer range 0 to 31;  -- Credibility value calculator
signal kappa: integer range 0 to 511;     -- Processed words counter
signal out_mem_addr: std_logic_vector(15 downto 0) := (others => '0');  -- Current memory address
signal valore_utile: std_logic_vector(7 downto 0) := (others => '0');  -- Last valid non-zero value

begin

process(i_clk, i_rst)
begin
    -- Reset Handling
    if i_rst = '1' then
        o_mem_en <= '0';
        o_mem_we <= '0';
        o_done <= '0';
        state <= rst;
    
    -- Clock Edge Processing
    elsif rising_edge(i_clk) then
        case state is
            -- Reset State
            when rst =>
                if i_start = '1' then
                    o_mem_en <= '1';
                    o_mem_we <= '0';
                    o_done <= '0';
                    o_mem_addr <= i_add;
                    out_mem_addr <= i_add;
                    kappa <= to_integer(unsigned(i_k));
                    state <= s0;
                end if;
            
            -- State 0: Initial Processing
            when s0 =>
                if kappa = 0 then
                    state <= fnl;
                else
                    state <= s1;
                end if;
            
            -- State 1: Data Evaluation
            when s1 =>
                if (to_integer(unsigned(i_k)) = kappa and i_mem_data = "00000000") then
                    state <= s6;
                elsif i_mem_data = "00000000" then
                    state <= s4;
                else
                    valore_utile <= i_mem_data;
                    out_mem_addr <= out_mem_addr + 1;
                    state <= s2;
                end if;
            
            -- States 2-X-3: Non-zero Value Handling
            when s2 =>  -- Write 0x1F and prepare next address
                o_mem_we <= '1';
                o_mem_data <= "00011111";
                o_mem_addr <= out_mem_addr;
                decounter <= 0;
                state <= sX;
            
            when sX =>  -- Address increment
                out_mem_addr <= out_mem_addr + 1;
                state <= s3;
            
            when s3 =>  -- Prepare next read
                o_mem_we <= '0';
                kappa <= kappa - 1;
                state <= s0;
            
            -- States 4-Z-5-Y: Zero Value Handling
            when s4 =>  -- Write previous valid value
                o_mem_we <= '1';
                o_mem_data <= valore_utile;
                out_mem_addr <= out_mem_addr + 1;
                decounter <= decounter + 1;
                state <= sZ;
            
            when sZ =>  -- Prepare credibility calculation
                o_mem_we <= '0';
                state <= s5;
            
            when s5 =>  -- Write credibility value (31-N)
                o_mem_we <= '1';
                if decounter <= 31 then
                    o_mem_data <= std_logic_vector(to_unsigned(31 - decounter, 8));
                else
                    o_mem_data <= (others => '0');
                end if;
                out_mem_addr <= out_mem_addr + 1;
                kappa <= kappa - 1;
                state <= sY;
            
            when sY =>  -- Prepare next operation
                o_mem_we <= '0';
                state <= s0;
            
            -- States 6-7-8: Initial Zero Handling
            when s6 =>  -- Special case for initial zero
                if kappa = 0 then
                    state <= fnl;
                elsif i_mem_data = "00000000" then
                    out_mem_addr <= out_mem_addr + 2;
                    state <= s7;
                else
                    valore_utile <= i_mem_data;
                    out_mem_addr <= out_mem_addr + 1;
                    state <= s2;
                end if;
            
            when s7 =>  -- Address adjustment
                o_mem_addr <= out_mem_addr;
                state <= s8;
            
            when s8 =>  -- Counter decrement
                kappa <= kappa - 1;
                state <= s6;
            
            -- Final State
            when fnl =>  -- Completion handling
                if i_start = '0' then
                    state <= rst;
                else
                    o_done <= '1';
                end if;
            
            when others =>
                state <= rst;
        end case;
    end if;
end process;

end Behavioral;


-- ============================================================================
-- Finite State Machine (FSM)
-- ============================================================================
-- An FSM is a computational model that:
-- - Operates through a finite set of states
-- - Transitions between states based on inputs
-- - Performs actions during state transitions
--
-- In this implementation:
-- - States represent different phases of memory processing
-- - Transitions are controlled by clock edges and input values
-- - Actions include memory reads/writes, counter updates, and data processing
--
-- This FSM specifically:
-- - Processes memory locations based on input address (i_add)
-- - Handles i_k elements from memory
-- - Implements special handling for zero-values using previous valid data
-- - Calculates credibility values (31 - N formula)
-- - Manages memory access timing and sequencing
--
-- The design demonstrates typical FSM characteristics:
-- - Clear state transitions
-- - State-specific operations
-- - Input-dependent behavior
-- - Sequential execution controlled by clock signals
-- ============================================================================
