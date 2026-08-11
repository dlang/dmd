/**
 * A library in the ELF format, used on Unix.
 *
 * Copyright:   Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/lib/elf.d, _libelf.d)
 * Documentation:  https://dlang.org/phobos/dmd_libelf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/lib/elf.d
 */

module dmd.lib.elf;

import core.stdc.time;
import core.stdc.string;
import core.stdc.stdlib;
import core.stdc.stdio;

version (Posix)
{
    import core.sys.posix.sys.stat;
    import core.sys.posix.unistd;
    alias Statbuf = stat_t;
}
else version (Windows)
{
    import core.sys.windows.stat;
    alias Statbuf = struct_stat;
}
else
    static assert(0, "unsupported operating system");

import dmd.errors : fatal;
import dmd.lib;
import dmd.location;
import dmd.utils;

import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.common.outbuffer;
import dmd.root.port;
import dmd.root.rmem;
import dmd.root.string;
import dmd.root.stringtable;

import dmd.lib.scanelf;

// Entry point (only public symbol in this module).
package(dmd.lib) extern (C++) Library LibElf_factory()
{
    return new LibElf();
}

private: // for the remainder of this module
nothrow:

enum LOG = false;

alias ElfObjSymbol = ArObjSymbol;
alias ElfObjModule = ArObjModule;

alias ElfObjModules = Array!(ElfObjModule*);
alias ElfObjSymbols = Array!(ElfObjSymbol*);

final class LibElf : Library
{
    ElfObjModules objmodules; // ElfObjModule[]
    ElfObjSymbols objsymbols; // ElfObjSymbol[]
    StringTable!(ElfObjSymbol*) tab;

    extern (D) this()
    {
        tab._init(14_000);
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    override void addObject(const(char)[] module_name, const(ubyte)[] buffer)
    {
        static if (LOG)
        {
            printf("LibElf::addObject(%.*s)\n",
                   cast(int)module_name.length, module_name.ptr);
        }

        void corrupt(int reason)
        {
            eSink.error(Loc.initial, "corrupt ELF object `%.*s` module %.*s %d",
                filename.fTuple.expand, module_name.fTuple.expand, reason);
        }

        int fromfile = 0;
        if (!buffer.length)
        {
            assert(module_name.length);
            // read file and take buffer ownership
            OutBuffer b;
            if (readFile(Loc.initial, module_name, b))
                fatal();
            buffer = cast(ubyte[])b.extractSlice();
            fromfile = 1;
        }
        if (buffer.length < 16)
        {
            static if (LOG)
            {
                printf("buf = %p, buffer.length = %d\n", buffer.ptr, buffer.length);
            }
            return corrupt(__LINE__);
        }
        if (memcmp(buffer.ptr, "!<arch>\n".ptr, 8) == 0)
        {
            /* Library file.
             * Pull each object module out of the library and add it
             * to the object module array.
             */
            static if (LOG)
            {
                printf("archive, buf = %p, buffer.length = %d\n", buffer.ptr, buffer.length);
            }
            uint offset = 8;
            char* symtab = null;
            uint symtab_size = 0;
            char* filenametab = null;
            uint filenametab_size = 0;
            uint mstart = cast(uint)objmodules.length;
            while (offset < buffer.length)
            {
                if (offset + ElfLibHeader.sizeof >= buffer.length)
                    return corrupt(__LINE__);
                ElfLibHeader* header = cast(ElfLibHeader*)(cast(ubyte*)buffer.ptr + offset);
                offset += ElfLibHeader.sizeof;
                char* endptr = null;
                uint size = cast(uint)strtoul(header.file_size.ptr, &endptr, 10);
                if (endptr >= header.file_size.ptr + 10 || *endptr != ' ')
                    return corrupt(__LINE__);
                if (offset + size > buffer.length)
                    return corrupt(__LINE__);
                if (header.object_name[0] == '/' && header.object_name[1] == ' ')
                {
                    /* Instead of rescanning the object modules we pull from a
                     * library, just use the already created symbol table.
                     */
                    if (symtab)
                        return corrupt(__LINE__);
                    symtab = cast(char*)buffer.ptr + offset;
                    symtab_size = size;
                    if (size < 4)
                        return corrupt(__LINE__);
                }
                else if (header.object_name[0] == '/' && header.object_name[1] == '/')
                {
                    /* This is the file name table, save it for later.
                     */
                    if (filenametab)
                        return corrupt(__LINE__);
                    filenametab = cast(char*)buffer.ptr + offset;
                    filenametab_size = size;
                }
                else
                {
                    auto om = new ElfObjModule();
                    om.base = cast(ubyte*)buffer.ptr + offset; /*- sizeof(ElfLibHeader)*/
                    om.length = size;
                    om.offset = 0;
                    if (header.object_name[0] == '/')
                    {
                        /* Pick long name out of file name table
                         */
                        uint foff = cast(uint)strtoul(header.object_name.ptr + 1, &endptr, 10);
                        uint i;
                        for (i = 0; 1; i++)
                        {
                            if (foff + i >= filenametab_size)
                                return corrupt(__LINE__);
                            char c = filenametab[foff + i];
                            if (c == '/')
                                break;
                        }
                        auto n = cast(char*)Mem.check(malloc(i + 1));
                        memcpy(n, filenametab + foff, i);
                        n[i] = 0;
                        om.name = n[0 .. i];
                    }
                    else
                    {
                        /* Pick short name out of header
                         */
                        auto n = cast(char*)Mem.check(malloc(ELF_OBJECT_NAME_SIZE));
                        for (int i = 0; 1; i++)
                        {
                            if (i == ELF_OBJECT_NAME_SIZE)
                                return corrupt(__LINE__);
                            char c = header.object_name[i];
                            if (c == '/')
                            {
                                n[i] = 0;
                                om.name = n[0 .. i];
                                break;
                            }
                            n[i] = c;
                        }
                    }
                    om.name_offset = -1;
                    om.file_time = strtoul(header.file_time.ptr, &endptr, 10);
                    om.user_id = cast(uint)strtoul(header.user_id.ptr, &endptr, 10);
                    om.group_id = cast(uint)strtoul(header.group_id.ptr, &endptr, 10);
                    om.file_mode = cast(uint)strtoul(header.file_mode.ptr, &endptr, 8);
                    om.scan = 0; // don't scan object module for symbols
                    objmodules.push(om);
                }
                offset += (size + 1) & ~1;
            }
            if (offset != buffer.length)
                return corrupt(__LINE__);
            /* Scan the library's symbol table, and insert it into our own.
             * We use this instead of rescanning the object module, because
             * the library's creator may have a different idea of what symbols
             * go into the symbol table than we do.
             * This is also probably faster.
             */
            uint nsymbols = Port.readlongBE(symtab);
            char* s = symtab + 4 + nsymbols * 4;
            if (4 + nsymbols * (4 + 1) > symtab_size)
                return corrupt(__LINE__);
            for (uint i = 0; i < nsymbols; i++)
            {
                const(char)[] name = s.toDString();
                s += name.length + 1;
                if (s - symtab > symtab_size)
                    return corrupt(__LINE__);
                uint moff = Port.readlongBE(symtab + 4 + i * 4);
                //printf("symtab[%d] moff = %x  %x, name = %s\n", i, moff, moff + ElfLibHeader.sizeof, name.ptr);
                for (uint m = mstart; 1; m++)
                {
                    if (m == objmodules.length)
                        return corrupt(__LINE__);  // didn't find it
                    ElfObjModule* om = objmodules[m];
                    //printf("\t%x\n", cast(char *)om.base - cast(char *)buffer.ptr);
                    if (moff + ElfLibHeader.sizeof == cast(char*)om.base - cast(char*)buffer.ptr)
                    {
                        addSymbol(om, name, 1);
                        //if (mstart == m)
                        //    mstart++;
                        break;
                    }
                }
            }
            return;
        }
        /* It's an object module
         */
        auto om = new ElfObjModule();
        om.base = cast(ubyte*)buffer.ptr;
        om.length = cast(uint)buffer.length;
        om.offset = 0;
        // remove path, but not extension
        om.name = toCString(FileName.name(module_name));
        om.name_offset = -1;
        om.scan = 1;
        if (fromfile)
        {
            Statbuf statbuf;
            int i = module_name.toCStringThen!(name => stat(name.ptr, &statbuf));
            if (i == -1) // error, errno is set
                return corrupt(__LINE__);
            om.file_time = statbuf.st_ctime;
            om.user_id = statbuf.st_uid;
            om.group_id = statbuf.st_gid;
            om.file_mode = statbuf.st_mode;
        }
        else
        {
            /* Mock things up for the object module file that never was
             * actually written out.
             */
            version (Posix)
            {
                __gshared uid_t uid;
                __gshared gid_t gid;
                __gshared int _init;
                if (!_init)
                {
                    _init = 1;
                    uid = getuid();
                    gid = getgid();
                }
                om.user_id = uid;
                om.group_id = gid;
            }
            else version (Windows)
            {
                om.user_id = 0;  // meaningless on Windows
                om.group_id = 0; // meaningless on Windows
            }
            else
                static assert(0, "unsupported operating system");

            time_t file_time = 0;
            time(&file_time);
            om.file_time = cast(long)file_time;
            om.file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644
        }
        objmodules.push(om);
    }

    /*****************************************************************************/

    void addSymbol(ElfObjModule* om, const(char)[] name, int pickAny = 0) nothrow
    {
        static if (LOG)
        {
            printf("LibElf::addSymbol(%s, %s, %d)\n", om.name.ptr, name.ptr, pickAny);
        }
        arAddSymbol(tab, objsymbols, om, name, eSink, pickAny);
    }

private:
    /**********************************************
     * Create and write library to libbuf.
     * The library consists of:
     *      !<arch>\n
     *      header
     *      dictionary
     *      object modules...
     */
    protected override void writeLibToBuffer(ref OutBuffer libbuf)
    {
        static if (LOG)
        {
            printf("LibElf::WriteLibToBuffer()\n");
        }
        scanAndWriteArLib!scanElfObjModule(libbuf, objmodules, objsymbols, tab, eSink, filename);
    }
}

// ar header format and object-module struct are defined in dmd.lib (package.d)
// and shared with wasm.d.
alias ELF_OBJECT_NAME_SIZE = AR_OBJECT_NAME_SIZE;
alias ElfLibHeader         = ArHeader;
