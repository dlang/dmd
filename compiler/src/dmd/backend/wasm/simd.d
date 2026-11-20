/**
 * WebAssembly SIMD128 support for the code generator.
 *
 * DMD's generic `__vector(T[N])` map to 16-byte backend types `TYfloat4` ... `TYullong2`.
 * This module maps it to `0xFD`-prefixed SIMD sub-opcodes.
 */

module dmd.backend.wasm.simd;

import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.wasm.enums;

nothrow @safe:

/**
 * Map a binary oper on a 16-byte vector type to its SIMD sub-opcode.
 *
 * Bitwise and/or/xor are lane-shape independent; arithmetic depends on the
 * element shape. Shifts and `%` never reach here (rejected for wasm by
 * `Target.isVectorOpSupported`).
 *
 * Params:
 *      op = backend binary oper (OPadd, OPmin, OPmul, OPdiv, OPand, OPor, OPxor)
 *      ty = the vector type mask
 * Returns: the `0xFD`-prefixed sub-opcode
 */
WASM_SIMD vecBinSubop(int op, tym_t ty)
{
    with (WASM_SIMD)
    {
        switch (op)
        {
        case OPand: return V128_AND;
        case OPor:  return V128_OR;
        case OPxor: return V128_XOR;
        default: break;
        }

        switch (tybasic(ty))
        {
        case TYfloat4:
            switch (op)
            {
            case OPadd: return F32X4_ADD;
            case OPmin: return F32X4_SUB;
            case OPmul: return F32X4_MUL;
            case OPdiv: return F32X4_DIV;
            default: assert(0);
            }
        case TYdouble2:
            switch (op)
            {
            case OPadd: return F64X2_ADD;
            case OPmin: return F64X2_SUB;
            case OPmul: return F64X2_MUL;
            case OPdiv: return F64X2_DIV;
            default: assert(0);
            }
        case TYschar16, TYuchar16:
            switch (op)
            {
            case OPadd: return I8X16_ADD;
            case OPmin: return I8X16_SUB;
            default: assert(0);
            }
        case TYshort8, TYushort8:
            switch (op)
            {
            case OPadd: return I16X8_ADD;
            case OPmin: return I16X8_SUB;
            case OPmul: return I16X8_MUL;
            default: assert(0);
            }
        case TYlong4, TYulong4:
            switch (op)
            {
            case OPadd: return I32X4_ADD;
            case OPmin: return I32X4_SUB;
            case OPmul: return I32X4_MUL;
            default: assert(0);
            }
        case TYllong2, TYullong2:
            switch (op)
            {
            case OPadd: return I64X2_ADD;
            case OPmin: return I64X2_SUB;
            case OPmul: return I64X2_MUL;
            default: assert(0);
            }
        default:
            assert(0);
        }
    }
}

/**
 * Map a comparison oper on a 16-byte vector type to its SIMD sub-opcode.
 *
 * The result is a lane mask (all-ones/all-zeros). Integer ordered comparisons
 * always use the signed opcodes: e2ir biases unsigned operands by `int.min`
 * before emitting `OPgt` (glue/e2ir.d), so a signed compare is correct for both
 * signednesses (and `i64x2` has only signed compares anyway).
 *
 * Params:
 *      op = backend comparison oper (OPeqeq, OPne, OPlt, OPle, OPgt, OPge)
 *      ty = the vector type mask
 * Returns: the `0xFD`-prefixed sub-opcode
 */
WASM_SIMD vecRelSubop(int op, tym_t ty)
{
    with (WASM_SIMD)
    {
        switch (tybasic(ty))
        {
        case TYfloat4:
            switch (op)
            {
            case OPeqeq: return F32X4_EQ;
            case OPne:   return F32X4_NE;
            case OPlt:   return F32X4_LT;
            case OPle:   return F32X4_LE;
            case OPgt:   return F32X4_GT;
            case OPge:   return F32X4_GE;
            default: assert(0);
            }
        case TYdouble2:
            switch (op)
            {
            case OPeqeq: return F64X2_EQ;
            case OPne:   return F64X2_NE;
            case OPlt:   return F64X2_LT;
            case OPle:   return F64X2_LE;
            case OPgt:   return F64X2_GT;
            case OPge:   return F64X2_GE;
            default: assert(0);
            }
        case TYschar16, TYuchar16:
            switch (op)
            {
            case OPeqeq: return I8X16_EQ;
            case OPne:   return I8X16_NE;
            case OPlt:   return I8X16_LT_S;
            case OPle:   return I8X16_LE_S;
            case OPgt:   return I8X16_GT_S;
            case OPge:   return I8X16_GE_S;
            default: assert(0);
            }
        case TYshort8, TYushort8:
            switch (op)
            {
            case OPeqeq: return I16X8_EQ;
            case OPne:   return I16X8_NE;
            case OPlt:   return I16X8_LT_S;
            case OPle:   return I16X8_LE_S;
            case OPgt:   return I16X8_GT_S;
            case OPge:   return I16X8_GE_S;
            default: assert(0);
            }
        case TYlong4, TYulong4:
            switch (op)
            {
            case OPeqeq: return I32X4_EQ;
            case OPne:   return I32X4_NE;
            case OPlt:   return I32X4_LT_S;
            case OPle:   return I32X4_LE_S;
            case OPgt:   return I32X4_GT_S;
            case OPge:   return I32X4_GE_S;
            default: assert(0);
            }
        case TYllong2, TYullong2:
            switch (op)
            {
            case OPeqeq: return I64X2_EQ;
            case OPne:   return I64X2_NE;
            case OPlt:   return I64X2_LT_S;
            case OPle:   return I64X2_LE_S;
            case OPgt:   return I64X2_GT_S;
            case OPge:   return I64X2_GE_S;
            default: assert(0);
            }
        default:
            assert(0);
        }
    }
}

WASM_SIMD vecSplatSubop(tym_t ty)
{
    with (WASM_SIMD)
    switch (tybasic(ty))
    {
    case TYfloat4:             return F32X4_SPLAT;
    case TYdouble2:            return F64X2_SPLAT;
    case TYschar16, TYuchar16: return I8X16_SPLAT;
    case TYshort8, TYushort8:  return I16X8_SPLAT;
    case TYlong4, TYulong4:    return I32X4_SPLAT;
    case TYllong2, TYullong2:  return I64X2_SPLAT;
    default: assert(0);
    }
}

WASM_SIMD vecNegSubop(tym_t ty)
{
    with (WASM_SIMD)
    switch (tybasic(ty))
    {
    case TYfloat4:             return F32X4_NEG;
    case TYdouble2:            return F64X2_NEG;
    case TYschar16, TYuchar16: return I8X16_NEG;
    case TYshort8, TYushort8:  return I16X8_NEG;
    case TYlong4, TYulong4:    return I32X4_NEG;
    case TYllong2, TYullong2:  return I64X2_NEG;
    default: assert(0);
    }
}
