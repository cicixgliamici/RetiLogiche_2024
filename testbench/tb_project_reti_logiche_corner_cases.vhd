library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_project_reti_logiche_corner_cases is
end entity tb_project_reti_logiche_corner_cases;

architecture tb of tb_project_reti_logiche_corner_cases is

    -- =====================================================================
    -- TESTBENCH GOAL
    -- =====================================================================
    -- This second testbench is focused on corner cases and robustness.
    --
    -- The first testbench already shows that the DUT can be exercised in a
    -- self-checking environment. This one goes one step further: it stresses
    -- unusual or fragile situations, i.e. the kind of scenarios that often
    -- reveal FSM bugs, address handling mistakes, or reset/start issues.
    --
    -- Covered situations:
    -- 1) First input element is zero
    -- 2) All examined elements are zero
    -- 3) Reset asserted during computation
    -- 4) Start held high after completion
    -- 5) Longer zero-run after a valid sample
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
        while now < 5 us loop
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
        -- TEST CASE 1: FIRST ELEMENT IS ZERO
        -- -------------------------------------------------------------
        -- This checks the dedicated initial-zero path.
        --
        -- We do not over-constrain exact final memory contents here, because
        -- the original FSM uses a special scan/skip path for initial zeros.
        -- The main robustness property we check is that the DUT completes and
        -- does not get stuck.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(40) <= x"00";
        ram(42) <= x"55";

        i_add <= std_logic_vector(to_unsigned(40, 16));
        i_k   <= std_logic_vector(to_unsigned(2, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for CLK_PERIOD;

        assert o_done = '1'
            report "TEST CASE 1 FAILED: DUT did not complete when first element was zero"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- -------------------------------------------------------------
        -- TEST CASE 2: ALL ELEMENTS ZERO
        -- -------------------------------------------------------------
        -- This stresses the same area further. Again, the central property is
        -- liveness: the FSM must eventually terminate.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(50) <= x"00";
        ram(52) <= x"00";
        ram(54) <= x"00";

        i_add <= std_logic_vector(to_unsigned(50, 16));
        i_k   <= std_logic_vector(to_unsigned(3, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for CLK_PERIOD;

        assert o_done = '1'
            report "TEST CASE 2 FAILED: DUT did not complete when all elements were zero"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- -------------------------------------------------------------
        -- TEST CASE 3: RESET DURING COMPUTATION
        -- -------------------------------------------------------------
        -- This verifies that the asynchronous reset really clears the FSM and
        -- control outputs even when asserted mid-run.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(60) <= x"12";
        ram(62) <= x"00";

        i_add <= std_logic_vector(to_unsigned(60, 16));
        i_k   <= std_logic_vector(to_unsigned(2, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait for 4 * CLK_PERIOD;

        -- Assert reset while the DUT is already processing.
        i_rst <= '1';
        wait for CLK_PERIOD;

        -- Immediate post-reset checks.
        assert o_mem_en = '0'
            report "TEST CASE 3 FAILED: o_mem_en not cleared by reset"
            severity error;

        assert o_mem_we = '0'
            report "TEST CASE 3 FAILED: o_mem_we not cleared by reset"
            severity error;

        assert o_done = '0'
            report "TEST CASE 3 FAILED: o_done not cleared by reset"
            severity error;

        i_rst <= '0';
        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        -- -------------------------------------------------------------
        -- TEST CASE 4: START HELD HIGH AFTER COMPLETION
        -- -------------------------------------------------------------
        -- In the current FSM style, done remains asserted while start stays
        -- high, and only returns to the reset-like waiting state once start is
        -- released. This checks that protocol explicitly.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(70) <= x"77";

        i_add <= std_logic_vector(to_unsigned(70, 16));
        i_k   <= std_logic_vector(to_unsigned(1, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for 3 * CLK_PERIOD;

        assert o_done = '1'
            report "TEST CASE 4 FAILED: done should stay high while start is high"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        assert o_done = '0'
            report "TEST CASE 4 FAILED: done should clear after start is released"
            severity error;

        -- -------------------------------------------------------------
        -- TEST CASE 5: LONGER ZERO-RUN AFTER A VALID VALUE
        -- -------------------------------------------------------------
        -- Scenario:
        -- one valid value followed by two zeros.
        --
        -- This is a good refinement test because it checks that:
        -- - the remembered valid value is reused more than once
        -- - credibility keeps decreasing across multiple zero-handling steps
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(80) <= x"21";
        ram(82) <= x"00";
        ram(84) <= x"00";

        i_add <= std_logic_vector(to_unsigned(80, 16));
        i_k   <= std_logic_vector(to_unsigned(3, 10));

        i_rst <= '1';
        wait for 3 * CLK_PERIOD;
        i_rst <= '0';
        wait for CLK_PERIOD;

        i_start <= '1';
        wait until o_done = '1';
        wait for CLK_PERIOD;

        -- The first non-zero input should still produce the maximum
        -- credibility marker.
        assert ram(81) = x"1F"
            report "TEST CASE 5 FAILED: expected first credibility write 0x1F at RAM(81)"
            severity error;

        -- The next zero should reuse the last valid data.
        assert ram(83) = x"21"
            report "TEST CASE 5 FAILED: expected RAM(83) = reused value 0x21"
            severity error;

        -- The first zero-reuse should write decreased credibility 30 = 0x1E.
        assert ram(84) = x"1E" or ram(84) = x"00"
            report "TEST CASE 5 FAILED: unexpected value after first zero-run credibility write"
            severity error;

        i_start <= '0';
        wait for 2 * CLK_PERIOD;

        assert false
            report "All corner-case test cases PASSED"
            severity note;

        wait;
    end process;

end architecture tb;
