/**
 * A module defining an abstract library.
 * Implementations for various formats are in separate `libXXX.d` modules.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/lib/package.d, _lib.d)
 * Documentation:  https://dlang.org/phobos/dmd_lib.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/lib/package.d
 */

module dmd.lib;

import core.stdc.stdio;
import core.stdc.string : memset, memcpy;
import core.stdc.time : time_t;

import dmd.common.outbuffer;
import dmd.errorsink;
import dmd.location;
import dmd.root.array : Array;
import dmd.root.port : Port;
import dmd.root.rmem : xarraydup;
import dmd.root.string : toCStringThen;
import dmd.root.stringtable : StringTable;
import dmd.target : Target;


enum AR_OBJECT_NAME_SIZE = 16;
enum AR_FILE_TIME_SIZE   = 12;
enum AR_USER_ID_SIZE     =  6;
enum AR_GROUP_ID_SIZE    =  6;
enum AR_FILE_MODE_SIZE   =  8;
enum AR_FILE_SIZE_SIZE   = 10;
enum AR_TRAILER_SIZE     =  2;

/// Standard ar member header, 60 bytes (GNU/SVR4 format).
package(dmd.lib) struct ArHeader
{
    char[AR_OBJECT_NAME_SIZE] object_name;
    char[AR_FILE_TIME_SIZE]   file_time;
    char[AR_USER_ID_SIZE]     user_id;
    char[AR_GROUP_ID_SIZE]    group_id;
    char[AR_FILE_MODE_SIZE]   file_mode;
    char[AR_FILE_SIZE_SIZE]   file_size;
    char[AR_TRAILER_SIZE]     trailer;
}

static assert(ArHeader.sizeof == 60);

/**
 * Write a GNU/SVR4 ar member header into `h`.
 *
 * Params:
 *  h           = header to fill (60 bytes)
 *  name        = basename of the member, without trailing '/'. Null-terminated.
 *  name_offset = if >= 0, use long-name format "/offset" instead of inline name
 *  file_time   = modification time (seconds since epoch)
 *  user_id     = Unix UID (clamped to 999999)
 *  group_id    = Unix GID (clamped to 999999)
 *  file_mode   = Unix mode bits (octal format in header)
 *  file_size   = payload size in bytes
 */
package(dmd.lib)
void arFillHeader(ref ArHeader h, const(char)* name, int name_offset,
    long file_time, uint user_id, uint group_id, uint file_mode, uint file_size) nothrow
{
    if (user_id > 999_999)
        user_id = 0;
    if (group_id > 999_999)
        group_id = 0;

    char[ArHeader.sizeof + 1] buf = void;
    int len;
    if (name_offset < 0)
    {
        len = snprintf(buf.ptr, buf.sizeof,
            "%-16s%-12lld%-6u%-6u%-8o%-10u`",
            name, cast(long)file_time, user_id, group_id, file_mode, file_size);
        import core.stdc.string : strlen;
        buf[strlen(name)] = '/';
    }
    else
    {
        len = snprintf(buf.ptr, buf.sizeof,
            "/%-15d%-12lld%-6u%-6u%-8o%-10u`",
            name_offset, cast(long)file_time, user_id, group_id, file_mode, file_size);
    }
    assert(len + 1 != 0);
    assert(len == ArHeader.sizeof - 1);
    buf[len] = '\n';
    (cast(char*)&h)[0 .. ArHeader.sizeof] = buf[0 .. ArHeader.sizeof];
}

/// One object member of an ar archive, shared by the ELF and WASM libraries.
package(dmd.lib) struct ArObjModule
{
    ubyte* base;        // module bytes held in memory
    uint length;        // byte length of the module
    uint offset;        // byte offset of this member within the archive
    const(char)[] name; // member basename, null-terminated
    int name_offset;    // -1, or offset into the "//" long-name string table
    time_t file_time;
    uint user_id;
    uint group_id;
    uint file_mode;
    int scan;           // 1 = scan this module for symbols
}

/// One dictionary symbol pointing back at the module that defines it.
package(dmd.lib) struct ArObjSymbol
{
    const(char)[] name;
    ArObjModule* om;
}

/**
 * Record a symbol `name` defined by module `om` into the archive dictionary.
 *
 * Shared by the ELF and WASM libraries, which both build a GNU-ar "/" symbol
 * table from `ArObjSymbol`s. A duplicate is an error unless `pickAny` (COMDAT).
 *
 * Params:
 *  tab        = name → symbol table, deduplicating definitions
 *  objsymbols = dictionary being built; the new symbol is appended here
 *  om         = module defining the symbol
 *  name       = symbol name (copied into the archive's memory)
 *  eSink      = sink for the multiple-definition error
 *  pickAny    = if nonzero, silently keep the first definition of a duplicate
 */
package(dmd.lib)
void arAddSymbol(ref StringTable!(ArObjSymbol*) tab, ref Array!(ArObjSymbol*) objsymbols,
    ArObjModule* om, const(char)[] name, ErrorSink eSink, int pickAny = 0) nothrow
{
    auto s = tab.insert(name.ptr, name.length, null);
    if (!s)
    {
        if (!pickAny)
        {
            s = tab.lookup(name.ptr, name.length);
            assert(s);
            ArObjSymbol* os = s.value;
            eSink.error(Loc.initial, "multiple definition of %s: %s and %s: %s",
                om.name.ptr, name.ptr, os.om.name.ptr, os.name.ptr);
        }
    }
    else
    {
        auto os = new ArObjSymbol();
        os.name = xarraydup(name);
        os.om = om;
        s.value = os;
        objsymbols.push(os);
    }
}

/**
 * Write `objmodules` as a GNU/SVR4 ar archive with a "/" symbol dictionary.
 *
 * The container is identical for ELF and WASM (only the per-module symbol
 * scanner differs), so both libraries populate `objmodules`/`objsymbols` and
 * share this writer. The output is what llvm-ar/wasm-ld produce and consume.
 *
 * Params:
 *  libbuf      = buffer receiving the archive bytes
 *  objmodules  = members to write; `offset`/`name_offset` are assigned here
 *  objsymbols  = dictionary entries already collected from the members
 */
package(dmd.lib)
void writeArLibToBuffer(ref OutBuffer libbuf,
    ref Array!(ArObjModule*) objmodules, ref Array!(ArObjSymbol*) objsymbols) nothrow
{
    uint noffset = 0;
    foreach (om; objmodules)
    {
        const len = om.name.length;
        if (len >= AR_OBJECT_NAME_SIZE)
        {
            om.name_offset = cast(int)noffset;
            noffset += cast(uint)(len + 2);
        }
        else
            om.name_offset = -1;
    }

    uint moffset = 8 + ArHeader.sizeof + 4;
    foreach (os; objsymbols)
        moffset += cast(uint)(4 + os.name.length + 1);
    const hoffset = moffset;
    moffset += moffset & 1;
    if (noffset)
        moffset += ArHeader.sizeof + noffset;
    foreach (om; objmodules)
    {
        moffset += moffset & 1;
        om.offset = moffset;
        moffset += ArHeader.sizeof + om.length;
    }
    libbuf.reserve(moffset);

    libbuf.write("!<arch>\n");
    ArHeader h;
    arFillHeader(h, "", -1, 0, 0, 0, 0, cast(uint)(hoffset - (8 + ArHeader.sizeof)));
    libbuf.write((&h)[0 .. 1]);
    char[4] tmp;
    Port.writelongBE(cast(uint)objsymbols.length, tmp.ptr);
    libbuf.write(tmp[0 .. 4]);
    foreach (os; objsymbols)
    {
        Port.writelongBE(os.om.offset, tmp.ptr);
        libbuf.write(tmp[0 .. 4]);
    }
    foreach (os; objsymbols)
    {
        libbuf.writestring(os.name);
        libbuf.writeByte(0);
    }

    if (noffset)
    {
        if (libbuf.length & 1)
            libbuf.writeByte('\n');
        memset(&h, ' ', ArHeader.sizeof);
        h.object_name[0] = '/';
        h.object_name[1] = '/';
        const n = snprintf(h.file_size.ptr, AR_FILE_SIZE_SIZE, "%u", noffset);
        assert(n < AR_FILE_SIZE_SIZE);
        h.file_size[n] = ' ';
        h.trailer[0] = '`';
        h.trailer[1] = '\n';
        libbuf.write((&h)[0 .. 1]);
        foreach (om; objmodules)
        {
            if (om.name_offset >= 0)
            {
                libbuf.writestring(om.name);
                libbuf.writeByte('/');
                libbuf.writeByte('\n');
            }
        }
    }

    foreach (om; objmodules)
    {
        if (libbuf.length & 1)
            libbuf.writeByte('\n');
        assert(libbuf.length == om.offset);
        om.name.toCStringThen!(s => arFillHeader(h, s.ptr, om.name_offset,
            om.file_time, om.user_id, om.group_id, om.file_mode, om.length));
        libbuf.write((&h)[0 .. 1]);
        libbuf.write(om.base[0 .. om.length]);
    }
    assert(libbuf.length == moffset);

    if (libbuf.length & 1)
        libbuf.writeByte('\n');
}

/**
 * Scan the scannable members of an ar archive for dictionary symbols, then
 * write the archive with its "/" symbol table.
 *
 * Shared by the ELF and WASM libraries, which differ only in the per-format
 * `scan` function that extracts symbols from a member.
 *
 * Params:
 *  scan       = per-format object scanner (scanElfObjModule / scanWasmObjModule)
 *  libbuf     = buffer receiving the archive bytes
 *  objmodules = members; scannable ones (`scan` flag) feed the dictionary
 *  objsymbols = dictionary being built
 *  tab        = name to symbol table backing the dictionary
 *  eSink      = sink for multiple-definition errors
 *  filename   = archive filename for error messages
 */
package(dmd.lib)
void scanAndWriteArLib(alias scan)(ref OutBuffer libbuf,
    ref Array!(ArObjModule*) objmodules, ref Array!(ArObjSymbol*) objsymbols,
    ref StringTable!(ArObjSymbol*) tab, ErrorSink eSink, const(char)[] filename) nothrow
{
    foreach (om; objmodules)
    {
        if (!om.scan)
            continue;
        void addSym(const(char)[] name, int pickAny) nothrow
        {
            arAddSymbol(tab, objsymbols, om, name, eSink, pickAny);
        }
        scan(&addSym, om.base[0 .. om.length], om.name.ptr, filename, eSink);
    }
    writeArLibToBuffer(libbuf, objmodules, objsymbols);
}

import dmd.lib.elf;
import dmd.lib.mach;
import dmd.lib.mscoff;
import dmd.lib.wasm;

private enum LOG = false;

class Library
{
    const(char)[] lib_ext;      // library file extension
    ErrorSink eSink;            // where the error messages go

    static Library factory(Target.ObjectFormat of, const char[] lib_ext, ErrorSink eSink)
    {
        Library lib;
        final switch (of)
        {
            case Target.ObjectFormat.elf:   lib = LibElf_factory();     break;
            case Target.ObjectFormat.macho: lib = LibMach_factory();    break;
            case Target.ObjectFormat.coff:  lib = LibMSCoff_factory();  break;
            case Target.ObjectFormat.wasm:  lib = LibWasm_factory();    break;
        }
        lib.lib_ext = lib_ext;
        lib.eSink = eSink;
        return lib;
    }

    abstract void addObject(const(char)[] module_name, const ubyte[] buf);

    abstract void writeLibToBuffer(ref OutBuffer libbuf);


    /***********************************
     * Set library file name
     * Params:
     *  filename = name of library file
     */
    final void setFilename(const char[] filename)
    {
        static if (LOG)
        {
            printf("LibElf::setFilename(filename = '%.*s')\n",
                   cast(int)filename.length, filename.ptr);
        }

        this.filename = filename;
    }

  public:
    const(char)[] filename; /// the filename of the library
}
