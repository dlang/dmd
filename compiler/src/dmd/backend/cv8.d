/**
 * CodeView 8 symbolic debug info generation
 *
 * This module generates the `.debug$S` and `.debug$T` sections for Win64,
 * which are the MS-Coff symbolic debug info and type debug info sections.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:    Copyright (C) 2012-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/cv8.d, backend/cv8.d)
 * Documentation:  https://dlang.org/phobos/dmd_backend_cv8.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/cv8.d
 */

module dmd.backend.cv8;

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
import dmd.backend.global : getFileContentsCallback;
import dmd.common.outbuffer;
import dmd.backend.rtlsym;
import dmd.backend.symbol : globsym;
import dmd.backend.ty;
import dmd.backend.type;
import dmd.backend.dvarstats;


nothrow:
@safe:

static if (1)
{


// Determine if this Symbol is stored in a COMDAT
@trusted
private bool symbol_iscomdat4(Symbol* s)
{
    return s.Sclass == SC.comdat ||
        config.flags2 & CFG2comdat && s.Sclass == SC.inline ||
        config.flags4 & CFG4allcomdat && s.Sclass == SC.global;
}


// if symbols get longer than 65500 bytes, the linker reports corrupt debug info or exits with
// 'fatal error LNK1318: Unexpected PDB error; RPC (23) '(0x000006BA)'
enum CV8_MAX_SYMBOL_LENGTH = 0xffd8;

// Modern CodeView symbol records not declared in cv4.d
enum
{
    S_OBJNAME_V3 = 0x1101,      // object file name (same value as S_COMPILAND_V3)
    S_COMPILE3   = 0x113C,      // compile flags, language and compiler version
    S_ENVBLOCK   = 0x113D,      // build environment block
    S_BUILDINFO  = 0x114C,      // reference to an LF_BUILDINFO record
    S_FRAMEPROC  = 0x1012,      // extra frame and procedure information
    S_REGREL32   = 0x1111,      // register-relative address
    S_LTHREAD32  = 0x1112,      // thread-local static data (local)
    S_GTHREAD32  = 0x1113,      // thread-local static data (global)
    S_LPROC32_ID = 0x1146,      // local procedure (type field is an LF_FUNC_ID)
    S_GPROC32_ID = 0x1147,      // global procedure (type field is an LF_FUNC_ID)
}

// Type leaf records used by the ID stream
enum
{
    LF_FUNC_ID   = 0x1601,      // function id: function type + name
    LF_STRING_ID = 0x1605,      // interned string -> type index
    LF_BUILDINFO = 0x1603,      // cwd, tool, source, pdb, args
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

private @trusted
void cv8_writename(OutBuffer* buf, const(char)* name, size_t len)
{
    if(config.flags2 & CFG2gms)
    {
        const(char)* start = name;
        const(char)* cur = strchr(start, '.');
        const(char)* end = start + len;
        while(cur != null)
        {
            if(cur >= end)
            {
                buf.writen(start, end - start);
                return;
            }
            buf.writen(start, cur - start);
            buf.writeByte('@');
            start = cur + 1;
            if(start >= end)
                return;
            cur = strchr(start, '.');
        }
        buf.writen(start, end - start);
    }
    else
        buf.writen(name, len);
}

/************************************************
 * Called at the start of an object file generation.
 * One source file can generate multiple object files; this starts an object file.
 * Input:
 *      filename        source file name
 */
@trusted
void cv8_initfile(const(char)* filename)
{
    //printf("cv8_initfile()\n");

    // Recycle buffers; much faster than delete/renew

    if (!F1_buf)
    {
        __gshared OutBuffer f1buf;
        f1buf.reserve(1024);
        F1_buf = &f1buf;
    }
    F1_buf.reset();

    if (!F1fixup)
    {
        __gshared OutBuffer f1fixupbuf;
        f1fixupbuf.reserve(1024);
        F1fixup = &f1fixupbuf;
    }
    F1fixup.reset();

    if (!F2_buf)
    {
        __gshared OutBuffer f2buf;
        f2buf.reserve(1024);
        F2_buf = &f2buf;
    }
    F2_buf.reset();

    if (!F3_buf)
    {
        __gshared OutBuffer f3buf;
        f3buf.reserve(1024);
        F3_buf = &f3buf;
    }
    F3_buf.reset();
    F3_buf.writeByte(0);       // first "filename"

    if (!F4_buf)
    {
        __gshared OutBuffer f4buf;
        f4buf.reserve(1024);
        F4_buf = &f4buf;
    }
    F4_buf.reset();

    if (!funcdata)
    {
        __gshared OutBuffer funcdatabuf;
        funcdatabuf.reserve(1024);
        funcdata = &funcdatabuf;
    }
    funcdata.reset();

    if (!linepair)
    {
        __gshared OutBuffer linepairbuf;
        linepairbuf.reserve(1024);
        linepair = &linepairbuf;
    }
    linepair.reset();

    memset(&currentfuncdata, 0, currentfuncdata.sizeof);
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;

    cv_init();
}

@trusted
void cv8_termfile(const(char)[] objfilename)
{
    //printf("cv8_termfile()\n");

    /* Write out the debug info sections.
     */

    int seg = MsCoffObj_seg_debugS();

    uint value = 4;
    objmod.bytes(seg,0,(cast(void*)&value)[0 .. 4]);

    /* Start with starting symbols in a separate "F1" section
     */
    auto buf = OutBuffer(1024);

    // S_OBJNAME record
    {
        size_t len = objfilename.length;
        buf.write16(cast(int)(2 + 4 + len + 1));
        buf.write16(S_OBJNAME_V3);
        buf.write32(0);                          // signature
        buf.write(objfilename.ptr, cast(uint)(len + 1));
    }

    // S_COMPILE3 record: honor the configured language and report the real
    // compiler version string (works for dmd/ldc/gdc)
    {
        const uint flags = config.flags2 & CFG2gms ? 0 : 'D'; // iLanguage in low byte
        const(char)[] ver = config._version;
        buf.write16(cast(int)(2 + 4 + 2 + 8 + 8 + ver.length + 1));
        buf.write16(S_COMPILE3);
        buf.write32(flags);
        buf.write16(I64 ? 0xD0 : 0x06);          // machine: AMD64 / x86
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // front end version
        buf.write16(0); buf.write16(0); buf.write16(0); buf.write16(0); // back end version
        buf.write(ver.ptr, cast(uint)ver.length);
        buf.writeByte(0);
    }

    cv8_writesection(seg, DEBUG_S_SYMBOLS, &buf);

    // S_ENVBLOCK record: build environment (cwd), double-null terminated
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
        cv8_writesection(seg, DEBUG_S_SYMBOLS, &ebuf);
    }

    // S_BUILDINFO record referencing an LF_BUILDINFO id record
    {
        auto bbuf = OutBuffer(64);
        idx_t biidx = cv8_buildinfo();
        bbuf.write16(2 + 4);
        bbuf.write16(S_BUILDINFO);
        bbuf.write32(biidx);
        cv8_writesection(seg, DEBUG_S_SYMBOLS, &bbuf);
    }

    // Write out "F2" sections
    uint length = cast(uint)funcdata.length();
    ubyte* p = funcdata.buf;
    for (uint u = 0; u < length; u += FuncData.sizeof)
    {   FuncData* fd = cast(FuncData*)(p + u);

        F2_buf.reset();

        F2_buf.write32(cast(uint)fd.sfunc.Soffset);
        F2_buf.write32(0);
        F2_buf.write32(fd.section_length);
        F2_buf.write(linepair.buf + fd.linepairstart, fd.linepairbytes);

        int f2seg = seg;
        if (symbol_iscomdat4(fd.sfunc))
        {
            f2seg = MsCoffObj_seg_debugS_comdat(fd.sfunc);
            objmod.bytes(f2seg, 0, (cast(void*)&value)[0..4]);
        }

        uint offset = cast(uint)SegData[f2seg].SDoffset + 8;
        cv8_writesection(f2seg, DEBUG_S_LINES, F2_buf);
        objmod.reftoident(f2seg, offset, fd.sfunc, 0, CF.seg | CF.off);

        if (f2seg != seg && fd.f1buf.length())
        {
            // Write out "F1" section
            const uint f1offset = cast(uint)SegData[f2seg].SDoffset;
            cv8_writesection(f2seg, DEBUG_S_SYMBOLS, fd.f1buf);

            // Fixups for "F1" section
            const uint fixupLength = cast(uint)fd.f1fixup.length();
            ubyte* pfixup = fd.f1fixup.buf;
            for (uint v = 0; v < fixupLength; v += F1_Fixups.sizeof)
            {   F1_Fixups* f = cast(F1_Fixups*)(pfixup + v);

                objmod.reftoident(f2seg, f1offset + 8 + f.offset, f.s, f.value, CF.seg | CF.off);
            }
        }
    }

    // Write out "F3" section
    if (F3_buf.length() > 1)
        cv8_writesection(seg, DEBUG_S_STRINGTABLE, F3_buf);

    // Write out "F4" section
    if (F4_buf.length() > 0)
        cv8_writesection(seg, DEBUG_S_FILECHKSMS, F4_buf);

    if (F1_buf.length())
    {
        // Write out "F1" section
        uint f1offset = cast(uint)SegData[seg].SDoffset;
        cv8_writesection(seg, DEBUG_S_SYMBOLS, F1_buf);

        // Fixups for "F1" section
        length = cast(uint)F1fixup.length();
        p = F1fixup.buf;
        for (uint u = 0; u < length; u += F1_Fixups.sizeof)
        {   F1_Fixups* f = cast(F1_Fixups*)(p + u);

            objmod.reftoident(seg, f1offset + 8 + f.offset, f.s, f.value, CF.seg | CF.off);
        }
    }

    // Write out .debug$T section
    cv_term();
}

/************************************************
 * Called at the start of a module.
 * Note that there can be multiple modules in one object file.
 * cv8_initfile() must be called first.
 */
void cv8_initmodule(const(char)* filename, const(char)* modulename)
{
    //printf("cv8_initmodule(filename = %s, modulename = %s)\n", filename, modulename);
}

@trusted
void cv8_termmodule()
{
    //printf("cv8_termmodule()\n");
    assert(config.objfmt == OBJ_MSCOFF);
}

/******************************************
 * Called at the start of a function.
 */
@trusted
void cv8_func_start(Symbol* sfunc)
{
    //printf("cv8_func_start(%s)\n", sfunc.Sident);
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
void cv8_func_term(Symbol* sfunc)
{
    //printf("cv8_func_term(%s)\n", sfunc.Sident);

    assert(currentfuncdata.sfunc == sfunc);
    currentfuncdata.section_length = cast(uint)sfunc.Ssize;

    funcdata.write(&currentfuncdata, currentfuncdata.sizeof);

    // Write function symbol
    assert(tyfunc(sfunc.ty()));
    idx_t typidx;
    func_t* fn = sfunc.Sfunc;
    if(fn.Fclass)
    {
        // generate member function type info
        // it would be nicer if this could be in cv4_typidx, but the function info is not available there
        uint nparam;
        ubyte call = cv4_callconv(sfunc.Stype);
        idx_t paramidx = cv4_arglist(sfunc.Stype,&nparam);
        uint next = cv4_typidx(sfunc.Stype.Tnext);

        type* classtype = cast(type*)fn.Fclass;
        uint classidx = cv4_typidx(classtype);
        type* tp = type_allocn(TYnptr, classtype);
        uint thisidx = cv4_typidx(tp);  // TODO
        debtyp_t* d = debtyp_alloc(2 + 4 + 4 + 4 + 1 + 1 + 2 + 4 + 4);
        TOWORD(d.data.ptr,LF_MFUNCTION_V2);
        TOLONG(d.data.ptr + 2,next);       // return type
        TOLONG(d.data.ptr + 6,classidx);   // class type
        TOLONG(d.data.ptr + 10,thisidx);   // this type
        d.data.ptr[14] = call;
        d.data.ptr[15] = 0;                // reserved
        TOWORD(d.data.ptr + 16,nparam);
        TOLONG(d.data.ptr + 18,paramidx);
        TOLONG(d.data.ptr + 22,0);  // this adjust
        typidx = cv_debtyp(d);
    }
    else
        typidx = cv_typidx(sfunc.Stype);

    const(char)* id = sfunc.prettyIdent ? sfunc.prettyIdent : prettyident(sfunc);

    // ID-stream record tying the function's type to its name (S_GPROC32_ID references this)
    idx_t funcid = cv8_func_id(id, typidx);

    size_t len = strlen(id);
    if(len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;
    /*
     *  2       length (not including these 2 bytes)
     *  2       S_GPROC32_ID / S_LPROC32_ID
     *  4       parent
     *  4       pend
     *  4       pnext
     *  4       size of function
     *  4       size of function prolog
     *  4       offset to function epilog
     *  4       LF_FUNC_ID (ID stream)
     *  6       seg:offset of function start
     *  1       flags
     *  n       0 terminated name string
     */
    auto buf = currentfuncdata.f1buf;
    buf.reserve(cast(uint)(2 + 2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(cast(int)(2 + 4 * 7 + 6 + 1 + len + 1));
    buf.write16n(sfunc.Sclass == SC.static_ ? S_LPROC32_ID : S_GPROC32_ID);
    buf.write32(0);            // parent
    buf.write32(0);            // pend
    buf.write32(0);            // pnext
    buf.write32(cast(uint)currentfuncdata.section_length); // size of function
    buf.write32(cast(uint)cgstate.startoffset);                    // size of prolog
    buf.write32(cast(uint)cgstate.retoffset);                      // offset to epilog
    buf.write32(funcid);           // LF_FUNC_ID (ID stream), resolved to the function type

    F1_Fixups f1f;
    f1f.s = sfunc;
    f1f.offset = cast(uint)buf.length();
    f1f.value = 0;
    currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
    buf.write32(0);
    buf.write16n(0);

    buf.writeByte(0);
    buf.writen(id, len);
    buf.writeByte(0);

    // S_FRAMEPROC: describe this function's stack frame
    {
        // Locals and parameters are addressed relative to the frame pointer
        // (RBP/EBP), matching the S_REGREL32 records emitted for them.
        uint frameflags = CV_FRAME_LOCALBP_RBP | CV_FRAME_PARAMBP_RBP;
        if (cgstate.Alloca.size)
            frameflags |= CV_FRAME_HASALLOCA;
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

    struct cv8
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
            auto buf = currentfuncdata.f1buf;
            buf.write16(2);
            buf.write16(S_ENDARG);
        }
        static void beginBlock(int offset, int length)
        {
            auto buf = currentfuncdata.f1buf;
            uint soffset = cast(uint)buf.length();
            // parent and end to be filled by linker
            block_v3_data block32 = { block_v3_data.sizeof - 2, S_BLOCK_V3, 0, 0, length, offset, 0, [ 0 ] };
            buf.write(&block32, block32.sizeof);
            size_t offOffset = cast(char*)&block32.offset - cast(char*)&block32;

            F1_Fixups f1f;
            f1f.s = currentfuncdata.sfunc;
            f1f.offset = cast(uint)(soffset + offOffset);
            f1f.value = offset;
            currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
        }
        static void endBlock()
        {
            auto buf = currentfuncdata.f1buf;
            buf.write16(2);
            buf.write16(S_END);
        }
    }
    varStats_writeSymbolTable(sfunc, globsym, &cv8_outsym, &cv8.endArgs, &cv8.beginBlock, &cv8.endBlock);

    /* Put out function return record S_RETURN
     * (VC doesn't, so we won't bother, either.)
     */

    // Write function end symbol
    buf.write16(2);
    buf.write16(S_END);

    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
}

/**********************************************
 */

@trusted
void cv8_linnum(Srcpos srcpos, uint offset)
{
    const sfilename = srcpos.Sfilename;
    //printf("cv8_linnum(file = %s, line = %d, offset = x%x)\n", sfilename, cast(int)srcpos.Slinnum, cast(uint)offset);

    if (!sfilename)
        return;

    varStats_recordLineOffset(srcpos, offset);

    __gshared uint lastoffset;
    __gshared uint lastlinnum;

    if (!currentfuncdata.srcfilename ||
        (currentfuncdata.srcfilename != sfilename && strcmp(currentfuncdata.srcfilename, sfilename)))
    {
        currentfuncdata.srcfilename = sfilename;
        uint srcfileoff = cv8_addfile(sfilename);

        // new file segment
        currentfuncdata.linepairsegment = currentfuncdata.linepairstart + currentfuncdata.linepairbytes;

        linepair.write32(srcfileoff);
        linepair.write32(0); // reserve space for length information
        linepair.write32(12);
        currentfuncdata.linepairbytes += 12;
    }
    else if (offset <= lastoffset || srcpos.Slinnum == lastlinnum)
        return; // avoid multiple entries for the same offset

    lastoffset = offset;
    lastlinnum = srcpos.Slinnum;
    linepair.write32(offset);
    linepair.write32(srcpos.Slinnum | CV_LINE_STATEMENT); // mark as statement, not expression

    currentfuncdata.linepairbytes += 8;

    // update segment length
    auto segmentbytes = currentfuncdata.linepairstart + currentfuncdata.linepairbytes - currentfuncdata.linepairsegment;
    auto segmentheader = cast(uint*)(linepair.buf + currentfuncdata.linepairsegment);
    segmentheader[1] = (segmentbytes - 12) / 8;
    segmentheader[2] = segmentbytes;
}

/**********************************************
 * Make `filename` absolute by prefixing the current working directory, so the
 * debugger can find the source without knowing the compilation directory.
 * Params:
 *      filename = source file name (relative or absolute)
 *      buf      = scratch buffer to hold the result
 * Returns:
 *      pointer to the absolute path (stored in `buf`), or `filename` unchanged
 *      if it is already absolute or does not fit in `buf`.
 * Note:
 *      cv8_addfile() and cv8_udt_src_line() must spell the path identically so
 *      the debugger can match an LF_UDT_SRC_LINE record to a source file.
 */
@trusted
private const(char)* cv8_absfilename(const(char)* filename, char[] buf)
{
    const bool abs = (*filename == '\\') || (*filename == '/') ||
                     (*filename && filename[1] == ':');
    if (abs)
        return filename;

    __gshared char[260] cwd = 0;
    __gshared size_t cwdlen = 0;
    if (cwd[0] == 0)
    {
        if (!getcwd(cwd.ptr, cwd.sizeof))
            return filename;
        cwdlen = strlen(cwd.ptr);
        if (cwdlen && cwd[cwdlen - 1] != '\\' && cwd[cwdlen - 1] != '/')
            cwd[cwdlen++] = '\\';
    }

    const flen = strlen(filename);
    if (cwdlen + flen + 1 > buf.length)
        return filename;
    memcpy(buf.ptr, cwd.ptr, cwdlen);
    memcpy(buf.ptr + cwdlen, filename, flen + 1);
    return buf.ptr;
}

/**********************************************
 * Add source file, if it isn't already there.
 * Return offset into F4.
 */

@trusted
uint cv8_addfile(const(char)* filename)
{
    //printf("cv8_addfile('%s')\n", filename);

    /* The algorithms here use a linear search. This is acceptable only
     * because we expect only 1 or 2 files to appear.
     * Unlike C, there won't be lots of .h source files to be accounted for.
     */

    // The file names are stored as absolute paths (see cv8_absfilename) so the
    // debugger can find the source without knowing the compilation directory.
    char[2 * 260] pathbuf = void;
    const(char)* absname = cv8_absfilename(filename, pathbuf[]);
    size_t len = strlen(absname);

    uint length = cast(uint)F3_buf.length();
    ubyte* p = F3_buf.buf;

    uint off = 1;
    while (off + len < length)
    {
        if (memcmp(p + off, absname, len + 1) == 0)
            goto L1;                // already there
        off += strlen(cast(const(char)* )(p + off)) + 1;
    }
    off = length;
    F3_buf.write(absname, cast(uint)(len + 1));     // add it

L1:
    // off is the offset of the filename in F3.
    // Find it in F4.

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

    // Not present; append a checksum computed over the source file's content
    // so debuggers can verify the source matches.
    F4_buf.write32(off);
    ubyte[32] hash = void;
    if (cv8_filehash(filename, hash))
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

    //printf("\tadded %x\n", length);
    return length;
}

private @trusted
void cv8_writesection(int seg, uint type, OutBuffer* buf)
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
    objmod.bytes(seg,off,(cast(void*)&type)[0 .. 4]);
    uint length = cast(uint)buf.length();
    objmod.bytes(seg,off+4,(cast(void*)&length)[0 .. 4]);
    objmod.bytes(seg,off+8,buf.buf[0 .. length]);
    // Align to 4
    uint pad = ((length + 3) & ~3) - length;
    objmod.lidata(seg,off+8+length,pad);
}

@trusted
void cv8_outsym(Symbol* s)
{
    //printf("cv8_outsym(s = '%s')\n", s.Sident);
    //type_print(s.Stype);
    //symbol_print(s);
    if (s.Sflags & SFLnodebug)
        return;

    idx_t typidx = cv_typidx(s.Stype);
    //printf("typidx = %x\n", typidx);
    const(char)* id = s.prettyIdent ? s.prettyIdent : prettyident(s);
    size_t len = strlen(id);

    if(len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;

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
                cv8_outsym(s);
                s.Sfl = FL.reg;
                goto case_register;
            }
            base = cast(uint)(cgstate.Para.size - cgstate.BPoff);    // cancel out add of BPoff
            goto L1;

        case SC.auto_:
            if (s.Sfl == FL.reg)
                goto case_register;
        case_auto:
            base = cast(uint)cgstate.Auto.size;
        L1:
            if (s.Sscope) // local variables moved into the closure cannot be emitted directly
                break;
static if (1)
{
            // Register relative addressing
            buf.reserve(cast(uint)(2 + 2 + 4 + 4 + 2 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 4 + 2 + len + 1));
            buf.write16n(S_REGREL32);
            buf.write32(cast(uint)(s.Soffset + base + cgstate.BPoff));
            buf.write32(typidx);
            buf.write16n(I64 ? CV_AMD64_RBP : CV_REG_EBP);       // relative to RBP/EBP
            cv8_writename(buf, id, len);
            buf.writeByte(0);
}
else
{
            // This is supposed to work, implicit BP relative addressing, but it does not
            buf.reserve(2 + 2 + 4 + 4 + len + 1);
            buf.write16n( 2 + 4 + 4 + len + 1);
            buf.write16n(S_BPREL_V3);
            buf.write32(s.Soffset + base + cgstate.BPoff);
            buf.write32(typidx);
            cv8_writename(buf, id, len);
            buf.writeByte(0);
}
            break;

        case SC.bprel:
            base = -cgstate.BPoff;
            goto L1;

        case SC.fastpar:
            if (s.Sfl != FL.reg)
            {   base = cast(uint)cgstate.Fast.size;
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
            buf.write16n(cv8_regnum(s));
            cv8_writename(buf, id, len);
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
            /*
             *  2       length (not including these 2 bytes)
             *  2       S_GDATA_V2
             *  4       typidx
             *  6       ref to symbol
             *  n       0 terminated name string
             */
            if (s.ty() & mTYthread)            // thread local storage
                sr = (sr == S_GDATA_V3) ? S_GTHREAD32 : S_LTHREAD32;

            buf.reserve(cast(uint)(2 + 2 + 4 + 6 + len + 1));
            buf.write16n(cast(uint)(2 + 4 + 6 + len + 1));
            buf.write16n(sr);
            buf.write32(typidx);

            f1f.s = s;
            f1f.offset = cast(uint)buf.length();
            currentfuncdata.f1fixup.write(&f1f, f1f.sizeof);
            buf.write32(0);
            buf.write16n(0);

            cv8_writename(buf, id, len);
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
void cv8_udt(const(char)* id, idx_t typidx)
{
    //printf("cv8_udt('%s', %x)\n", id, typidx);
    auto buf = currentfuncdata.f1buf;
    size_t len = strlen(id);

    if (len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;
    buf.reserve(cast(uint)(2 + 2 + 4 + len + 1));
    buf.write16n(cast(uint)(2 + 4 + len + 1));
    buf.write16n(S_UDT_V3);
    buf.write32(typidx);
    cv8_writename(buf, id, len);
    buf.writeByte(0);
}

/*********************************************
 * Get Codeview register number for symbol s.
 */
int cv8_regnum(Symbol* s)
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
idx_t cv8_fwdref(Symbol* s)
{
    assert(config.fulltypes == CV8);
//    if (s.Stypidx && !global.params.multiobj)
//      return s.Stypidx;
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

    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

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
idx_t cv8_darray(type* t, idx_t etypidx)
{
    //printf("cv8_darray(etypidx = %x)\n", etypidx);
    /* Put out a struct:
     *    struct dArray {
     *      size_t length;
     *      E* ptr;
     *    }
     */

static if (0)
{
    d = debtyp_alloc(18);
    TOWORD(d.data.ptr, 0x100F);
    TOWORD(d.data.ptr + 2, OEM);
    TOWORD(d.data.ptr + 4, 1);     // 1 = dynamic array
    TOLONG(d.data.ptr + 6, 2);     // count of type indices to follow
    TOLONG(d.data.ptr + 10, 0x23); // index type, T_UQUAD
    TOLONG(d.data.ptr + 14, next); // element type
    return cv_debtyp(d);
}

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

    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

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
        cv8_udt(id, debidx);

    return debidx;
}

/****************************************
 * Return type index for a delegate
 * Input:
 *      t          delegate type
 *      functypidx type index for pointer to function
 */
@trusted
idx_t cv8_ddelegate(type* t, idx_t functypidx)
{
    //printf("cv8_ddelegate(functypidx = %x)\n", functypidx);
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

static if (0)
{
    debtyp_t* d = debtyp_alloc(18);
    TOWORD(d.data.ptr, 0x100F);
    TOWORD(d.data.ptr + 2, OEM);
    TOWORD(d.data.ptr + 4, 3);     // 3 = delegate
    TOLONG(d.data.ptr + 6, 2);     // count of type indices to follow
    TOLONG(d.data.ptr + 10, key);  // void* type
    TOLONG(d.data.ptr + 14, functypidx); // function type
}
else
{
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
    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

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
}
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
idx_t cv8_daarray(type* t, idx_t keyidx, idx_t validx)
{
    //printf("cv8_daarray(keyidx = %x, validx = %x)\n", keyidx, validx);
    /* Put out a struct:
     *    struct dAssocArray {
     *      void* ptr;
     *      typedef key-type __key_t;
     *      typedef val-type __val_t;
     *    }
     */

static if (0)
{
    debtyp_t* d = debtyp_alloc(18);
    TOWORD(d.data.ptr, 0x100F);
    TOWORD(d.data.ptr + 2, OEM);
    TOWORD(d.data.ptr + 4, 2);     // 2 = associative array
    TOLONG(d.data.ptr + 6, 2);     // count of type indices to follow
    TOLONG(d.data.ptr + 10, keyidx);  // key type
    TOLONG(d.data.ptr + 14, validx);  // element type
}
else
{
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
    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

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

}
    return cv_debtyp(d);
}

/* Compute a blake3 hash over the *content* of the named source file, so that
 * debuggers can verify the source matches. The hash goes into the 32-byte
 * SHA256 checksum slot of the file-checksums (F4) subsection.
 * The content is fetched from the front-end FileManager cache (Module.src)
 * rather than re-read from disk, which would add significant I/O to every build.
 * Returns: true on success (hash filled in), false if the content is unavailable.
 */
private @trusted
bool cv8_filehash(const(char)* filename, ref ubyte[32] hash)
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

/* LF_STRING_ID: an interned string returning a type index. */
@trusted
idx_t cv8_string_id(const(char)* s)
{
    if (!s) s = "";
    int idlen = cast(int)strlen(s);
    if (idlen > CV8_MAX_SYMBOL_LENGTH)      // CodeView records have a 16-bit length field
        idlen = CV8_MAX_SYMBOL_LENGTH;
    debtyp_t* d = debtyp_alloc(2 + 4 + idlen + 1);
    TOWORD(d.data.ptr, LF_STRING_ID);
    TOLONG(d.data.ptr + 2, 0);          // substring list id
    cv_namestring(d.data.ptr + 6, s, idlen);
    d.data.ptr[6 + idlen] = 0;
    return cv_debtyp(d);
}

/* LF_BUILDINFO: cwd, build tool, source, pdb, args. */
@trusted
idx_t cv8_buildinfo()
{
    char[260] cwd = 0;
    if (!getcwd(cwd.ptr, cwd.sizeof))
        cwd[0] = 0;

    // build tool: identify the compiler and its version
    char[64] tool = 0;
    strcpy(tool.ptr, "dmd ");
    const(char)[] ver = config._version;
    size_t vn = ver.length;
    if (vn > tool.sizeof - 5)   // leave room for the "dmd " prefix and the null terminator
        vn = tool.sizeof - 5;
    memcpy(tool.ptr + 4, ver.ptr, vn);
    tool[4 + vn] = 0;

    idx_t cwdId  = cv8_string_id(cwd.ptr);
    idx_t toolId = cv8_string_id(tool.ptr);
    idx_t srcId  = cv8_string_id("");
    idx_t pdbId  = cv8_string_id("");
    idx_t argId  = cv8_string_id("");
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

/* LF_FUNC_ID: ties a function type to its name in the ID stream. */
@trusted
idx_t cv8_func_id(const(char)* id, idx_t functype)
{
    int idlen = cast(int)strlen(id);
    if (idlen > CV8_MAX_SYMBOL_LENGTH)      // CodeView records have a 16-bit length field
        idlen = CV8_MAX_SYMBOL_LENGTH;
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + idlen + 1);
    TOWORD(d.data.ptr, LF_FUNC_ID);
    TOLONG(d.data.ptr + 2, 0);          // parent scope id
    TOLONG(d.data.ptr + 6, functype);
    cv_namestring(d.data.ptr + 10, id, idlen);
    d.data.ptr[10 + idlen] = 0;
    return cv_debtyp(d);
}

/* LF_UDT_SRC_LINE: source file and line where a user-defined type is defined. */
@trusted
idx_t cv8_udt_src_line(idx_t typidx, const(char)* filename, uint line)
{
    /* The source file must be spelled the same way as in the module's source
     * file list (see cv8_addfile), i.e. as an absolute path, otherwise the
     * debugger cannot associate this record with a known source file.
     */
    char[2 * 260] pathbuf = void;
    const(char)* srcpath = cv8_absfilename(filename, pathbuf[]);

    idx_t srcId = cv8_string_id(srcpath);
    debtyp_t* d = debtyp_alloc(2 + 4 + 4 + 4);
    TOWORD(d.data.ptr, LF_UDT_SRC_LINE);
    TOLONG(d.data.ptr + 2, typidx);     // the user-defined type
    TOLONG(d.data.ptr + 6, srcId);      // LF_STRING_ID of the source file
    TOLONG(d.data.ptr + 10, line);      // line number of the definition
    return cv_debtyp(d);
}

}
