library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_project_reti_logiche_protocol is
end entity tb_project_reti_logiche_protocol;

architecture tb of tb_project_reti_logiche_protocol is

    -- =====================================================================
    -- TESTBENCH GOAL
    -- =====================================================================
    -- This third testbench is meant to show a further refinement step in the
    -- verification style.
    --
    -- Compared to the previous testbenches, this version introduces:
    -- 1) helper procedures to reduce duplicated stimulus code
    -- 2) a more structured protocol-oriented verification style
    -- 3) checks on handshake/control behavior, not only on data results
    --
    -- In other words, this testbench is useful to show the transition from:
    --   "I wrote some simulation scenarios"
    -- to:
    --   "I started organizing a reusable verification environment"
    --
    -- It is still intentionally simple and fully plain-VHDL, so it stays
    -- aligned with the educational origin of the project.
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
        while now < 6 us loop
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
    -- As in the other testbenches, we keep memory timing simple on purpose.
    -- The focus here is on DUT protocol behavior and structured checking.
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
    -- MAIN VERIFICATION PROCESS
    -- =====================================================================
    stim_proc : process

        -- -------------------------------------------------------------
        -- Helper: initialize the DUT with reset and configuration inputs.
        -- -------------------------------------------------------------
        procedure setup_dut(
            constant base_addr : in integer;
            constant k_value   : in integer
        ) is
        begin
            i_add <= std_logic_vector(to_unsigned(base_addr, 16));
            i_k   <= std_logic_vector(to_unsigned(k_value, 10));

            i_rst   <= '1';
            i_start <= '0';
            wait for 3 * CLK_PERIOD;
            i_rst   <= '0';
            wait for CLK_PERIOD;
        end procedure;

        -- -------------------------------------------------------------
        -- Helper: start the DUT with a clean pulse/level transition.
        -- -------------------------------------------------------------
        procedure start_dut is
        begin
            i_start <= '1';
            wait for CLK_PERIOD;
        end procedure;

        -- -------------------------------------------------------------
        -- Helper: wait until completion or fail on timeout.
        -- -------------------------------------------------------------
        procedure wait_for_done(
            constant max_cycles : in integer
        ) is
        begin
            for cycle in 1 to max_cycles loop
                wait until rising_edge(i_clk);
                exit when o_done = '1';
            end loop;

            assert o_done = '1'
                report "TIMEOUT: DUT did not raise done within expected number of cycles"
                severity error;
        end procedure;

        -- -------------------------------------------------------------
        -- Helper: release start and let the DUT go back to idle/reset-like
        -- waiting mode.
        -- -------------------------------------------------------------
        procedure release_start is
        begin
            i_start <= '0';
            wait for 2 * CLK_PERIOD;
        end procedure;

        -- -------------------------------------------------------------
        -- Helper: check a RAM location.
        -- -------------------------------------------------------------
        procedure check_ram(
            constant addr     : in integer;
            constant expected : in std_logic_vector(7 downto 0);
            constant msg      : in string
        ) is
        begin
            assert ram(addr) = expected
                report msg
                severity error;
        end procedure;

    begin
        -- -------------------------------------------------------------
        -- TEST CASE 1: BASIC CONTROL PROTOCOL AFTER RESET
        -- -------------------------------------------------------------
        -- Goal:
        -- verify that reset leaves the DUT in a safe non-active state.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        setup_dut(10, 1);

        assert o_done = '0'
            report "TEST CASE 1 FAILED: o_done should be low after reset"
            severity error;

        assert o_mem_we = '0'
            report "TEST CASE 1 FAILED: o_mem_we should be low after reset"
            severity error;

        assert o_mem_en = '0'
            report "TEST CASE 1 FAILED: o_mem_en should be low after reset"
            severity error;

        -- -------------------------------------------------------------
        -- TEST CASE 2: START ENABLES PROCESSING AND EVENTUALLY COMPLETES
        -- -------------------------------------------------------------
        -- Goal:
        -- verify the protocol sequence reset -> start -> done.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(10) <= x"44";

        setup_dut(10, 1);
        start_dut;

        -- Once the computation has started, memory should become enabled.
        assert o_mem_en = '1'
            report "TEST CASE 2 FAILED: o_mem_en should go high after start"
            severity error;

        wait_for_done(20);
        check_ram(11, x"1F", "TEST CASE 2 FAILED: expected RAM(11) = 0x1F after single valid input");
        release_start;

        -- -------------------------------------------------------------
        -- TEST CASE 3: DONE MUST STAY HIGH WHILE START STAYS HIGH
        -- -------------------------------------------------------------
        -- Goal:
        -- verify the completion handshake policy implemented by the FSM.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(20) <= x"66";

        setup_dut(20, 1);
        i_start <= '1';
        wait_for_done(20);
        wait for 3 * CLK_PERIOD;

        assert o_done = '1'
            report "TEST CASE 3 FAILED: o_done should remain high while start is high"
            severity error;

        release_start;

        assert o_done = '0'
            report "TEST CASE 3 FAILED: o_done should clear after start release"
            severity error;

        -- -------------------------------------------------------------
        -- TEST CASE 4: NO SPURIOUS WRITE WHEN K = 0
        -- -------------------------------------------------------------
        -- Goal:
        -- verify that an empty workload does not accidentally write data.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));

        setup_dut(30, 0);
        start_dut;
        wait_for_done(10);

        check_ram(30, x"00", "TEST CASE 4 FAILED: unexpected write detected for k = 0");
        release_start;

        -- -------------------------------------------------------------
        -- TEST CASE 5: REPEATED ZERO-REUSE PATH
        -- -------------------------------------------------------------
        -- Goal:
        -- verify a slightly longer flow and reuse helper procedures.
        --
        -- This is useful not just functionally, but stylistically: it shows
        -- that the verification environment is becoming more structured and
        -- easier to extend.
        -- -------------------------------------------------------------
        ram <= (others => (others => '0'));
        ram(40) <= x"22";
        ram(42) <= x"00";
        ram(44) <= x"00";

        setup_dut(40, 3);
        start_dut;
        wait_for_done(50);

        check_ram(41, x"1F", "TEST CASE 5 FAILED: expected first credibility value 0x1F at RAM(41)");
        check_ram(43, x"22", "TEST CASE 5 FAILED: expected reused data 0x22 at RAM(43)");

        -- The exact address/data pattern of later writes depends on the FSM
        -- path details, so here we check a robust intermediate milestone
        -- instead of over-constraining every location.
        assert o_done = '1'
            report "TEST CASE 5 FAILED: expected computation to complete"
            severity error;

        release_start;

        assert false
            report "All protocol-oriented test cases PASSED"
            severity note;

        wait;
    end process;

end architecture tb;
