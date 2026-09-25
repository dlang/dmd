/**
 * WASM binary encoding constants
 */

module dmd.backend.wasm.enums;

/// WASM instruction opcodes
enum OP : ubyte
{
    UNREACHABLE = 0x00,
    NOP = 0x01,
    BLOCK = 0x02,
    LOOP = 0x03,
    IF = 0x04,
    ELSE = 0x05,
    THROW = 0x08,
    THROW_REF = 0x0A,
    TRY_TABLE = 0x1F,
    END = 0x0B,
    BR = 0x0C,
    BR_IF = 0x0D,
    BR_TABLE = 0x0E,
    RETURN = 0x0F,
    CALL = 0x10,
    CALL_INDIRECT = 0x11,
    RETURN_CALL = 0x12,
    RETURN_CALL_INDIRECT = 0x13,
    DROP = 0x1A,
    SELECT = 0x1B,
    LOCAL_GET = 0x20,
    LOCAL_SET = 0x21,
    LOCAL_TEE = 0x22,
    GLOBAL_GET = 0x23,
    GLOBAL_SET = 0x24,
    I32_LOAD = 0x28,
    I64_LOAD = 0x29,
    F32_LOAD = 0x2A,
    F64_LOAD = 0x2B,
    I32_LOAD8_S = 0x2C,
    I32_LOAD8_U = 0x2D,
    I32_LOAD16_S = 0x2E,
    I32_LOAD16_U = 0x2F,
    I64_LOAD8_S = 0x30,
    I64_LOAD8_U = 0x31,
    I64_LOAD16_S = 0x32,
    I64_LOAD16_U = 0x33,
    I64_LOAD32_S = 0x34,
    I64_LOAD32_U = 0x35,
    I32_STORE = 0x36,
    I64_STORE = 0x37,
    F32_STORE = 0x38,
    F64_STORE = 0x39,
    I32_STORE8 = 0x3A,
    I32_STORE16 = 0x3B,
    I64_STORE8 = 0x3C,
    I64_STORE16 = 0x3D,
    I64_STORE32 = 0x3E,
    MEMORY_SIZE = 0x3F,
    MEMORY_GROW = 0x40,
    I32_CONST = 0x41,
    I64_CONST = 0x42,
    F32_CONST = 0x43,
    F64_CONST = 0x44,
    I32_EQZ = 0x45,
    I32_EQ = 0x46,
    I32_NE = 0x47,
    I32_LT_S = 0x48,
    I32_LT_U = 0x49,
    I32_GT_S = 0x4A,
    I32_GT_U = 0x4B,
    I32_LE_S = 0x4C,
    I32_LE_U = 0x4D,
    I32_GE_S = 0x4E,
    I32_GE_U = 0x4F,
    I64_EQZ = 0x50,
    I64_EQ = 0x51,
    I64_NE = 0x52,
    I64_LT_S = 0x53,
    I64_LT_U = 0x54,
    I64_GT_S = 0x55,
    I64_GT_U = 0x56,
    I64_LE_S = 0x57,
    I64_LE_U = 0x58,
    I64_GE_S = 0x59,
    I64_GE_U = 0x5A,
    F32_EQ = 0x5B,
    F32_NE = 0x5C,
    F32_LT = 0x5D,
    F32_GT = 0x5E,
    F32_LE = 0x5F,
    F32_GE = 0x60,
    F64_EQ = 0x61,
    F64_NE = 0x62,
    F64_LT = 0x63,
    F64_GT = 0x64,
    F64_LE = 0x65,
    F64_GE = 0x66,
    I32_CLZ = 0x67,
    I32_CTZ = 0x68,
    I32_POPCNT = 0x69,
    I32_ADD = 0x6A,
    I32_SUB = 0x6B,
    I32_MUL = 0x6C,
    I32_DIV_S = 0x6D,
    I32_DIV_U = 0x6E,
    I32_REM_S = 0x6F,
    I32_REM_U = 0x70,
    I32_AND = 0x71,
    I32_OR = 0x72,
    I32_XOR = 0x73,
    I32_SHL = 0x74,
    I32_SHR_S = 0x75,
    I32_SHR_U = 0x76,
    I32_ROTL = 0x77,
    I32_ROTR = 0x78,
    I64_CLZ = 0x79,
    I64_CTZ = 0x7A,
    I64_POPCNT = 0x7B,
    I64_ADD = 0x7C,
    I64_SUB = 0x7D,
    I64_MUL = 0x7E,
    I64_DIV_S = 0x7F,
    I64_DIV_U = 0x80,
    I64_REM_S = 0x81,
    I64_REM_U = 0x82,
    I64_AND = 0x83,
    I64_OR = 0x84,
    I64_XOR = 0x85,
    I64_SHL = 0x86,
    I64_SHR_S = 0x87,
    I64_SHR_U = 0x88,
    I64_ROTL = 0x89,
    I64_ROTR = 0x8A,
    F32_ABS = 0x8B,
    F32_NEG = 0x8C,
    F32_SQRT = 0x91,
    F32_ADD = 0x92,
    F32_SUB = 0x93,
    F32_MUL = 0x94,
    F32_DIV = 0x95,
    F64_ABS = 0x99,
    F64_NEG = 0x9A,
    F64_SQRT = 0x9F,
    F64_ADD = 0xA0,
    F64_SUB = 0xA1,
    F64_MUL = 0xA2,
    F64_DIV = 0xA3,
    I32_WRAP_I64 = 0xA7,
    I32_TRUNC_F32_S = 0xA8,
    I32_TRUNC_F32_U = 0xA9,
    I32_TRUNC_F64_S = 0xAA,
    I32_TRUNC_F64_U = 0xAB,
    I64_EXTEND_I32_S = 0xAC,
    I64_EXTEND_I32_U = 0xAD,
    I64_TRUNC_F32_S = 0xAE,
    I64_TRUNC_F32_U = 0xAF,
    I64_TRUNC_F64_S = 0xB0,
    I64_TRUNC_F64_U = 0xB1,
    F32_CONVERT_I32_S = 0xB2,
    F32_CONVERT_I32_U = 0xB3,
    F32_CONVERT_I64_S = 0xB4,
    F32_CONVERT_I64_U = 0xB5,
    F32_DEMOTE_F64 = 0xB6,
    F64_CONVERT_I32_S = 0xB7,
    F64_CONVERT_I32_U = 0xB8,
    F64_CONVERT_I64_S = 0xB9,
    F64_CONVERT_I64_U = 0xBA,
    F64_PROMOTE_F32 = 0xBB,
    I32_REINTERPRET_F32 = 0xBC,
    I64_REINTERPRET_F64 = 0xBD,
    F32_REINTERPRET_I32 = 0xBE,
    F64_REINTERPRET_I64 = 0xBF,
    FC_PREFIX = 0xFC,
    I32_EXTEND8_S = 0xC0,
    I32_EXTEND16_S = 0xC1,
    I64_EXTEND8_S = 0xC2,
    I64_EXTEND16_S = 0xC3,
    I64_EXTEND32_S = 0xC4,
    FD_PREFIX = 0xFD,
}

/// Sub-opcodes following the `0xFD` SIMD prefix (uLEB128-encoded)
enum WASM_SIMD : uint
{
    V128_LOAD = 0x00,
    V128_STORE = 0x0B,
    V128_CONST = 0x0C,

    I8X16_SPLAT = 0x0F,
    I16X8_SPLAT = 0x10,
    I32X4_SPLAT = 0x11,
    I64X2_SPLAT = 0x12,
    F32X4_SPLAT = 0x13,
    F64X2_SPLAT = 0x14,

    I8X16_EQ = 0x23,
    I8X16_NE = 0x24,
    I8X16_LT_S = 0x25,
    I8X16_LT_U = 0x26,
    I8X16_GT_S = 0x27,
    I8X16_GT_U = 0x28,
    I8X16_LE_S = 0x29,
    I8X16_LE_U = 0x2A,
    I8X16_GE_S = 0x2B,
    I8X16_GE_U = 0x2C,

    I16X8_EQ = 0x2D,
    I16X8_NE = 0x2E,
    I16X8_LT_S = 0x2F,
    I16X8_LT_U = 0x30,
    I16X8_GT_S = 0x31,
    I16X8_GT_U = 0x32,
    I16X8_LE_S = 0x33,
    I16X8_LE_U = 0x34,
    I16X8_GE_S = 0x35,
    I16X8_GE_U = 0x36,

    I32X4_EQ = 0x37,
    I32X4_NE = 0x38,
    I32X4_LT_S = 0x39,
    I32X4_LT_U = 0x3A,
    I32X4_GT_S = 0x3B,
    I32X4_GT_U = 0x3C,
    I32X4_LE_S = 0x3D,
    I32X4_LE_U = 0x3E,
    I32X4_GE_S = 0x3F,
    I32X4_GE_U = 0x40,

    F32X4_EQ = 0x41,
    F32X4_NE = 0x42,
    F32X4_LT = 0x43,
    F32X4_GT = 0x44,
    F32X4_LE = 0x45,
    F32X4_GE = 0x46,

    F64X2_EQ = 0x47,
    F64X2_NE = 0x48,
    F64X2_LT = 0x49,
    F64X2_GT = 0x4A,
    F64X2_LE = 0x4B,
    F64X2_GE = 0x4C,

    V128_NOT = 0x4D,
    V128_AND = 0x4E,
    V128_OR = 0x50,
    V128_XOR = 0x51,

    I8X16_NEG = 0x61,
    I8X16_SHL = 0x6B,
    I8X16_SHR_S = 0x6C,
    I8X16_SHR_U = 0x6D,
    I8X16_ADD = 0x6E,
    I8X16_SUB = 0x71,

    I16X8_NEG = 0x81,
    I16X8_SHL = 0x8B,
    I16X8_SHR_S = 0x8C,
    I16X8_SHR_U = 0x8D,
    I16X8_ADD = 0x8E,
    I16X8_SUB = 0x91,
    I16X8_MUL = 0x95,

    I32X4_NEG = 0xA1,
    I32X4_SHL = 0xAB,
    I32X4_SHR_S = 0xAC,
    I32X4_SHR_U = 0xAD,
    I32X4_ADD = 0xAE,
    I32X4_SUB = 0xB1,
    I32X4_MUL = 0xB5,

    I64X2_NEG = 0xC1,
    I64X2_SHL = 0xCB,
    I64X2_SHR_S = 0xCC,
    I64X2_SHR_U = 0xCD,
    I64X2_ADD = 0xCE,
    I64X2_SUB = 0xD1,
    I64X2_MUL = 0xD5,
    I64X2_EQ = 0xD6,
    I64X2_NE = 0xD7,
    I64X2_LT_S = 0xD8,
    I64X2_GT_S = 0xD9,
    I64X2_LE_S = 0xDA,
    I64X2_GE_S = 0xDB,

    F32X4_NEG = 0xE1,
    F32X4_ADD = 0xE4,
    F32X4_SUB = 0xE5,
    F32X4_MUL = 0xE6,
    F32X4_DIV = 0xE7,

    F64X2_NEG = 0xED,
    F64X2_ADD = 0xF0,
    F64X2_SUB = 0xF1,
    F64X2_MUL = 0xF2,
    F64X2_DIV = 0xF3,
}

/// Sub-opcodes following the `0xFC` prefix.
/// Should be uLEB128-encoded unlike regular opcodes which are 1 byte
enum WASM_FC : uint
{
    I32_TRUNC_SAT_F32_S = 0,
    I32_TRUNC_SAT_F32_U = 1,
    I32_TRUNC_SAT_F64_S = 2,
    I32_TRUNC_SAT_F64_U = 3,
    I64_TRUNC_SAT_F32_S = 4,
    I64_TRUNC_SAT_F32_U = 5,
    I64_TRUNC_SAT_F64_S = 6,
    I64_TRUNC_SAT_F64_U = 7,

    MEMORY_COPY = 10,
    MEMORY_FILL = 11,
}

/// Value type bytes
enum WASM_TYPE : ubyte
{
    I32 = 0x7F,
    I64 = 0x7E,
    F32 = 0x7D,
    F64 = 0x7C,
    V128 = 0x7B,
    // Reference to an in-flight exception. Pushed by a `try_table`'s `catch_all_ref`
    // clause when unwinding into a `finally` (blocks.d openTryFrames), stashed in a
    // local (codgen.d exnLocalFor) across the finally body, then rethrown with
    // `throw_ref` (codgen.d OP.THROW_REF).
    EXNREF = 0x69,
}

/// Catch clause kind bytes inside a `try_table` instruction
enum WASM_CATCH : ubyte
{
    CATCH = 0x00,
    CATCH_REF = 0x01,
    CATCH_ALL = 0x02,
    CATCH_ALL_REF = 0x03,
}

enum WASM_I32 = WASM_TYPE.I32;
enum WASM_I64 = WASM_TYPE.I64;
enum WASM_F32 = WASM_TYPE.F32;
enum WASM_F64 = WASM_TYPE.F64;

enum ubyte WASM_VOID_BLOCK = 0x40;

/// Section IDs
enum WASM_SECTION : ubyte
{
    custom = 0,
    type_ = 1,
    import_ = 2,
    function_ = 3,
    table = 4,
    memory = 5,
    global = 6,
    export_ = 7,
    start = 8,
    element = 9,
    code = 10,
    data = 11,
    tag = 13,
}

/// Reference type bytes (used in element type fields, e.g. table imports)
enum WASM_REFTYPE : ubyte
{
    FUNCREF = 0x70,
    EXTERNREF = 0x6F,
}

/// Limits flags byte (used in memory and table types)
enum WASM_LIMITS : ubyte
{
    NO_MAX = 0x00,
    HAS_MAX = 0x01,
}

/// Mutability flag byte (used in global types)
enum WASM_MUT : ubyte
{
    CONST = 0x00,
    VAR = 0x01,
}

/// Import/export descriptor kinds. Same byte encoding for both
/// `importdesc` and `exportdesc` per the WASM core spec.
enum WASM_EXPORT : ubyte
{
    FUNC = 0x00,
    TABLE = 0x01,
    MEM = 0x02,
    GLOBAL = 0x03,
}

/// WASM relocation types (WebAssembly tool conventions / linking metadata)
enum R_WASM : ubyte
{
    FUNCTION_INDEX_LEB = 0,
    TABLE_INDEX_SLEB = 1,
    TABLE_INDEX_I32 = 2,
    MEMORY_ADDR_LEB = 3,
    MEMORY_ADDR_SLEB = 4,
    MEMORY_ADDR_I32 = 5,
    TYPE_INDEX_LEB = 6,
    GLOBAL_INDEX_LEB = 7,
    TAG_INDEX_LEB = 10,
    TABLE_NUMBER_LEB = 20,
}

/// "linking" custom section subsection IDs (version 2)
enum WASM_LINKING : ubyte
{
    SEGMENT_INFO = 5,
    INIT_FUNCS = 6,
    COMDAT_INFO = 7,
    SYMBOL_TABLE = 8,
}

/// SEGMENT_INFO per-segment flags (linking metadata)
enum WASM_SEG : uint
{
    STRINGS = 0x01,
    TLS = 0x02,
    RETAIN = 0x04, // keep under --gc-sections even without a reference
}

/// Symbol table entry kinds
enum WASM_SYMTAB : ubyte
{
    FUNCTION = 0,
    DATA = 1,
    GLOBAL = 2,
    SECTION = 3,
    TAG = 4,
    TABLE = 5,
}

/// Symbol table flags
enum WASM_SYM : uint
{
    BINDING_WEAK = 0x01,
    BINDING_LOCAL = 0x02,
    VISIBILITY_HIDDEN = 0x04,
    UNDEFINED = 0x10,
    EXPORTED = 0x20,      // force wasm-ld to export the symbol without --export-dynamic
    EXPLICIT_NAME = 0x40,
    NO_STRIP = 0x80,      // retain even without a reference (no --gc-sections stripping)
    TLS = 0x100,
}

/**
 * The log2 of the access size of a load/store instruction, which is the
 * alignment its memarg encodes when the access is naturally aligned.
 * Params:
 *      op = a load or store opcode
 * Returns: log2 of the accessed byte size, 4 (the v128 access size) for anything else
 */
uint naturalAlign(OP op) @safe pure nothrow @nogc
{
    switch (op)
    {
        case OP.I32_LOAD8_S, OP.I32_LOAD8_U, OP.I64_LOAD8_S, OP.I64_LOAD8_U,
             OP.I32_STORE8, OP.I64_STORE8:
            return 0;
        case OP.I32_LOAD16_S, OP.I32_LOAD16_U, OP.I64_LOAD16_S, OP.I64_LOAD16_U,
             OP.I32_STORE16, OP.I64_STORE16:
            return 1;
        case OP.I32_LOAD, OP.F32_LOAD, OP.I64_LOAD32_S, OP.I64_LOAD32_U,
             OP.I32_STORE, OP.F32_STORE, OP.I64_STORE32:
            return 2;
        case OP.I64_LOAD, OP.F64_LOAD, OP.I64_STORE, OP.F64_STORE:
            return 3;
        default:
            return 4;
    }
}
