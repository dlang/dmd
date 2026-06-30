/**
 * Modern CodeView / PDB symbolic debug info generation.
 *
 * This module is a self-contained emitter for the `.debug$S` and `.debug$T`
 * sections for Win64 MS-COFF objects. It is an alternative to cv8.d intended to
 * eventually retire cv4.d/cv8.d. It targets the record set documented by LLVM
 * (https://llvm.org/docs/PDB/) and Microsoft
 * (https://github.com/microsoft/microsoft-pdb) and is enabled by the
 * `-preview=newpdb` compiler flag.
 *
 * It does not modify the existing CV4/CV8 paths; the type-record pool helpers in
 * cgcv.d are reused read-only.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:    Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/pdb.d, backend/pdb.d)
 */

module dmd.backend.pdb;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
extern (C) nothrow char* getcwd(char*, size_t);

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.cv4;
import dmd.backend.mem;
import dmd.backend.el;
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
/* CodeView constants not present in cv4.d, kept local to avoid touching     */
/* the legacy CV4/CV8 implementations.                                       */
/* ======================================================================== */

// Symbol records (DEBUG_S_SYMBOLS subsection content)
enum
{
    S_END_PDB         = 0x0006,
    S_OBJNAME_V3      = 0x1101,
    S_COMPILE3        = 0x113C,
    S_ENVBLOCK        = 0x113D,
    S_BUILDINFO       = 0x114C,
    S_FRAMEPROC       = 0x1012,
    S_GPROC32_ID      = 0x1147,
    S_LPROC32_ID      = 0x1146,
    S_PROC_ID_END     = 0x114F,
    S_GPROC32         = 0x1110,
    S_LPROC32         = 0x110F,
    S_REGREL32        = 0x1111,
    S_BPREL32_V3      = 0x110B,
    S_REGISTER_V3     = 0x1106,
    S_LDATA32         = 0x110C,
    S_GDATA32         = 0x110D,
    S_LTHREAD32       = 0x1112,
    S_GTHREAD32       = 0x1113,
    S_PUB32           = 0x110E,
    S_CONSTANT_V3     = 0x1107,
    S_UDT_V3_         = 0x1108,
    S_LABEL32_V3      = 0x1105,
    S_THUNK32         = 0x1102,
    S_LOCAL           = 0x113E,
    S_BLOCK32         = 0x1103,
    S_RETURN          = 0x000D,
}

// Type leaf records used by the ID stream / source lines
enum
{
    LF_FUNC_ID        = 0x1601,
    LF_STRING_ID      = 0x1605,
    LF_BUILDINFO      = 0x1603,
    LF_UDT_SRC_LINE   = 0x1606,
    LF_SUBSTR_LIST    = 0x1604,
    LF_ALIAS          = 0x150A,
}

// .debug$S subsection kinds
enum
{
    DEBUG_S_SYMBOLS         = 0xF1,
    DEBUG_S_LINES           = 0xF2,
    DEBUG_S_STRINGTABLE     = 0xF3,
    DEBUG_S_FILECHKSMS      = 0xF4,
}

// File checksum kinds
enum
{
    CHKSUM_NONE   = 0,
    CHKSUM_MD5    = 1,
    CHKSUM_SHA1   = 2,
    CHKSUM_SHA256 = 3,
}

// keep symbol records well under linker limits
enum PDB_MAX_SYMBOL_LENGTH = 0xffd8;

// CV_PUBSYMFLAGS
enum PUB_FUNCTION = 0x00000002;

/* ======================================================================== */
/* State                                                                    */
/* ======================================================================== */

private __gshared OutBuffer* F1_buf;     // symbols
private __gshared OutBuffer* F2_buf;     // line numbers
private __gshared OutBuffer* F3_buf;     // string table of source file names
private __gshared OutBuffer* F4_buf;     // file checksums

struct F1_Fixups
{
    Symbol* s;
    uint offset;
    uint value;
}

private __gshared OutBuffer* F1fixup;

struct FuncData
{
    Symbol* sfunc;
    uint section_length;
    const(char)* srcfilename;
    uint srcfileoff;
    uint linepairstart;
    uint linepairbytes;
    uint linepairsegment;
    OutBuffer* f1buf;
    OutBuffer* f1fixup;
}

__gshared FuncData currentfuncdata;

private __gshared OutBuffer* funcdata;    // array of FuncData
private __gshared OutBuffer* linepair;    // offset/line pairs

// Determine if this Symbol lives in a COMDAT
@trusted
private bool symbol_iscomdat_pdb(Symbol* s)
{
    return s.Sclass == SC.comdat ||
        config.flags2 & CFG2comdat && s.Sclass == SC.inline ||
        config.flags4 & CFG4allcomdat && s.Sclass == SC.global;
}

/* ======================================================================== */
/* Name encoding                                                            */
/* ======================================================================== */

private @trusted
void pdb_writename(OutBuffer* buf, const(char)* name, size_t len)
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

@trusted
void pdb_initfile(const(char)* filename)
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

void pdb_initmodule(const(char)* filename, const(char)* modulename)
{
}

@trusted
void pdb_termmodule()
{
    assert(config.objfmt == OBJ_MSCOFF);
}

@trusted
void pdb_termfile(const(char)[] objfilename)
{
    int seg = MsCoffObj_seg_debugS();

    uint value = 4;            // CV signature C13
    objmod.bytes(seg, 0, (cast(void*)&value)[0 .. 4]);

    auto buf = OutBuffer(1024);

    // S_OBJNAME
    {
        size_t len = objfilename.length;
        buf.write16(cast(int)(2 + 4 + len + 1));
        buf.write16(S_OBJNAME_V3);
        buf.write32(0);                          // signature
        buf.write(objfilename.ptr, cast(uint)(len + 1));
    }

    // S_COMPILE3
    {
        const ver = "DMD ";
        size_t vlen = VERSION.length;
        buf.write16(cast(int)(2 + 4 + 2 + 2 + 2 + 2 + 2 + 2 + 2 + 2 + 2 + ver.length + vlen + 1));
        buf.write16(S_COMPILE3);
        buf.write32(0x00010044);                 // flags: language=D(0x44)<<8? language byte=0x44, rest 0
        buf.write16(I64 ? 0xD0 : 0x07);          // machine: AMD64 / x86
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // FE ver
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // BE ver
        buf.write(ver.ptr, cast(uint)ver.length);
        buf.write(VERSION.ptr, cast(uint)vlen);
        buf.writeByte(0);
    }

    pdb_writesection(seg, DEBUG_S_SYMBOLS, &buf);

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
        pdb_writesection(seg, DEBUG_S_SYMBOLS, &ebuf);
    }

    // S_BUILDINFO referencing an LF_BUILDINFO id record
    {
        auto bbuf = OutBuffer(64);
        idx_t biidx = pdb_buildinfo();
        bbuf.write16(2 + 4);
        bbuf.write16(S_BUILDINFO);
        bbuf.write32(biidx);
        pdb_writesection(seg, DEBUG_S_SYMBOLS, &bbuf);
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
        if (symbol_iscomdat_pdb(fd.sfunc))
        {
            f2seg = MsCoffObj_seg_debugS_comdat(fd.sfunc);
            objmod.bytes(f2seg, 0, (cast(void*)&value)[0 .. 4]);
        }

        uint offset = cast(uint)SegData[f2seg].SDoffset + 8;
        pdb_writesection(f2seg, DEBUG_S_LINES, F2_buf);
        objmod.reftoident(f2seg, offset, fd.sfunc, 0, CF.seg | CF.off);

        if (f2seg != seg && fd.f1buf.length())
        {
            const uint f1offset = cast(uint)SegData[f2seg].SDoffset;
            pdb_writesection(f2seg, DEBUG_S_SYMBOLS, fd.f1buf);

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
        pdb_writesection(seg, DEBUG_S_STRINGTABLE, F3_buf);

    if (F4_buf.length() > 0)
        pdb_writesection(seg, DEBUG_S_FILECHKSMS, F4_buf);

    if (F1_buf.length())
    {
        uint f1offset = cast(uint)SegData[seg].SDoffset;
        pdb_writesection(seg, DEBUG_S_SYMBOLS, F1_buf);

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

@trusted
void pdb_func_start(Symbol* sfunc)
{
    currentfuncdata.sfunc = sfunc;
    currentfuncdata.section_length = 0;
    currentfuncdata.srcfilename = null;
    currentfuncdata.linepairstart += currentfuncdata.linepairbytes;
    currentfuncdata.linepairbytes = 0;
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
    if (symbol_iscomdat_pdb(sfunc))
    {
        currentfuncdata.f1buf = cast(OutBuffer*)mem_calloc(OutBuffer.sizeof);
        currentfuncdata.f1buf.reserve(128);
        currentfuncdata.f1fixup = cast(OutBuffer*)mem_calloc(OutBuffer.sizeof);
        currentfuncdata.f1fixup.reserve(128);
    }
    varStats_startFunction();
}

@trusted
void pdb_func_term(Symbol* sfunc)
{
    assert(currentfuncdata.sfunc == sfunc);
    currentfuncdata.section_length = cast(uint)sfunc.Ssize;
    funcdata.write(&currentfuncdata, currentfuncdata.sizeof);

    assert(tyfunc(sfunc.ty()));
    idx_t typidx = cv_typidx(sfunc.Stype);

    const(char)* id = sfunc.prettyIdent ? sfunc.prettyIdent : prettyident(sfunc);
    size_t len = strlen(id);
    if (len > PDB_MAX_SYMBOL_LENGTH)
        len = PDB_MAX_SYMBOL_LENGTH;

    auto buf = currentfuncdata.f1buf;
    buf.reserve(cast(uint)(2 + 2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(cast(int)(2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(sfunc.Sclass == SC.static_ ? S_LPROC32 : S_GPROC32);
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

    // S_FRAMEPROC
    {
        buf.write16(2 + 4 + 4 + 4 + 4 + 4 + 4);
        buf.write16(S_FRAMEPROC);
        buf.write32(cast(uint)cgstate.Auto.size);   // frame bytes
        buf.write32(0);                             // pad
        buf.write32(0);                             // pad offset
        buf.write32(0);                             // SE callee saved
        buf.write32(0);                             // exception handler off
        // flags: encode RBP (2) as local & param base pointer for x64
        buf.write32(I64 ? (2 << 14) | (2 << 16) : 0);
    }

    struct pdbblk
    {
    nothrow:
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
            b.write16(0x000A);     // S_ENDARG
        }
        static void beginBlock(int offset, int length)
        {
            auto b = currentfuncdata.f1buf;
            uint soffset = cast(uint)b.length();
            block_v3_data block32 = { block_v3_data.sizeof - 2, S_BLOCK32, 0, 0, length, offset, 0, [ 0 ] };
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
            b.write16(S_END_PDB);
        }
    }
    varStats_writeSymbolTable(sfunc, globsym, &pdb_outsym, &pdbblk.endArgs, &pdbblk.beginBlock, &pdbblk.endBlock);

    // S_RETURN to mark the epilogue for "step out"
    buf.write16(5);
    buf.write16(S_RETURN);
    buf.write16(0);            // CV_GENERIC_FLAG
    buf.writeByte(0);          // CV_GENERIC_STYLE: void

    buf.write16(2);
    buf.write16(S_END_PDB);

    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
}

/* ======================================================================== */
/* Line numbers                                                             */
/* ======================================================================== */

@trusted
void pdb_linnum(Srcpos srcpos, uint offset)
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
        uint srcfileoff = pdb_addfile(sfilename);
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
    linepair.write32(srcpos.Slinnum | 0x80000000);
    currentfuncdata.linepairbytes += 8;

    auto segmentbytes = currentfuncdata.linepairstart + currentfuncdata.linepairbytes - currentfuncdata.linepairsegment;
    auto segmentheader = cast(uint*)(linepair.buf + currentfuncdata.linepairsegment);
    segmentheader[1] = (segmentbytes - 12) / 8;
    segmentheader[2] = segmentbytes;
}

/* ======================================================================== */
/* Source files (F3 names + F4 checksums via blake3)                        */
/* ======================================================================== */

@trusted
uint pdb_addfile(const(char)* filename)
{
    uint length = cast(uint)F3_buf.length();
    ubyte* p = F3_buf.buf;
    size_t len = strlen(filename);

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
    while (u + 8 <= length)
    {
        if (off == *cast(uint*)(p + u))
            return u;
        u += 4;
        ubyte cklen = *(p + u);
        u += 4;
        u += cklen;
        u = (u + 3) & ~3;
    }

    // not present; append a full SHA256-slot checksum from blake3 (32 bytes)
    F4_buf.write32(off);
    import dmd.common.blake3;
    const hash = blake3((cast(ubyte*)filename)[0 .. len]);
    F4_buf.writeByte(32);          // checksum size
    F4_buf.writeByte(CHKSUM_SHA256);
    F4_buf.write16(0);
    F4_buf.write(hash.ptr, 32);
    while (F4_buf.length() & 3)
        F4_buf.writeByte(0);
    return length;
}

private @trusted
void pdb_writesection(int seg, uint type, OutBuffer* buf)
{
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
void pdb_outsym(Symbol* s)
{
    if (s.Sflags & SFLnodebug)
        return;

    idx_t typidx = cv_typidx(s.Stype);
    const(char)* id = s.prettyIdent ? s.prettyIdent : prettyident(s);
    size_t len = strlen(id);
    if (len > PDB_MAX_SYMBOL_LENGTH)
        len = PDB_MAX_SYMBOL_LENGTH;

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
                pdb_outsym(s);
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
            buf.write16n(S_REGREL32);
            buf.write32(cast(uint)(s.Soffset + base + cgstate.BPoff));
            buf.write32(typidx);
            buf.write16n(I64 ? 334 : 22);
            pdb_writename(buf, id, len);
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
            buf.write16n(pdb_regnum(s));
            pdb_writename(buf, id, len);
            buf.writeByte(0);
            break;

        case SC.extern_:
            break;

        case SC.typedef_:
            // LF_ALIAS: a named typedef of an existing type
            pdb_alias(id, typidx);
            break;

        case SC.const_:
            // enum members and manifest constants
            {
                if (!s.Svalue)
                    break;
                uint val = cast(uint)el_tolong(s.Svalue);
                buf.reserve(cast(uint)(2 + 2 + 4 + 2 + 4 + len + 1));
                buf.write16n(cast(uint)(2 + 4 + 2 + 4 + len + 1));
                buf.write16n(S_CONSTANT_V3);
                buf.write32(typidx);
                buf.write16n(0x8004);   // LF_ULONG numeric leaf
                buf.write32(val);
                pdb_writename(buf, id, len);
                buf.writeByte(0);
            }
            break;

        case SC.static_:
        case SC.locstat:
            sr = S_LDATA32;
            goto Ldata;

        case SC.global:
        case SC.comdat:
        case SC.comdef:
            sr = S_GDATA32;
        Ldata:
            if (s.ty() & mTYthread)            // full TLS support
                sr = (sr == S_GDATA32) ? S_GTHREAD32 : S_LTHREAD32;

            buf.reserve(cast(uint)(2 + 2 + 4 + 6 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 6 + len + 1));
            buf.write16n(sr);
            buf.write32(typidx);
            f1f.s = s;
            f1f.offset = cast(uint)buf.length();
            currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
            buf.write32(0);
            buf.write16n(0);
            pdb_writename(buf, id, len);
            buf.writeByte(0);
            break;

        default:
            break;
    }
}

/* Put out a name for a user defined type. */
@trusted
void pdb_udt(const(char)* id, idx_t typidx)
{
    auto buf = currentfuncdata.f1buf;
    size_t len = strlen(id);
    if (len > PDB_MAX_SYMBOL_LENGTH)
        len = PDB_MAX_SYMBOL_LENGTH;
    buf.reserve(cast(uint)(2 + 2 + 4 + len + 1));
    buf.write16n(cast(uint)(2 + 4 + len + 1));
    buf.write16n(S_UDT_V3_);
    buf.write32(typidx);
    pdb_writename(buf, id, len);
    buf.writeByte(0);
}

/* ======================================================================== */
/* ID-stream type records (reuse the shared cgcv type pool, read-only)      */
/* ======================================================================== */

/* LF_STRING_ID: an interned string returning a type index. */
@trusted
idx_t pdb_string_id(const(char)* s)
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
idx_t pdb_buildinfo()
{
    char[260] cwd = 0;
    if (!getcwd(cwd.ptr, cwd.sizeof))
        cwd[0] = 0;
    idx_t cwdId  = pdb_string_id(cwd.ptr);
    idx_t toolId = pdb_string_id("dmd");
    idx_t srcId  = pdb_string_id("");
    idx_t pdbId  = pdb_string_id("");
    idx_t argId  = pdb_string_id("");
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
idx_t pdb_func_id(const(char)* id, idx_t functype)
{
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + cv_stringbytes(id));
    TOWORD(d.data.ptr, LF_FUNC_ID);
    TOLONG(d.data.ptr + 2, 0);          // parent scope id
    TOLONG(d.data.ptr + 6, functype);
    cv_namestring(d.data.ptr + 10, id);
    return cv_debtyp(d);
}

/* LF_ALIAS: a named typedef of an underlying type. */
@trusted
idx_t pdb_alias(const(char)* id, idx_t utype)
{
    debtyp_t* d = debtyp_alloc(2 + 4 + cv_stringbytes(id));
    TOWORD(d.data.ptr, LF_ALIAS);
    TOLONG(d.data.ptr + 2, utype);
    cv_namestring(d.data.ptr + 6, id);
    return cv_debtyp(d);
}

/* LF_UDT_SRC_LINE: source location of a user-defined type. */
@trusted
idx_t pdb_udt_src_line(idx_t typidx, idx_t srcId, uint line)
{
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + 4);
    TOWORD(d.data.ptr, LF_UDT_SRC_LINE);
    TOLONG(d.data.ptr + 2, typidx);
    TOLONG(d.data.ptr + 6, srcId);
    TOLONG(d.data.ptr + 10, line);
    return cv_debtyp(d);
}

/* Codeview register number for symbol s. */
int pdb_regnum(Symbol* s)
{
    int reg = s.Sreglsw;
    assert(s.Sfl == FL.reg);
    if ((1 << reg) & XMMREGS)
        return reg - XMM0 + 154;
    switch (type_size(s.Stype))
    {
        case 1:
            if (reg < 4)        reg += 1;
            else if (reg < 8)   reg += 324 - 4;
            else                reg += 344 - 4;
            break;
        case 2:
            if (reg < 8)        reg += 9;
            else                reg += 352 - 8;
            break;
        case 4:
            if (reg < 8)        reg += 17;
            else                reg += 360 - 8;
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
