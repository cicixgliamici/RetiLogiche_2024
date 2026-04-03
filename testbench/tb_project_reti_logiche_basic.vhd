library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_project_reti_logiche_basic is
end entity tb_project_reti_logiche_basic;

architecture tb of tb_project_reti_logiche_basic is

    -- =====================================================================
    -- TESTBENCH GOAL
    -- =====================================================================
    -- This testbench is meant to show the first verification refinement step:
    -- instead of only writing the DUT, we also build a simple simulation
    -- environment around it.
    --
    -- What is included here:
    -- 1) Clock and reset generation
    -- 2) A very small RAM model
    -- 3) Start stimulus
    -- 4) Automatic checks with assert
    --
    -- The goal is not yet to build a full verification framework, but to make
    -- the project clearly evolve from “university RTL implementation” toward
    -- “self-checking design with reproducible simulation”.
    -- =====================================================================

    constant CLK_PERIOD : time := 10 ns;
    constant MEM_DEPTH  : integer := 256;

    -- DUT inputs
    signal i_clk      : std_logic := '0';
    signal i_rst      : std_logic := '0';
    signal i_start    : std_logic := '0';
    signal i_add      : std_logic_vector(15 downto 0) := (others => '0');
    signal i_k        : std_logic_vector(9 downto 0)  := (others => '0');
    signal i_mem_data : std_logic_vector(7 downto 0)  := (others => '0');

    -- DUT outputs
    signal o_done     : std_logic;
    signal o_mem_addr : std_logic_vector(15 downto 0);
    signal o_mem_data : std_logic_vector(7 downto 0);
    signal o_mem_we   : std_logic;
    signal o_mem_en   : std_logic;

    -- Simple memory model.
    -- This is enough for a first realistic simulation: the DUT sees a memory
    -- that can be read and written through address/data/control signals.
    type ram_type is array (0 to MEM_DEPTH - 1) of std_logic_vector(7 downto 0);
    signal ram : ram_type := (others => (others => '0'));

begin

    -- =====================================================================
    -- DUT INSTANTIATION
    -- =====================================================================
    dut: entity work.project_reti_logiche
        port map (
            i_clk      => i_clk,
            i_rst      => i_rst,
            i_start    => i_start,
            i_add      => i_add,
            i_k        => i_k,
            o_done     => o_done,
            o_mem_addr => o_mem_addr,
            i_mem_data => i_mem_data,
            o_mem_data => o_mem_data,
            o_mem_we   => o_mem_we,
            o_mem_en   => o_mem_en
        );

    -- =====================================================================
    -- CLOCK GENERATION
    -- =====================================================================
    clk_process : process
    begin
        while now < 2 us loop
            i_clk <= '0';
            wait for CLK_PERIOD / 2;
            i_clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- =====================================================================
    -- SIMPLE MEMORY MODEL
    -- =====================================================================
    -- Read behavior:
    -- the current addressed byte is continuously reflected on i_mem_data.
    --
    -- Write behavior:
    -- on the rising edge, if memory is enabled and write-enable is high, the
    -- output data is written into the RAM.
    --
    -- This is intentionally simple, because the first goal is to verify logic
    -- correctness before modelling more detailed memory timing.
    mem_read_process : process(all)
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(o_mem_addr));

        if (o_mem_en = '1') and (addr_int >= 0) and (addr_int < MEM_DEPTH) then
            i_mem_data <= ram(addr_int);
        else
            i_mem_data <= (others => '0');
        end if;
    end process;

    mem_write_process : process(i_clk)
        variable addr_int : integer;
    begin
        if rising_edge(i_clk) then
            addr_int := to_integer(unsigned(o_mem_addr));

            if (o_mem_en = '1') and (o_mem_we = '1') and (addr_int >= 0) and (addr_int < MEM_DEPTH) then
                ram(addr_int) <= o_mem_data;
            end if;
        end if;
    end process;

    -- =====================================================================
    -- STIMULUS + CHECKS
    -- =====================================================================
    stim_proc : process
    begin
        -- -------------------------------------------------------------
        -- TEST CASE 1
        -- -------------------------------------------------------------
        -- Scenario:
        -- first element is non-zero.
        --
        -- We expect the DUT to:
        -- - read the value at base address
        -- - treat it as valid
        -- - write 0x1F in the next address
        -- - eventually raise done
        --
        -- Initial RAM contents:
        --   ram(10) = 0x12
        -- -------------------------------------------------------------

        ram <= (others => (others => '0'));
        ram(10) <= x"12";

        i_add <= std_logic_vector(to_unsigned(10, 16));
        i_k   <= std_logic_vector(to_unsigned(1, 10));

        -- Apply reset.
        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        -- Start the computation.
        i_start <= '1';

        -- Wait until the DUT signals completion.
        wait until o_done = '1';
        wait for CLK_PERIOD;

        -- First automatic check:
        -- after a non-zero input value, the design writes 0x1F to the next
        -- memory location.
        assert ram(11) = x"1F"
            report "TEST CASE 1 FAILED: expected RAM(11) = 0x1F after non-zero input"
            severity error;

        -- Release start to allow the FSM to return to its waiting state.
        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- -------------------------------------------------------------
        -- TEST CASE 2
        -- -------------------------------------------------------------
        -- Scenario:
        -- one non-zero value followed by one zero.
        --
        -- Initial RAM contents:
        --   ram(20) = 0x34
        --   ram(22) = 0x00
        --
        -- Expected qualitative behavior:
        -- - first valid value produces 0x1F credibility
        -- - later zero uses the stored last valid value
        -- - then writes a decreased credibility value
        --
        -- NOTE:
        -- the exact addresses reflect the style of the original FSM, which
        -- advances the memory pointer as it writes intermediate results.
        -- -------------------------------------------------------------

        ram <= (others => (others => '0'));
        ram(20) <= x"34";
        ram(22) <= x"00";

        i_add <= std_logic_vector(to_unsigned(20, 16));
        i_k   <= std_logic_vector(to_unsigned(2, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for CLK_PERIOD;

        -- Check 1: after the first valid value, 0x1F should be written.
        assert ram(21) = x"1F"
            report "TEST CASE 2 FAILED: expected RAM(21) = 0x1F after first valid value"
            severity error;

        -- Check 2: zero handling should rewrite the last valid value.
        assert ram(23) = x"34"
            report "TEST CASE 2 FAILED: expected RAM(23) = last valid value 0x34"
            severity error;

        -- Check 3: credibility after one zero should become 30 = 0x1E.
        assert ram(24) = x"1E"
            report "TEST CASE 2 FAILED: expected RAM(24) = 0x1E after first zero reuse"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- -------------------------------------------------------------
        -- TEST CASE 3
        -- -------------------------------------------------------------
        -- Scenario:
        -- k = 0, so the DUT should terminate without processing data.
        --
        -- This is a very important basic corner case because it verifies that
        -- the FSM handles an empty workload gracefully.
        -- -------------------------------------------------------------

        ram <= (others => (others => '0'));

        i_add <= std_logic_vector(to_unsigned(30, 16));
        i_k   <= std_logic_vector(to_unsigned(0, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for CLK_PERIOD;

        -- No memory write should have occurred in this simple empty case.
        assert ram(30) = x"00"
            report "TEST CASE 3 FAILED: unexpected write for k = 0"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- If all assertions passed, print a success message.
        assert false
            report "All basic test cases PASSED"
            severity note;

        wait;
    end process;

end architecture tb;
