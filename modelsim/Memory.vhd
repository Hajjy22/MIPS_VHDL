library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Memory is
    port(
        CS, WE, Clk: in std_logic;
        ADDR: in unsigned(31 downto 0);
        Mem_Bus: inout unsigned(31 downto 0)
    );
end Memory;

architecture Internal of Memory is
    type RAMtype is array (0 to 127) of unsigned(31 downto 0);
    signal RAM1: RAMtype := (others => (others => '0'));
    signal output: unsigned(31 downto 0);
begin
    -- Tri-state buffer control for Mem_Bus
    Mem_Bus <= (others => 'Z') when CS = '0' or WE = '1' else output;

    process(Clk)
    begin
        if rising_edge(Clk) then
            if CS = '1' and WE = '1' then
                -- Write to RAM at specified address when CS and WE are active
                RAM1(to_integer(ADDR(6 downto 0))) <= Mem_Bus;
            end if;
            -- Read from RAM and assign to output
            output <= RAM1(to_integer(ADDR(6 downto 0)));
        end if;
    end process;
end Internal;
