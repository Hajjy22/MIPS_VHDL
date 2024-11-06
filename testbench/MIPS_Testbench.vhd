library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MIPS_Testbench is
end MIPS_Testbench;

architecture test of MIPS_Testbench is
    component MIPS
        port(
            CLK, RST: in std_logic;
            CS, WE: out std_logic;
            ADDR: out unsigned(31 downto 0);
            Mem_Bus: inout unsigned(31 downto 0)
        );
    end component;

    component Memory
        port(
            CS, WE, CLK: in std_logic;
            ADDR: in unsigned(31 downto 0);
            Mem_Bus: inout unsigned(31 downto 0)
        );
    end component;

    constant N: integer := 8;
    constant W: integer := 26;
    type Iarr is array(1 to W) of unsigned(31 downto 0);
    constant Instr_List: Iarr := (
        x"30000000", x"20010006", x"34020012", x"00221820",
        x"00412022", x"00222824", x"00223025", x"0022382A",
        x"00024100", x"00014842", x"10220001", x"8C0A0004",
        x"14620001", x"30210000", x"08000010", x"30420000",
        x"00400008", x"30630000", x"AC030040", x"AC040041",
        x"AC050042", x"AC060043", x"AC070044", x"AC080045",
        x"AC090046", x"AC0A0047"
    );
    
    type output_arr is array(1 to N) of integer;
    constant expected: output_arr := (24, 12, 2, 22, 1, 288, 3, 4268066);

    signal CS, WE, CLK: std_logic := '0';
    signal Mem_Bus, Address, AddressTB, Address_Mux: unsigned(31 downto 0);
    signal RST, init, WE_Mux, CS_Mux, WE_TB, CS_TB: std_logic;

begin
    -- Instantiate MIPS processor
    CPU: MIPS port map (CLK, RST, CS, WE, Address, Mem_Bus);

    -- Instantiate Memory module
    MEM: Memory port map (CS_Mux, WE_Mux, CLK, Address_Mux, Mem_Bus);
  
    -- Clock signal generation
    CLK <= not CLK after 10 ns;

    -- Multiplex Address, CS, and WE signals based on `init` phase
    Address_Mux <= AddressTB when init = '1' else Address;
    WE_Mux <= WE_TB when init = '1' else WE;
    CS_Mux <= CS_TB when init = '1' else CS;

    -- Process for initialization and testing
    process
    begin
        -- Initialize reset
        RST <= '1';
        wait until CLK = '1' and CLK'event;
        
        -- Load instructions into Memory during `init` phase
        init <= '1';
        CS_TB <= '1';
        WE_TB <= '1';
        
        for i in 1 to W loop
            wait until CLK = '1' and CLK'event;
            AddressTB <= to_unsigned(i-1, 32);
            Mem_Bus <= Instr_List(i);
        end loop;

        -- End initialization phase
        wait until CLK = '1' and CLK'event;
        Mem_Bus <= (others => 'Z');  -- Release bus
        CS_TB <= '0';
        WE_TB <= '0';
        init <= '0';

        -- Start actual testing
        wait until CLK = '1' and CLK'event;
        RST <= '0';

        for i in 1 to N loop
            wait until WE = '1' and WE'event;  -- Trigger on store word
            wait until CLK = '0' and CLK'event;
            
            -- Assertion to check the expected value
            assert (to_integer(Mem_Bus) = expected(i))
            report "Output mismatch at index " & integer'image(i) severity error;
        end loop;

        -- End of testing
        report "Testing Finished.";
        wait;
    end process;
end test;
