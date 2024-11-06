library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MIPS is
    port (
        CLK, RST: in std_logic;
        CS, WE: out std_logic;
        ADDR: out unsigned(31 downto 0);
        Mem_Bus: inout unsigned(31 downto 0)
    );
end MIPS;

architecture structure of MIPS is

    -- Component declaration for the register file
    component REG is
        port (
            CLK: in std_logic;
            RegW: in std_logic;
            DR, SR1, SR2: in unsigned(4 downto 0);
            Reg_In: in unsigned(31 downto 0);
            ReadReg1, ReadReg2: out unsigned(31 downto 0)
        );
    end component;

    -- Data type declarations
    type Operation is (and1, or1, add, sub, slt, shr, shl, jr);
    signal Op, OpSave: Operation := and1;
    type Instr_Format is (R, I, J); -- (Arithmetic, Addr_Imm, Jump)
    signal Format: Instr_Format := R;

    -- Signal declarations
    signal Instr, Imm_Ext, PC, nPC, ReadReg1, ReadReg2, Reg_In: unsigned(31 downto 0);
    signal ALU_InA, ALU_InB, ALU_Result, ALU_Result_Save: unsigned(31 downto 0);
    signal ALUorMEM, RegW, FetchDorI, Writing, REGorIMM, REGorIMM_Save, ALUorMEM_Save: std_logic := '0';
    signal DR: unsigned(4 downto 0);
    signal State, nState: integer range 0 to 4 := 0;

    -- Constants for operation codes
    constant addi: unsigned(5 downto 0) := "001000"; -- 8
    constant andi: unsigned(5 downto 0) := "001100"; -- 12
    constant ori: unsigned(5 downto 0) := "001101"; -- 13
    constant lw: unsigned(5 downto 0) := "100011"; -- 35
    constant sw: unsigned(5 downto 0) := "101011"; -- 43
    constant beq: unsigned(5 downto 0) := "000100"; -- 4
    constant bne: unsigned(5 downto 0) := "000101"; -- 5
    constant jump: unsigned(5 downto 0) := "000010"; -- 2

    -- Aliases for instruction fields
    alias opcode: unsigned(5 downto 0) is Instr(31 downto 26);
    alias SR1: unsigned(4 downto 0) is Instr(25 downto 21);
    alias SR2: unsigned(4 downto 0) is Instr(20 downto 16);
    alias F_Code: unsigned(5 downto 0) is Instr(5 downto 0);
    alias NumShift: unsigned(4 downto 0) is Instr(10 downto 6);
    alias ImmField: unsigned(15 downto 0) is Instr(15 downto 0);

begin

    -- Register file instantiation
    A1: Reg port map (CLK, RegW, DR, SR1, SR2, Reg_In, ReadReg1, ReadReg2);

    -- Immediate field sign extension
    Imm_Ext <= x"FFFF" & Instr(15 downto 0) when Instr(15) = '1'
                else x"0000" & Instr(15 downto 0);

    -- Destination Register MUX (MUX1)
    DR <= Instr(15 downto 11) when Format = R else Instr(20 downto 16);

    -- ALU inputs and MUX selections
    ALU_InA <= ReadReg1;
    ALU_InB <= Imm_Ext when REGorIMM_Save = '1' else ReadReg2;
    Reg_in <= Mem_Bus when ALUorMEM_Save = '1' else ALU_Result_Save;

    -- Format selection
    Format <= R when opcode = 0 else J when opcode = 2 else I;

    -- Memory bus driving
    Mem_Bus <= ReadReg2 when Writing = '1' else "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";

    -- Address MUX
    ADDR <= PC when FetchDorI = '1' else ALU_Result_Save;

    -- Main control process
    process(State, PC, Instr, Format, F_Code, opcode, Op, ALU_InA, ALU_InB, Imm_Ext)
    begin
        FetchDorI <= '0'; CS <= '0'; WE <= '0'; RegW <= '0'; Writing <= '0';
        ALU_Result <= "00000000000000000000000000000000";
        nPC <= PC; Op <= jr; REGorIMM <= '0'; ALUorMEM <= '0';

        case State is
            when 0 => -- Fetch instruction
                nPC <= PC + 1; CS <= '1'; nState <= 1;
                FetchDorI <= '1';
            when 1 =>
                nState <= 2; REGorIMM <= '0'; ALUorMEM <= '0';
                if Format = J then
                    nPC <= "000000" & Instr(25 downto 0); nState <= 0;
                elsif Format = R then
                    case F_code is
                        when "100000" => Op <= add;
                        when "100010" => Op <= sub;
                        when "100100" => Op <= and1;
                        when "100101" => Op <= or1;
                        when "101010" => Op <= slt;
                        when "000010" => Op <= shr;
                        when "000000" => Op <= shl;
                        when "001000" => Op <= jr;
                        when others => null;
                    end case;
                elsif Format = I then
                    REGorIMM <= '1';
                    case Opcode is
                        when lw | sw | addi => Op <= add;
                        when beq | bne => Op <= sub; REGorIMM <= '0';
                        when andi => Op <= and1;
                        when ori => Op <= or1;
                        when others => null;
                    end case;
                    if Opcode = lw then ALUorMEM <= '1'; end if;
                end if;
            when 2 =>
                nState <= 3;
                case OpSave is
                    when and1 => ALU_Result <= ALU_InA and ALU_InB;
                    when or1 => ALU_Result <= ALU_InA or ALU_InB;
                    when add => ALU_Result <= ALU_InA + ALU_InB;
                    when sub => ALU_Result <= ALU_InA - ALU_InB;
                    when shr => ALU_Result <= ALU_InB srl to_integer(NumShift);
                    when shl => ALU_Result <= ALU_InB sll to_integer(NumShift);
                    when slt =>
                        if ALU_InA < ALU_InB then ALU_Result <= x"00000001";
                        else ALU_Result <= x"00000000";
                        end if;
                    when others => null;
                end case;
                if ((ALU_InA = ALU_InB) and Opcode = beq) or
                   ((ALU_InA /= ALU_InB) and Opcode = bne) then
                    nPC <= PC + Imm_Ext; nState <= 0;
                elsif Opcode = bne or Opcode = beq then nState <= 0;
                elsif OpSave = jr then nPC <= ALU_InA; nState <= 0;
                end if;
            when 3 =>
                nState <= 0;
                if Format = R or Opcode = addi or Opcode = andi or Opcode = ori then
                    RegW <= '1';
                elsif Opcode = sw then
                    CS <= '1'; WE <= '1'; Writing <= '1';
                elsif Opcode = lw then
                    CS <= '1'; nState <= 4;
                end if;
            when 4 =>
                nState <= 0; CS <= '1';
                if Opcode = lw then RegW <= '1'; end if;
            when others => null;
        end case;
    end process;

    -- Sequential process
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                State <= 0;
                PC <= x"00000000";
            else
                State <= nState;
                PC <= nPC;
            end if;

            if State = 0 then Instr <= Mem_Bus; end if;
            if State = 1 then
                OpSave <= Op;
                REGorIMM_Save <= REGorIMM;
                ALUorMEM_Save <= ALUorMEM;
            end if;
            if State = 2 then ALU_Result_Save <= ALU_Result; end if;
        end if;
    end process;

end structure;
