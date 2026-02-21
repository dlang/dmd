/**
 * Inline assembler implementation for DMD.
 * https://dlang.org/spec/iasm.html
 *
 * Copyright:   Copyright (C) 2025-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     Walter Bright
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/iasmaarch64.d, _iasmaarch64.d)
 * Documentation:  https://dlang.org/phobos/dmd_iasmaarch64.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/iasmaarch64.d
 */

module dmd.iasm.dmdaarch64;

import core.stdc.stdio;
import core.stdc.stdarg;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.astenums;
import dmd.declaration;
import dmd.denum;
import dmd.dinterpret;
import dmd.dmdparams;
import dmd.dscope;
import dmd.dsymbol;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.funcsem : checkNestedReference;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.location;
import dmd.mtype;
import dmd.optimize;
import dmd.statement;
import dmd.target;
import dmd.tokens;
import dmd.typesem : pointerTo, size;

import dmd.root.ctfloat;
import dmd.common.outbuffer;
import dmd.root.rmem;
import dmd.rootobject;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.codebuilder : CodeBuilder;
import dmd.backend.global;
import dmd.backend.iasm;
import dmd.backend.arm.instr : INSTR;

/*******************************
 * Constants
 */

/// Immediate value range constants
private enum ImmediateRange
{
    AddSub12Bit_Min = 0,
    AddSub12Bit_Max = 4095,

    PrePostIndex_Min = -256,
    PrePostIndex_Max = 255,

    MaxShiftAmount = 4,
    MaxBitPos64 = 63,
    MaxBitPos32 = 31,
}

/// Register constants
private enum Reg : ubyte
{
    SP = 31,   /// Stack pointer register number
    ZR = 31,   /// Zero register number
    LR = 30,   /// Link register (x30)
}

/// AArch64 register size encoding
private enum RegSize : ubyte
{
    W = 0,     /// 32-bit (W registers) - sf=0
    X = 1,     /// 64-bit (X registers) - sf=1
}

/// Load/Store size encoding
private enum LSSize : ubyte
{
    Byte = 0,       /// 8-bit load/store
    HalfWord = 1,   /// 16-bit load/store
    Word = 2,       /// 32-bit load/store
    DoubleWord = 3, /// 64-bit load/store
}

/// Load/Store pair opc encoding
private enum LSPairOpc : ubyte
{
    Word = 0,       /// 32-bit pair (W registers)
    DoubleWord = 2, /// 64-bit pair (X registers)
}

/*******************************
 * AArch64 Operand Types and Structures
 */

/// Extend operations for scaled register offsets
private enum ExtendOp : ubyte
{
    None    = 0,
    UXTW    = 2,  /// Zero-extend word (32-bit)
    LSL     = 3,  /// Logical shift left (alias for UXTX for 64-bit)
    SXTW    = 6,  /// Sign-extend word (32-bit)
    SXTX    = 7,  /// Sign-extend doubleword (64-bit)
}

/// Addressing mode type for memory operands
private enum AddressingMode : ubyte
{
    Offset,       /// [Xn, #imm] or [Xn, Xm] - offset addressing
    PreIndexed,   /// [Xn, #imm]! - pre-indexed addressing
    PostIndexed,  /// [Xn], #imm - post-indexed addressing
}

/// Represents a parsed operand in an AArch64 instruction
private struct AArch64Operand
{
    enum Type
    {
        None,
        Register,
        Immediate,
        Memory,
        Label
    }

    Type type;

    // Register operands
    ubyte reg;          /// Register number (0-31)
    bool is64bit;       /// true for X registers, false for W registers

    // Immediate operands
    long imm;           /// Immediate value

    // Memory operands
    ubyte baseReg;      /// Base register
    ubyte indexReg;     /// Index register (if used)
    long offset;        /// Immediate offset
    bool hasIndex;      /// True if index register is used
    bool hasOffset;     /// True if immediate offset is used

    // Extended addressing modes (Phase 2)
    ExtendOp extend;    /// Extend operation for register offset
    ubyte shiftAmount;  /// Shift amount for extend operation
    AddressingMode addressingMode;  /// Offset, pre-indexed, or post-indexed

    // Label operands
    Identifier label;   /// Label identifier
}

/// State for parsing a single asm statement
private struct AsmState
{
    Token* tok;         /// Current token
    Scope* sc;          /// Scope
    Loc loc;            /// Location for error reporting
    uint startErrors;   /// Error count at start
}

/// Global state for current asm parsing
private __gshared AsmState asmstate;

/*******************************
 * Condition Codes
 */

/// AArch64 condition codes for conditional instructions
enum CondCode : ubyte
{
    EQ = 0b0000,  // Equal (Z set)
    NE = 0b0001,  // Not equal (Z clear)
    CS = 0b0010,  // Carry set / unsigned higher or same
    HS = CS,      // Unsigned higher or same (alias for CS)
    CC = 0b0011,  // Carry clear / unsigned lower
    LO = CC,      // Unsigned lower (alias for CC)
    MI = 0b0100,  // Minus / negative (N set)
    PL = 0b0101,  // Plus / positive or zero (N clear)
    VS = 0b0110,  // Overflow set (V set)
    VC = 0b0111,  // Overflow clear (V clear)
    HI = 0b1000,  // Unsigned higher
    LS = 0b1001,  // Unsigned lower or same
    GE = 0b1010,  // Signed greater than or equal
    LT = 0b1011,  // Signed less than
    GT = 0b1100,  // Signed greater than
    LE = 0b1101,  // Signed less than or equal
    AL = 0b1110,  // Always (unconditional)
    NV = 0b1111,  // Always (unconditional) - reserved
}

/// Parse a condition code from a string
private bool parseConditionCode(const(char)[] name, out CondCode cond)
{
    import core.stdc.ctype : tolower;

    if (name.length < 2 || name.length > 2)
        return false;

    // Convert to lowercase for comparison
    char[2] lower;
    lower[0] = cast(char)tolower(name[0]);
    lower[1] = cast(char)tolower(name[1]);

    switch (lower)
    {
        case "eq": cond = CondCode.EQ; return true;
        case "ne": cond = CondCode.NE; return true;
        case "cs": cond = CondCode.CS; return true;
        case "hs": cond = CondCode.HS; return true;
        case "cc": cond = CondCode.CC; return true;
        case "lo": cond = CondCode.LO; return true;
        case "mi": cond = CondCode.MI; return true;
        case "pl": cond = CondCode.PL; return true;
        case "vs": cond = CondCode.VS; return true;
        case "vc": cond = CondCode.VC; return true;
        case "hi": cond = CondCode.HI; return true;
        case "ls": cond = CondCode.LS; return true;
        case "ge": cond = CondCode.GE; return true;
        case "lt": cond = CondCode.LT; return true;
        case "gt": cond = CondCode.GT; return true;
        case "le": cond = CondCode.LE; return true;
        case "al": cond = CondCode.AL; return true;
        default: return false;
    }
}

/*******************************
 * Helper Functions
 */

/// Advance to the next token
private void asmNextToken()
{
    asmstate.tok = asmstate.tok.next;
}

/// Get the current token value
private TOK tokValue()
{
    return asmstate.tok ? asmstate.tok.value : TOK.endOfFile;
}

/// Check if there were errors during parsing
private bool hadErrors()
{
    return global.errors > asmstate.startErrors;
}

/*******************************
 * Validation Helper Functions
 */

/// Validate that an operand is a register
private bool validateRegisterOperand(ref const AArch64Operand op, const(char)* instrName)
{
    if (op.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected for `%s` instruction", instrName);
        return false;
    }
    return true;
}

/// Validate that an operand is a 64-bit register
private bool validate64BitRegister(ref const AArch64Operand op, const(char)* instrName)
{
    if (!validateRegisterOperand(op, instrName))
        return false;

    if (!op.is64bit)
    {
        error(asmstate.loc, "64-bit register expected for `%s` instruction", instrName);
        return false;
    }
    return true;
}

/// Validate that two registers have the same size
private bool validateRegisterSizeMatch(ref const AArch64Operand op1, ref const AArch64Operand op2,
                                       const(char)* instrName)
{
    if (op1.is64bit != op2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
        return false;
    }
    return true;
}

/// Validate that a memory operand is valid
private bool validateMemoryOperand(ref const AArch64Operand op, const(char)* instrName)
{
    if (op.type != AArch64Operand.Type.Memory)
    {
        error(asmstate.loc, "memory operand expected for `%s` instruction", instrName);
        return false;
    }
    return true;
}

/// Get the size encoding for a register (0=32-bit, 1=64-bit)
private uint getSizeFlag(bool is64bit)
{
    return is64bit ? RegSize.X : RegSize.W;
}

/// Get the load/store size encoding for a register
private uint getLSSize(bool is64bit)
{
    return is64bit ? LSSize.DoubleWord : LSSize.Word;
}

/// Validate and encode an imm9 value for pre/post-indexed addressing
private bool encodeImm9(long offset, out uint imm9, const(char)* context)
{
    if (!validateImmediateRange(offset, ImmediateRange.PrePostIndex_Min,
                                ImmediateRange.PrePostIndex_Max, context))
        return false;

    imm9 = cast(uint)(offset & 0x1FF);
    return true;
}

/*******************************
 * Register Parsing
 */

/// Parse a register name and extract register number and size
private bool parseRegisterName(const(char)[] name, out ubyte regNum, out bool is64bit)
{
    import core.stdc.ctype : tolower;

    if (name.length < 2)
        return false;

    char prefix = cast(char)tolower(name[0]);

    // Check for special 2-character register: sp
    if (name.length == 2)
    {
        if ((name[0] == 's' || name[0] == 'S') &&
            (name[1] == 'p' || name[1] == 'P'))
        {
            regNum = 31;
            is64bit = true;
            return true;
        }
    }

    // Check for special 3-character registers: xzr or wzr
    if (name.length == 3)
    {
        if ((name[0] == 'x' || name[0] == 'X' || name[0] == 'w' || name[0] == 'W') &&
            (name[1] == 'z' || name[1] == 'Z') &&
            (name[2] == 'r' || name[2] == 'R'))
        {
            is64bit = (name[0] == 'x' || name[0] == 'X');
            regNum = 31;
            return true;
        }
    }

    // Check for x0-x30 or w0-w30
    if ((prefix == 'x' || prefix == 'w') && name.length >= 2)
    {
        is64bit = (prefix == 'x');

        // Parse register number
        uint num = 0;
        foreach (i, c; name[1 .. $])
        {
            if (c < '0' || c > '9')
                return false;
            num = num * 10 + (c - '0');
            if (num > 31)
                return false;
        }

        if (name.length == 2 && name[1] == '0')
            num = 0;

        if (num <= 30)
        {
            regNum = cast(ubyte)num;
            return true;
        }
    }

    return false;
}

/// Parse a register operand from the current token
private bool parseRegister(out AArch64Operand op)
{
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "register expected, not `%s`", asmstate.tok.toChars());
        return false;
    }

    ubyte regNum;
    bool is64bit;
    const(char)[] regName = asmstate.tok.ident.toString();

    if (!parseRegisterName(regName, regNum, is64bit))
    {
        error(asmstate.loc, "unknown register `%s`", regName.ptr);
        return false;
    }

    op.type = AArch64Operand.Type.Register;
    op.reg = regNum;
    op.is64bit = is64bit;

    asmNextToken();
    return true;
}

/*******************************
 * Immediate Parsing
 */

/// Parse an immediate value (expecting # prefix)
private bool parseImmediate(out AArch64Operand op)
{
    // Expect # prefix
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value must start with `#`");
        return false;
    }

    asmNextToken();

    // Parse the numeric value
    if (tokValue() == TOK.int32Literal || tokValue() == TOK.int64Literal)
    {
        op.type = AArch64Operand.Type.Immediate;
        op.imm = asmstate.tok.intvalue;
        asmNextToken();
        return true;
    }
    else if (tokValue() == TOK.uns32Literal || tokValue() == TOK.uns64Literal)
    {
        op.type = AArch64Operand.Type.Immediate;
        op.imm = cast(long)asmstate.tok.unsvalue;
        asmNextToken();
        return true;
    }
    else if (tokValue() == TOK.min)
    {
        // Handle negative numbers (- token followed by number)
        asmNextToken();
        if (tokValue() == TOK.int32Literal || tokValue() == TOK.int64Literal)
        {
            op.type = AArch64Operand.Type.Immediate;
            op.imm = -asmstate.tok.intvalue;
            asmNextToken();
            return true;
        }
        else if (tokValue() == TOK.uns32Literal || tokValue() == TOK.uns64Literal)
        {
            op.type = AArch64Operand.Type.Immediate;
            op.imm = -cast(long)asmstate.tok.unsvalue;
            asmNextToken();
            return true;
        }
    }

    error(asmstate.loc, "numeric value expected after `#`");
    return false;
}

/// Validate immediate is within range
private bool validateImmediateRange(long value, long min, long max, const(char)* context)
{
    if (value < min || value > max)
    {
        error(asmstate.loc, "immediate value %lld out of range for `%s` (must be %lld..%lld)",
              cast(long)value, context, cast(long)min, cast(long)max);
        return false;
    }
    return true;
}

/*******************************
 * Shift Parsing
 */

/**
 * Parse optional shift operand: [, shift_type #amount]
 * Params:
 *   instrName = Name of instruction (for error messages)
 *   is64bit = Whether this is a 64-bit operation (affects max shift)
 *   shift = Output: shift type (0=LSL, 1=LSR, 2=ASR, 3=ROR)
 *   amount = Output: shift amount (0-31 for 32-bit, 0-63 for 64-bit)
 * Returns: true if shift was successfully parsed (or no shift present), false on error
 */
private bool parseOptionalShift(const(char)* instrName, bool is64bit, out uint shift, out uint amount)
{
    // Default values (no shift)
    shift = 0;   // LSL
    amount = 0;  // No shift

    // Check for optional shift (comma followed by shift type)
    if (tokValue() != TOK.comma)
        return true;  // No shift present, that's OK

    asmNextToken();

    // Expect shift type identifier (lsl, lsr, asr, ror)
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "shift type expected after comma in `%s`", instrName);
        return false;
    }

    const(char)* shiftStr = asmstate.tok.ident.toChars();

    if (strcmp(shiftStr, "lsl") == 0)
        shift = 0;
    else if (strcmp(shiftStr, "lsr") == 0)
        shift = 1;
    else if (strcmp(shiftStr, "asr") == 0)
        shift = 2;
    else if (strcmp(shiftStr, "ror") == 0)
        shift = 3;
    else
    {
        error(asmstate.loc, "invalid shift type for `%s`, expected lsl/lsr/asr/ror", instrName);
        return false;
    }

    asmNextToken();

    // Expect '#' before shift amount
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "`#` expected before shift amount in `%s`", instrName);
        return false;
    }
    asmNextToken();

    // Parse shift amount
    if (tokValue() != TOK.int32Literal && tokValue() != TOK.int64Literal &&
        tokValue() != TOK.uns32Literal && tokValue() != TOK.uns64Literal)
    {
        error(asmstate.loc, "shift amount expected in `%s`", instrName);
        return false;
    }

    amount = cast(uint)asmstate.tok.unsvalue;

    // Validate shift amount range
    uint maxShift = is64bit ? 63 : 31;
    if (amount > maxShift)
    {
        error(asmstate.loc, "shift amount %u out of range for `%s` (0-%u)", amount, instrName, maxShift);
        return false;
    }

    asmNextToken();
    return true;
}

/*******************************
 * Memory Operand Parsing
 */

/// Parse an extend operation (LSL, UXTW, SXTW, SXTX)
private bool parseExtendOp(out ExtendOp extend)
{
    if (tokValue() != TOK.identifier)
        return false;

    const(char)[] extName = asmstate.tok.ident.toString();
    import core.stdc.ctype : tolower;

    // Convert to lowercase for comparison
    char[4] lowerName;
    size_t len = extName.length > 4 ? 4 : extName.length;
    foreach (i; 0 .. len)
        lowerName[i] = cast(char)tolower(extName[i]);

    const(char)[] lower = lowerName[0 .. len];

    if (lower == "lsl")
        extend = ExtendOp.LSL;
    else if (lower == "uxtw")
        extend = ExtendOp.UXTW;
    else if (lower == "sxtw")
        extend = ExtendOp.SXTW;
    else if (lower == "sxtx")
        extend = ExtendOp.SXTX;
    else
        return false;

    asmNextToken();
    return true;
}

/// Parse a memory operand: [Xn], [Xn, #imm], or [Xn, Xm]
/// Also supports extended modes: [Xn, Xm, extend #amount], [Xn, #imm]!, [Xn], #imm
private bool parseMemoryOperand(out AArch64Operand op)
{
    // Expect opening bracket
    if (tokValue() != TOK.leftBracket)
    {
        error(asmstate.loc, "`[` expected for memory operand");
        return false;
    }
    asmNextToken();

    // Parse base register
    AArch64Operand baseOp;
    if (!parseRegister(baseOp))
        return false;

    if (baseOp.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "base register expected in memory operand");
        return false;
    }

    // Base register should be 64-bit (X register or SP)
    if (!baseOp.is64bit)
    {
        error(asmstate.loc, "64-bit register expected as base in memory operand");
        return false;
    }

    op.type = AArch64Operand.Type.Memory;
    op.baseReg = baseOp.reg;
    op.hasIndex = false;
    op.hasOffset = false;
    op.extend = ExtendOp.None;
    op.shiftAmount = 0;
    op.addressingMode = AddressingMode.Offset;

    // Check for offset or index
    if (tokValue() == TOK.comma)
    {
        asmNextToken();

        // Check if it's an immediate or register
        if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
        {
            // Immediate offset
            AArch64Operand immOp;
            if (!parseImmediate(immOp))
                return false;

            op.offset = immOp.imm;
            op.hasOffset = true;
        }
        else
        {
            // Register offset
            AArch64Operand indexOp;
            if (!parseRegister(indexOp))
                return false;

            if (indexOp.type != AArch64Operand.Type.Register || !indexOp.is64bit)
            {
                error(asmstate.loc, "64-bit register expected as index in memory operand");
                return false;
            }

            op.indexReg = indexOp.reg;
            op.hasIndex = true;

            // Check for optional extend operation: [Xn, Xm, LSL #amount]
            if (tokValue() == TOK.comma)
            {
                asmNextToken();

                ExtendOp ext;
                if (parseExtendOp(ext))
                {
                    op.extend = ext;

                    // Check for optional shift amount
                    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
                    {
                        AArch64Operand shiftOp;
                        if (!parseImmediate(shiftOp))
                            return false;

                        // Validate shift amount (typically 0-3 for load/store)
                        if (shiftOp.imm < 0 || shiftOp.imm > 4)
                        {
                            error(asmstate.loc, "shift amount must be 0-4");
                            return false;
                        }
                        op.shiftAmount = cast(ubyte)shiftOp.imm;
                    }
                }
                else
                {
                    error(asmstate.loc, "extend operation (LSL, UXTW, SXTW, SXTX) expected");
                    return false;
                }
            }
        }
    }

    // Expect closing bracket
    if (tokValue() != TOK.rightBracket)
    {
        error(asmstate.loc, "`]` expected to close memory operand");
        return false;
    }
    asmNextToken();

    // Check for pre-indexed or post-indexed modes
    if (tokValue() == TOK.not)  // '!' for pre-indexed
    {
        if (!op.hasOffset)
        {
            error(asmstate.loc, "pre-indexed mode requires immediate offset");
            return false;
        }
        if (op.hasIndex)
        {
            error(asmstate.loc, "pre-indexed mode cannot use register offset");
            return false;
        }
        op.addressingMode = AddressingMode.PreIndexed;
        asmNextToken();
    }
    else if (tokValue() == TOK.comma)  // Post-indexed: [Xn], #imm
    {
        if (op.hasOffset || op.hasIndex)
        {
            error(asmstate.loc, "post-indexed mode cannot have offset inside brackets");
            return false;
        }

        asmNextToken();

        // Parse post-index immediate
        if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
        {
            error(asmstate.loc, "immediate offset expected for post-indexed mode");
            return false;
        }

        AArch64Operand postOp;
        if (!parseImmediate(postOp))
            return false;

        op.offset = postOp.imm;
        op.hasOffset = true;
        op.addressingMode = AddressingMode.PostIndexed;
    }

    return true;
}

/*******************************
 * Instruction Encoding Helpers
 */

/// Create a code structure with the encoded instruction
private code* emitInstruction(uint encoding)
{
    code* c = code_calloc();
    c.Iop = encoding;
    return c;
}

/// Encode a load/store instruction based on addressing mode
/// Params:
///   isLoad = true for LDR, false for STR
///   rt = target register
///   mem = memory operand
///   is64bit = true for 64-bit operation, false for 32-bit
/// Returns: encoded instruction or 0 on error
private uint encodeLoadStore(bool isLoad)(bool is64bit, ubyte rt, ref const AArch64Operand mem)
{
    immutable uint size = getLSSize(is64bit);
    immutable uint opc = isLoad ? 1 : 0;  // LDR=1, STR=0

    if (mem.hasIndex)
    {
        // Register offset mode: [Xn, Xm{, extend #amount}]
        uint extend = mem.extend != ExtendOp.None ? mem.extend : ExtendOp.LSL;
        uint S = mem.shiftAmount > 0 ? 1 : 0;
        return INSTR.ldst_regoff(size, 0, opc, mem.indexReg, extend, S, mem.baseReg, rt);
    }
    else if (mem.addressingMode == AddressingMode.PostIndexed)
    {
        // Post-indexed mode: [Xn], #imm
        uint imm9;
        if (!encodeImm9(mem.offset, imm9, isLoad ? "post-indexed ldr" : "post-indexed str"))
            return 0;
        return INSTR.ldst_immpost(size, 0, opc, imm9, mem.baseReg, rt);
    }
    else if (mem.addressingMode == AddressingMode.PreIndexed)
    {
        // Pre-indexed mode: [Xn, #imm]!
        uint imm9;
        if (!encodeImm9(mem.offset, imm9, isLoad ? "pre-indexed ldr" : "pre-indexed str"))
            return 0;
        return INSTR.ldst_immpre(size, 0, opc, imm9, mem.baseReg, rt);
    }
    else
    {
        // Offset mode: [Xn] or [Xn, #imm]
        ulong offset = mem.hasOffset ? mem.offset : 0;
        static if (isLoad)
            return INSTR.ldr_imm_gen(is64bit, rt, mem.baseReg, offset);
        else
            return INSTR.str_imm_gen(is64bit, rt, mem.baseReg, offset);
    }
}

/*******************************
 * Instruction Handlers
 */

/*******************************
 * Data Movement Instructions
 */

/// MOV instruction: mov Xd, Xn
private code* parseInstr_mov()
{
    asmNextToken(); // Skip 'mov'

    AArch64Operand dst, src;

    // Parse destination and source registers
    if (!parseRegister(dst) || !validateRegisterOperand(dst, "mov"))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    if (!parseRegister(src) || !validateRegisterOperand(src, "mov"))
        return null;

    // Validate register sizes match
    if (!validateRegisterSizeMatch(dst, src, "mov"))
        return null;

    uint encoding = INSTR.mov_register(getSizeFlag(dst.is64bit), src.reg, dst.reg);
    return emitInstruction(encoding);
}

/*******************************
 * Memory Access Instructions
 */

/// LDR instruction: ldr Xt, [Xn{, #imm|Xm}] with all addressing modes
private code* parseInstr_ldr()
{
    asmNextToken(); // Skip 'ldr'

    AArch64Operand dst, mem;

    // Parse destination register
    if (!parseRegister(dst) || !validateRegisterOperand(dst, "ldr"))
        return null;

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, "ldr"))
        return null;

    // Encode using helper function
    uint encoding = encodeLoadStore!true(dst.is64bit, dst.reg, mem);
    if (encoding == 0)
        return null;

    return emitInstruction(encoding);
}

/// STR instruction: str Xt, [Xn{, #imm|Xm}] with all addressing modes
private code* parseInstr_str()
{
    asmNextToken(); // Skip 'str'

    AArch64Operand src, mem;

    // Parse source register
    if (!parseRegister(src) || !validateRegisterOperand(src, "str"))
        return null;

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, "str"))
        return null;

    // Encode using helper function
    uint encoding = encodeLoadStore!false(src.is64bit, src.reg, mem);
    if (encoding == 0)
        return null;

    return emitInstruction(encoding);
}

/// Helper template for load/store pair instructions
private code* parseLoadStorePair(bool isLoad)(const(char)* instrName)
{
    asmNextToken();

    AArch64Operand rt1, rt2, mem;

    // Parse first register
    if (!parseRegister(rt1) || !validateRegisterOperand(rt1, instrName))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first register");
        return null;
    }
    asmNextToken();

    // Parse second register
    if (!parseRegister(rt2) || !validateRegisterOperand(rt2, instrName))
        return null;

    // Both registers must be same size
    if (!validateRegisterSizeMatch(rt1, rt2, instrName))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after second register");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, instrName))
        return null;

    // Load/store pair doesn't support register offset
    if (mem.hasIndex)
    {
        error(asmstate.loc, "register offset not supported for `%s`", instrName);
        return null;
    }

    uint opc = rt1.is64bit ? LSPairOpc.DoubleWord : LSPairOpc.Word;
    uint L = isLoad ? 1 : 0;
    uint imm7 = cast(uint)((mem.hasOffset ? mem.offset : 0) >> (rt1.is64bit ? 3 : 2)) & 0x7F;
    uint encoding;

    if (mem.addressingMode == AddressingMode.PostIndexed)
        encoding = INSTR.ldstpair_post(opc, 0, L, imm7, rt2.reg, mem.baseReg, rt1.reg);
    else if (mem.addressingMode == AddressingMode.PreIndexed)
        encoding = INSTR.ldstpair_pre(opc, 0, L, imm7, rt2.reg, mem.baseReg, rt1.reg);
    else
        encoding = INSTR.ldstpair_off(opc, 0, L, imm7, rt2.reg, mem.baseReg, rt1.reg);

    return emitInstruction(encoding);
}

/// LDP instruction: ldp Xt1, Xt2, [Xn{, #imm}] (load pair)
private code* parseInstr_ldp()
{
    return parseLoadStorePair!true("ldp");
}

/// STP instruction: stp Xt1, Xt2, [Xn{, #imm}] (store pair)
private code* parseInstr_stp()
{
    return parseLoadStorePair!false("stp");
}

/// Helper template for byte/halfword load/store instructions
private code* parseByteHalfwordLoadStore(LSSize size, bool isLoad)(const(char)* instrName)
{
    asmNextToken();

    AArch64Operand rt, mem;

    // Parse register (must be W register)
    if (!parseRegister(rt) || !validateRegisterOperand(rt, instrName))
        return null;

    if (rt.is64bit)
    {
        error(asmstate.loc, "32-bit register expected for `%s` (use W register)", instrName);
        return null;
    }

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after %s register", isLoad ? "destination".ptr : "source".ptr);
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, instrName))
        return null;

    uint encoding;

    if (mem.hasIndex)
    {
        uint extend = mem.extend != ExtendOp.None ? mem.extend : ExtendOp.LSL;
        uint S = mem.shiftAmount > 0 ? 1 : 0;

        static if (size == LSSize.Byte)
        {
            static if (isLoad)
                encoding = INSTR.ldrb_reg(0, mem.indexReg, extend, S, mem.baseReg, rt.reg);
            else
                encoding = INSTR.strb_reg(mem.indexReg, extend, S, mem.baseReg, rt.reg);
        }
        else static if (size == LSSize.HalfWord)
        {
            static if (isLoad)
                encoding = INSTR.ldrh_reg(0, mem.indexReg, extend, S, mem.baseReg, rt.reg);
            else
                encoding = INSTR.strh_reg(mem.indexReg, extend, S, mem.baseReg, rt.reg);
        }
    }
    else
    {
        ulong offset = mem.hasOffset ? mem.offset : 0;

        static if (size == LSSize.Byte)
        {
            static if (isLoad)
                encoding = INSTR.ldrb_imm(0, rt.reg, mem.baseReg, offset);
            else
                encoding = INSTR.strb_imm(rt.reg, mem.baseReg, offset);
        }
        else static if (size == LSSize.HalfWord)
        {
            static if (isLoad)
                encoding = INSTR.ldrh_imm(0, rt.reg, mem.baseReg, offset);
            else
                encoding = INSTR.strh_imm(rt.reg, mem.baseReg, offset);
        }
    }

    return emitInstruction(encoding);
}

/// LDRB instruction: ldrb Wt, [Xn{, #imm|Xm}] (load byte)
private code* parseInstr_ldrb()
{
    return parseByteHalfwordLoadStore!(LSSize.Byte, true)("ldrb");
}

/// STRB instruction: strb Wt, [Xn{, #imm|Xm}] (store byte)
private code* parseInstr_strb()
{
    return parseByteHalfwordLoadStore!(LSSize.Byte, false)("strb");
}

/// LDRH instruction: ldrh Wt, [Xn{, #imm|Xm}] (load halfword)
private code* parseInstr_ldrh()
{
    return parseByteHalfwordLoadStore!(LSSize.HalfWord, true)("ldrh");
}

/// STRH instruction: strh Wt, [Xn{, #imm|Xm}] (store halfword)
private code* parseInstr_strh()
{
    return parseByteHalfwordLoadStore!(LSSize.HalfWord, false)("strh");
}

/// Helper template for signed byte/halfword load instructions
private code* parseSignedLoad(LSSize size)(const(char)* instrName)
{
    asmNextToken();

    AArch64Operand dst, mem;

    // Parse destination register (can be W or X)
    if (!parseRegister(dst) || !validateRegisterOperand(dst, instrName))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, instrName))
        return null;

    uint encoding;
    uint sz = dst.is64bit ? 0 : 1;  // 0 for 64-bit dest, 1 for 32-bit dest

    if (mem.hasIndex)
    {
        uint extend = mem.extend != ExtendOp.None ? mem.extend : ExtendOp.LSL;
        uint S = mem.shiftAmount > 0 ? 1 : 0;

        static if (size == LSSize.Byte)
            encoding = INSTR.ldrsb_reg(sz, mem.indexReg, extend, S, mem.baseReg, dst.reg);
        else static if (size == LSSize.HalfWord)
            encoding = INSTR.ldrsh_reg(sz, mem.indexReg, extend, S, mem.baseReg, dst.reg);
    }
    else
    {
        ulong offset = mem.hasOffset ? mem.offset : 0;

        static if (size == LSSize.Byte)
            encoding = INSTR.ldrsb_imm(sz, dst.reg, mem.baseReg, offset);
        else static if (size == LSSize.HalfWord)
            encoding = INSTR.ldrsh_imm(sz, dst.reg, mem.baseReg, offset);
    }

    return emitInstruction(encoding);
}

/// LDRSB instruction: ldrsb Xt, [Xn{, #imm|Xm}] (load signed byte)
private code* parseInstr_ldrsb()
{
    return parseSignedLoad!(LSSize.Byte)("ldrsb");
}

/// LDRSH instruction: ldrsh Xt, [Xn{, #imm|Xm}] (load signed halfword)
private code* parseInstr_ldrsh()
{
    return parseSignedLoad!(LSSize.HalfWord)("ldrsh");
}

/// LDRSW instruction: ldrsw Xt, [Xn{, #imm}] (load signed word)
private code* parseInstr_ldrsw()
{
    asmNextToken(); // Skip 'ldrsw'

    AArch64Operand dst, mem;

    // Parse destination register (must be X register)
    if (!parseRegister(dst) || !validate64BitRegister(dst, "ldrsw"))
        return null;

    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse memory operand
    if (!parseMemoryOperand(mem) || !validateMemoryOperand(mem, "ldrsw"))
        return null;

    // LDRSW only supports immediate offset (no register offset in basic form)
    if (mem.hasIndex)
    {
        error(asmstate.loc, "register offset not supported for `ldrsw`");
        return null;
    }

    uint imm12 = cast(uint)((mem.hasOffset ? mem.offset : 0) >> 2) & 0xFFF;
    uint encoding = INSTR.ldrsw_imm(imm12, mem.baseReg, dst.reg);

    return emitInstruction(encoding);
}

/*******************************
 * Arithmetic Instructions
 */

/**
 * Helper function for ADD/ADDS/SUB/SUBS style instructions
 * Params:
 *   instrName = instruction name for error messages
 *   op = 0 for ADD, 1 for SUB
 *   S = 0 for non-flag-setting, 1 for flag-setting
 * Returns: encoded instruction or null on error
 */
private code* parseArithmeticAddSub(const(char)* instrName, uint op, uint S)
{
    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `%s`", instrName);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `%s`", instrName);
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if third operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form
        if (!parseImmediate(src2))
            return null;

        // Validate immediate range (0-4095, or 0-4095 shifted left by 12)
        if (!validateImmediateRange(src2.imm, 0, 4095, instrName))
            return null;

        encoding = INSTR.addsub_imm(sf, op, S, 0, cast(uint)src2.imm, src1.reg, dst.reg);
    }
    else
    {
        // Register form
        if (!parseRegister(src2))
            return null;

        if (src2.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as second source for `%s`", instrName);
            return null;
        }

        // Validate size match
        if (dst.is64bit != src2.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
            return null;
        }

        // Parse optional shift
        uint shift, imm6;
        if (!parseOptionalShift(instrName, dst.is64bit, shift, imm6))
            return null;

        encoding = INSTR.addsub_shift(sf, op, S, shift, src2.reg, imm6, src1.reg, dst.reg);
    }

    return emitInstruction(encoding);
}

/**
 * Helper function for ADC/ADCS/SBC/SBCS style instructions
 * Params:
 *   instrName = instruction name for error messages
 *   op = 0 for ADC, 1 for SBC
 *   S = 0 for non-flag-setting, 1 for flag-setting
 * Returns: encoded instruction or null on error
 */
private code* parseArithmeticCarry(const(char)* instrName, uint op, uint S)
{
    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `%s`", instrName);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `%s`", instrName);
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `%s`", instrName);
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `%s` instruction", instrName);
        return null;
    }

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = (op == 0) ?
        (S == 0 ? INSTR.adc(sf, src2.reg, src1.reg, dst.reg) : INSTR.adcs(sf, src2.reg, src1.reg, dst.reg)) :
        (S == 0 ? INSTR.sbc(sf, src2.reg, src1.reg, dst.reg) : INSTR.sbcs(sf, src2.reg, src1.reg, dst.reg));

    return emitInstruction(encoding);
}

/// ADD instruction: add Xd, Xn, #imm|Xm
private code* parseInstr_add()
{
    asmNextToken(); // Skip 'add'
    return parseArithmeticAddSub("add", 0, 0); // op=0 (ADD), S=0 (no flags)
}

/// ADDS instruction: adds Xd, Xn, #imm|Xm (add and set flags)
private code* parseInstr_adds()
{
    asmNextToken(); // Skip 'adds'
    return parseArithmeticAddSub("adds", 0, 1); // op=0 (ADD), S=1 (set flags)
}

/// SUB instruction: sub Xd, Xn, #imm|Xm
private code* parseInstr_sub()
{
    asmNextToken(); // Skip 'sub'
    return parseArithmeticAddSub("sub", 1, 0); // op=1 (SUB), S=0 (no flags)
}

/// SUBS instruction: subs Xd, Xn, #imm|Xm (subtract and set flags)
private code* parseInstr_subs()
{
    asmNextToken(); // Skip 'subs'
    return parseArithmeticAddSub("subs", 1, 1); // op=1 (SUB), S=1 (set flags)
}

/*******************************
 * Multiply Instructions
 */

/// MUL instruction: mul Xd, Xn, Xm (multiply, encoded as MADD with Ra=XZR)
private code* parseInstr_mul()
{
    asmNextToken(); // Skip 'mul'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `mul`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `mul`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `mul` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `mul`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `mul` instruction");
        return null;
    }

    // MUL is encoded as MADD with Ra=XZR (register 31)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.madd(sf, src2.reg, 31, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// MADD instruction: madd Xd, Xn, Xm, Xa (Xd = Xa + Xn * Xm)
private code* parseInstr_madd()
{
    asmNextToken(); // Skip 'madd'

    AArch64Operand dst, src1, src2, src3;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `madd`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register (Xn)
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `madd`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `madd` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register (Xm)
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `madd`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `madd` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after second source register");
        return null;
    }
    asmNextToken();

    // Parse third source register (Xa - addend)
    if (!parseRegister(src3))
        return null;

    if (src3.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as third source for `madd`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src3.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `madd` instruction");
        return null;
    }

    // MADD: Xd = Xa + Xn * Xm
    // Encoding: madd(sf, Rm, Ra, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.madd(sf, src2.reg, src3.reg, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// MSUB instruction: msub Xd, Xn, Xm, Xa (Xd = Xa - Xn * Xm)
private code* parseInstr_msub()
{
    asmNextToken(); // Skip 'msub'

    AArch64Operand dst, src1, src2, src3;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `msub`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register (Xn)
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `msub`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `msub` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register (Xm)
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `msub`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `msub` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after second source register");
        return null;
    }
    asmNextToken();

    // Parse third source register (Xa - minuend)
    if (!parseRegister(src3))
        return null;

    if (src3.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as third source for `msub`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src3.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `msub` instruction");
        return null;
    }

    // MSUB: Xd = Xa - Xn * Xm
    // Encoding: msub(sf, Rm, Ra, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.msub(sf, src2.reg, src3.reg, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// SDIV instruction: sdiv Xd, Xn, Xm (Xd = Xn / Xm, signed)
private code* parseInstr_sdiv()
{
    asmNextToken(); // Skip 'sdiv'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `sdiv`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register (dividend)
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `sdiv`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `sdiv` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register (divisor)
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `sdiv`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `sdiv` instruction");
        return null;
    }

    // SDIV: Xd = Xn / Xm (signed)
    // Encoding: sdiv_udiv(sf, uns, Rm, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.sdiv_udiv(sf, false, src2.reg, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// UDIV instruction: udiv Xd, Xn, Xm (Xd = Xn / Xm, unsigned)
private code* parseInstr_udiv()
{
    asmNextToken(); // Skip 'udiv'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `udiv`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register (dividend)
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `udiv`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `udiv` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register (divisor)
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `udiv`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `udiv` instruction");
        return null;
    }

    // UDIV: Xd = Xn / Xm (unsigned)
    // Encoding: sdiv_udiv(sf, uns, Rm, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.sdiv_udiv(sf, true, src2.reg, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// NEG instruction: neg Xd, Xm[, shift #amount] (Xd = 0 - Xm)
private code* parseInstr_neg()
{
    asmNextToken(); // Skip 'neg'

    AArch64Operand dst, src;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `neg`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `neg`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `neg` instruction");
        return null;
    }

    // Parse optional shift
    uint shift, imm6;
    if (!parseOptionalShift("neg", dst.is64bit, shift, imm6))
        return null;

    // NEG: Xd = 0 - Xm (with optional shift)
    // Encoding: neg_sub_addsub_shift(sf, S, shift, Rm, imm6, Rd)
    // S=0 for NEG (don't set flags), S=1 for NEGS (set flags)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.neg_sub_addsub_shift(sf, 0, shift, src.reg, imm6, dst.reg);

    return emitInstruction(encoding);
}

/// NEGS instruction: negs Xd, Xm (negate and set flags)
private code* parseInstr_negs()
{
    asmNextToken(); // Skip 'negs'

    AArch64Operand dst, src;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `negs`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `negs`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `negs` instruction");
        return null;
    }

    // Parse optional shift
    uint shift, imm6;
    if (!parseOptionalShift("negs", dst.is64bit, shift, imm6))
        return null;

    // NEGS: Xd = 0 - Xm (with optional shift), set flags
    // Encoding: neg_sub_addsub_shift(sf, S, shift, Rm, imm6, Rd)
    // S=1 for NEGS (set flags)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.neg_sub_addsub_shift(sf, 1, shift, src.reg, imm6, dst.reg);

    return emitInstruction(encoding);
}

/// ADC instruction: adc Xd, Xn, Xm (add with carry)
private code* parseInstr_adc()
{
    asmNextToken(); // Skip 'adc'
    return parseArithmeticCarry("adc", 0, 0); // op=0 (ADC), S=0 (no flags)
}

/// SBC instruction: sbc Xd, Xn, Xm (subtract with carry)
private code* parseInstr_sbc()
{
    asmNextToken(); // Skip 'sbc'
    return parseArithmeticCarry("sbc", 1, 0); // op=1 (SBC), S=0 (no flags)
}

/// ADCS instruction: adcs Xd, Xn, Xm (add with carry and set flags)
private code* parseInstr_adcs()
{
    asmNextToken(); // Skip 'adcs'
    return parseArithmeticCarry("adcs", 0, 1); // op=0 (ADC), S=1 (set flags)
}

/// SBCS instruction: sbcs Xd, Xn, Xm (subtract with carry and set flags)
private code* parseInstr_sbcs()
{
    asmNextToken(); // Skip 'sbcs'
    return parseArithmeticCarry("sbcs", 1, 1); // op=1 (SBC), S=1 (set flags)
}

/*******************************
 * Logical Instructions
 */

/// AND instruction: and Xd, Xn, Xm (bitwise and)
private code* parseInstr_and()
{
    asmNextToken(); // Skip 'and'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `and`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `and`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `and` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `and`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `and` instruction");
        return null;
    }

    // AND: log_shift(sf, opc=0, shift=0, N=0, Rm, imm6=0, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 0, 0, 0, src2.reg, 0, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// ORR instruction: orr Xd, Xn, Xm (bitwise or)
private code* parseInstr_orr()
{
    asmNextToken(); // Skip 'orr'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `orr`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `orr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `orr` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `orr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `orr` instruction");
        return null;
    }

    // ORR: log_shift(sf, opc=1, shift=0, N=0, Rm, imm6=0, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 1, 0, 0, src2.reg, 0, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// EOR instruction: eor Xd, Xn, Xm (bitwise exclusive or)
private code* parseInstr_eor()
{
    asmNextToken(); // Skip 'eor'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `eor`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `eor`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `eor` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `eor`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `eor` instruction");
        return null;
    }

    // EOR: log_shift(sf, opc=2, shift=0, N=0, Rm, imm6=0, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 2, 0, 0, src2.reg, 0, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// MVN instruction: mvn Xd, Xm (bitwise NOT, encoded as ORN with Rn=XZR)
private code* parseInstr_mvn()
{
    asmNextToken(); // Skip 'mvn'

    AArch64Operand dst, src;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `mvn`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `mvn`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `mvn` instruction");
        return null;
    }

    // MVN is encoded as ORN (ORR-NOT) with Rn=XZR (register 31)
    // log_shift(sf, opc=1 (ORR), shift=0, N=1 (NOT), Rm, imm6=0, Rn=31, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 1, 0, 1, src.reg, 0, 31, dst.reg);

    return emitInstruction(encoding);
}

/// BIC instruction: bic Xd, Xn, Xm[, shift #amount] (bit clear: Xd = Xn & ~Xm)
private code* parseInstr_bic()
{
    asmNextToken(); // Skip 'bic'

    AArch64Operand dst, src1, src2;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `bic`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `bic`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `bic` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `bic`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `bic` instruction");
        return null;
    }

    // Parse optional shift
    uint shift, imm6;
    if (!parseOptionalShift("bic", dst.is64bit, shift, imm6))
        return null;

    // BIC: Xd = Xn & ~Xm (with optional shift on Xm)
    // Encoding: log_shift(sf, opc=0 (AND), shift, N=1 (NOT), Rm, imm6, Rn, Rd)
    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 0, shift, 1, src2.reg, imm6, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// TST instruction: tst Xn, Xm[, shift #amount] (test bits: flags = Xn & Xm)
private code* parseInstr_tst()
{
    asmNextToken(); // Skip 'tst'

    AArch64Operand src1, src2;

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `tst`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `tst`");
        return null;
    }

    // Validate size match
    if (src1.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `tst` instruction");
        return null;
    }

    // Parse optional shift
    uint shift, imm6;
    if (!parseOptionalShift("tst", src1.is64bit, shift, imm6))
        return null;

    // TST: Flags = Xn & Xm (with optional shift on Xm)
    // Encoding: log_shift(sf, opc=3 (ANDS), shift, N=0, Rm, imm6, Rn, Rd=31 (XZR))
    // Rd is XZR because TST only sets flags, doesn't write result
    uint sf = src1.is64bit ? 1 : 0;
    uint encoding = INSTR.log_shift(sf, 3, shift, 0, src2.reg, imm6, src1.reg, 31);

    return emitInstruction(encoding);
}

/*******************************
 * Compare Instructions
 */

/// CMP instruction: cmp Xn, #imm or cmp Xn, Xm (compare)
private code* parseInstr_cmp()
{
    asmNextToken(); // Skip 'cmp'

    AArch64Operand src1, src2;

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first operand for `cmp`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first operand");
        return null;
    }
    asmNextToken();

    uint sf = src1.is64bit ? 1 : 0;
    uint encoding;

    // Check if second operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form
        if (!parseImmediate(src2))
            return null;

        // Validate immediate range (0-4095)
        if (!validateImmediateRange(src2.imm, 0, 4095, "cmp"))
            return null;

        // CMP with immediate
        encoding = INSTR.cmp_imm(sf, 0, cast(uint)src2.imm, src1.reg);
    }
    else
    {
        // Register form
        if (!parseRegister(src2))
            return null;

        if (src2.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as second operand for `cmp`");
            return null;
        }

        // Validate size match
        if (src1.is64bit != src2.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `cmp` instruction");
            return null;
        }

        // CMP with register (no shift)
        encoding = INSTR.cmp_subs_addsub_shift(sf, src2.reg, 0, 0, src1.reg);
    }

    return emitInstruction(encoding);
}

/// CMN instruction: cmn Xn, #imm|Xm (compare negative - adds and sets flags, discards result)
private code* parseInstr_cmn()
{
    asmNextToken(); // Skip 'cmn'

    AArch64Operand src1, src2;

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first operand for `cmn`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first operand");
        return null;
    }
    asmNextToken();

    uint sf = src1.is64bit ? 1 : 0;
    uint encoding;

    // Check if second operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form
        if (!parseImmediate(src2))
            return null;

        // Validate immediate range (0-4095)
        if (!validateImmediateRange(src2.imm, 0, 4095, "cmn"))
            return null;

        // CMN with immediate: ADDS XZR, Xn, #imm (op=0, S=1, Rd=31)
        encoding = INSTR.addsub_imm(sf, 0, 1, 0, cast(uint)src2.imm, src1.reg, 31);
    }
    else
    {
        // Register form
        if (!parseRegister(src2))
            return null;

        if (src2.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as second operand for `cmn`");
            return null;
        }

        // Validate size match
        if (src1.is64bit != src2.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `cmn` instruction");
            return null;
        }

        // Parse optional shift
        uint shift, imm6;
        if (!parseOptionalShift("cmn", src1.is64bit, shift, imm6))
            return null;

        // CMN with register: ADDS XZR, Xn, Xm (op=0, S=1, Rd=31)
        encoding = INSTR.addsub_shift(sf, 0, 1, shift, src2.reg, imm6, src1.reg, 31);
    }

    return emitInstruction(encoding);
}

/*******************************
 * Shift and Bit Manipulation Instructions
 */

/// LSL instruction: lsl Xd, Xn, #shift or lsl Xd, Xn, Xm
private code* parseInstr_lsl()
{
    asmNextToken(); // Skip 'lsl'

    AArch64Operand dst, src, shiftOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `lsl`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `lsl`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `lsl` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if third operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form: lsl Xd, Xn, #shift
        if (!parseImmediate(shiftOp))
            return null;

        uint maxShift = dst.is64bit ? 63 : 31;
        if (shiftOp.imm < 0 || shiftOp.imm > maxShift)
        {
            error(asmstate.loc, "shift amount out of range (0-%u) for `lsl`", maxShift);
            return null;
        }

        // LSL Rd, Rn, #shift is an alias for UBFM
        encoding = INSTR.lsl_ubfm(sf, cast(uint)shiftOp.imm, src.reg, dst.reg);
    }
    else
    {
        // Register form: lsl Xd, Xn, Xm
        if (!parseRegister(shiftOp))
            return null;

        if (shiftOp.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as shift amount for `lsl`");
            return null;
        }

        // Validate size match
        if (dst.is64bit != shiftOp.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `lsl` instruction");
            return null;
        }

        // LSL Rd, Rn, Rm uses LSLV
        encoding = INSTR.lslv(sf, shiftOp.reg, src.reg, dst.reg);
    }

    return emitInstruction(encoding);
}

/// LSR instruction: lsr Xd, Xn, #shift or lsr Xd, Xn, Xm
private code* parseInstr_lsr()
{
    asmNextToken(); // Skip 'lsr'

    AArch64Operand dst, src, shiftOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `lsr`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `lsr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `lsr` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if third operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form: lsr Xd, Xn, #shift
        if (!parseImmediate(shiftOp))
            return null;

        uint maxShift = dst.is64bit ? 63 : 31;
        if (shiftOp.imm < 0 || shiftOp.imm > maxShift)
        {
            error(asmstate.loc, "shift amount out of range (0-%u) for `lsr`", maxShift);
            return null;
        }

        // LSR Rd, Rn, #shift is an alias for UBFM
        encoding = INSTR.lsr_ubfm(sf, cast(uint)shiftOp.imm, src.reg, dst.reg);
    }
    else
    {
        // Register form: lsr Xd, Xn, Xm
        if (!parseRegister(shiftOp))
            return null;

        if (shiftOp.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as shift amount for `lsr`");
            return null;
        }

        // Validate size match
        if (dst.is64bit != shiftOp.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `lsr` instruction");
            return null;
        }

        // LSR Rd, Rn, Rm uses LSRV
        encoding = INSTR.lsrv(sf, shiftOp.reg, src.reg, dst.reg);
    }

    return emitInstruction(encoding);
}

/// ASR instruction: asr Xd, Xn, #shift or asr Xd, Xn, Xm
private code* parseInstr_asr()
{
    asmNextToken(); // Skip 'asr'

    AArch64Operand dst, src, shiftOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `asr`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `asr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `asr` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if third operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form: asr Xd, Xn, #shift
        if (!parseImmediate(shiftOp))
            return null;

        uint maxShift = dst.is64bit ? 63 : 31;
        if (shiftOp.imm < 0 || shiftOp.imm > maxShift)
        {
            error(asmstate.loc, "shift amount out of range (0-%u) for `asr`", maxShift);
            return null;
        }

        // ASR Rd, Rn, #shift is an alias for SBFM
        encoding = INSTR.asr_sbfm(sf, cast(uint)shiftOp.imm, src.reg, dst.reg);
    }
    else
    {
        // Register form: asr Xd, Xn, Xm
        if (!parseRegister(shiftOp))
            return null;

        if (shiftOp.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as shift amount for `asr`");
            return null;
        }

        // Validate size match
        if (dst.is64bit != shiftOp.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `asr` instruction");
            return null;
        }

        // ASR Rd, Rn, Rm uses ASRV
        encoding = INSTR.asrv(sf, shiftOp.reg, src.reg, dst.reg);
    }

    return emitInstruction(encoding);
}

/// ROR instruction: ror Xd, Xn, #shift or ror Xd, Xn, Xm
private code* parseInstr_ror()
{
    asmNextToken(); // Skip 'ror'

    AArch64Operand dst, src, shiftOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `ror`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `ror`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `ror` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding;

    // Check if third operand is immediate or register
    if (tokValue() == TOK.identifier && asmstate.tok.ident.toString() == "#")
    {
        // Immediate form: ror Xd, Xn, #shift
        if (!parseImmediate(shiftOp))
            return null;

        uint maxShift = dst.is64bit ? 63 : 31;
        if (shiftOp.imm < 0 || shiftOp.imm > maxShift)
        {
            error(asmstate.loc, "shift amount out of range (0-%u) for `ror`", maxShift);
            return null;
        }

        // ROR Rd, Rn, #shift is an alias for EXTR
        encoding = INSTR.ror_extr(sf, cast(uint)shiftOp.imm, src.reg, dst.reg);
    }
    else
    {
        // Register form: ror Xd, Xn, Xm
        if (!parseRegister(shiftOp))
            return null;

        if (shiftOp.type != AArch64Operand.Type.Register)
        {
            error(asmstate.loc, "register or immediate expected as shift amount for `ror`");
            return null;
        }

        // Validate size match
        if (dst.is64bit != shiftOp.is64bit)
        {
            error(asmstate.loc, "register size mismatch in `ror` instruction");
            return null;
        }

        // ROR Rd, Rn, Rm uses RORV
        encoding = INSTR.rorv(sf, shiftOp.reg, src.reg, dst.reg);
    }

    return emitInstruction(encoding);
}

/// EXTR instruction: extr Xd, Xn, Xm, #lsb
private code* parseInstr_extr()
{
    asmNextToken(); // Skip 'extr'

    AArch64Operand dst, src1, src2, lsbOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `extr`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse first source register
    if (!parseRegister(src1))
        return null;

    if (src1.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as first source for `extr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src1.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `extr` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after first source register");
        return null;
    }
    asmNextToken();

    // Parse second source register
    if (!parseRegister(src2))
        return null;

    if (src2.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as second source for `extr`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src2.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `extr` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after second source register");
        return null;
    }
    asmNextToken();

    // Parse immediate LSB
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for LSB in `extr`");
        return null;
    }

    if (!parseImmediate(lsbOp))
        return null;

    uint maxLsb = dst.is64bit ? 63 : 31;
    if (lsbOp.imm < 0 || lsbOp.imm > maxLsb)
    {
        error(asmstate.loc, "LSB out of range (0-%u) for `extr`", maxLsb);
        return null;
    }

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.extr(sf, src2.reg, cast(uint)lsbOp.imm, src1.reg, dst.reg);

    return emitInstruction(encoding);
}

/// UBFM instruction: ubfm Xd, Xn, #immr, #imms (unsigned bitfield move)
private code* parseInstr_ubfm()
{
    asmNextToken(); // Skip 'ubfm'

    AArch64Operand dst, src, immrOp, immsOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `ubfm`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `ubfm`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `ubfm` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    // Parse immr
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for immr in `ubfm`");
        return null;
    }

    if (!parseImmediate(immrOp))
        return null;

    uint maxImm = dst.is64bit ? 63 : 31;
    if (immrOp.imm < 0 || immrOp.imm > maxImm)
    {
        error(asmstate.loc, "immr out of range (0-%u) for `ubfm`", maxImm);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after immr");
        return null;
    }
    asmNextToken();

    // Parse imms
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for imms in `ubfm`");
        return null;
    }

    if (!parseImmediate(immsOp))
        return null;

    if (immsOp.imm < 0 || immsOp.imm > maxImm)
    {
        error(asmstate.loc, "imms out of range (0-%u) for `ubfm`", maxImm);
        return null;
    }

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.ubfm(sf, sf, cast(uint)immrOp.imm, cast(uint)immsOp.imm, src.reg, dst.reg);

    return emitInstruction(encoding);
}

/// SBFM instruction: sbfm Xd, Xn, #immr, #imms (signed bitfield move)
private code* parseInstr_sbfm()
{
    asmNextToken(); // Skip 'sbfm'

    AArch64Operand dst, src, immrOp, immsOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `sbfm`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `sbfm`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `sbfm` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    // Parse immr
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for immr in `sbfm`");
        return null;
    }

    if (!parseImmediate(immrOp))
        return null;

    uint maxImm = dst.is64bit ? 63 : 31;
    if (immrOp.imm < 0 || immrOp.imm > maxImm)
    {
        error(asmstate.loc, "immr out of range (0-%u) for `sbfm`", maxImm);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after immr");
        return null;
    }
    asmNextToken();

    // Parse imms
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for imms in `sbfm`");
        return null;
    }

    if (!parseImmediate(immsOp))
        return null;

    if (immsOp.imm < 0 || immsOp.imm > maxImm)
    {
        error(asmstate.loc, "imms out of range (0-%u) for `sbfm`", maxImm);
        return null;
    }

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.sbfm(sf, sf, cast(uint)immrOp.imm, cast(uint)immsOp.imm, src.reg, dst.reg);

    return emitInstruction(encoding);
}

/// BFM instruction: bfm Xd, Xn, #immr, #imms (bitfield move/insert)
private code* parseInstr_bfm()
{
    asmNextToken(); // Skip 'bfm'

    AArch64Operand dst, src, immrOp, immsOp;

    // Parse destination register
    if (!parseRegister(dst))
        return null;

    if (dst.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as destination for `bfm`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after destination register");
        return null;
    }
    asmNextToken();

    // Parse source register
    if (!parseRegister(src))
        return null;

    if (src.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected as source for `bfm`");
        return null;
    }

    // Validate size match
    if (dst.is64bit != src.is64bit)
    {
        error(asmstate.loc, "register size mismatch in `bfm` instruction");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after source register");
        return null;
    }
    asmNextToken();

    // Parse immr
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for immr in `bfm`");
        return null;
    }

    if (!parseImmediate(immrOp))
        return null;

    uint maxImm = dst.is64bit ? 63 : 31;
    if (immrOp.imm < 0 || immrOp.imm > maxImm)
    {
        error(asmstate.loc, "immr out of range (0-%u) for `bfm`", maxImm);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after immr");
        return null;
    }
    asmNextToken();

    // Parse imms
    if (tokValue() != TOK.identifier || asmstate.tok.ident.toString() != "#")
    {
        error(asmstate.loc, "immediate value expected for imms in `bfm`");
        return null;
    }

    if (!parseImmediate(immsOp))
        return null;

    if (immsOp.imm < 0 || immsOp.imm > maxImm)
    {
        error(asmstate.loc, "imms out of range (0-%u) for `bfm`", maxImm);
        return null;
    }

    uint sf = dst.is64bit ? 1 : 0;
    uint encoding = INSTR.bfm(sf, sf, cast(uint)immrOp.imm, cast(uint)immsOp.imm, src.reg, dst.reg);

    return emitInstruction(encoding);
}

/*******************************
 * Branch Instructions
 */

/// B instruction: b[.cond] label
private code* parseInstr_b()
{
    // The mnemonic might be "b" or "b.eq", "b.ne", etc.
    // Check if there's a dot followed by a condition code
    const(char)[] mnemonic = asmstate.tok.ident.toString();
    asmNextToken(); // Skip mnemonic

    CondCode cond = CondCode.AL;  // Default: always (unconditional)
    bool hasCondition = false;

    // Check if mnemonic contains a dot (e.g., "b.eq")
    foreach (i, c; mnemonic)
    {
        if (c == '.')
        {
            if (i + 1 < mnemonic.length)
            {
                const(char)[] condStr = mnemonic[i + 1 .. $];
                if (parseConditionCode(condStr, cond))
                {
                    hasCondition = true;
                }
                else
                {
                    error(asmstate.loc, "unknown condition code `%s`", condStr.ptr);
                    return null;
                }
            }
            break;
        }
    }

    // Parse label operand
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `b` instruction");
        return null;
    }

    // Note: Full label resolution requires backend integration
    // For now, emit a placeholder instruction with offset 0
    uint encoding;
    if (hasCondition)
    {
        // Conditional branch: b.cond label
        // Use b_cond encoding with offset 0 as placeholder
        encoding = INSTR.b_cond(0, cond);
    }
    else
    {
        // Unconditional branch: b label
        encoding = INSTR.b_uncond(0);
    }

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/// CBZ instruction: cbz Xt, label (compare and branch if zero)
private code* parseInstr_cbz()
{
    asmNextToken(); // Skip 'cbz'

    AArch64Operand reg;

    // Parse register to test
    if (!parseRegister(reg))
        return null;

    if (reg.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected for `cbz`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after register");
        return null;
    }
    asmNextToken();

    // Parse label
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `cbz`");
        return null;
    }

    // Encode cbz with offset 0 as placeholder
    uint sf = reg.is64bit ? 1 : 0;
    uint encoding = INSTR.compbranch(sf, 0, 0, reg.reg);

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/// CBNZ instruction: cbnz Xt, label (compare and branch if non-zero)
private code* parseInstr_cbnz()
{
    asmNextToken(); // Skip 'cbnz'

    AArch64Operand reg;

    // Parse register to test
    if (!parseRegister(reg))
        return null;

    if (reg.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected for `cbnz`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after register");
        return null;
    }
    asmNextToken();

    // Parse label
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `cbnz`");
        return null;
    }

    // Encode cbnz with offset 0 as placeholder
    uint sf = reg.is64bit ? 1 : 0;
    uint encoding = INSTR.compbranch(sf, 1, 0, reg.reg);

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/// TBZ instruction: tbz Xt, #imm, label (test bit and branch if zero)
private code* parseInstr_tbz()
{
    asmNextToken(); // Skip 'tbz'

    AArch64Operand reg, bitImm;

    // Parse register to test
    if (!parseRegister(reg))
        return null;

    if (reg.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected for `tbz`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after register");
        return null;
    }
    asmNextToken();

    // Parse bit number immediate
    if (!parseImmediate(bitImm))
        return null;

    // Validate bit number range
    uint maxBit = reg.is64bit ? 63 : 31;
    if (bitImm.imm < 0 || bitImm.imm > maxBit)
    {
        error(asmstate.loc, "bit number %lld out of range for `tbz` (must be 0..%u)",
              cast(long)bitImm.imm, maxBit);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after bit number");
        return null;
    }
    asmNextToken();

    // Parse label
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `tbz`");
        return null;
    }

    // Encode tbz with offset 0 as placeholder
    uint b5 = (bitImm.imm >> 5) & 1;
    uint b40 = bitImm.imm & 0x1F;
    uint encoding = INSTR.testbranch(b5, 0, b40, 0, reg.reg);

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/// TBNZ instruction: tbnz Xt, #imm, label (test bit and branch if non-zero)
private code* parseInstr_tbnz()
{
    asmNextToken(); // Skip 'tbnz'

    AArch64Operand reg, bitImm;

    // Parse register to test
    if (!parseRegister(reg))
        return null;

    if (reg.type != AArch64Operand.Type.Register)
    {
        error(asmstate.loc, "register expected for `tbnz`");
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after register");
        return null;
    }
    asmNextToken();

    // Parse bit number immediate
    if (!parseImmediate(bitImm))
        return null;

    // Validate bit number range
    uint maxBit = reg.is64bit ? 63 : 31;
    if (bitImm.imm < 0 || bitImm.imm > maxBit)
    {
        error(asmstate.loc, "bit number %lld out of range for `tbnz` (must be 0..%u)",
              cast(long)bitImm.imm, maxBit);
        return null;
    }

    // Expect comma
    if (tokValue() != TOK.comma)
    {
        error(asmstate.loc, "comma expected after bit number");
        return null;
    }
    asmNextToken();

    // Parse label
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `tbnz`");
        return null;
    }

    // Encode tbnz with offset 0 as placeholder
    uint b5 = (bitImm.imm >> 5) & 1;
    uint b40 = bitImm.imm & 0x1F;
    uint encoding = INSTR.testbranch(b5, 1, b40, 0, reg.reg);

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/*******************************
 * Function Call Instructions (Phase 6)
 */

/// BL instruction: bl label (branch with link)
private code* parseInstr_bl()
{
    asmNextToken(); // Skip 'bl'

    // Parse label operand
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "label expected for `bl` instruction");
        return null;
    }

    // Note: Full label resolution requires backend integration
    // For now, emit a placeholder instruction with offset 0
    // The imm26 field represents PC-relative offset in 4-byte instructions
    uint encoding = INSTR.bl(0);

    asmNextToken(); // Skip label

    return emitInstruction(encoding);
}

/// BLR instruction: blr Xn (branch with link to register)
private code* parseInstr_blr()
{
    asmNextToken(); // Skip 'blr'

    AArch64Operand target;
    if (!parseRegister(target) || !validate64BitRegister(target, "blr"))
        return null;

    return emitInstruction(INSTR.blr(target.reg));
}

/// BR instruction: br Xn (branch to register)
private code* parseInstr_br()
{
    asmNextToken(); // Skip 'br'

    AArch64Operand target;
    if (!parseRegister(target) || !validate64BitRegister(target, "br"))
        return null;

    return emitInstruction(INSTR.br(target.reg));
}

/// RET instruction: ret [Xn] (return from subroutine)
private code* parseInstr_ret()
{
    asmNextToken(); // Skip 'ret'

    ubyte returnReg = Reg.LR;  // Default to x30 (link register)

    // Check if a register is specified (optional)
    if (tokValue() == TOK.identifier)
    {
        AArch64Operand target;
        if (parseRegister(target))
        {
            if (!validate64BitRegister(target, "ret"))
                return null;
            returnReg = target.reg;
        }
        // If parseRegister fails, assume it's not a register and use default
    }

    return emitInstruction(INSTR.ret(returnReg));
}

/*******************************
 * Instruction Dispatch Table
 */

alias InstrHandlerFunc = code* function();

private struct InstrHandler
{
    string mnemonic;
    InstrHandlerFunc handler;
}

private immutable InstrHandler[] instrTable =
[
    InstrHandler("mov",   &parseInstr_mov),
    InstrHandler("ldr",   &parseInstr_ldr),
    InstrHandler("str",   &parseInstr_str),
    InstrHandler("ldp",   &parseInstr_ldp),
    InstrHandler("stp",   &parseInstr_stp),
    InstrHandler("ldrb",  &parseInstr_ldrb),
    InstrHandler("strb",  &parseInstr_strb),
    InstrHandler("ldrh",  &parseInstr_ldrh),
    InstrHandler("strh",  &parseInstr_strh),
    InstrHandler("ldrsb", &parseInstr_ldrsb),
    InstrHandler("ldrsh", &parseInstr_ldrsh),
    InstrHandler("ldrsw", &parseInstr_ldrsw),
    InstrHandler("add",   &parseInstr_add),
    InstrHandler("adds",  &parseInstr_adds),
    InstrHandler("sub",  &parseInstr_sub),
    InstrHandler("subs",  &parseInstr_subs),
    InstrHandler("mul",  &parseInstr_mul),
    InstrHandler("madd", &parseInstr_madd),
    InstrHandler("msub", &parseInstr_msub),
    InstrHandler("sdiv", &parseInstr_sdiv),
    InstrHandler("udiv", &parseInstr_udiv),
    InstrHandler("neg",  &parseInstr_neg),
    InstrHandler("negs", &parseInstr_negs),
    InstrHandler("adc",  &parseInstr_adc),
    InstrHandler("adcs",  &parseInstr_adcs),
    InstrHandler("sbc",  &parseInstr_sbc),
    InstrHandler("sbcs",  &parseInstr_sbcs),
    InstrHandler("and",  &parseInstr_and),
    InstrHandler("orr",  &parseInstr_orr),
    InstrHandler("eor",  &parseInstr_eor),
    InstrHandler("mvn",  &parseInstr_mvn),
    InstrHandler("bic",  &parseInstr_bic),
    InstrHandler("tst",  &parseInstr_tst),
    InstrHandler("cmp",  &parseInstr_cmp),
    InstrHandler("cmn",  &parseInstr_cmn),
    InstrHandler("lsl",  &parseInstr_lsl),
    InstrHandler("lsr",  &parseInstr_lsr),
    InstrHandler("asr",  &parseInstr_asr),
    InstrHandler("ror",  &parseInstr_ror),
    InstrHandler("extr", &parseInstr_extr),
    InstrHandler("ubfm", &parseInstr_ubfm),
    InstrHandler("sbfm", &parseInstr_sbfm),
    InstrHandler("bfm",  &parseInstr_bfm),
    InstrHandler("b",    &parseInstr_b),
    InstrHandler("cbz",  &parseInstr_cbz),
    InstrHandler("cbnz", &parseInstr_cbnz),
    InstrHandler("tbz",  &parseInstr_tbz),
    InstrHandler("tbnz", &parseInstr_tbnz),
    InstrHandler("bl",   &parseInstr_bl),
    InstrHandler("blr",  &parseInstr_blr),
    InstrHandler("br",   &parseInstr_br),
    InstrHandler("ret",  &parseInstr_ret),
];

/// Look up an instruction handler by mnemonic (case-insensitive)
private InstrHandlerFunc lookupInstruction(const(char)[] mnemonic)
{
    import core.stdc.ctype : tolower;

    // Check for conditional branch (b.eq, b.ne, etc.)
    // These should all use the 'b' handler
    if (mnemonic.length > 2 && mnemonic[0] == 'b' && mnemonic[1] == '.')
    {
        // It's a conditional branch like "b.eq", use the 'b' handler
        return &parseInstr_b;
    }

    foreach (ref handler; instrTable)
    {
        if (handler.mnemonic.length != mnemonic.length)
            continue;

        bool match = true;
        foreach (i, c; handler.mnemonic)
        {
            if (tolower(c) != tolower(mnemonic[i]))
            {
                match = false;
                break;
            }
        }

        if (match)
            return handler.handler;
    }

    return null;
}

/************************
 * Perform semantic analysis on InlineAsmStatement.
 * Params:
 *      s = inline asm statement
 *      sc = context
 * Returns:
 *      `s` on success, ErrorStatement if errors happened
 */
public Statement inlineAsmAArch64Semantic(InlineAsmStatement s, Scope* sc)
{
    // Initialize state
    asmstate.tok = s.tokens;
    asmstate.sc = sc;
    asmstate.loc = s.loc;
    asmstate.startErrors = global.errors;

    // Check for empty statement
    if (!asmstate.tok || tokValue() == TOK.endOfFile)
    {
        error(s.loc, "empty asm statement");
        return new ErrorStatement();
    }

    // Get instruction mnemonic
    if (tokValue() != TOK.identifier)
    {
        error(asmstate.loc, "instruction mnemonic expected, not `%s`", asmstate.tok.toChars());
        return new ErrorStatement();
    }

    const(char)[] mnemonic = asmstate.tok.ident.toString();

    // Look up instruction handler
    InstrHandlerFunc handler = lookupInstruction(mnemonic);
    if (!handler)
    {
        error(asmstate.loc, "unknown AArch64 instruction `%s`", mnemonic.ptr);
        return new ErrorStatement();
    }

    // Call instruction handler
    code* c = handler();

    // Check for errors
    if (hadErrors() || !c)
        return new ErrorStatement();

    // Check for unexpected tokens after instruction
    if (tokValue() != TOK.endOfFile)
    {
        error(asmstate.loc, "unexpected token `%s` after instruction", asmstate.tok.toChars());
        return new ErrorStatement();
    }

    // Set the generated code
    s.asmcode = c;

    return s;
}

/*******************************
 * Unit Tests
 */

unittest
{
    // Test register name parsing
    ubyte regNum;
    bool is64bit;

    // Test X registers
    assert(parseRegisterName("x0", regNum, is64bit));
    assert(regNum == 0 && is64bit);

    assert(parseRegisterName("x15", regNum, is64bit));
    assert(regNum == 15 && is64bit);

    assert(parseRegisterName("x30", regNum, is64bit));
    assert(regNum == 30 && is64bit);

    // Test W registers
    assert(parseRegisterName("w0", regNum, is64bit));
    assert(regNum == 0 && !is64bit);

    assert(parseRegisterName("w20", regNum, is64bit));
    assert(regNum == 20 && !is64bit);

    // Test special registers
    assert(parseRegisterName("sp", regNum, is64bit));
    assert(regNum == 31 && is64bit);

    assert(parseRegisterName("SP", regNum, is64bit));
    assert(regNum == 31 && is64bit);

    assert(parseRegisterName("xzr", regNum, is64bit));
    assert(regNum == 31 && is64bit);

    assert(parseRegisterName("wzr", regNum, is64bit));
    assert(regNum == 31 && !is64bit);

    // Test case insensitivity
    assert(parseRegisterName("X0", regNum, is64bit));
    assert(regNum == 0 && is64bit);

    assert(parseRegisterName("W5", regNum, is64bit));
    assert(regNum == 5 && !is64bit);

    // Test invalid registers
    assert(!parseRegisterName("x32", regNum, is64bit));
    assert(!parseRegisterName("r0", regNum, is64bit));
    assert(!parseRegisterName("q0", regNum, is64bit));
    assert(!parseRegisterName("", regNum, is64bit));
    assert(!parseRegisterName("x", regNum, is64bit));
}

unittest
{
    // Test MOV encoding
    // mov x0, x1 should encode to 0xAA0103E0
    uint encoding = INSTR.mov_register(1, 1, 0);
    assert(encoding == 0xAA0103E0, "mov x0, x1 encoding incorrect");

    // mov w5, w10 should encode to 0x2A0A03E5
    encoding = INSTR.mov_register(0, 10, 5);
    assert(encoding == 0x2A0A03E5, "mov w5, w10 encoding incorrect");
}

unittest
{
    // Test ADD immediate encoding
    // add x0, x1, #42
    // Format: sf=1, op=0, S=0, sh=0, imm12=42, Rn=1, Rd=0
    uint encoding = INSTR.add_addsub_imm(1, 0, 42, 1, 0);
    assert(encoding == 0x9100A820, "add x0, x1, #42 encoding incorrect");
}

unittest
{
    // Test ADD register encoding
    // add x2, x3, x4
    uint encoding = INSTR.addsub_shift(1, 0, 0, 0, 4, 0, 3, 2);
    // This should produce a valid add instruction
    assert(encoding != 0, "add x2, x3, x4 encoding failed");
}

unittest
{
    // Test SUB immediate encoding
    // sub x0, x1, #42
    // Format: sf=1, op=1, S=0, sh=0, imm12=42, Rn=1, Rd=0
    uint encoding = INSTR.sub_addsub_imm(1, 0, 42, 1, 0);
    assert(encoding == 0xD100A820, "sub x0, x1, #42 encoding incorrect");
}

unittest
{
    // Test LDR encoding
    // ldr x0, [x1]
    uint encoding = INSTR.ldr_imm_gen(1, 0, 1, 0);
    // Should produce valid ldr instruction
    assert(encoding != 0, "ldr x0, [x1] encoding failed");
}

unittest
{
    // Test STR encoding
    // str x0, [x1]
    uint encoding = INSTR.str_imm_gen(1, 0, 1, 0);
    // Should produce valid str instruction
    assert(encoding != 0, "str x0, [x1] encoding failed");
}

unittest
{
    // Test instruction lookup
    assert(lookupInstruction("mov") !is null);
    assert(lookupInstruction("MOV") !is null);
    assert(lookupInstruction("ldr") !is null);
    assert(lookupInstruction("str") !is null);
    assert(lookupInstruction("add") !is null);
    assert(lookupInstruction("sub") !is null);
    assert(lookupInstruction("b") !is null);

    // Test unknown instruction
    assert(lookupInstruction("unknown") is null);
    assert(lookupInstruction("movx") is null);
}

unittest
{
    // Test more register parsing variations
    ubyte regNum;
    bool is64bit;

    // Test all valid X registers
    foreach (i; 0 .. 31)
    {
        import std.conv : to;
        string regName = "x" ~ i.to!string;
        assert(parseRegisterName(regName, regNum, is64bit));
        assert(regNum == i && is64bit);
    }

    // Test all valid W registers
    foreach (i; 0 .. 31)
    {
        import std.conv : to;
        string regName = "w" ~ i.to!string;
        assert(parseRegisterName(regName, regNum, is64bit));
        assert(regNum == i && !is64bit);
    }

    // Test case variations for special registers
    assert(parseRegisterName("XZR", regNum, is64bit));
    assert(regNum == 31 && is64bit);

    assert(parseRegisterName("WZR", regNum, is64bit));
    assert(regNum == 31 && !is64bit);

    assert(parseRegisterName("Sp", regNum, is64bit));
    assert(regNum == 31 && is64bit);
}

unittest
{
    // Test MOV with different register combinations
    uint encoding;

    // 64-bit moves
    encoding = INSTR.mov_register(1, 0, 0);   // mov x0, x0
    assert(encoding != 0);

    encoding = INSTR.mov_register(1, 30, 29); // mov x29, x30 (fp, lr)
    assert(encoding != 0);

    // 32-bit moves
    encoding = INSTR.mov_register(0, 0, 0);   // mov w0, w0
    assert(encoding != 0);

    encoding = INSTR.mov_register(0, 15, 7);  // mov w7, w15
    assert(encoding != 0);
}

unittest
{
    // Test ADD with different immediate values
    uint encoding;

    // Boundary values for 12-bit immediate
    encoding = INSTR.add_addsub_imm(1, 0, 0, 0, 0);      // add x0, x0, #0
    assert(encoding != 0);

    encoding = INSTR.add_addsub_imm(1, 0, 4095, 5, 3);   // add x3, x5, #4095 (max)
    assert(encoding != 0);

    encoding = INSTR.add_addsub_imm(1, 0, 1, 1, 1);      // add x1, x1, #1
    assert(encoding != 0);

    // 32-bit variants
    encoding = INSTR.add_addsub_imm(0, 0, 100, 10, 11);  // add w11, w10, #100
    assert(encoding != 0);
}

unittest
{
    // Test SUB with different immediate values
    uint encoding;

    // Different immediate values
    encoding = INSTR.sub_addsub_imm(1, 0, 1, 2, 3);      // sub x3, x2, #1
    assert(encoding != 0);

    encoding = INSTR.sub_addsub_imm(1, 0, 255, 4, 5);    // sub x5, x4, #255
    assert(encoding != 0);

    encoding = INSTR.sub_addsub_imm(0, 0, 16, 8, 7);     // sub w7, w8, #16
    assert(encoding != 0);
}

unittest
{
    // Test ADD with register operands
    uint encoding;

    // add x0, x1, x2
    encoding = INSTR.addsub_shift(1, 0, 0, 0, 2, 0, 1, 0);
    assert(encoding != 0);

    // add x10, x11, x12
    encoding = INSTR.addsub_shift(1, 0, 0, 0, 12, 0, 11, 10);
    assert(encoding != 0);

    // add w5, w6, w7
    encoding = INSTR.addsub_shift(0, 0, 0, 0, 7, 0, 6, 5);
    assert(encoding != 0);
}

unittest
{
    // Test SUB with register operands
    uint encoding;

    // sub x0, x1, x2
    encoding = INSTR.addsub_shift(1, 1, 0, 0, 2, 0, 1, 0);
    assert(encoding != 0);

    // sub x15, x16, x17
    encoding = INSTR.addsub_shift(1, 1, 0, 0, 17, 0, 16, 15);
    assert(encoding != 0);

    // sub w20, w21, w22
    encoding = INSTR.addsub_shift(0, 1, 0, 0, 22, 0, 21, 20);
    assert(encoding != 0);
}

unittest
{
    // Test LDR with different addressing modes
    uint encoding;

    // 64-bit loads
    encoding = INSTR.ldr_imm_gen(1, 0, 1, 0);    // ldr x0, [x1]
    assert(encoding != 0);

    encoding = INSTR.ldr_imm_gen(1, 5, 10, 8);   // ldr x5, [x10, #8]
    assert(encoding != 0);

    encoding = INSTR.ldr_imm_gen(1, 15, 20, 16); // ldr x15, [x20, #16]
    assert(encoding != 0);

    // 32-bit loads
    encoding = INSTR.ldr_imm_gen(0, 0, 1, 0);    // ldr w0, [x1]
    assert(encoding != 0);

    encoding = INSTR.ldr_imm_gen(0, 7, 8, 4);    // ldr w7, [x8, #4]
    assert(encoding != 0);
}

unittest
{
    // Test LDR with register offset
    uint encoding;

    // ldr x0, [x1, x2] - size=3, VR=0, opc=1, extend=3 (LSL), S=0
    encoding = INSTR.ldst_regoff(3, 0, 1, 2, 3, 0, 1, 0);
    assert(encoding != 0);

    // ldr w5, [x6, x7] - size=2, VR=0, opc=1, extend=3 (LSL), S=0
    encoding = INSTR.ldst_regoff(2, 0, 1, 7, 3, 0, 6, 5);
    assert(encoding != 0);
}

unittest
{
    // Test STR with different addressing modes
    uint encoding;

    // 64-bit stores
    encoding = INSTR.str_imm_gen(1, 0, 1, 0);    // str x0, [x1]
    assert(encoding != 0);

    encoding = INSTR.str_imm_gen(1, 3, 4, 8);    // str x3, [x4, #8]
    assert(encoding != 0);

    encoding = INSTR.str_imm_gen(1, 10, 11, 24); // str x10, [x11, #24]
    assert(encoding != 0);

    // 32-bit stores
    encoding = INSTR.str_imm_gen(0, 0, 1, 0);    // str w0, [x1]
    assert(encoding != 0);

    encoding = INSTR.str_imm_gen(0, 5, 6, 4);    // str w5, [x6, #4]
    assert(encoding != 0);
}

unittest
{
    // Test STR with register offset
    uint encoding;

    // str x0, [x1, x2] - size=3, VR=0, opc=0, extend=3 (LSL), S=0
    encoding = INSTR.ldst_regoff(3, 0, 0, 2, 3, 0, 1, 0);
    assert(encoding != 0);

    // str w8, [x9, x10] - size=2, VR=0, opc=0, extend=3 (LSL), S=0
    encoding = INSTR.ldst_regoff(2, 0, 0, 10, 3, 0, 9, 8);
    assert(encoding != 0);
}

unittest
{
    // Test encoding consistency - same instruction should produce same encoding
    uint enc1, enc2;

    // MOV
    enc1 = INSTR.mov_register(1, 5, 10);
    enc2 = INSTR.mov_register(1, 5, 10);
    assert(enc1 == enc2);

    // ADD immediate
    enc1 = INSTR.add_addsub_imm(1, 0, 123, 7, 8);
    enc2 = INSTR.add_addsub_imm(1, 0, 123, 7, 8);
    assert(enc1 == enc2);

    // SUB immediate
    enc1 = INSTR.sub_addsub_imm(0, 0, 50, 3, 4);
    enc2 = INSTR.sub_addsub_imm(0, 0, 50, 3, 4);
    assert(enc1 == enc2);
}

unittest
{
    // Test mixed 32/64-bit combinations to ensure size distinction
    uint enc64, enc32;

    // MOV - 64-bit vs 32-bit should be different
    enc64 = INSTR.mov_register(1, 1, 0);  // mov x0, x1
    enc32 = INSTR.mov_register(0, 1, 0);  // mov w0, w1
    assert(enc64 != enc32);

    // ADD - 64-bit vs 32-bit should be different
    enc64 = INSTR.add_addsub_imm(1, 0, 10, 2, 3);  // add x3, x2, #10
    enc32 = INSTR.add_addsub_imm(0, 0, 10, 2, 3);  // add w3, w2, #10
    assert(enc64 != enc32);

    // SUB - 64-bit vs 32-bit should be different
    enc64 = INSTR.sub_addsub_imm(1, 0, 20, 5, 6);  // sub x6, x5, #20
    enc32 = INSTR.sub_addsub_imm(0, 0, 20, 5, 6);  // sub w6, w5, #20
    assert(enc64 != enc32);
}

unittest
{
    // Test special register encodings
    uint encoding;

    // Using sp (register 31) as base
    encoding = INSTR.ldr_imm_gen(1, 0, 31, 0);  // ldr x0, [sp]
    assert(encoding != 0);

    encoding = INSTR.str_imm_gen(1, 0, 31, 8);  // str x0, [sp, #8]
    assert(encoding != 0);

    // Using different registers with sp
    encoding = INSTR.add_addsub_imm(1, 0, 16, 31, 29);  // add x29, sp, #16
    assert(encoding != 0);

    encoding = INSTR.sub_addsub_imm(1, 0, 32, 31, 31);  // sub sp, sp, #32
    assert(encoding != 0);
}

unittest
{
    // Test that different operands produce different encodings
    uint enc1, enc2;

    // Different destination registers
    enc1 = INSTR.mov_register(1, 1, 0);  // mov x0, x1
    enc2 = INSTR.mov_register(1, 1, 2);  // mov x2, x1
    assert(enc1 != enc2);

    // Different source registers
    enc1 = INSTR.mov_register(1, 1, 0);  // mov x0, x1
    enc2 = INSTR.mov_register(1, 3, 0);  // mov x0, x3
    assert(enc1 != enc2);

    // Different immediates
    enc1 = INSTR.add_addsub_imm(1, 0, 10, 1, 0);  // add x0, x1, #10
    enc2 = INSTR.add_addsub_imm(1, 0, 20, 1, 0);  // add x0, x1, #20
    assert(enc1 != enc2);
}

unittest
{
    // Test condition code parsing
    CondCode cond;

    // Test all standard condition codes
    assert(parseConditionCode("eq", cond) && cond == CondCode.EQ);
    assert(parseConditionCode("ne", cond) && cond == CondCode.NE);
    assert(parseConditionCode("cs", cond) && cond == CondCode.CS);
    assert(parseConditionCode("hs", cond) && cond == CondCode.HS);
    assert(parseConditionCode("cc", cond) && cond == CondCode.CC);
    assert(parseConditionCode("lo", cond) && cond == CondCode.LO);
    assert(parseConditionCode("mi", cond) && cond == CondCode.MI);
    assert(parseConditionCode("pl", cond) && cond == CondCode.PL);
    assert(parseConditionCode("vs", cond) && cond == CondCode.VS);
    assert(parseConditionCode("vc", cond) && cond == CondCode.VC);
    assert(parseConditionCode("hi", cond) && cond == CondCode.HI);
    assert(parseConditionCode("ls", cond) && cond == CondCode.LS);
    assert(parseConditionCode("ge", cond) && cond == CondCode.GE);
    assert(parseConditionCode("lt", cond) && cond == CondCode.LT);
    assert(parseConditionCode("gt", cond) && cond == CondCode.GT);
    assert(parseConditionCode("le", cond) && cond == CondCode.LE);
    assert(parseConditionCode("al", cond) && cond == CondCode.AL);

    // Test case insensitivity
    assert(parseConditionCode("EQ", cond) && cond == CondCode.EQ);
    assert(parseConditionCode("Ne", cond) && cond == CondCode.NE);
    assert(parseConditionCode("GE", cond) && cond == CondCode.GE);

    // Test invalid condition codes
    assert(!parseConditionCode("xx", cond));
    assert(!parseConditionCode("e", cond));
    assert(!parseConditionCode("equ", cond));
}

unittest
{
    // Test conditional branch encodings
    uint encoding;

    // b.eq with offset 0
    encoding = INSTR.b_cond(0, CondCode.EQ);
    assert(encoding != 0);

    // b.ne with offset 0
    encoding = INSTR.b_cond(0, CondCode.NE);
    assert(encoding != 0);

    // b.gt with offset 0
    encoding = INSTR.b_cond(0, CondCode.GT);
    assert(encoding != 0);

    // b.le with offset 0
    encoding = INSTR.b_cond(0, CondCode.LE);
    assert(encoding != 0);

    // Different conditions should produce different encodings
    uint enc_eq = INSTR.b_cond(0, CondCode.EQ);
    uint enc_ne = INSTR.b_cond(0, CondCode.NE);
    assert(enc_eq != enc_ne);
}

unittest
{
    // Test unconditional branch encoding
    uint encoding;

    // b with offset 0
    encoding = INSTR.b_uncond(0);
    assert(encoding != 0);

    // Different offsets should produce different encodings
    uint enc1 = INSTR.b_uncond(0);
    uint enc2 = INSTR.b_uncond(4);
    assert(enc1 != enc2);
}

unittest
{
    // Test CBZ/CBNZ encodings
    uint encoding;

    // cbz x0, label (64-bit)
    encoding = INSTR.compbranch(1, 0, 0, 0);
    assert(encoding != 0);

    // cbz w5, label (32-bit)
    encoding = INSTR.compbranch(0, 0, 0, 5);
    assert(encoding != 0);

    // cbnz x10, label (64-bit)
    encoding = INSTR.compbranch(1, 1, 0, 10);
    assert(encoding != 0);

    // cbnz w15, label (32-bit)
    encoding = INSTR.compbranch(0, 1, 0, 15);
    assert(encoding != 0);

    // CBZ vs CBNZ should be different
    uint cbz_enc = INSTR.compbranch(1, 0, 0, 0);
    uint cbnz_enc = INSTR.compbranch(1, 1, 0, 0);
    assert(cbz_enc != cbnz_enc);

    // Different registers should produce different encodings
    uint enc_x0 = INSTR.compbranch(1, 0, 0, 0);
    uint enc_x1 = INSTR.compbranch(1, 0, 0, 1);
    assert(enc_x0 != enc_x1);

    // 32-bit vs 64-bit should be different
    uint enc_64 = INSTR.compbranch(1, 0, 0, 0);
    uint enc_32 = INSTR.compbranch(0, 0, 0, 0);
    assert(enc_64 != enc_32);
}

unittest
{
    // Test TBZ/TBNZ encodings
    uint encoding;

    // tbz x0, #0, label
    encoding = INSTR.testbranch(0, 0, 0, 0, 0);
    assert(encoding != 0);

    // tbz x0, #31, label
    encoding = INSTR.testbranch(0, 0, 31, 0, 0);
    assert(encoding != 0);

    // tbz x0, #63, label (bit 63 requires b5=1, b40=31)
    encoding = INSTR.testbranch(1, 0, 31, 0, 0);
    assert(encoding != 0);

    // tbnz x5, #15, label
    encoding = INSTR.testbranch(0, 1, 15, 0, 5);
    assert(encoding != 0);

    // TBZ vs TBNZ should be different
    uint tbz_enc = INSTR.testbranch(0, 0, 10, 0, 0);
    uint tbnz_enc = INSTR.testbranch(0, 1, 10, 0, 0);
    assert(tbz_enc != tbnz_enc);

    // Different bit numbers should produce different encodings
    uint enc_bit0 = INSTR.testbranch(0, 0, 0, 0, 0);
    uint enc_bit10 = INSTR.testbranch(0, 0, 10, 0, 0);
    assert(enc_bit0 != enc_bit10);

    // Different registers should produce different encodings
    uint enc_x0 = INSTR.testbranch(0, 0, 5, 0, 0);
    uint enc_x7 = INSTR.testbranch(0, 0, 5, 0, 7);
    assert(enc_x0 != enc_x7);
}

unittest
{
    // Test instruction lookup for conditional branches
    assert(lookupInstruction("b") !is null);
    assert(lookupInstruction("b.eq") !is null);
    assert(lookupInstruction("b.ne") !is null);
    assert(lookupInstruction("b.gt") !is null);
    assert(lookupInstruction("b.le") !is null);
    assert(lookupInstruction("b.ge") !is null);
    assert(lookupInstruction("b.lt") !is null);
    assert(lookupInstruction("cbz") !is null);
    assert(lookupInstruction("cbnz") !is null);
    assert(lookupInstruction("tbz") !is null);
    assert(lookupInstruction("tbnz") !is null);

    // Verify b.eq and b both return the same handler (the b handler)
    assert(lookupInstruction("b") == lookupInstruction("b.eq"));
    assert(lookupInstruction("b") == lookupInstruction("b.ne"));
}

unittest
{
    // Test that all condition codes have distinct values
    assert(CondCode.EQ != CondCode.NE);
    assert(CondCode.CS != CondCode.CC);
    assert(CondCode.MI != CondCode.PL);
    assert(CondCode.VS != CondCode.VC);
    assert(CondCode.HI != CondCode.LS);
    assert(CondCode.GE != CondCode.LT);
    assert(CondCode.GT != CondCode.LE);

    // Test that aliases match their base values
    assert(CondCode.HS == CondCode.CS);
    assert(CondCode.LO == CondCode.CC);
}

// Phase 2: Extended Addressing Modes Unit Tests

unittest
{
    // Test pre-indexed addressing mode encoding for LDR
    // ldr x0, [x1, #8]! - pre-indexed with immediate offset
    // Expected: size=3, VR=0, opc=1, imm9=8, Rn=1, Rt=0
    uint encoding = INSTR.ldst_immpre(3, 0, 1, 8, 1, 0);
    assert(encoding != 0, "ldr x0, [x1, #8]! encoding failed");

    // Verify pre-indexed bit pattern (bits [11:10] should be 0b11)
    assert((encoding & (3 << 10)) == (3 << 10), "pre-indexed mode bits incorrect");
}

unittest
{
    // Test post-indexed addressing mode encoding for LDR
    // ldr x0, [x1], #8 - post-indexed with immediate offset
    // Expected: size=3, VR=0, opc=1, imm9=8, Rn=1, Rt=0
    uint encoding = INSTR.ldst_immpost(3, 0, 1, 8, 1, 0);
    assert(encoding != 0, "ldr x0, [x1], #8 encoding failed");

    // Verify post-indexed bit pattern (bits [11:10] should be 0b01)
    assert((encoding & (3 << 10)) == (1 << 10), "post-indexed mode bits incorrect");
}

unittest
{
    // Test pre-indexed addressing mode encoding for STR
    // str x0, [x1, #8]! - pre-indexed with immediate offset
    // Expected: size=3, VR=0, opc=0, imm9=8, Rn=1, Rt=0
    uint encoding = INSTR.ldst_immpre(3, 0, 0, 8, 1, 0);
    assert(encoding != 0, "str x0, [x1, #8]! encoding failed");
}

unittest
{
    // Test post-indexed addressing mode encoding for STR
    // str x0, [x1], #8 - post-indexed with immediate offset
    // Expected: size=3, VR=0, opc=0, imm9=8, Rn=1, Rt=0
    uint encoding = INSTR.ldst_immpost(3, 0, 0, 8, 1, 0);
    assert(encoding != 0, "str x0, [x1], #8 encoding failed");
}

unittest
{
    // Test register offset with extend operation
    // ldr x0, [x1, x2, lsl #3] - register offset with shift
    // Expected: size=3, VR=0, opc=1, Rm=2, option=3 (LSL), S=1, Rn=1, Rt=0
    uint encoding = INSTR.ldst_regoff(3, 0, 1, 2, 3, 1, 1, 0);
    assert(encoding != 0, "ldr x0, [x1, x2, lsl #3] encoding failed");
}

unittest
{
    // Test register offset with different extend operations
    // ldr x0, [x1, x2, uxtw #2] - register offset with UXTW extend
    // Expected: size=3, VR=0, opc=1, Rm=2, option=2 (UXTW), S=1, Rn=1, Rt=0
    uint encoding = INSTR.ldst_regoff(3, 0, 1, 2, 2, 1, 1, 0);
    assert(encoding != 0, "ldr x0, [x1, x2, uxtw #2] encoding failed");

    // ldr x0, [x1, x2, sxtw #3] - register offset with SXTW extend
    encoding = INSTR.ldst_regoff(3, 0, 1, 2, 6, 1, 1, 0);
    assert(encoding != 0, "ldr x0, [x1, x2, sxtw #3] encoding failed");
}

unittest
{
    // Test 32-bit loads/stores with pre/post-indexed modes
    // ldr w0, [x1, #4]! - 32-bit pre-indexed
    uint encoding = INSTR.ldst_immpre(2, 0, 1, 4, 1, 0);
    assert(encoding != 0, "ldr w0, [x1, #4]! encoding failed");

    // str w0, [x1], #4 - 32-bit post-indexed
    encoding = INSTR.ldst_immpost(2, 0, 0, 4, 1, 0);
    assert(encoding != 0, "str w0, [x1], #4 encoding failed");
}

unittest
{
    // Test negative offsets for pre/post-indexed modes
    // ldr x0, [x1, #-8]! - pre-indexed with negative offset
    // imm9 is 9-bit signed, so -8 should be encoded as 0x1F8 (two's complement)
    uint imm9 = cast(uint)(-8) & 0x1FF;
    uint encoding = INSTR.ldst_immpre(3, 0, 1, imm9, 1, 0);
    assert(encoding != 0, "ldr x0, [x1, #-8]! encoding failed");

    // str x0, [x1], #-16 - post-indexed with negative offset
    imm9 = cast(uint)(-16) & 0x1FF;
    encoding = INSTR.ldst_immpost(3, 0, 0, imm9, 1, 0);
    assert(encoding != 0, "str x0, [x1], #-16 encoding failed");
}

unittest
{
    // Test extend operation parsing
    ExtendOp ext;

    // Simulate tokens for LSL
    // (Note: This is a structural test - actual parsing would require token stream)
    ext = ExtendOp.LSL;
    assert(ext == 3, "LSL extend value incorrect");

    ext = ExtendOp.UXTW;
    assert(ext == 2, "UXTW extend value incorrect");

    ext = ExtendOp.SXTW;
    assert(ext == 6, "SXTW extend value incorrect");

    ext = ExtendOp.SXTX;
    assert(ext == 7, "SXTX extend value incorrect");
}

unittest
{
    // Test different combinations of register offset modes
    // str x5, [x10, x15, lsl #3] - 64-bit store with shifted register offset
    uint encoding = INSTR.ldst_regoff(3, 0, 0, 15, 3, 1, 10, 5);
    assert(encoding != 0, "str x5, [x10, x15, lsl #3] encoding failed");

    // ldr w3, [x7, x9] - 32-bit load with unshifted register offset
    encoding = INSTR.ldst_regoff(2, 0, 1, 9, 3, 0, 7, 3);
    assert(encoding != 0, "ldr w3, [x7, x9] encoding failed");
}

unittest
{
    // Verify that pre-indexed and post-indexed encodings are distinct
    uint pre_enc = INSTR.ldst_immpre(3, 0, 1, 8, 1, 0);
    uint post_enc = INSTR.ldst_immpost(3, 0, 1, 8, 1, 0);
    assert(pre_enc != post_enc, "pre-indexed and post-indexed encodings should differ");

    // The difference should only be in bits [11:10]
    uint diff = pre_enc ^ post_enc;
    assert(diff == (2 << 10), "pre/post difference should only be in bits [11:10]");
}

// Phase 6: Function Call Support Unit Tests

unittest
{
    // Test BL (branch with link) encoding
    // bl label (with offset 0 as placeholder)
    uint encoding = INSTR.bl(0);
    assert(encoding != 0, "bl encoding failed");

    // Verify that BL has op=1 (bit 31)
    assert((encoding & (1 << 31)) != 0, "BL should have op=1 (bit 31 set)");

    // bl with non-zero offset
    encoding = INSTR.bl(0x100);
    assert(encoding != 0, "bl with offset encoding failed");
    assert((encoding & 0x3FFFFFF) == 0x100, "bl offset bits incorrect");
}

unittest
{
    // Test BLR (branch with link to register) encoding
    // blr x0
    uint encoding = INSTR.blr(0);
    assert(encoding != 0, "blr x0 encoding failed");

    // blr x30 (link register)
    encoding = INSTR.blr(30);
    assert(encoding != 0, "blr x30 encoding failed");

    // blr x15
    encoding = INSTR.blr(15);
    assert(encoding != 0, "blr x15 encoding failed");

    // Verify register encoding is in bits [9:5]
    assert(((encoding >> 5) & 0x1F) == 15, "blr register bits incorrect");
}

unittest
{
    // Test BR (branch to register) encoding
    // br x0
    uint encoding = INSTR.br(0);
    assert(encoding != 0, "br x0 encoding failed");

    // br x30
    encoding = INSTR.br(30);
    assert(encoding != 0, "br x30 encoding failed");

    // br x15
    encoding = INSTR.br(15);
    assert(encoding != 0, "br x15 encoding failed");

    // Verify register encoding is in bits [9:5]
    assert(((encoding >> 5) & 0x1F) == 15, "br register bits incorrect");
}

unittest
{
    // Test RET (return) encoding
    // ret (defaults to x30)
    uint encoding = INSTR.ret();
    assert(encoding == 0xd65f03c0, "ret encoding incorrect");

    // ret x30 (explicit)
    encoding = INSTR.ret(30);
    assert(encoding == 0xd65f03c0, "ret x30 encoding incorrect");

    // ret x0
    encoding = INSTR.ret(0);
    assert(encoding != 0, "ret x0 encoding failed");

    // ret x15
    encoding = INSTR.ret(15);
    assert(encoding != 0, "ret x15 encoding failed");

    // Verify register encoding is in bits [9:5]
    assert(((encoding >> 5) & 0x1F) == 15, "ret register bits incorrect");
}

unittest
{
    // Test that BR, BLR, and RET are distinct
    uint br_enc = INSTR.br(0);
    uint blr_enc = INSTR.blr(0);
    uint ret_enc = INSTR.ret(0);

    assert(br_enc != blr_enc, "BR and BLR encodings should differ");
    assert(br_enc != ret_enc, "BR and RET encodings should differ");
    assert(blr_enc != ret_enc, "BLR and RET encodings should differ");

    // They differ in the opc field (bits [22:21])
    // BR: opc=0, BLR: opc=1, RET: opc=2
    uint br_opc = (br_enc >> 21) & 3;
    uint blr_opc = (blr_enc >> 21) & 3;
    uint ret_opc = (ret_enc >> 21) & 3;

    assert(br_opc == 0, "BR opc should be 0");
    assert(blr_opc == 1, "BLR opc should be 1");
    assert(ret_opc == 2, "RET opc should be 2");
}

unittest
{
    // Test BL vs B encoding difference
    uint b_enc = INSTR.b_uncond(0);
    uint bl_enc = INSTR.bl(0);

    assert(b_enc != bl_enc, "B and BL encodings should differ");

    // They differ in the op field (bit 31)
    // B: op=0, BL: op=1
    assert((b_enc & (1 << 31)) == 0, "B should have op=0");
    assert((bl_enc & (1 << 31)) != 0, "BL should have op=1");
}

unittest
{
    // Test function call instruction dispatch table entries
    assert(lookupInstruction("bl") !is null, "bl should be in dispatch table");
    assert(lookupInstruction("blr") !is null, "blr should be in dispatch table");
    assert(lookupInstruction("br") !is null, "br should be in dispatch table");
    assert(lookupInstruction("ret") !is null, "ret should be in dispatch table");

    // Case insensitivity
    assert(lookupInstruction("BL") !is null, "BL should be case-insensitive");
    assert(lookupInstruction("BLR") !is null, "BLR should be case-insensitive");
    assert(lookupInstruction("BR") !is null, "BR should be case-insensitive");
    assert(lookupInstruction("RET") !is null, "RET should be case-insensitive");
}

unittest
{
    // Test various register encodings for function call instructions
    // Test different registers for BLR
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.blr(r);
        uint decoded_reg = (enc >> 5) & 0x1F;
        assert(decoded_reg == r, "BLR register encoding incorrect");
    }

    // Test different registers for BR
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.br(r);
        uint decoded_reg = (enc >> 5) & 0x1F;
        assert(decoded_reg == r, "BR register encoding incorrect");
    }

    // Test different registers for RET
    for (ubyte r = 0; r <= 30; r++)
    {
        uint enc = INSTR.ret(r);
        uint decoded_reg = (enc >> 5) & 0x1F;
        assert(decoded_reg == r, "RET register encoding incorrect");
    }
}

// Phase 5: Additional Load/Store Instructions Unit Tests

unittest
{
    // Test LDP (load pair) encoding with different addressing modes
    // ldp x0, x1, [x2] - offset mode
    uint encoding = INSTR.ldstpair_off(2, 0, 1, 0, 1, 2, 0);
    assert(encoding != 0, "ldp x0, x1, [x2] encoding failed");

    // ldp x3, x4, [x5, #16] - offset mode with immediate
    encoding = INSTR.ldstpair_off(2, 0, 1, 16 / 8, 4, 5, 3);
    assert(encoding != 0, "ldp x3, x4, [x5, #16] encoding failed");

    // ldp x6, x7, [x8, #16]! - pre-indexed mode
    encoding = INSTR.ldstpair_pre(2, 0, 1, 16 / 8, 7, 8, 6);
    assert(encoding != 0, "ldp x6, x7, [x8, #16]! encoding failed");

    // ldp x9, x10, [x11], #16 - post-indexed mode
    encoding = INSTR.ldstpair_post(2, 0, 1, 16 / 8, 10, 11, 9);
    assert(encoding != 0, "ldp x9, x10, [x11], #16 encoding failed");
}

unittest
{
    // Test STP (store pair) encoding with different addressing modes
    // stp x0, x1, [x2] - offset mode
    uint encoding = INSTR.ldstpair_off(2, 0, 0, 0, 1, 2, 0);
    assert(encoding != 0, "stp x0, x1, [x2] encoding failed");

    // stp x3, x4, [x5, #16] - offset mode with immediate
    encoding = INSTR.ldstpair_off(2, 0, 0, 16 / 8, 4, 5, 3);
    assert(encoding != 0, "stp x3, x4, [x5, #16] encoding failed");

    // stp x6, x7, [x8, #16]! - pre-indexed mode
    encoding = INSTR.ldstpair_pre(2, 0, 0, 16 / 8, 7, 8, 6);
    assert(encoding != 0, "stp x6, x7, [x8, #16]! encoding failed");

    // stp x9, x10, [x11], #16 - post-indexed mode
    encoding = INSTR.ldstpair_post(2, 0, 0, 16 / 8, 10, 11, 9);
    assert(encoding != 0, "stp x9, x10, [x11], #16 encoding failed");
}

unittest
{
    // Test that LDP and STP are distinct for same operands
    uint ldp_enc = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);
    uint stp_enc = INSTR.ldstpair_off(2, 0, 0, 0, 2, 1, 0);
    assert(ldp_enc != stp_enc, "LDP and STP encodings should differ");
}

unittest
{
    // Test LDRB (load byte) encoding
    // ldrb w0, [x1] - offset mode
    uint encoding = INSTR.ldrb_imm(0, 0, 1, 0);
    assert(encoding != 0, "ldrb w0, [x1] encoding failed");

    // ldrb w2, [x3, #4] - offset mode with immediate
    encoding = INSTR.ldrb_imm(0, 2, 3, 4);
    assert(encoding != 0, "ldrb w2, [x3, #4] encoding failed");

    // Verify size field for byte access
    uint size = (encoding >> 30) & 3;
    assert(size == 0, "LDRB size field should be 0 for byte access");
}

unittest
{
    // Test STRB (store byte) encoding
    // strb w0, [x1] - offset mode
    uint encoding = INSTR.strb_imm(0, 1, 0);
    assert(encoding != 0, "strb w0, [x1] encoding failed");

    // strb w2, [x3, #4] - offset mode with immediate
    encoding = INSTR.strb_imm(2, 3, 4);
    assert(encoding != 0, "strb w2, [x3, #4] encoding failed");

    // Verify size field for byte access
    uint size = (encoding >> 30) & 3;
    assert(size == 0, "STRB size field should be 0 for byte access");
}

unittest
{
    // Test that LDRB and STRB are distinct for same operands
    uint ldrb_enc = INSTR.ldrb_imm(0, 0, 1, 0);
    uint strb_enc = INSTR.strb_imm(0, 1, 0);
    assert(ldrb_enc != strb_enc, "LDRB and STRB encodings should differ");
}

unittest
{
    // Test LDRH (load halfword) encoding
    // ldrh w0, [x1] - offset mode
    uint encoding = INSTR.ldrh_imm(0, 0, 1, 0);
    assert(encoding != 0, "ldrh w0, [x1] encoding failed");

    // ldrh w2, [x3, #8] - offset mode with immediate
    encoding = INSTR.ldrh_imm(0, 2, 3, 8);
    assert(encoding != 0, "ldrh w2, [x3, #8] encoding failed");

    // Verify size field for halfword access
    uint size = (encoding >> 30) & 3;
    assert(size == 1, "LDRH size field should be 1 for halfword access");
}

unittest
{
    // Test STRH (store halfword) encoding
    // strh w0, [x1] - offset mode
    uint encoding = INSTR.strh_imm(0, 1, 0);
    assert(encoding != 0, "strh w0, [x1] encoding failed");

    // strh w2, [x3, #8] - offset mode with immediate
    encoding = INSTR.strh_imm(2, 3, 8);
    assert(encoding != 0, "strh w2, [x3, #8] encoding failed");

    // Verify size field for halfword access
    uint size = (encoding >> 30) & 3;
    assert(size == 1, "STRH size field should be 1 for halfword access");
}

unittest
{
    // Test that LDRH and STRH are distinct for same operands
    uint ldrh_enc = INSTR.ldrh_imm(0, 0, 1, 0);
    uint strh_enc = INSTR.strh_imm(0, 1, 0);
    assert(ldrh_enc != strh_enc, "LDRH and STRH encodings should differ");
}

unittest
{
    // Test LDRSB (load signed byte) encoding
    // ldrsb w0, [x1] - load to 32-bit register
    uint encoding = INSTR.ldrsb_imm(0, 0, 1, 0);
    assert(encoding != 0, "ldrsb w0, [x1] encoding failed");

    // ldrsb x2, [x3] - load to 64-bit register
    encoding = INSTR.ldrsb_imm(1, 2, 3, 0);
    assert(encoding != 0, "ldrsb x2, [x3] encoding failed");

    // ldrsb w4, [x5, #4] - with immediate offset
    encoding = INSTR.ldrsb_imm(0, 4, 5, 4);
    assert(encoding != 0, "ldrsb w4, [x5, #4] encoding failed");

    // Verify that 32-bit and 64-bit variants are different
    uint enc_w = INSTR.ldrsb_imm(0, 0, 1, 0);
    uint enc_x = INSTR.ldrsb_imm(1, 0, 1, 0);
    assert(enc_w != enc_x, "LDRSB w and LDRSB x should differ");
}

unittest
{
    // Test LDRSH (load signed halfword) encoding
    // ldrsh w0, [x1] - load to 32-bit register
    uint encoding = INSTR.ldrsh_imm(0, 0, 1, 0);
    assert(encoding != 0, "ldrsh w0, [x1] encoding failed");

    // ldrsh x2, [x3] - load to 64-bit register
    encoding = INSTR.ldrsh_imm(1, 2, 3, 0);
    assert(encoding != 0, "ldrsh x2, [x3] encoding failed");

    // ldrsh w4, [x5, #8] - with immediate offset
    encoding = INSTR.ldrsh_imm(0, 4, 5, 8);
    assert(encoding != 0, "ldrsh w4, [x5, #8] encoding failed");

    // Verify that 32-bit and 64-bit variants are different
    uint enc_w = INSTR.ldrsh_imm(0, 0, 1, 0);
    uint enc_x = INSTR.ldrsh_imm(1, 0, 1, 0);
    assert(enc_w != enc_x, "LDRSH w and LDRSH x should differ");
}

unittest
{
    // Test LDRSW (load signed word to 64-bit) encoding
    // ldrsw x0, [x1] - load signed 32-bit to 64-bit
    uint encoding = INSTR.ldrsw_imm(0, 1, 0);
    assert(encoding != 0, "ldrsw x0, [x1] encoding failed");

    // ldrsw x2, [x3, #8] - with immediate offset (8/4 = 2)
    encoding = INSTR.ldrsw_imm(2, 3, 2);
    assert(encoding != 0, "ldrsw x2, [x3, #8] encoding failed");

    // Verify size field for word access
    uint size = (encoding >> 30) & 3;
    assert(size == 2, "LDRSW size field should be 2 for word access");
}

unittest
{
    // Test Phase 5 instruction dispatch table entries
    assert(lookupInstruction("ldp") !is null, "ldp should be in dispatch table");
    assert(lookupInstruction("stp") !is null, "stp should be in dispatch table");
    assert(lookupInstruction("ldrb") !is null, "ldrb should be in dispatch table");
    assert(lookupInstruction("strb") !is null, "strb should be in dispatch table");
    assert(lookupInstruction("ldrh") !is null, "ldrh should be in dispatch table");
    assert(lookupInstruction("strh") !is null, "strh should be in dispatch table");
    assert(lookupInstruction("ldrsb") !is null, "ldrsb should be in dispatch table");
    assert(lookupInstruction("ldrsh") !is null, "ldrsh should be in dispatch table");
    assert(lookupInstruction("ldrsw") !is null, "ldrsw should be in dispatch table");

    // Case insensitivity
    assert(lookupInstruction("LDP") !is null, "LDP should be case-insensitive");
    assert(lookupInstruction("STP") !is null, "STP should be case-insensitive");
    assert(lookupInstruction("LDRB") !is null, "LDRB should be case-insensitive");
    assert(lookupInstruction("STRB") !is null, "STRB should be case-insensitive");
}

unittest
{
    // Test that different size loads produce different encodings
    uint ldrb_enc = INSTR.ldrb_imm(0, 0, 1, 0);   // byte
    uint ldrh_enc = INSTR.ldrh_imm(0, 0, 1, 0);   // halfword
    uint ldr_enc = INSTR.ldr_imm_gen(0, 0, 1, 0);  // word (32-bit)

    assert(ldrb_enc != ldrh_enc, "LDRB and LDRH should differ");
    assert(ldrb_enc != ldr_enc, "LDRB and LDR should differ");
    assert(ldrh_enc != ldr_enc, "LDRH and LDR should differ");

    // Verify size fields
    assert(((ldrb_enc >> 30) & 3) == 0, "LDRB size should be 0");
    assert(((ldrh_enc >> 30) & 3) == 1, "LDRH size should be 1");
}

unittest
{
    // Test pair instruction offset encoding
    // For 64-bit pairs, offset is in units of 8 bytes
    uint ldp_0 = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);      // offset 0
    uint ldp_8 = INSTR.ldstpair_off(2, 0, 1, 1, 2, 1, 0);      // offset 8 (1 * 8)
    uint ldp_16 = INSTR.ldstpair_off(2, 0, 1, 2, 2, 1, 0);     // offset 16 (2 * 8)

    assert(ldp_0 != ldp_8, "Different offsets should produce different encodings");
    assert(ldp_8 != ldp_16, "Different offsets should produce different encodings");
    assert(ldp_0 != ldp_16, "Different offsets should produce different encodings");
}

unittest
{
    // Test pair instruction addressing mode encoding
    uint ldp_offset = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);      // [Xn, #imm]
    uint ldp_pre = INSTR.ldstpair_pre(2, 0, 1, 0, 2, 1, 0);         // [Xn, #imm]!
    uint ldp_post = INSTR.ldstpair_post(2, 0, 1, 0, 2, 1, 0);       // [Xn], #imm

    assert(ldp_offset != ldp_pre, "Offset and pre-indexed should differ");
    assert(ldp_offset != ldp_post, "Offset and post-indexed should differ");
    assert(ldp_pre != ldp_post, "Pre-indexed and post-indexed should differ");
}

// Phase 5: Additional edge case unit tests

unittest
{
    // Test pair instructions with 32-bit variants
    uint ldp_w = INSTR.ldstpair_off(0, 0, 1, 0, 1, 2, 0);  // ldp w0, w1, [x2]
    uint ldp_x = INSTR.ldstpair_off(2, 0, 1, 0, 1, 2, 0);  // ldp x0, x1, [x2]

    assert(ldp_w != ldp_x, "32-bit and 64-bit pair instructions should differ");

    // Verify opc field
    uint opc_w = (ldp_w >> 30) & 3;
    uint opc_x = (ldp_x >> 30) & 3;
    assert(opc_w == 0, "32-bit pair opc should be 0");
    assert(opc_x == 2, "64-bit pair opc should be 2");
}

unittest
{
    // Test pair instructions with negative offsets
    // For 64-bit pairs, -16 bytes = -2 units (scaled by 8)
    uint neg_offset = cast(uint)(-2) & 0x7F;
    uint ldp_neg = INSTR.ldstpair_off(2, 0, 1, neg_offset, 2, 1, 0);
    uint ldp_pos = INSTR.ldstpair_off(2, 0, 1, 2, 2, 1, 0);

    assert(ldp_neg != ldp_pos, "Negative and positive offsets should differ");
}

unittest
{
    // Test byte load with different register offset extend modes
    uint ldrb_lsl = INSTR.ldrb_reg(0, 1, ExtendOp.LSL, 0, 2, 0);
    uint ldrb_uxtw = INSTR.ldrb_reg(0, 1, ExtendOp.UXTW, 0, 2, 0);
    uint ldrb_sxtw = INSTR.ldrb_reg(0, 1, ExtendOp.SXTW, 0, 2, 0);

    assert(ldrb_lsl != ldrb_uxtw, "Different extend modes should differ");
    assert(ldrb_lsl != ldrb_sxtw, "Different extend modes should differ");
    assert(ldrb_uxtw != ldrb_sxtw, "Different extend modes should differ");
}

unittest
{
    // Test halfword load with scaled vs unscaled register offset
    uint ldrh_unscaled = INSTR.ldrh_reg(0, 1, ExtendOp.LSL, 0, 2, 0);  // S=0
    uint ldrh_scaled = INSTR.ldrh_reg(0, 1, ExtendOp.LSL, 1, 2, 0);    // S=1

    assert(ldrh_unscaled != ldrh_scaled, "Scaled and unscaled should differ");
}

unittest
{
    // Test signed loads with maximum immediate offsets
    uint ldrsb_max = INSTR.ldrsb_imm(0, 0, 1, 0xFFF);  // Max 12-bit unsigned
    uint ldrsb_zero = INSTR.ldrsb_imm(0, 0, 1, 0);

    assert(ldrsb_max != ldrsb_zero, "Different offsets should differ");
}

unittest
{
    // Test that signed loads with W vs X destinations differ
    uint ldrsb_w = INSTR.ldrsb_imm(1, 0, 1, 0);  // sz=1 for W dest
    uint ldrsb_x = INSTR.ldrsb_imm(0, 0, 1, 0);  // sz=0 for X dest

    assert(ldrsb_w != ldrsb_x, "W and X destinations should differ");

    uint ldrsh_w = INSTR.ldrsh_imm(1, 0, 1, 0);
    uint ldrsh_x = INSTR.ldrsh_imm(0, 0, 1, 0);

    assert(ldrsh_w != ldrsh_x, "W and X destinations should differ");
}

unittest
{
    // Test LDRSW with scaled offset (word-aligned)
    // Offset is in units of 4 bytes, so 0 and 1 represent 0 and 4 byte offsets
    uint ldrsw_0 = INSTR.ldrsw_imm(0, 1, 0);
    uint ldrsw_4 = INSTR.ldrsw_imm(1, 1, 0);  // 1 * 4 = 4 bytes
    uint ldrsw_8 = INSTR.ldrsw_imm(2, 1, 0);  // 2 * 4 = 8 bytes

    assert(ldrsw_0 != ldrsw_4, "Different offsets should differ");
    assert(ldrsw_4 != ldrsw_8, "Different offsets should differ");
    assert(ldrsw_0 != ldrsw_8, "Different offsets should differ");
}

unittest
{
    // Test that byte/halfword/word sizes are properly encoded
    uint ldrb = INSTR.ldrb_imm(0, 0, 1, 0);
    uint ldrh = INSTR.ldrh_imm(0, 0, 1, 0);
    uint ldr_w = INSTR.ldr_imm_gen(0, 0, 1, 0);
    uint ldr_x = INSTR.ldr_imm_gen(1, 0, 1, 0);

    // All four should be distinct
    assert(ldrb != ldrh, "Byte and halfword should differ");
    assert(ldrb != ldr_w, "Byte and word should differ");
    assert(ldrb != ldr_x, "Byte and doubleword should differ");
    assert(ldrh != ldr_w, "Halfword and word should differ");
    assert(ldrh != ldr_x, "Halfword and doubleword should differ");
    assert(ldr_w != ldr_x, "Word and doubleword should differ");
}

unittest
{
    // Test pair instructions with maximum positive offset
    // For 64-bit pairs: 7-bit signed, max positive = 0x3F (63 units * 8 = 504 bytes)
    uint ldp_max = INSTR.ldstpair_off(2, 0, 1, 0x3F, 2, 1, 0);
    uint ldp_min = INSTR.ldstpair_off(2, 0, 1, 0, 2, 1, 0);

    assert(ldp_max != ldp_min, "Max and min offsets should differ");
}

unittest
{
    // Test store vs load with register offsets for byte/halfword
    uint ldrb_reg = INSTR.ldrb_reg(0, 1, ExtendOp.LSL, 0, 2, 0);
    uint strb_reg = INSTR.strb_reg(1, ExtendOp.LSL, 0, 2, 0);

    assert(ldrb_reg != strb_reg, "Load and store should differ");

    uint ldrh_reg = INSTR.ldrh_reg(0, 1, ExtendOp.LSL, 1, 2, 0);
    uint strh_reg = INSTR.strh_reg(1, ExtendOp.LSL, 1, 2, 0);

    assert(ldrh_reg != strh_reg, "Load and store should differ");
}

// Phase 4.1: Arithmetic Instructions Unit Tests

unittest
{
    // Test MADD (multiply-add) encoding
    // madd x0, x1, x2, x3 -> x0 = x3 + x1 * x2
    uint encoding = INSTR.madd(1, 2, 3, 1, 0);
    assert(encoding != 0, "madd x0, x1, x2, x3 encoding failed");

    // Test 32-bit variant: madd w0, w1, w2, w3
    uint encoding_w = INSTR.madd(0, 2, 3, 1, 0);
    assert(encoding_w != 0, "madd w0, w1, w2, w3 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "MADD 64-bit and 32-bit should differ");

    // Verify sf bit (bit 31)
    assert((encoding >> 31) & 1, "MADD 64-bit should have sf=1");
    assert(!((encoding_w >> 31) & 1), "MADD 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.madd(1, 10, 11, 12, 13);
    assert(enc2 != encoding, "Different registers should produce different encodings");

    // Verify register fields
    assert((enc2 & 0x1F) == 13, "MADD Rd field incorrect");
    assert(((enc2 >> 5) & 0x1F) == 12, "MADD Rn field incorrect");
    assert(((enc2 >> 10) & 0x1F) == 11, "MADD Ra field incorrect");
    assert(((enc2 >> 16) & 0x1F) == 10, "MADD Rm field incorrect");
}

unittest
{
    // Test MSUB (multiply-subtract) encoding
    // msub x0, x1, x2, x3 -> x0 = x3 - x1 * x2
    uint encoding = INSTR.msub(1, 2, 3, 1, 0);
    assert(encoding != 0, "msub x0, x1, x2, x3 encoding failed");

    // Test 32-bit variant: msub w0, w1, w2, w3
    uint encoding_w = INSTR.msub(0, 2, 3, 1, 0);
    assert(encoding_w != 0, "msub w0, w1, w2, w3 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "MSUB 64-bit and 32-bit should differ");

    // MADD and MSUB should differ (o0 bit differs)
    uint madd_enc = INSTR.madd(1, 2, 3, 1, 0);
    assert(encoding != madd_enc, "MSUB and MADD should differ");

    // Verify they only differ in bit 15 (o0 field)
    uint diff = encoding ^ madd_enc;
    assert(diff == (1 << 15), "MADD and MSUB should only differ in bit 15");

    // Test with different registers
    uint enc2 = INSTR.msub(1, 10, 11, 12, 13);
    assert((enc2 & 0x1F) == 13, "MSUB Rd field incorrect");
    assert(((enc2 >> 5) & 0x1F) == 12, "MSUB Rn field incorrect");
}

unittest
{
    // Test SDIV (signed division) encoding
    // sdiv x0, x1, x2 -> x0 = x1 / x2 (signed)
    uint encoding = INSTR.sdiv_udiv(1, false, 2, 1, 0);
    assert(encoding != 0, "sdiv x0, x1, x2 encoding failed");

    // Test 32-bit variant: sdiv w0, w1, w2
    uint encoding_w = INSTR.sdiv_udiv(0, false, 2, 1, 0);
    assert(encoding_w != 0, "sdiv w0, w1, w2 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "SDIV 64-bit and 32-bit should differ");

    // Verify sf bit (bit 31)
    assert((encoding >> 31) & 1, "SDIV 64-bit should have sf=1");
    assert(!((encoding_w >> 31) & 1), "SDIV 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.sdiv_udiv(1, false, 10, 11, 12);
    assert(enc2 != encoding, "Different registers should produce different encodings");

    // Verify register fields
    assert((enc2 & 0x1F) == 12, "SDIV Rd field incorrect");
    assert(((enc2 >> 5) & 0x1F) == 11, "SDIV Rn field incorrect");
    assert(((enc2 >> 16) & 0x1F) == 10, "SDIV Rm field incorrect");
}

unittest
{
    // Test UDIV (unsigned division) encoding
    // udiv x0, x1, x2 -> x0 = x1 / x2 (unsigned)
    uint encoding = INSTR.sdiv_udiv(1, true, 2, 1, 0);
    assert(encoding != 0, "udiv x0, x1, x2 encoding failed");

    // Test 32-bit variant: udiv w0, w1, w2
    uint encoding_w = INSTR.sdiv_udiv(0, true, 2, 1, 0);
    assert(encoding_w != 0, "udiv w0, w1, w2 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "UDIV 64-bit and 32-bit should differ");

    // SDIV and UDIV should differ (opcode bit differs)
    uint sdiv_enc = INSTR.sdiv_udiv(1, false, 2, 1, 0);
    assert(encoding != sdiv_enc, "UDIV and SDIV should differ");

    // Verify they differ in opcode field
    uint diff = encoding ^ sdiv_enc;
    assert(diff != 0, "SDIV and UDIV should have different opcodes");

    // Test with different registers
    uint enc2 = INSTR.sdiv_udiv(1, true, 10, 11, 12);
    assert((enc2 & 0x1F) == 12, "UDIV Rd field incorrect");
    assert(((enc2 >> 5) & 0x1F) == 11, "UDIV Rn field incorrect");
}

unittest
{
    // Test NEG (negate) encoding without shift
    // neg x0, x1 -> x0 = 0 - x1
    uint encoding = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0);
    assert(encoding != 0, "neg x0, x1 encoding failed");

    // Test 32-bit variant: neg w0, w1
    uint encoding_w = INSTR.neg_sub_addsub_shift(0, 0, 0, 1, 0, 0);
    assert(encoding_w != 0, "neg w0, w1 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "NEG 64-bit and 32-bit should differ");

    // Verify sf bit (bit 31)
    assert((encoding >> 31) & 1, "NEG 64-bit should have sf=1");
    assert(!((encoding_w >> 31) & 1), "NEG 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.neg_sub_addsub_shift(1, 0, 0, 10, 0, 11);
    assert(enc2 != encoding, "Different registers should produce different encodings");

    // Verify register fields
    assert((enc2 & 0x1F) == 11, "NEG Rd field incorrect");
    assert(((enc2 >> 16) & 0x1F) == 10, "NEG Rm field incorrect");
}

unittest
{
    // Test NEG with LSL shift
    // neg x0, x1, lsl #2 -> x0 = 0 - (x1 << 2)
    uint enc_lsl = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 2, 0);
    assert(enc_lsl != 0, "neg x0, x1, lsl #2 encoding failed");

    // NEG with and without shift should differ
    uint enc_no_shift = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0);
    assert(enc_lsl != enc_no_shift, "NEG with shift should differ from without shift");

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 2, "NEG shift amount incorrect");
}

unittest
{
    // Test NEG with different shift types
    // LSL (shift = 0)
    uint enc_lsl = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 3, 0);

    // LSR (shift = 1)
    uint enc_lsr = INSTR.neg_sub_addsub_shift(1, 0, 1, 1, 3, 0);

    // ASR (shift = 2)
    uint enc_asr = INSTR.neg_sub_addsub_shift(1, 0, 2, 1, 3, 0);

    // ROR (shift = 3)
    uint enc_ror = INSTR.neg_sub_addsub_shift(1, 0, 3, 1, 3, 0);

    // All four shift types should produce different encodings
    assert(enc_lsl != enc_lsr, "LSL and LSR should differ");
    assert(enc_lsl != enc_asr, "LSL and ASR should differ");
    assert(enc_lsl != enc_ror, "LSL and ROR should differ");
    assert(enc_lsr != enc_asr, "LSR and ASR should differ");
    assert(enc_lsr != enc_ror, "LSR and ROR should differ");
    assert(enc_asr != enc_ror, "ASR and ROR should differ");

    // Verify shift type in bits [23:22]
    assert(((enc_lsl >> 22) & 3) == 0, "LSL shift type should be 0");
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");
}

unittest
{
    // Test Phase 4.1 instruction dispatch table entries
    assert(lookupInstruction("madd") !is null, "madd should be in dispatch table");
    assert(lookupInstruction("msub") !is null, "msub should be in dispatch table");
    assert(lookupInstruction("sdiv") !is null, "sdiv should be in dispatch table");
    assert(lookupInstruction("udiv") !is null, "udiv should be in dispatch table");
    assert(lookupInstruction("neg") !is null, "neg should be in dispatch table");

    // Case insensitivity
    assert(lookupInstruction("MADD") !is null, "MADD should be case-insensitive");
    assert(lookupInstruction("MSUB") !is null, "MSUB should be case-insensitive");
    assert(lookupInstruction("SDIV") !is null, "SDIV should be case-insensitive");
    assert(lookupInstruction("UDIV") !is null, "UDIV should be case-insensitive");
    assert(lookupInstruction("NEG") !is null, "NEG should be case-insensitive");
}

unittest
{
    // Test that MUL and MADD encodings are related correctly
    // MUL is encoded as MADD with Ra=31 (XZR)
    // mul x0, x1, x2 -> x0 = 0 + x1 * x2 = x1 * x2
    uint mul_enc = INSTR.madd(1, 2, 31, 1, 0);  // Ra=31 for MUL
    uint madd_enc = INSTR.madd(1, 2, 3, 1, 0);  // Ra=3 for MADD

    // They should only differ in the Ra field (bits [14:10])
    uint ra_mul = (mul_enc >> 10) & 0x1F;
    uint ra_madd = (madd_enc >> 10) & 0x1F;

    assert(ra_mul == 31, "MUL should have Ra=31");
    assert(ra_madd == 3, "MADD should have Ra=3");
}

unittest
{
    // Test division with all register combinations
    for (ubyte rd = 0; rd <= 10; rd++)
    {
        for (ubyte rn = 0; rn <= 10; rn++)
        {
            for (ubyte rm = 0; rm <= 10; rm++)
            {
                // Test SDIV
                uint sdiv_enc = INSTR.sdiv_udiv(1, false, rm, rn, rd);
                assert((sdiv_enc & 0x1F) == rd, "SDIV Rd encoding failed");
                assert(((sdiv_enc >> 5) & 0x1F) == rn, "SDIV Rn encoding failed");
                assert(((sdiv_enc >> 16) & 0x1F) == rm, "SDIV Rm encoding failed");

                // Test UDIV
                uint udiv_enc = INSTR.sdiv_udiv(1, true, rm, rn, rd);
                assert((udiv_enc & 0x1F) == rd, "UDIV Rd encoding failed");
                assert(((udiv_enc >> 5) & 0x1F) == rn, "UDIV Rn encoding failed");
                assert(((udiv_enc >> 16) & 0x1F) == rm, "UDIV Rm encoding failed");
            }
        }
    }
}

unittest
{
    // Test NEG with maximum shift amounts
    // 64-bit: maximum shift is 63
    uint enc_max64 = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 63, 0);
    assert(((enc_max64 >> 10) & 0x3F) == 63, "NEG 64-bit max shift incorrect");

    // 32-bit: maximum shift is 31
    uint enc_max32 = INSTR.neg_sub_addsub_shift(0, 0, 0, 1, 31, 0);
    assert(((enc_max32 >> 10) & 0x3F) == 31, "NEG 32-bit max shift incorrect");

    // Zero shift
    uint enc_zero = INSTR.neg_sub_addsub_shift(1, 0, 0, 1, 0, 0);
    assert(((enc_zero >> 10) & 0x3F) == 0, "NEG zero shift incorrect");
}

unittest
{
    // Test MADD/MSUB edge cases with register 31 (XZR/SP)
    // Using XZR as addend/minuend should be valid
    uint madd_xzr = INSTR.madd(1, 2, 31, 1, 0);  // x0 = XZR + x1 * x2
    assert(madd_xzr != 0, "MADD with XZR as addend encoding failed");
    assert(((madd_xzr >> 10) & 0x1F) == 31, "MADD XZR addend incorrect");

    uint msub_xzr = INSTR.msub(1, 2, 31, 1, 0);  // x0 = XZR - x1 * x2
    assert(msub_xzr != 0, "MSUB with XZR as minuend encoding failed");
    assert(((msub_xzr >> 10) & 0x1F) == 31, "MSUB XZR minuend incorrect");

    // Using different source registers
    uint madd_all_diff = INSTR.madd(1, 5, 6, 7, 8);
    assert((madd_all_diff & 0x1F) == 8, "MADD with different regs Rd failed");
    assert(((madd_all_diff >> 5) & 0x1F) == 7, "MADD with different regs Rn failed");
    assert(((madd_all_diff >> 10) & 0x1F) == 6, "MADD with different regs Ra failed");
    assert(((madd_all_diff >> 16) & 0x1F) == 5, "MADD with different regs Rm failed");
}

// Phase 4.2: BIC and TST Instructions Unit Tests

unittest
{
    // Test BIC (Bit Clear) encoding without shift
    // bic x0, x1, x2 -> x0 = x1 & ~x2
    uint encoding = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);
    assert(encoding != 0, "bic x0, x1, x2 encoding failed");

    // Verify N bit (bit 21) is set for NOT
    assert((encoding >> 21) & 1, "BIC should have N=1 (NOT bit)");

    // Verify opc field (bits [30:29]) is 0 for AND
    assert(((encoding >> 29) & 3) == 0, "BIC should have opc=0 (AND)");

    // Test 32-bit variant: bic w0, w1, w2
    uint encoding_w = INSTR.log_shift(0, 0, 0, 1, 2, 0, 1, 0);
    assert(encoding_w != 0, "bic w0, w1, w2 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "BIC 64-bit and 32-bit should differ");

    // Verify sf bit (bit 31)
    assert((encoding >> 31) & 1, "BIC 64-bit should have sf=1");
    assert(!((encoding_w >> 31) & 1), "BIC 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.log_shift(1, 0, 0, 1, 10, 0, 11, 12);
    assert(enc2 != encoding, "Different registers should produce different encodings");

    // Verify register fields
    assert((enc2 & 0x1F) == 12, "BIC Rd field incorrect");
    assert(((enc2 >> 5) & 0x1F) == 11, "BIC Rn field incorrect");
    assert(((enc2 >> 16) & 0x1F) == 10, "BIC Rm field incorrect");
}

unittest
{
    // Test BIC with shifts
    // bic x0, x1, x2, lsl #3
    uint enc_lsl = INSTR.log_shift(1, 0, 0, 1, 2, 3, 1, 0);
    assert(enc_lsl != 0, "bic x0, x1, x2, lsl #3 encoding failed");

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 3, "BIC shift amount should be 3");

    // Verify shift type in bits [23:22]
    uint shift_type = (enc_lsl >> 22) & 3;
    assert(shift_type == 0, "LSL shift type should be 0");

    // Test different shift types
    uint enc_lsr = INSTR.log_shift(1, 0, 1, 1, 2, 4, 1, 0);  // LSR
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");
    assert(((enc_lsr >> 10) & 0x3F) == 4, "LSR shift amount should be 4");

    uint enc_asr = INSTR.log_shift(1, 0, 2, 1, 2, 8, 1, 0);  // ASR
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");
    assert(((enc_asr >> 10) & 0x3F) == 8, "ASR shift amount should be 8");

    uint enc_ror = INSTR.log_shift(1, 0, 3, 1, 2, 16, 1, 0);  // ROR
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");
    assert(((enc_ror >> 10) & 0x3F) == 16, "ROR shift amount should be 16");

    // All four shift types should produce different encodings
    assert(enc_lsl != enc_lsr, "LSL and LSR should differ");
    assert(enc_lsl != enc_asr, "LSL and ASR should differ");
    assert(enc_lsl != enc_ror, "LSL and ROR should differ");
}

unittest
{
    // Test BIC vs AND difference (N bit)
    uint and_enc = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);  // AND
    uint bic_enc = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);  // BIC

    // They should only differ in bit 21 (N field)
    uint diff = and_enc ^ bic_enc;
    assert(diff == (1 << 21), "AND and BIC should only differ in bit 21");

    // Verify N bit
    assert(!((and_enc >> 21) & 1), "AND should have N=0");
    assert((bic_enc >> 21) & 1, "BIC should have N=1");
}

unittest
{
    // Test TST (Test) encoding without shift
    // tst x1, x2 -> flags = x1 & x2, result to XZR (Rd=31)
    uint encoding = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);
    assert(encoding != 0, "tst x1, x2 encoding failed");

    // Verify Rd is 31 (XZR) - TST doesn't write result, only sets flags
    assert((encoding & 0x1F) == 31, "TST should have Rd=31 (XZR)");

    // Verify opc field (bits [30:29]) is 3 for ANDS
    assert(((encoding >> 29) & 3) == 3, "TST should have opc=3 (ANDS)");

    // Verify N bit (bit 21) is 0 for normal (not inverted)
    assert(!((encoding >> 21) & 1), "TST should have N=0");

    // Test 32-bit variant: tst w1, w2
    uint encoding_w = INSTR.log_shift(0, 3, 0, 0, 2, 0, 1, 31);
    assert(encoding_w != 0, "tst w1, w2 encoding failed");

    // 64-bit and 32-bit should differ
    assert(encoding != encoding_w, "TST 64-bit and 32-bit should differ");

    // Verify sf bit (bit 31)
    assert((encoding >> 31) & 1, "TST 64-bit should have sf=1");
    assert(!((encoding_w >> 31) & 1), "TST 32-bit should have sf=0");

    // Test with different registers
    uint enc2 = INSTR.log_shift(1, 3, 0, 0, 10, 0, 11, 31);
    assert(enc2 != encoding, "Different registers should produce different encodings");

    // Verify register fields
    assert((enc2 & 0x1F) == 31, "TST Rd should always be 31");
    assert(((enc2 >> 5) & 0x1F) == 11, "TST Rn field incorrect");
    assert(((enc2 >> 16) & 0x1F) == 10, "TST Rm field incorrect");
}

unittest
{
    // Test TST with shifts
    // tst x1, x2, lsl #3
    uint enc_lsl = INSTR.log_shift(1, 3, 0, 0, 2, 3, 1, 31);
    assert(enc_lsl != 0, "tst x1, x2, lsl #3 encoding failed");

    // Verify shift amount in bits [15:10]
    uint shift_amt = (enc_lsl >> 10) & 0x3F;
    assert(shift_amt == 3, "TST shift amount should be 3");

    // Verify shift type in bits [23:22]
    uint shift_type = (enc_lsl >> 22) & 3;
    assert(shift_type == 0, "LSL shift type should be 0");

    // Test different shift types
    uint enc_lsr = INSTR.log_shift(1, 3, 1, 0, 2, 4, 1, 31);  // LSR
    assert(((enc_lsr >> 22) & 3) == 1, "LSR shift type should be 1");

    uint enc_asr = INSTR.log_shift(1, 3, 2, 0, 2, 8, 1, 31);  // ASR
    assert(((enc_asr >> 22) & 3) == 2, "ASR shift type should be 2");

    uint enc_ror = INSTR.log_shift(1, 3, 3, 0, 2, 16, 1, 31);  // ROR
    assert(((enc_ror >> 22) & 3) == 3, "ROR shift type should be 3");

    // All four shift types should produce different encodings
    assert(enc_lsl != enc_lsr, "LSL and LSR should differ");
    assert(enc_lsl != enc_asr, "LSL and ASR should differ");
    assert(enc_lsl != enc_ror, "LSL and ROR should differ");
}

unittest
{
    // Test TST vs AND difference
    uint and_enc = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);   // AND (opc=0)
    uint tst_enc = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);  // TST (opc=3, Rd=31)

    assert(and_enc != tst_enc, "AND and TST should differ");

    // Verify opc field difference
    uint and_opc = (and_enc >> 29) & 3;
    uint tst_opc = (tst_enc >> 29) & 3;
    assert(and_opc == 0, "AND should have opc=0");
    assert(tst_opc == 3, "TST should have opc=3");

    // Verify Rd field difference
    assert((and_enc & 0x1F) == 0, "AND Rd should be 0");
    assert((tst_enc & 0x1F) == 31, "TST Rd should be 31");
}

unittest
{
    // Test Phase 4.2 instruction dispatch table entries
    assert(lookupInstruction("bic") !is null, "bic should be in dispatch table");
    assert(lookupInstruction("tst") !is null, "tst should be in dispatch table");

    // Case insensitivity
    assert(lookupInstruction("BIC") !is null, "BIC should be case-insensitive");
    assert(lookupInstruction("TST") !is null, "TST should be case-insensitive");
}

unittest
{
    // Test BIC with maximum shift amounts
    // 64-bit: maximum shift is 63
    uint enc_max64 = INSTR.log_shift(1, 0, 0, 1, 1, 63, 2, 0);
    assert(((enc_max64 >> 10) & 0x3F) == 63, "BIC 64-bit max shift incorrect");

    // 32-bit: maximum shift is 31
    uint enc_max32 = INSTR.log_shift(0, 0, 0, 1, 1, 31, 2, 0);
    assert(((enc_max32 >> 10) & 0x3F) == 31, "BIC 32-bit max shift incorrect");

    // Zero shift
    uint enc_zero = INSTR.log_shift(1, 0, 0, 1, 1, 0, 2, 0);
    assert(((enc_zero >> 10) & 0x3F) == 0, "BIC zero shift incorrect");
}

unittest
{
    // Test TST with maximum shift amounts
    // 64-bit: maximum shift is 63
    uint enc_max64 = INSTR.log_shift(1, 3, 0, 0, 1, 63, 2, 31);
    assert(((enc_max64 >> 10) & 0x3F) == 63, "TST 64-bit max shift incorrect");

    // 32-bit: maximum shift is 31
    uint enc_max32 = INSTR.log_shift(0, 3, 0, 0, 1, 31, 2, 31);
    assert(((enc_max32 >> 10) & 0x3F) == 31, "TST 32-bit max shift incorrect");

    // Zero shift
    uint enc_zero = INSTR.log_shift(1, 3, 0, 0, 1, 0, 2, 31);
    assert(((enc_zero >> 10) & 0x3F) == 0, "TST zero shift incorrect");
}

unittest
{
    // Test BIC/TST relationship with AND/ANDS
    // BIC = AND with N=1 (NOT)
    // TST = ANDS with Rd=31 (XZR)

    // Verify BIC is AND with NOT
    uint and_enc = INSTR.log_shift(1, 0, 0, 0, 2, 0, 1, 0);  // AND: opc=0, N=0
    uint bic_enc = INSTR.log_shift(1, 0, 0, 1, 2, 0, 1, 0);  // BIC: opc=0, N=1
    assert(((and_enc >> 21) & 1) == 0, "AND should have N=0");
    assert(((bic_enc >> 21) & 1) == 1, "BIC should have N=1");
    assert(((and_enc >> 29) & 3) == ((bic_enc >> 29) & 3), "AND and BIC should have same opc");

    // Verify TST is ANDS with Rd=31
    uint ands_enc = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 0);  // ANDS: opc=3, Rd=0
    uint tst_enc = INSTR.log_shift(1, 3, 0, 0, 2, 0, 1, 31);  // TST: opc=3, Rd=31
    assert(((ands_enc >> 29) & 3) == 3, "ANDS should have opc=3");
    assert(((tst_enc >> 29) & 3) == 3, "TST should have opc=3");
    assert((ands_enc & 0x1F) == 0, "ANDS Rd should be 0");
    assert((tst_enc & 0x1F) == 31, "TST Rd should be 31");
}

unittest
{
    // Test all register combinations for BIC
    for (ubyte rd = 0; rd <= 10; rd++)
    {
        for (ubyte rn = 0; rn <= 10; rn++)
        {
            for (ubyte rm = 0; rm <= 10; rm++)
            {
                uint enc = INSTR.log_shift(1, 0, 0, 1, rm, 0, rn, rd);
                assert((enc & 0x1F) == rd, "BIC Rd encoding failed");
                assert(((enc >> 5) & 0x1F) == rn, "BIC Rn encoding failed");
                assert(((enc >> 16) & 0x1F) == rm, "BIC Rm encoding failed");
            }
        }
    }
}

unittest
{
    // Test all register combinations for TST (Rd is always 31)
    for (ubyte rn = 0; rn <= 10; rn++)
    {
        for (ubyte rm = 0; rm <= 10; rm++)
        {
            uint enc = INSTR.log_shift(1, 3, 0, 0, rm, 0, rn, 31);
            assert((enc & 0x1F) == 31, "TST Rd should always be 31");
            assert(((enc >> 5) & 0x1F) == rn, "TST Rn encoding failed");
            assert(((enc >> 16) & 0x1F) == rm, "TST Rm encoding failed");
        }
    }
}

unittest
{
    // Test BIC with all shift types and various amounts
    for (uint shift = 0; shift <= 3; shift++)
    {
        for (uint amt = 0; amt <= 15; amt++)
        {
            uint enc = INSTR.log_shift(1, 0, shift, 1, 1, amt, 2, 0);
            assert(((enc >> 22) & 3) == shift, "BIC shift type encoding failed");
            assert(((enc >> 10) & 0x3F) == amt, "BIC shift amount encoding failed");
        }
    }
}

unittest
{
    // Test TST with all shift types and various amounts
    for (uint shift = 0; shift <= 3; shift++)
    {
        for (uint amt = 0; amt <= 15; amt++)
        {
            uint enc = INSTR.log_shift(1, 3, shift, 0, 1, amt, 2, 31);
            assert(((enc >> 22) & 3) == shift, "TST shift type encoding failed");
            assert(((enc >> 10) & 0x3F) == amt, "TST shift amount encoding failed");
        }
    }
}

