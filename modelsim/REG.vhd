library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity REG is
    port (
        CLK: in std_logic;
        RegW: in std_logic;
        DR, SR1, SR2: in unsigned(4 downto 0);
        Reg_In: in unsigned(31 downto 0);
        ReadReg1, ReadReg2: out unsigned(31 downto 0)
    );
end REG;

architecture Behavioral of REG is
    type RAM is array (0 to 31) of unsigned(31 downto 0);
    signal Regs: RAM := (others => (others => '1')); -- Set all register bits to '1' initially
begin
    process (CLK)
    begin
        -- Write operation on rising edge of CLK
        if rising_edge(CLK) then
            if RegW = '1' then
                Regs(to_integer(DR)) <= Reg_In;
            end if;
        end if;
    end process;

    -- Asynchronous read operations
    ReadReg1 <= Regs(to_integer(SR1));
    ReadReg2 <= Regs(to_integer(SR2));
end Behavioral;
