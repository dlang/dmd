// Written in the D programming language.

/**
 * Builtin SIMD intrinsics
 *
 * Source: $(DRUNTIMESRC core/_simd.d)
 *
 * Copyright: Copyright Digital Mars 2012.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright),
 */

module core.simd;

pure:
nothrow:
@safe:

/*******************************
 * Create a vector type.
 *
 * Parameters:
 *      T = one of double[2], float[4], void[16], byte[16], ubyte[16],
 *      short[8], ushort[8], int[4], uint[4], long[2], ulong[2]
 */

template Vector(T)
{
    /* __vector is compiler magic, hide it behind a template.
     * The compiler will reject T's that don't work.
     */
    alias __vector(T) Vector;
}

/** Handy aliases
 */
alias Vector!(void[16])  void16;        ///
alias Vector!(double[2]) double2;       ///
alias Vector!(float[4])  float4;        ///
alias Vector!(byte[16])  byte16;        ///
alias Vector!(ubyte[16]) ubyte16;       ///
alias Vector!(short[8])  short8;        ///
alias Vector!(ushort[8]) ushort8;       ///
alias Vector!(int[4])    int4;          ///
alias Vector!(uint[4])   uint4;         ///
alias Vector!(long[2])   long2;         ///

enum XMM
{
    // Need to add in all the rest
    PCMPEQW = 0x660F75,
}

/**
 * Generate two operand instruction with XMM 128 bit operands.
 * Parameters:
 *      opcode  any of the XMM opcodes
 *      op1     first operand
 *      op2     second operand
 * Returns:
 *      result of opcode
 */
void16 simd(XMM opcode, void16 op1, void16 op2);

/* The following use overloading to ensure correct typing.
 * Compile with inlining on for best performance.
 */

short8 pcmpeq()(short8 v1, short8 v2)
{
    return simd(XMM.PCMPEQW, v1, v2);
}

ushort8 pcmpeq()(ushort8 v1, ushort8 v2)
{
    return simd(XMM.PCMPEQW, v1, v2);
}



