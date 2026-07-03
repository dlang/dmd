/**
 * CodeView / PDB symbolic debug info generation.
 *
 * This module generates the `.debug$S` (symbols) and `.debug$T` (types)
 * sections for Win64 MS-COFF objects. It merges the CodeView 4 record
 * declarations, the legacy CodeView 8 emitter, and the modern CodeView/PDB
 * record set documented by LLVM (https://llvm.org/docs/PDB/) and Microsoft
 * (https://github.com/microsoft/microsoft-pdb) into a single emitter.
 *
 * The shared type-record pool in cgcv.d/cv4-era helpers is reused via
 * `cv_typidx`, so D-specific type records (dynamic arrays, delegates,
 * associative arrays) stay shared.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:    Copyright (C) 2012-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/codeview.d, backend/codeview.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_codeview.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/codeview.d
 */

module dmd.backend.codeview;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
extern (C) nothrow char* getcwd(char*, size_t);

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.mem;
import dmd.backend.global : getFileContentsCallback;
import dmd.backend.mscoffobj;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.common.outbuffer;
import dmd.backend.rtlsym;
import dmd.backend.symbol : globsym;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.dvarstats;


nothrow:
@safe:

/* ======================================================================== */
/* CodeView record constants (formerly backend/cv4.d).                      */
/* ======================================================================== */

enum OEM = 0x42;        // Digital Mars OEM number (picked at random)

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

    S_COMPILAND_V3        = 0x1101,
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
    S_MSTOOLINFO_V3       = 0x113C,
    S_MSTOOLENV_V3        = 0x113D,
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
}

/* ======================================================================== */
/* Modern CodeView (CV8 / PDB) records not present in the CV4 record set.    */
/* ======================================================================== */

// Symbol records
enum
{
    S_COMPILE3   = 0x113C,      // modern compiland flags/version (aka S_MSTOOLINFO_V3)
    S_ENVBLOCK   = 0x113D,      // build environment (aka S_MSTOOLENV_V3)
    S_BUILDINFO  = 0x114C,      // references an LF_BUILDINFO id record
    S_FRAMEPROC  = 0x1012,      // per-function frame info (aka S_FUNCINFO_V2)
    S_REGREL_V3  = 0x1111,      // register-relative addressing (aka S_BPREL_XXXX_V3)
    S_LTHREAD_V3 = 0x1112,      // local thread-local storage
    S_GTHREAD_V3 = 0x1113,      // global thread-local storage
}

// ID-stream type leaves
enum
{
    LF_FUNC_ID      = 0x1601,   // ties a function type to its name
    LF_STRING_ID    = 0x1605,   // interned string -> type index
    LF_BUILDINFO    = 0x1603,   // cwd, tool, source, pdb, args
    LF_UDT_SRC_LINE = 0x1606,   // source file/line where a UDT is defined
}

// .debug$S subsection kinds
enum
{
    DEBUG_S_SYMBOLS     = 0xF1,
    DEBUG_S_LINES       = 0xF2,
    DEBUG_S_STRINGTABLE = 0xF3,
    DEBUG_S_FILECHKSMS  = 0xF4,
}

// File checksum kinds
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
    CV_FRAME_HASINLASM   = 1 << 3,    // function has inline asm
    CV_FRAME_HASEH       = 1 << 4,    // function has exception handling
    CV_FRAME_SECURITY    = 1 << 8,    // stack security cookie checks
    CV_FRAME_OPTSPEED    = 1 << 20,   // optimized for speed
    CV_FRAME_LOCALBP_RBP = 2 << 14,   // locals addressed relative to RBP/EBP
    CV_FRAME_PARAMBP_RBP = 2 << 16,   // params addressed relative to RBP/EBP
}

// Mark a line-number entry as a statement (not an expression)
enum CV_LINE_STATEMENT = 0x80000000;

// CodeView register encodings for base-pointer relative records
enum
{
    CV_REG_EBP   = 22,          // x86 EBP
    CV_AMD64_RBP = 334,         // x64 RBP
}

// if symbols get longer than 65500 bytes, the linker reports corrupt debug info or exits with
// 'fatal error LNK1318: Unexpected PDB error; RPC (23) '(0x000006BA)'
enum CV_MAX_SYMBOL_LENGTH = 0xffd8;

// CV_PUBSYMFLAGS
enum PUB_FUNCTION = 0x00000002;

/* ======================================================================== */
/* State                                                                    */
/* ======================================================================== */

// Determine if this Symbol is stored in a COMDAT
@trusted
private bool symbol_iscomdat4(Symbol* s)
{
    return s.Sclass == SC.comdat ||
        config.flags2 & CFG2comdat && s.Sclass == SC.inline ||
        config.flags4 & CFG4allcomdat && s.Sclass == SC.global;
}

// The "F1" section, which is the symbols
private __gshared OutBuffer* F1_buf;

// The "F2" section, which is the line numbers
private __gshared OutBuffer* F2_buf;

// The "F3" section, which is global and a string table of source file names.
private __gshared OutBuffer* F3_buf;

// The "F4" section, which is global and a list of info about source files.
private __gshared OutBuffer* F4_buf;

/* Fixups that go into F1 section
 */
struct F1_Fixups
{
    Symbol* s;
    uint offset;
    uint value;
}

private __gshared OutBuffer* F1fixup;      // array of F1_Fixups

/* Struct in which to collect per-function data, for later emission
 * into .debug$S.
 */
struct FuncData
{
    Symbol* sfunc;
    uint section_length;
    const(char)* srcfilename;
    uint srcfileoff;
    uint linepairstart;     // starting byte index of offset/line pairs in linebuf[]
    uint linepairbytes;     // number of bytes for offset/line pairs
    uint linepairsegment;   // starting byte index of filename segment for offset/line pairs
    OutBuffer* f1buf;
    OutBuffer* f1fixup;
}

__gshared FuncData currentfuncdata;

private __gshared OutBuffer* funcdata;     // array of FuncData's

private __gshared OutBuffer* linepair;     // array of offset/line pairs

/* ======================================================================== */
/* Name encoding                                                            */
/* ======================================================================== */

private @trusted
void cv_writename(OutBuffer* buf, const(char)* name, size_t len)
{
    if (!(config.flags2 & CFG2gms))
    {
        buf.writen(name, len);
        return;
    }

    const(char)* start = name;
    const(char)* cur = strchr(start, '.');
    const(char)* end = start + len;
    while (cur != null)
    {
        if (cur >= end)
        {
            buf.writen(start, end - start);
            return;
        }
        buf.writen(start, cur - start);
        buf.writeByte('@');
        start = cur + 1;
        if (start >= end)
            return;
        cur = strchr(start, '.');
    }
    buf.writen(start, end - start);
}

/* ======================================================================== */
/* File lifecycle                                                           */
/* ======================================================================== */

/************************************************
 * Called at the start of an object file generation.
 * One source file can generate multiple object files; this starts an object file.
 * Input:
 *      filename        source file name
 */
@trusted
void cv_initfile(const(char)* filename)
{
    void initBuf(ref OutBuffer* ptr)
    {
        if (!ptr)
        {
            ptr = cast(OutBuffer*)mem_calloc(OutBuffer.sizeof);
            ptr.reserve(1024);
        }
        ptr.reset();
    }

    initBuf(F1_buf);
    initBuf(F1fixup);
    initBuf(F2_buf);

    initBuf(F3_buf);
    F3_buf.writeByte(0);       // first "filename"

    initBuf(F4_buf);
    initBuf(funcdata);
    initBuf(linepair);

    memset(&currentfuncdata, 0, currentfuncdata.sizeof);
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;

    cv_init();
}

/************************************************
 * Called at the start of a module.
 * Note that there can be multiple modules in one object file.
 * cv_initfile() must be called first.
 */
void cv_initmodule(const(char)* filename, const(char)* modulename)
{
}

@trusted
void cv_termmodule()
{
    assert(config.objfmt == OBJ_MSCOFF);
}

@trusted
void cv_termfile(const(char)[] objfilename)
{
    int seg = MsCoffObj_seg_debugS();

    uint value = 4;            // CV signature C13
    objmod.bytes(seg, 0, (cast(void*)&value)[0 .. 4]);

    auto buf = OutBuffer(1024);

    // S_OBJNAME
    {
        size_t len = objfilename.length;
        buf.write16(cast(int)(2 + 4 + len + 1));
        buf.write16(S_COMPILAND_V3);
        buf.write32(0);                          // signature
        buf.write(objfilename.ptr, cast(uint)(len + 1));
    }

    // S_COMPILE3
    {
        // Honor the configured language/compiler instead of hardcoding it:
        // emit the D language index unless the debug info was requested for
        // non-DMD (Microsoft) debuggers (-gc sets CFG2gms), and report the
        // actual compiler version string (dmd/ldc/gdc) via config._version.
        const uint flags = config.flags2 & CFG2gms ? 0 : 'D'; // iLanguage in low byte
        const(char)[] ver = config._version;
        buf.write16(cast(int)(2 + 4 + 2 + 8 + 8 + ver.length + 1));
        buf.write16(S_COMPILE3);
        buf.write32(flags);
        buf.write16(I64 ? 0xD0 : 0x07);          // machine: AMD64 / x86
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // FE ver
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // BE ver
        buf.write(ver.ptr, cast(uint)ver.length);
        buf.writeByte(0);
    }

    cv_writesection(seg, DEBUG_S_SYMBOLS, &buf);

    // S_ENVBLOCK: build environment (cwd, tool), double-null terminated
    {
        auto ebuf = OutBuffer(128);
        char[260] cwd = 0;
        if (!getcwd(cwd.ptr, cwd.sizeof))
            cwd[0] = 0;
        size_t cwdlen = strlen(cwd.ptr);
        uint rec = cast(uint)(2 + 1 + 4 + cwdlen + 1 + 4 + 1 + 1);
        ebuf.write16(cast(int)rec);
        ebuf.write16(S_ENVBLOCK);
        ebuf.writeByte(0);                       // flags
        ebuf.write("cwd\0".ptr, 4);
        ebuf.write(cwd.ptr, cast(uint)(cwdlen + 1));
        ebuf.write("cmd\0".ptr, 4);
        ebuf.writeByte(0);                       // empty cmd value
        ebuf.writeByte(0);                       // terminating double-null
        cv_writesection(seg, DEBUG_S_SYMBOLS, &ebuf);
    }

    // S_BUILDINFO referencing an LF_BUILDINFO id record
    {
        auto bbuf = OutBuffer(64);
        idx_t biidx = cv_buildinfo();
        bbuf.write16(2 + 4);
        bbuf.write16(S_BUILDINFO);
        bbuf.write32(biidx);
        cv_writesection(seg, DEBUG_S_SYMBOLS, &bbuf);
    }

    uint length = cast(uint)funcdata.length();
    ubyte* p = funcdata.buf;
    for (uint u = 0; u < length; u += FuncData.sizeof)
    {
        FuncData* fd = cast(FuncData*)(p + u);

        F2_buf.reset();
        F2_buf.write32(cast(uint)fd.sfunc.Soffset);
        F2_buf.write32(0);
        F2_buf.write32(fd.section_length);
        F2_buf.write(linepair.buf + fd.linepairstart, fd.linepairbytes);

        int f2seg = seg;
        if (symbol_iscomdat4(fd.sfunc))
        {
            f2seg = MsCoffObj_seg_debugS_comdat(fd.sfunc);
            objmod.bytes(f2seg, 0, (cast(void*)&value)[0 .. 4]);
        }

        uint offset = cast(uint)SegData[f2seg].SDoffset + 8;
        cv_writesection(f2seg, DEBUG_S_LINES, F2_buf);
        objmod.reftoident(f2seg, offset, fd.sfunc, 0, CF.seg | CF.off);

        if (f2seg != seg && fd.f1buf.length())
        {
            const uint f1offset = cast(uint)SegData[f2seg].SDoffset;
            cv_writesection(f2seg, DEBUG_S_SYMBOLS, fd.f1buf);

            const uint fixupLength = cast(uint)fd.f1fixup.length();
            ubyte* pfixup = fd.f1fixup.buf;
            for (uint v = 0; v < fixupLength; v += F1_Fixups.sizeof)
            {
                F1_Fixups* f = cast(F1_Fixups*)(pfixup + v);
                objmod.reftoident(f2seg, f1offset + 8 + f.offset, f.s, f.value, CF.seg | CF.off);
            }
        }
    }

    if (F3_buf.length() > 1)
        cv_writesection(seg, DEBUG_S_STRINGTABLE, F3_buf);

    if (F4_buf.length() > 0)
        cv_writesection(seg, DEBUG_S_FILECHKSMS, F4_buf);

    if (F1_buf.length())
    {
        uint f1offset = cast(uint)SegData[seg].SDoffset;
        cv_writesection(seg, DEBUG_S_SYMBOLS, F1_buf);

        length = cast(uint)F1fixup.length();
        p = F1fixup.buf;
        for (uint u = 0; u < length; u += F1_Fixups.sizeof)
        {
            F1_Fixups* f = cast(F1_Fixups*)(p + u);
            objmod.reftoident(seg, f1offset + 8 + f.offset, f.s, f.value, CF.seg | CF.off);
        }
    }

    cv_term();      // .debug$T
}

/* ======================================================================== */
/* Functions                                                                */
/* ======================================================================== */

/******************************************
 * Called at the start of a function.
 */
@trusted
void cv_func_start(Symbol* sfunc)
{
    currentfuncdata.sfunc = sfunc;
    currentfuncdata.section_length = 0;
    currentfuncdata.srcfilename = null;
    currentfuncdata.linepairstart += currentfuncdata.linepairbytes;
    currentfuncdata.linepairbytes = 0;
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
    if (symbol_iscomdat4(sfunc))
    {
        // This leaks memory
        currentfuncdata.f1buf = cast(OutBuffer*)mem_calloc(OutBuffer.sizeof);
        currentfuncdata.f1buf.reserve(128);
        currentfuncdata.f1fixup = cast(OutBuffer*)mem_calloc(OutBuffer.sizeof);
        currentfuncdata.f1fixup.reserve(128);
    }
    varStats_startFunction();
}

@trusted
void cv_func_term(Symbol* sfunc)
{
    assert(currentfuncdata.sfunc == sfunc);
    currentfuncdata.section_length = cast(uint)sfunc.Ssize;
    funcdata.write(&currentfuncdata, currentfuncdata.sizeof);

    assert(tyfunc(sfunc.ty()));
    idx_t typidx;
    func_t* fn = sfunc.Sfunc;
    if (fn.Fclass)
    {
        // Member functions get a dedicated LF_MFUNCTION_V2 type record that
        // records the enclosing class and the `this` pointer type. This info
        // isn't available inside cv_typidx, so generate it here.
        uint nparam;
        const ubyte call = cv4_callconv(sfunc.Stype);
        const idx_t paramidx = cv4_arglist(sfunc.Stype, &nparam);
        const uint next = cv4_typidx(sfunc.Stype.Tnext);
        type* classtype = cast(type*)fn.Fclass;
        const uint classidx = cv4_typidx(classtype);
        type* tp = type_allocn(TYnptr, classtype);
        const uint thisidx = cv4_typidx(tp);
        debtyp_t* d = debtyp_alloc(2 + 4 + 4 + 4 + 1 + 1 + 2 + 4 + 4);
        TOWORD(d.data.ptr, LF_MFUNCTION_V2);
        TOLONG(d.data.ptr + 2, next);       // return type
        TOLONG(d.data.ptr + 6, classidx);   // class type
        TOLONG(d.data.ptr + 10, thisidx);   // this type
        d.data.ptr[14] = call;
        d.data.ptr[15] = 0;                 // reserved
        TOWORD(d.data.ptr + 16, nparam);
        TOLONG(d.data.ptr + 18, paramidx);
        TOLONG(d.data.ptr + 22, 0);         // this adjust
        typidx = cv_debtyp(d);
    }
    else
        typidx = cv_typidx(sfunc.Stype);

    const(char)* id = sfunc.prettyIdent ? sfunc.prettyIdent : prettyident(sfunc);
    size_t len = strlen(id);
    if (len > CV_MAX_SYMBOL_LENGTH)
        len = CV_MAX_SYMBOL_LENGTH;

    auto buf = currentfuncdata.f1buf;
    buf.reserve(cast(uint)(2 + 2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(cast(int)(2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(sfunc.Sclass == SC.static_ ? S_LPROC_V3 : S_GPROC_V3);
    buf.write32(0);            // parent
    buf.write32(0);            // pend
    buf.write32(0);            // pnext
    buf.write32(cast(uint)currentfuncdata.section_length);
    buf.write32(cast(uint)cgstate.startoffset);     // prolog size
    buf.write32(cast(uint)cgstate.retoffset);       // epilog offset
    buf.write32(typidx);

    F1_Fixups f1f;
    f1f.s = sfunc;
    f1f.offset = cast(uint)buf.length();
    f1f.value = 0;
    currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
    buf.write32(0);
    buf.write16n(0);
    buf.writeByte(0);          // flags
    buf.writen(id, len);
    buf.writeByte(0);

    // S_FRAMEPROC: describe this function's stack frame
    {
        // Locals and parameters are addressed relative to the frame pointer
        // (RBP/EBP), matching the S_REGREL_V3 records emitted for them.
        uint frameflags = CV_FRAME_LOCALBP_RBP | CV_FRAME_PARAMBP_RBP;
        if (cgstate.anyiasm)
            frameflags |= CV_FRAME_HASINLASM;
        if (cgstate.usednteh)
            frameflags |= CV_FRAME_HASEH;
        if (config.flags2 & CFG2stomp)
            frameflags |= CV_FRAME_SECURITY;
        if (config.flags4 & CFG4speed)
            frameflags |= CV_FRAME_OPTSPEED;

        buf.write16(2 + 4 + 4 + 4 + 4 + 4 + 2 + 4);
        buf.write16(S_FRAMEPROC);
        buf.write32(cast(uint)localsize);        // cbFrame: total frame size
        buf.write32(0);                          // cbPad
        buf.write32(0);                          // offPad
        buf.write32(0);                          // cbSaveRegs
        buf.write32(0);                          // offExHdlr
        buf.write16(0);                          // sectExHdlr
        buf.write32(frameflags);                 // flags
    }

    struct cvblk
    {
    nothrow:
        // record for CV record S_BLOCK_V3
        struct block_v3_data
        {
            ushort len;
            ushort id;
            uint pParent;
            uint pEnd;
            uint length;
            uint offset;
            ushort seg;
            ubyte[1] name;
        }
        static void endArgs()
        {
            auto b = currentfuncdata.f1buf;
            b.write16(2);
            b.write16(S_ENDARG);
        }
        static void beginBlock(int offset, int length)
        {
            auto b = currentfuncdata.f1buf;
            uint soffset = cast(uint)b.length();
            // parent and end to be filled by linker
            block_v3_data block32 = { block_v3_data.sizeof - 2, S_BLOCK_V3, 0, 0, length, offset, 0, [ 0 ] };
            b.write(&block32, block32.sizeof);
            size_t offOffset = cast(char*)&block32.offset - cast(char*)&block32;
            F1_Fixups f;
            f.s = currentfuncdata.sfunc;
            f.offset = cast(uint)(soffset + offOffset);
            f.value = offset;
            currentfuncdata.f1fixup.write(&f, f.sizeof);
        }
        static void endBlock()
        {
            auto b = currentfuncdata.f1buf;
            b.write16(2);
            b.write16(S_END);
        }
    }
    varStats_writeSymbolTable(sfunc, globsym, &cv_symbol, &cvblk.endArgs, &cvblk.beginBlock, &cvblk.endBlock);

    // No S_RETURN record: its register list uses single-byte CodeView register
    // codes, which cannot encode x64 return registers (e.g. CV_AMD64_RAX = 328).
    // Both MSVC and the legacy CV8 path omit it, so a real record can't be produced here.

    buf.write16(2);
    buf.write16(S_END);

    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
}

/* ======================================================================== */
/* Line numbers                                                             */
/* ======================================================================== */

@trusted
void cv_linnum(Srcpos srcpos, uint offset)
{
    const sfilename = srcpos.Sfilename;
    if (!sfilename)
        return;

    varStats_recordLineOffset(srcpos, offset);

    __gshared uint lastoffset;
    __gshared uint lastlinnum;

    if (!currentfuncdata.srcfilename ||
        (currentfuncdata.srcfilename != sfilename && strcmp(currentfuncdata.srcfilename, sfilename)))
    {
        currentfuncdata.srcfilename = sfilename;
        uint srcfileoff = cv_addfile(sfilename);
        currentfuncdata.linepairsegment = currentfuncdata.linepairstart + currentfuncdata.linepairbytes;
        linepair.write32(srcfileoff);
        linepair.write32(0);
        linepair.write32(12);
        currentfuncdata.linepairbytes += 12;
    }
    else if (offset <= lastoffset || srcpos.Slinnum == lastlinnum)
        return;

    lastoffset = offset;
    lastlinnum = srcpos.Slinnum;
    linepair.write32(offset);
    linepair.write32(srcpos.Slinnum | CV_LINE_STATEMENT); // mark as statement, not expression
    currentfuncdata.linepairbytes += 8;

    auto segmentbytes = currentfuncdata.linepairstart + currentfuncdata.linepairbytes - currentfuncdata.linepairsegment;
    auto segmentheader = cast(uint*)(linepair.buf + currentfuncdata.linepairsegment);
    segmentheader[1] = (segmentbytes - 12) / 8;
    segmentheader[2] = segmentbytes;
}

/* ======================================================================== */
/* Source files (F3 names + F4 checksums via blake3)                        */
/* ======================================================================== */

/**********************************************
 * Add source file, if it isn't already there.
 * Return offset into F4.
 */
@trusted
uint cv_addfile(const(char)* filename)
{
    uint length = cast(uint)F3_buf.length();
    ubyte* p = F3_buf.buf;
    size_t len = strlen(filename);

    // ensure the filename is absolute to help the debugger to find the source
    // without having to know the working directory during compilation
    __gshared char[260] cwd = 0;
    __gshared uint cwdlen;
    bool abs = (*filename == '\\') || (*filename == '/') ||
               (*filename && filename[1] == ':');

    if (!abs && cwd[0] == 0)
    {
        if (getcwd(cwd.ptr, cwd.sizeof))
        {
            cwdlen = cast(uint)strlen(cwd.ptr);
            if (cwd[cwdlen - 1] != '\\' && cwd[cwdlen - 1] != '/')
                cwd[cwdlen++] = '\\';
        }
    }
    uint off = 1;
    while (off + len < length)
    {
        if (!abs)
        {
            if (memcmp(p + off, cwd.ptr, cwdlen) == 0 &&
                memcmp(p + off + cwdlen, filename, len + 1) == 0)
                goto L1;
        }
        else if (memcmp(p + off, filename, len + 1) == 0)
            goto L1;
        off += strlen(cast(const(char)*)(p + off)) + 1;
    }
    off = length;
    if (!abs)
        F3_buf.write(cwd.ptr, cwdlen);
    F3_buf.write(filename, cast(uint)(len + 1));

L1:
    length = cast(uint)F4_buf.length();
    p = F4_buf.buf;
    uint u = 0;
    while (u + 6 <= length)
    {
        if (off == *cast(uint*)(p + u))
            return u;
        u += 4;                     // file name offset
        ubyte cklen = *(p + u);     // checksum size
        u += 2;                     // skip size + kind bytes
        u += cklen;                 // skip checksum bytes
        u = (u + 3) & ~3;           // realign to 4
    }

    // Not present; append a checksum computed over the source file's *content*
    // (not over its name) so debuggers can verify the source matches.
    F4_buf.write32(off);
    ubyte[32] hash = void;
    if (cv_filehash(filename, hash))
    {
        F4_buf.writeByte(32);              // checksum size
        F4_buf.writeByte(CHKSUM_SHA256);   // 32-byte checksum slot
        F4_buf.write(hash.ptr, 32);
    }
    else
    {
        F4_buf.writeByte(0);               // no checksum available
        F4_buf.writeByte(CHKSUM_NONE);
    }
    while (F4_buf.length() & 3)
        F4_buf.writeByte(0);
    return length;
}

/* Compute a blake3 hash over the *content* of the named source file.
 * The bytes are fetched from the front-end's FileManager cache (populated when
 * the module was read) via a callback, avoiding a second read from disk.
 * Returns: true on success (hash filled in), false if the content is unavailable.
 */
private @trusted
bool cv_filehash(const(char)* filename, ref ubyte[32] hash)
{
    if (!getFileContentsCallback)
        return false;

    size_t length;
    const(ubyte)* data = getFileContentsCallback(filename, length);
    if (!data)
        return false;

    import dmd.common.blake3;
    hash = blake3(data[0 .. length]);
    return true;
}

private @trusted
void cv_writesection(int seg, uint type, OutBuffer* buf)
{
    /* Write out as:
     *  bytes   desc
     *  -------+----
     *  4       type
     *  4       length
     *  length  data
     *  pad     pad to 4 byte boundary
     */
    uint off = cast(uint)SegData[seg].SDoffset;
    objmod.bytes(seg, off, (cast(void*)&type)[0 .. 4]);
    uint length = cast(uint)buf.length();
    objmod.bytes(seg, off + 4, (cast(void*)&length)[0 .. 4]);
    objmod.bytes(seg, off + 8, buf.buf[0 .. length]);
    uint pad = ((length + 3) & ~3) - length;
    objmod.lidata(seg, off + 8 + length, pad);
}

/* ======================================================================== */
/* Symbols                                                                  */
/* ======================================================================== */

@trusted
void cv_symbol(Symbol* s)
{
    if (s.Sflags & SFLnodebug)
        return;

    idx_t typidx = cv_typidx(s.Stype);
    const(char)* id = s.prettyIdent ? s.prettyIdent : prettyident(s);
    size_t len = strlen(id);
    if (len > CV_MAX_SYMBOL_LENGTH)
        len = CV_MAX_SYMBOL_LENGTH;

    F1_Fixups f1f;
    f1f.value = 0;
    auto buf = currentfuncdata.f1buf;

    uint sr;
    uint base;
    switch (s.Sclass)
    {
        case SC.parameter:
        case SC.regpar:
        case SC.shadowreg:
            if (s.Sfl == FL.reg)
            {
                s.Sfl = FL.para;
                cv_symbol(s);
                s.Sfl = FL.reg;
                goto case_register;
            }
            base = cast(uint)(cgstate.Para.size - cgstate.BPoff);
            goto L1;

        case SC.auto_:
            if (s.Sfl == FL.reg)
                goto case_register;
        case_auto:
            base = cast(uint)cgstate.Auto.size;
        L1:
            if (s.Sscope)
                break;
            buf.reserve(cast(uint)(2 + 2 + 4 + 4 + 2 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 4 + 2 + len + 1));
            buf.write16n(S_REGREL_V3);
            buf.write32(cast(uint)(s.Soffset + base + cgstate.BPoff));
            buf.write32(typidx);
            buf.write16n(I64 ? CV_AMD64_RBP : CV_REG_EBP);   // relative to RBP/EBP
            cv_writename(buf, id, len);
            buf.writeByte(0);
            break;

        case SC.bprel:
            base = -cgstate.BPoff;
            goto L1;

        case SC.fastpar:
            if (s.Sfl != FL.reg)
            {
                base = cast(uint)cgstate.Fast.size;
                goto L1;
            }
            goto L2;

        case SC.register:
            if (s.Sfl != FL.reg)
                goto case_auto;
            goto case;

        case SC.pseudo:
        case_register:
        L2:
            buf.reserve(cast(uint)(2 + 2 + 4 + 2 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 2 + len + 1));
            buf.write16n(S_REGISTER_V3);
            buf.write32(typidx);
            buf.write16n(cv_regnum(s));
            cv_writename(buf, id, len);
            buf.writeByte(0);
            break;

        case SC.extern_:
            break;

        case SC.static_:
        case SC.locstat:
            sr = S_LDATA_V3;
            goto Ldata;

        case SC.global:
        case SC.comdat:
        case SC.comdef:
            sr = S_GDATA_V3;
        Ldata:
            if (s.ty() & mTYthread)            // full TLS support
                sr = (sr == S_GDATA_V3) ? S_GTHREAD_V3 : S_LTHREAD_V3;

            buf.reserve(cast(uint)(2 + 2 + 4 + 6 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 6 + len + 1));
            buf.write16n(sr);
            buf.write32(typidx);
            f1f.s = s;
            f1f.offset = cast(uint)buf.length();
            currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
            buf.write32(0);
            buf.write16n(0);
            cv_writename(buf, id, len);
            buf.writeByte(0);
            break;

        default:
            break;
    }
}

/*******************************************
 * Put out a name for a user defined type.
 * Input:
 *      id      the name
 *      typidx  and its type
 */
@trusted
void cv_udt_symbol(const(char)* id, idx_t typidx)
{
    auto buf = currentfuncdata.f1buf;
    size_t len = strlen(id);
    if (len > CV_MAX_SYMBOL_LENGTH)
        len = CV_MAX_SYMBOL_LENGTH;
    buf.reserve(cast(uint)(2 + 2 + 4 + len + 1));
    buf.write16n(cast(uint)(2 + 4 + len + 1));
    buf.write16n(S_UDT_V3);
    buf.write32(typidx);
    cv_writename(buf, id, len);
    buf.writeByte(0);
}

/*********************************************
 * Get Codeview register number for symbol s.
 */
int cv_regnum(Symbol* s)
{
    int reg = s.Sreglsw;
    assert(s.Sfl == FL.reg);
    if ((1 << reg) & XMMREGS)
        return reg - XMM0 + 154;
    switch (type_size(s.Stype))
    {
        case 1:
            if (reg < 4)
                reg += 1;
            else if (reg >= 4 && reg < 8)
                reg += 324 - 4;
            else
                reg += 344 - 4;
            break;

        case 2:
            if (reg < 8)
                reg += 9;
            else
                reg += 352 - 8;
            break;

        case 4:
            if (reg < 8)
                reg += 17;
            else
                reg += 360 - 8;
            break;

        case 8:
            reg += 328;
            break;

        default:
            reg = 0;
            break;
    }
    return reg;
}

/***************************************
 * Put out a forward ref for structs, unions, and classes.
 * Only put out the real definitions with toDebug().
 */
@trusted
idx_t cv_fwdref(Symbol* s)
{
    assert(config.fulltypes == CV8);
    struct_t* st = s.Sstruct;
    uint leaf;
    uint numidx;
    if (st.Sflags & STRunion)
    {
        leaf = LF_UNION_V3;
        numidx = 10;
    }
    else if (st.Sflags & STRclass)
    {
        leaf = LF_CLASS_V3;
        numidx = 18;
    }
    else
    {
        leaf = LF_STRUCTURE_V3;
        numidx = 18;
    }
    uint len = numidx + cv4_numericbytes(0);
    int idlen = cast(int)strlen(s.Sident.ptr);

    if (idlen > CV_MAX_SYMBOL_LENGTH)
        idlen = CV_MAX_SYMBOL_LENGTH;

    debtyp_t* d = debtyp_alloc(len + idlen + 1);
    TOWORD(d.data.ptr, leaf);
    TOWORD(d.data.ptr + 2, 0);     // number of fields
    TOWORD(d.data.ptr + 4, 0x80);  // property
    TOLONG(d.data.ptr + 6, 0);     // field list
    if (leaf == LF_CLASS_V3 || leaf == LF_STRUCTURE_V3)
    {
        TOLONG(d.data.ptr + 10, 0);        // dList
        TOLONG(d.data.ptr + 14, 0);        // vshape
    }
    cv4_storenumeric(d.data.ptr + numidx, 0);
    cv_namestring(d.data.ptr + len, s.Sident.ptr, idlen);
    d.data.ptr[len + idlen] = 0;
    idx_t typidx = cv_debtyp(d);
    s.Stypidx = typidx;

    return typidx;
}

/****************************************
 * Return type index for a darray of type E[]
 * Input:
 *      t       darray type
 *      etypidx type index for E
 */
@trusted
idx_t cv_darray(type* t, idx_t etypidx)
{
    /* Put out a struct:
     *    struct dArray {
     *      size_t length;
     *      E* ptr;
     *    }
     */

    type* tp = type_pointer(t.Tnext);
    idx_t ptridx = cv4_typidx(tp);
    type_free(tp);

    __gshared const ubyte[38] fl =
    [
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x23, 0x00, 0x00, 0x00, // size_t
        0x00, 0x00,             // offset
        'l', 'e', 'n', 'g', 't', 'h', 0x00,
        0xf3, 0xf2, 0xf1,       // align to 4-byte including length word before data
        0x0d, 0x15,
        0x03, 0x00,
        0x00, 0x00, 0x00, 0x00, // etypidx
        0x08, 0x00,
        'p', 't', 'r', 0x00,
        0xf2, 0xf1,
    ];

    debtyp_t* f = debtyp_alloc(fl.sizeof);
    memcpy(f.data.ptr,fl.ptr,fl.sizeof);
    TOLONG(f.data.ptr + 6, I64 ? 0x23 : 0x22); // size_t
    TOLONG(f.data.ptr + 26, ptridx);
    TOWORD(f.data.ptr + 30, _tysize[TYnptr]);
    idx_t fieldlist = cv_debtyp(f);

    const(char)* id;
    switch (t.Tnext.Tty)
    {
        case mTYimmutable | TYchar:
            id = "string";
            break;

        case mTYimmutable | TYwchar_t:
            id = "wstring";
            break;

        case mTYimmutable | TYdchar:
            id = "dstring";
            break;

        default:
            id = t.Tident ? t.Tident : "dArray";
            break;
    }

    int idlen = cast(int)strlen(id);

    if (idlen > CV_MAX_SYMBOL_LENGTH)
        idlen = CV_MAX_SYMBOL_LENGTH;

    debtyp_t* d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d.data.ptr, LF_STRUCTURE_V3);
    TOWORD(d.data.ptr + 2, 2);     // count
    TOWORD(d.data.ptr + 4, 0);     // property
    TOLONG(d.data.ptr + 6, fieldlist);
    TOLONG(d.data.ptr + 10, 0);    // dList
    TOLONG(d.data.ptr + 14, 0);    // vtshape
    TOWORD(d.data.ptr + 18, 2 * _tysize[TYnptr]);   // size
    cv_namestring(d.data.ptr + 20, id, idlen);
    d.data.ptr[20 + idlen] = 0;

    idx_t top = cv_numdebtypes();
    idx_t debidx = cv_debtyp(d);
    if(top != cv_numdebtypes())
        cv_udt_symbol(id, debidx);

    return debidx;
}

/****************************************
 * Return type index for a delegate
 * Input:
 *      t          delegate type
 *      functypidx type index for pointer to function
 */
@trusted
idx_t cv_ddelegate(type* t, idx_t functypidx)
{
    /* Put out a struct:
     *    struct dDelegate {
     *      void* ptr;
     *      function* funcptr;
     *    }
     */

    type* tv = type_fake(TYnptr);
    tv.Tcount++;
    idx_t pvidx = cv4_typidx(tv);
    type_free(tv);

    type* tp = type_pointer(t.Tnext);
    idx_t ptridx = cv4_typidx(tp);
    type_free(tp);

    __gshared const ubyte[38] fl =
    [
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x00, 0x00, 0x00, 0x00, // void*
        0x00, 0x00,             // offset
        'p','t','r',0,          // "ptr"
        0xf2, 0xf1,             // align to 4-byte including length word before data
        0x0d, 0x15,
        0x03, 0x00,
        0x00, 0x00, 0x00, 0x00, // ptrtypidx
        0x08, 0x00,
        'f', 'u','n','c','p','t','r', 0,        // "funcptr"
        0xf2, 0xf1,
    ];

    debtyp_t* f = debtyp_alloc(fl.sizeof);
    memcpy(f.data.ptr,fl.ptr,fl.sizeof);
    TOLONG(f.data.ptr + 6, pvidx);
    TOLONG(f.data.ptr + 22, ptridx);
    TOWORD(f.data.ptr + 26, _tysize[TYnptr]);
    idx_t fieldlist = cv_debtyp(f);

    const(char)* id = "dDelegate";
    int idlen = cast(int)strlen(id);
    if (idlen > CV_MAX_SYMBOL_LENGTH)
        idlen = CV_MAX_SYMBOL_LENGTH;

    debtyp_t* d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d.data.ptr, LF_STRUCTURE_V3);
    TOWORD(d.data.ptr + 2, 2);     // count
    TOWORD(d.data.ptr + 4, 0);     // property
    TOLONG(d.data.ptr + 6, fieldlist);
    TOLONG(d.data.ptr + 10, 0);    // dList
    TOLONG(d.data.ptr + 14, 0);    // vtshape
    TOWORD(d.data.ptr + 18, 2 * _tysize[TYnptr]);   // size
    memcpy(d.data.ptr + 20, id, idlen);
    d.data.ptr[20 + idlen] = 0;

    return cv_debtyp(d);
}

/****************************************
 * Return type index for a aarray of type Value[Key]
 * Input:
 *      t          associative array type
 *      keyidx     key type
 *      validx     value type
 */
@trusted
idx_t cv_daarray(type* t, idx_t keyidx, idx_t validx)
{
    /* Put out a struct:
     *    struct dAssocArray {
     *      void* ptr;
     *      typedef key-type __key_t;
     *      typedef val-type __val_t;
     *    }
     */

    type* tv = type_fake(TYnptr);
    tv.Tcount++;
    idx_t pvidx = cv4_typidx(tv);
    type_free(tv);

    __gshared const ubyte[50] fl =
    [
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x00, 0x00, 0x00, 0x00, // void*
        0x00, 0x00,             // offset
        'p','t','r',0,          // "ptr"
        0xf2, 0xf1,             // align to 4-byte including field id
        // offset 18
        0x10, 0x15,             // LF_NESTTYPE_V3
        0x00, 0x00,             // padding
        0x00, 0x00, 0x00, 0x00, // key type
        '_','_','k','e','y','_','t',0,  // "__key_t"
        // offset 34
        0x10, 0x15,             // LF_NESTTYPE_V3
        0x00, 0x00,             // padding
        0x00, 0x00, 0x00, 0x00, // value type
        '_','_','v','a','l','_','t',0,  // "__val_t"
    ];

    debtyp_t* f = debtyp_alloc(fl.sizeof);
    memcpy(f.data.ptr,fl.ptr,fl.sizeof);
    TOLONG(f.data.ptr + 6, pvidx);
    TOLONG(f.data.ptr + 22, keyidx);
    TOLONG(f.data.ptr + 38, validx);
    idx_t fieldlist = cv_debtyp(f);

    const(char)* id = t.Tident ? t.Tident : "dAssocArray";
    int idlen = cast(int)strlen(id);
    if (idlen > CV_MAX_SYMBOL_LENGTH)
        idlen = CV_MAX_SYMBOL_LENGTH;

    debtyp_t* d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d.data.ptr, LF_STRUCTURE_V3);
    TOWORD(d.data.ptr + 2, 1);     // count
    TOWORD(d.data.ptr + 4, 0);     // property
    TOLONG(d.data.ptr + 6, fieldlist);
    TOLONG(d.data.ptr + 10, 0);    // dList
    TOLONG(d.data.ptr + 14, 0);    // vtshape
    TOWORD(d.data.ptr + 18, _tysize[TYnptr]);   // size
    memcpy(d.data.ptr + 20, id, idlen);
    d.data.ptr[20 + idlen] = 0;

    return cv_debtyp(d);
}

/* ======================================================================== */
/* ID-stream type records (reuse the shared cgcv type pool, read-only)      */
/* ======================================================================== */

/* LF_STRING_ID: an interned string returning a type index. */
@trusted
idx_t cv_string_id(const(char)* s)
{
    if (!s) s = "";
    debtyp_t* d = debtyp_alloc(2 + 4 + cv_stringbytes(s));
    TOWORD(d.data.ptr, LF_STRING_ID);
    TOLONG(d.data.ptr + 2, 0);          // substring list id
    cv_namestring(d.data.ptr + 6, s);
    return cv_debtyp(d);
}

/* LF_BUILDINFO: cwd, build tool, source, pdb, args. */
@trusted
idx_t cv_buildinfo()
{
    char[260] cwd = 0;
    if (!getcwd(cwd.ptr, cwd.sizeof))
        cwd[0] = 0;
    idx_t cwdId  = cv_string_id(cwd.ptr);
    idx_t toolId = cv_string_id("dmd");
    idx_t srcId  = cv_string_id("");
    idx_t pdbId  = cv_string_id("");
    idx_t argId  = cv_string_id("");
    debtyp_t* d = debtyp_alloc(2 + 2 + 5 * 4);
    TOWORD(d.data.ptr, LF_BUILDINFO);
    TOWORD(d.data.ptr + 2, 5);          // count
    TOLONG(d.data.ptr + 4, cwdId);
    TOLONG(d.data.ptr + 8, toolId);
    TOLONG(d.data.ptr + 12, srcId);
    TOLONG(d.data.ptr + 16, pdbId);
    TOLONG(d.data.ptr + 20, argId);
    return cv_debtyp(d);
}

/* LF_FUNC_ID: ties a function type to its name for the ID stream. */
@trusted
idx_t cv_func_id(const(char)* id, idx_t functype)
{
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + cv_stringbytes(id));
    TOWORD(d.data.ptr, LF_FUNC_ID);
    TOLONG(d.data.ptr + 2, 0);          // parent scope id
    TOLONG(d.data.ptr + 6, functype);
    cv_namestring(d.data.ptr + 10, id);
    return cv_debtyp(d);
}

/* LF_UDT_SRC_LINE: source location of a user-defined type. */
@trusted
idx_t cv_udt_src_line(idx_t typidx, idx_t srcId, uint line)
{
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + 4);
    TOWORD(d.data.ptr, LF_UDT_SRC_LINE);
    TOLONG(d.data.ptr + 2, typidx);
    TOLONG(d.data.ptr + 6, srcId);
    TOLONG(d.data.ptr + 10, line);
    return cv_debtyp(d);
}
