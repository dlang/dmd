/**
 * CodeView symbolic debug info declarations
 *
 * See "Microsoft Symbol and Type OMF" document
 *
 * See https://github.com/microsoft/microsoft-pdb/tree/master/include
 * for a more complete set of publicly available definitions
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/cv4.d, backend/_cv4.d)
 */

module dmd.backend.cv4;

@safe:

// Online documentation: https://dlang.org/phobos/dmd_backend_cv4.html

// Symbol Indices
enum
{
    S_COMPILE     = 1,
    S_REGISTER    = 2,
    S_CONST       = 3,
    S_UDT         = 4,
    S_SSEARCH     = 5,
    S_END         = 6,
    S_SKIP        = 7,
    S_CVRESERVE   = 8,
    S_OBJNAME     = 9,
    S_ENDARG      = 0x0A,
    S_COBOLUDT    = 0x0B,
    S_MANYREG     = 0x0C,
    S_RETURN      = 0x0D,
    S_ENTRYTHIS   = 0x0E,
    S_TDBNAME     = 0x0F,

    S_BPREL16     = 0x100,
    S_LDATA16     = 0x101,
    S_GDATA16     = 0x102,
    S_PUB16       = 0x103,
    S_LPROC16     = 0x104,
    S_GPROC16     = 0x105,
    S_THUNK16     = 0x106,
    S_BLOCK16     = 0x107,
    S_WITH16      = 0x108,
    S_LABEL16     = 0x109,
    S_CEXMODEL16  = 0x10A,
    S_VFTPATH16   = 0x10B,

    S_BPREL32     = 0x200,
    S_LDATA32     = 0x201,
    S_GDATA32     = 0x202,
    S_PUB32       = 0x203,
    S_LPROC32     = 0x204,
    S_GPROC32     = 0x205,
    S_THUNK32     = 0x206,
    S_BLOCK32     = 0x207,
    S_WITH32      = 0x208,
    S_LABEL32     = 0x209,
    S_CEXMODEL32  = 0x20A,
    S_VFTPATH32   = 0x20B,

    /************** Added Since CV4 *********************/

    S_REGISTER_V2         = 0x1001,
    S_CONSTANT_V2         = 0x1002,
    S_UDT_V2              = 0x1003,
    S_COBOLUDT_V2         = 0x1004,
    S_MANYREG_V2          = 0x1005,
    S_BPREL_V2            = 0x1006,
    S_LDATA_V2            = 0x1007,
    S_GDATA_V2            = 0x1008,
    S_PUB_V2              = 0x1009,
    S_LPROC_V2            = 0x100A,
    S_GPROC_V2            = 0x100B,
    S_VFTTABLE_V2         = 0x100C,
    S_REGREL_V2           = 0x100D,
    S_LTHREAD_V2          = 0x100E,
    S_GTHREAD_V2          = 0x100F,
    S_FUNCINFO_V2         = 0x1012,
    S_COMPILAND_V2        = 0x1013,

    S_OBJNAME_V3          = 0x1101,
    S_THUNK_V3            = 0x1102,
    S_BLOCK_V3            = 0x1103,
    S_LABEL_V3            = 0x1105,
    S_REGISTER_V3         = 0x1106,
    S_CONSTANT_V3         = 0x1107,
    S_UDT_V3              = 0x1108,
    S_BPREL_V3            = 0x110B,
    S_LDATA_V3            = 0x110C,
    S_GDATA_V3            = 0x110D,
    S_PUB_V3              = 0x110E,
    S_LPROC_V3            = 0x110F,
    S_GPROC_V3            = 0x1110,
    S_BPREL_XXXX_V3       = 0x1111,
    S_MSTOOL_V3           = 0x1116,
    S_PUB_FUNC1_V3        = 0x1125,
    S_PUB_FUNC2_V3        = 0x1127,
    S_SECTINFO_V3         = 0x1136,
    S_SUBSECTINFO_V3      = 0x1137,
    S_ENTRYPOINT_V3       = 0x1138,
    S_SECUCOOKIE_V3       = 0x113A,

    S_COMPILE3            = 0x113C,      // compile flags, language and compiler version
    S_ENVBLOCK            = 0x113D,      // build environment block
    S_BUILDINFO           = 0x114C,      // reference to an LF_BUILDINFO record
    S_FRAMEPROC           = 0x1012,      // extra frame and procedure information
    S_REGREL32            = 0x1111,      // register-relative address
    S_LTHREAD32           = 0x1112,      // thread-local static data (local)
    S_GTHREAD32           = 0x1113,      // thread-local static data (global)
    S_LPROC32_ID          = 0x1146,      // local procedure (type field is an LF_FUNC_ID)
    S_GPROC32_ID          = 0x1147,      // global procedure (type field is an LF_FUNC_ID)
}

// Leaf Indices
enum
{
    LF_MODIFIER    = 1,
    LF_POINTER     = 2,
    LF_ARRAY       = 3,
    LF_CLASS       = 4,
    LF_STRUCTURE   = 5,
    LF_UNION       = 6,
    LF_ENUM        = 7,
    LF_PROCEDURE   = 8,
    LF_MFUNCTION   = 9,
    LF_VTSHAPE     = 0x0A,
    LF_COBOL0      = 0x0B,
    LF_COBOL1      = 0x0C,
    LF_BARRAY      = 0x0D,
    LF_LABEL       = 0x0E,
    LF_NULL        = 0x0F,
    LF_NOTTRAN     = 0x10,
    LF_DIMARRAY    = 0x11,
    LF_VFTPATH     = 0x12,
    LF_PRECOMP     = 0x13,
    LF_ENDPRECOMP  = 0x14,
    LF_OEM         = 0x15,
    LF_TYPESERVER  = 0x16,

    // D extensions (not used, causes linker to fail)
    LF_DYN_ARRAY   = 0x17,
    LF_ASSOC_ARRAY = 0x18,
    LF_DELEGATE    = 0x19,

    LF_SKIP        = 0x200,
    LF_ARGLIST     = 0x201,
    LF_DEFARG      = 0x202,
    LF_LIST        = 0x203,
    LF_FIELDLIST   = 0x204,
    LF_DERIVED     = 0x205,
    LF_BITFIELD    = 0x206,
    LF_METHODLIST  = 0x207,
    LF_DIMCONU     = 0x208,
    LF_DIMCONLU    = 0x209,
    LF_DIMVARU     = 0x20A,
    LF_DIMVARLU    = 0x20B,
    LF_REFSYM      = 0x20C,

    LF_BCLASS      = 0x400,
    LF_VBCLASS     = 0x401,
    LF_IVBCLASS    = 0x402,
    LF_ENUMERATE   = 0x403,
    LF_FRIENDFCN   = 0x404,
    LF_INDEX       = 0x405,
    LF_MEMBER      = 0x406,
    LF_STMEMBER    = 0x407,
    LF_METHOD      = 0x408,
    LF_NESTTYPE    = 0x409,
    LF_VFUNCTAB    = 0x40A,
    LF_FRIENDCLS   = 0x40B,

    LF_NUMERIC     = 0x8000,
    LF_CHAR        = 0x8000,
    LF_SHORT       = 0x8001,
    LF_USHORT      = 0x8002,
    LF_LONG        = 0x8003,
    LF_ULONG       = 0x8004,
    LF_REAL32      = 0x8005,
    LF_REAL64      = 0x8006,
    LF_REAL80      = 0x8007,
    LF_REAL128     = 0x8008,
    LF_QUADWORD    = 0x8009,
    LF_UQUADWORD   = 0x800A,
    LF_REAL48      = 0x800B,

    LF_COMPLEX32   = 0x800C,
    LF_COMPLEX64   = 0x800D,
    LF_COMPLEX80   = 0x800E,
    LF_COMPLEX128  = 0x800F,

    LF_VARSTRING   = 0x8010,

    /************** Added Since CV4 *********************/

    LF_MODIFIER_V2        = 0x1001,
    LF_POINTER_V2         = 0x1002,
    LF_ARRAY_V2           = 0x1003,
    LF_CLASS_V2           = 0x1004,
    LF_STRUCTURE_V2       = 0x1005,
    LF_UNION_V2           = 0x1006,
    LF_ENUM_V2            = 0x1007,
    LF_PROCEDURE_V2       = 0x1008,
    LF_MFUNCTION_V2       = 0x1009,
    LF_COBOL0_V2          = 0x100A,
    LF_BARRAY_V2          = 0x100B,
    LF_DIMARRAY_V2        = 0x100C,
    LF_VFTPATH_V2         = 0x100D,
    LF_PRECOMP_V2         = 0x100E,
    LF_OEM_V2             = 0x100F,

    LF_SKIP_V2            = 0x1200,
    LF_ARGLIST_V2         = 0x1201,
    LF_DEFARG_V2          = 0x1202,
    LF_FIELDLIST_V2       = 0x1203,
    LF_DERIVED_V2         = 0x1204,
    LF_BITFIELD_V2        = 0x1205,
    LF_METHODLIST_V2      = 0x1206,
    LF_DIMCONU_V2         = 0x1207,
    LF_DIMCONLU_V2        = 0x1208,
    LF_DIMVARU_V2         = 0x1209,
    LF_DIMVARLU_V2        = 0x120A,

    LF_BCLASS_V2          = 0x1400,
    LF_VBCLASS_V2         = 0x1401,
    LF_IVBCLASS_V2        = 0x1402,
    LF_FRIENDFCN_V2       = 0x1403,
    LF_INDEX_V2           = 0x1404,
    LF_MEMBER_V2          = 0x1405,
    LF_STMEMBER_V2        = 0x1406,
    LF_METHOD_V2          = 0x1407,
    LF_NESTTYPE_V2        = 0x1408,
    LF_VFUNCTAB_V2        = 0x1409,
    LF_FRIENDCLS_V2       = 0x140A,
    LF_ONEMETHOD_V2       = 0x140B,
    LF_VFUNCOFF_V2        = 0x140C,
    LF_NESTTYPEEX_V2      = 0x140D,

    LF_ENUMERATE_V3       = 0x1502,
    LF_ARRAY_V3           = 0x1503,
    LF_CLASS_V3           = 0x1504,
    LF_STRUCTURE_V3       = 0x1505,
    LF_UNION_V3           = 0x1506,
    LF_ENUM_V3            = 0x1507,
    LF_MEMBER_V3          = 0x150D,
    LF_STMEMBER_V3        = 0x150E,
    LF_METHOD_V3          = 0x150F,
    LF_NESTTYPE_V3        = 0x1510,
    LF_ONEMETHOD_V3       = 0x1511,

    // Type leaf records used by the ID stream
    LF_FUNC_ID            = 0x1601,   // function id: function type + name
    LF_STRING_ID          = 0x1605,   // interned string -> type index
    LF_BUILDINFO          = 0x1603,   // cwd, tool, source, pdb, args
    LF_UDT_SRC_LINE       = 0x1606,   // source file/line where a UDT is defined
}

// .debug$S subsection kinds
enum
{
    DEBUG_S_SYMBOLS     = 0xF1,
    DEBUG_S_LINES       = 0xF2,
    DEBUG_S_STRINGTABLE = 0xF3,
    DEBUG_S_FILECHKSMS  = 0xF4,
}

// Source file checksum kinds
enum
{
    CHKSUM_NONE   = 0,
    CHKSUM_MD5    = 1,
    CHKSUM_SHA1   = 2,
    CHKSUM_SHA256 = 3,
}

// S_FRAMEPROC flags
enum
{
    CV_FRAME_HASALLOCA   = 1 << 0,      // function uses alloca()
    CV_FRAME_HASINLASM   = 1 << 3,      // function has inline asm
    CV_FRAME_HASEH       = 1 << 4,      // function has exception handling
    CV_FRAME_SECURITY    = 1 << 8,      // function has a stack security cookie
    CV_FRAME_OPTSPEED    = 1 << 20,     // function was optimized for speed
    CV_FRAME_LOCALBP_RBP = 2 << 14,     // locals addressed relative to RBP/EBP
    CV_FRAME_PARAMBP_RBP = 2 << 16,     // parameters addressed relative to RBP/EBP
}

// Mark a line-number entry as a statement (not an expression)
enum CV_LINE_STATEMENT = 0x80000000;

// CodeView register encodings for base-pointer-relative records
enum
{
    CV_REG_EBP   = 22,          // x86 EBP
    CV_AMD64_RBP = 334,         // x64 RBP
}
