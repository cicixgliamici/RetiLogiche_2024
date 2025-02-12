# Vivado and VHDL: Development Environment and Testing

## What is Vivado and VHDL?
**Vivado** is Xilinx/AMD's FPGA/SoC development suite for:
- RTL design and synthesis
- Hardware implementation (place & route)
- Simulation and verification
- Bitstream generation for programmable devices

**VHDL** (VHSIC Hardware Description Language) is used for:
- Digital circuit description
- Behavioral/structural modeling
- Formal verification and simulation

## Basic Vivado Project Structure

    my_project/
    ├── sources/
    │   ├── main.vhd
    │   └── utilities_pkg.vhd
    ├── constraints/
    │   └── clock.xdc
    ├── sim/
    │   └── tb_main.vhd
    └── scripts/
        └── build.tcl

### Basic VHDL Example

    -- File: sources/main.vhd
    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;

    entity counter is
        Port ( clk   : in  STD_LOGIC;
               reset : in  STD_LOGIC;
               count : out UNSIGNED(3 downto 0));
    end counter;

    architecture Behavioral of counter is
        signal counter_reg : UNSIGNED(3 downto 0) := (others => '0');
    begin
        process(clk, reset)
        begin
            if reset = '1' then
                counter_reg <= (others => '0');
            elsif rising_edge(clk) then
                counter_reg <= counter_reg + 1;
            end if;
        end process;
        
        count <= counter_reg;
    end Behavioral;

## Vivado Compilation Flow
1. **Synthesis** (RTL → Technology-mapped netlist)
2. **Implementation** (Placement & Routing)
3. **Bitstream Generation** (.bit file)
4. **Device Programming**

### Basic TCL Automation Script

    # File: scripts/build.tcl
    create_project my_project ./my_project -part xc7a100tcsg324-1
    add_files {sources/main.vhd}
    add_files -fileset constrs_1 constraints/clock.xdc
    set_property top counter [current_fileset]
    launch_runs synth_1
    wait_on_run synth_1
    launch_runs impl_1 -to_step write_bitstream
    wait_on_run impl_1

## Testing and Simulation Environment
Vivado includes:
- Mixed-language simulator (VHDL/Verilog)
- Waveform debugging
- Assertion-based verification
- Integrated Logic Analyzer (ILA)

### VHDL Testbench Example

    -- File: sim/tb_main.vhd
    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;

    entity tb_counter is
    end tb_counter;

    architecture Behavioral of tb_counter is
        constant CLK_PERIOD : time := 10 ns;
        signal clk, reset : STD_LOGIC := '0';
        signal count : UNSIGNED(3 downto 0);
    begin
        DUT: entity work.counter
            port map(clk => clk,
                     reset => reset,
                     count => count);

        -- Clock Generation
        clk_process: process
        begin
            while now < 1000 ns loop
                clk <= '0';
                wait for CLK_PERIOD/2;
                clk <= '1';
                wait for CLK_PERIOD/2;
            end loop;
            wait;
        end process;

        -- Stimulus Process
        stim_proc: process
        begin
            reset <= '1';
            wait for 25 ns;
            reset <= '0';
            
            -- Test reset functionality
            assert count = x"0"
                report "Reset failed" severity error;
            
            wait until count = x"A";
            assert count = x"A"
                report "Counting error at 10" severity error;
            
            wait;
        end process;
    end Behavioral;

## Vivado IDE Integration
1. **Key Tools**:
   - Schematic Viewer
   - Timing Analyzer
   - Power Analysis
   - Hardware Manager
   - IP Integrator

2. **Simulation Workflow**:
   - Create testbench files
   - Run behavioral simulation
   - Add signals to waveform window
   - Verify timing and values

3. **Hardware Debugging**:
   - Insert ILA (Integrated Logic Analyzer)
   - Set trigger conditions
   - Program device and capture signals

## Vivado Workflow Benefits
- ✅ Complete RTL-to-bitstream flow
- ✅ Advanced timing closure tools
- ✅ Mixed-language simulation
- ✅ IP Catalog integration
- ✅ TCL scripting automation

## Essential Resources
- Vivado Documentation Hub: https://docs.xilinx.com/
- VHDL IEEE Standard: IEEE Std 1076-2019
- Xilinx Answer Database: https://support.xilinx.com/
- Example Projects: https://github.com/Xilinx
