library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;
        i_rst      : in  std_logic;
        i_start    : in  std_logic;
        i_add      : in  std_logic_vector(15 downto 0);
        i_k        : in  std_logic_vector(9 downto 0);

        o_done     : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;

architecture rtl of project_reti_logiche is

    -- =====================================================================
    -- REFINEMENT NOTES
    -- =====================================================================
    -- This version keeps the original design intent, but applies a first
    -- refinement pass to make the code cleaner and more consistent.
    --
    -- Main improvements introduced:
    -- 1) Removed std_logic_unsigned:
    --    arithmetic on std_logic_vector is avoided because it is less explicit
    --    and less robust than using numeric_std with proper types.
    --
    -- 2) out_mem_addr is now an unsigned signal internally:
    --    this makes address increments explicit and type-safe.
    --
    -- 3) kappa range aligned with i_k width:
    --    i_k is 10 bits, so the correct integer range is 0..1023.
    --
    -- 4) Reset behavior made more complete:
    --    outputs and internal registers are explicitly initialized.
    --
    -- 5) State names improved:
    --    original short names (s0, s1, s2, ...) were renamed into more
    --    descriptive names to make the FSM easier to read and maintain.
    --
    -- Important note:
    -- This is intentionally still a single-process FSM, to stay close to the
    -- original university project. A later refinement could split controller
    -- and datapath into separate modules/processes.
    -- =====================================================================

    type state_type is (
        RST_ST,
        IDLE_ST,
        READ_EVAL_ST,
        WRITE_CRED_31_ST,
        ADVANCE_AFTER_NONZERO_ST,
        PREPARE_NEXT_READ_ST,
        WRITE_LAST_VALID_ST,
        PREPARE_CRED_WRITE_ST,
        WRITE_CRED_DEC_ST,
        FINISH_ZERO_PATH_ST,
        FIRST_ZERO_SCAN_ST,
        FIRST_ZERO_SKIP_ST,
        FIRST_ZERO_DECR_ST,
        DONE_ST
    );

    -- Current FSM state.
    signal state         : state_type := RST_ST;

    -- Credibility counter.
    -- In the original code this was already bounded to 31, and here that idea
    -- is preserved. Later, during zero handling, the counter is saturated so it
    -- never exceeds its legal range.
    signal decounter     : integer range 0 to 31 := 0;

    -- Number of remaining elements to process.
    -- Refined from 0..511 to 0..1023 because i_k is 10 bits wide.
    signal kappa         : integer range 0 to 1023 := 0;

    -- Internal memory address register.
    -- Changed from std_logic_vector to unsigned so that operations like
    -- "+ 1" and "+ 2" are well-typed and rely only on numeric_std.
    signal out_mem_addr  : unsigned(15 downto 0) := (others => '0');

    -- Stores the last valid non-zero input value.
    signal valore_utile  : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- Convert internal typed address register back to std_logic_vector for the
    -- external port. This is a clean boundary between internal arithmetic and
    -- external interface representation.
    o_mem_addr <= std_logic_vector(out_mem_addr);

    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            -- More complete reset than the original version:
            -- not only control outputs, but also registers and data outputs are
            -- explicitly initialized. This makes simulation behavior cleaner and
            -- reduces the chance of stale values.
            o_mem_en     <= '0';
            o_mem_we     <= '0';
            o_done       <= '0';
            o_mem_data   <= (others => '0');
            out_mem_addr <= (others => '0');
            valore_utile <= (others => '0');
            decounter    <= 0;
            kappa        <= 0;
            state        <= RST_ST;

        elsif rising_edge(i_clk) then
            case state is

                when RST_ST =>
                    -- Default safe values while waiting for a new start pulse.
                    o_done   <= '0';
                    o_mem_en <= '0';
                    o_mem_we <= '0';

                    if i_start = '1' then
                        -- Latch input configuration when computation starts.
                        -- Address is converted once into unsigned and then kept
                        -- in arithmetic-friendly form internally.
                        o_mem_en     <= '1';
                        out_mem_addr <= unsigned(i_add);
                        kappa        <= to_integer(unsigned(i_k));
                        decounter    <= 0;
                        valore_utile <= (others => '0');
                        state        <= IDLE_ST;
                    end if;

                when IDLE_ST =>
                    -- If there is nothing left to process, move to completion.
                    -- Otherwise evaluate current memory data.
                    if kappa = 0 then
                        state <= DONE_ST;
                    else
                        state <= READ_EVAL_ST;
                    end if;

                when READ_EVAL_ST =>
                    -- Original logic preserved:
                    -- - if we are still at the first effective element and it is
                    --   zero, use the dedicated initial-zero path
                    -- - if the current element is zero later in the stream, use
                    --   the last valid value path
                    -- - otherwise store the new valid value and write 31
                    if (to_integer(unsigned(i_k)) = kappa) and (i_mem_data = x"00") then
                        state <= FIRST_ZERO_SCAN_ST;
                    elsif i_mem_data = x"00" then
                        state <= WRITE_LAST_VALID_ST;
                    else
                        valore_utile <= i_mem_data;
                        out_mem_addr <= out_mem_addr + 1;
                        state <= WRITE_CRED_31_ST;
                    end if;

                when WRITE_CRED_31_ST =>
                    -- After a valid non-zero value, write the maximum credibility
                    -- value (31 = 0x1F).
                    o_mem_we   <= '1';
                    o_mem_data <= x"1F";
                    decounter  <= 0;
                    state      <= ADVANCE_AFTER_NONZERO_ST;

                when ADVANCE_AFTER_NONZERO_ST =>
                    -- Advance to the next memory slot after the credibility write.
                    out_mem_addr <= out_mem_addr + 1;
                    state <= PREPARE_NEXT_READ_ST;

                when PREPARE_NEXT_READ_ST =>
                    -- Deassert write enable and consume one element.
                    o_mem_we <= '0';
                    kappa    <= kappa - 1;
                    state    <= IDLE_ST;

                when WRITE_LAST_VALID_ST =>
                    -- For a zero value, rewrite the most recent valid value.
                    o_mem_we     <= '1';
                    o_mem_data   <= valore_utile;
                    out_mem_addr <= out_mem_addr + 1;

                    -- Saturating increment:
                    -- functionally safer than a blind increment on a bounded
                    -- integer signal. This also documents the intended behavior.
                    if decounter < 31 then
                        decounter <= decounter + 1;
                    else
                        decounter <= 31;
                    end if;

                    state <= PREPARE_CRED_WRITE_ST;

                when PREPARE_CRED_WRITE_ST =>
                    -- One intermediate state kept to stay close to the timing and
                    -- sequencing style of the original FSM.
                    o_mem_we <= '0';
                    state    <= WRITE_CRED_DEC_ST;

                when WRITE_CRED_DEC_ST =>
                    -- Write decreasing credibility: 31 - decounter.
                    -- Since decounter is saturated in 0..31, this subtraction is
                    -- safe and remains within the 8-bit unsigned range.
                    o_mem_we     <= '1';
                    o_mem_data   <= std_logic_vector(to_unsigned(31 - decounter, 8));
                    out_mem_addr <= out_mem_addr + 1;
                    kappa        <= kappa - 1;
                    state        <= FINISH_ZERO_PATH_ST;

                when FINISH_ZERO_PATH_ST =>
                    -- Return to read flow after completing the zero-handling path.
                    o_mem_we <= '0';
                    state    <= IDLE_ST;

                when FIRST_ZERO_SCAN_ST =>
                    -- Dedicated handling for the "initial zeros" case.
                    -- This branch is kept conceptually close to the original code,
                    -- but renamed for readability.
                    if kappa = 0 then
                        state <= DONE_ST;
                    elsif i_mem_data = x"00" then
                        out_mem_addr <= out_mem_addr + 2;
                        state <= FIRST_ZERO_SKIP_ST;
                    else
                        valore_utile <= i_mem_data;
                        out_mem_addr <= out_mem_addr + 1;
                        state <= WRITE_CRED_31_ST;
                    end if;

                when FIRST_ZERO_SKIP_ST =>
                    -- Transitional state preserved from the original design flow.
                    state <= FIRST_ZERO_DECR_ST;

                when FIRST_ZERO_DECR_ST =>
                    -- Consume one logical element while scanning the initial zero
                    -- region.
                    kappa <= kappa - 1;
                    state <= FIRST_ZERO_SCAN_ST;

                when DONE_ST =>
                    -- Raise done while start remains asserted.
                    -- Once start is released, return to reset-like waiting state.
                    o_done   <= '1';
                    o_mem_we <= '0';

                    if i_start = '0' then
                        o_done   <= '0';
                        o_mem_en <= '0';
                        state    <= RST_ST;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;
