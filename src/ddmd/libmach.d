/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _libmach.d)
 */

module ddmd.libmach;

import core.stdc.time;
import core.stdc.string;
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.config;

import core.sys.posix.sys.stat;
import core.sys.posix.unistd;

import ddmd.globals;
import ddmd.lib;
import ddmd.utils;

import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.port;
import ddmd.root.rmem;
import ddmd.root.stringtable;

import ddmd.scanmach;

enum LOG = false;

struct MachObjSymbol
{
    const(char)[] name;         // still has a terminating 0
    MachObjModule* om;
}

alias MachObjModules = Array!(MachObjModule*);
alias MachObjSymbols = Array!(MachObjSymbol*);

final class LibMach : Library
{
    MachObjModules objmodules; // MachObjModule[]
    MachObjSymbols objsymbols; // MachObjSymbol[]
    StringTable tab;

    extern (D) this()
    {
        tab._init(14000);
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    override void addObject(const(char)* module_name, const ubyte[] buffer)
    {
        if (!module_name)
            module_name = "";
        static if (LOG)
        {
            printf("LibMach::addObject(%s)\n", module_name);
        }

        void corrupt(int reason)
        {
            error("corrupt Mach object module %s %d", module_name, reason);
        }

        int fromfile = 0;
        auto buf = buffer.ptr;
        auto buflen = buffer.length;
        if (!buf)
        {
            assert(module_name[0]);
            File* file = File.create(cast(char*)module_name);
            readFile(Loc(), file);
            buf = file.buffer;
            buflen = file.len;
            file._ref = 1;
            fromfile = 1;
        }
        int reason = 0;
        if (buflen < 16)
        {
            static if (LOG)
            {
                printf("buf = %p, buflen = %d\n", buf, buflen);
            }
            return corrupt(__LINE__);
        }
        if (memcmp(buf, cast(char*)"!<arch>\n", 8) == 0)
        {
            /* Library file.
             * Pull each object module out of the library and add it
             * to the object module array.
             */
            static if (LOG)
            {
                printf("archive, buf = %p, buflen = %d\n", buf, buflen);
            }
            uint offset = 8;
            char* symtab = null;
            uint symtab_size = 0;
            uint mstart = cast(uint)objmodules.dim;
            while (offset < buflen)
            {
                if (offset + MachLibHeader.sizeof >= buflen)
                    return corrupt(__LINE__);
                MachLibHeader* header = cast(MachLibHeader*)(cast(ubyte*)buf + offset);
                offset += MachLibHeader.sizeof;
                char* endptr = null;
                uint size = cast(uint)strtoul(header.file_size.ptr, &endptr, 10);
                if (endptr >= header.file_size.ptr + 10 || *endptr != ' ')
                    return corrupt(__LINE__);
                if (offset + size > buflen)
                    return corrupt(__LINE__);
                if (memcmp(header.object_name.ptr, cast(char*)"__.SYMDEF       ", 16) == 0 ||
                    memcmp(header.object_name.ptr, cast(char*)"__.SYMDEF SORTED", 16) == 0)
                {
                    /* Instead of rescanning the object modules we pull from a
                     * library, just use the already created symbol table.
                     */
                    if (symtab)
                        return corrupt(__LINE__);
                    symtab = cast(char*)buf + offset;
                    symtab_size = size;
                    if (size < 4)
                        return corrupt(__LINE__);
                }
                else
                {
                    auto om = new MachObjModule();
                    om.base = cast(ubyte*)buf + offset - MachLibHeader.sizeof;
                    om.length = cast(uint)(size + MachLibHeader.sizeof);
                    om.offset = 0;
                    const n = cast(const(char)*)(om.base + MachLibHeader.sizeof);
                    om.name = n[0 .. strlen(n)];
                    om.file_time = cast(uint)strtoul(header.file_time.ptr, &endptr, 10);
                    om.user_id = cast(uint)strtoul(header.user_id.ptr, &endptr, 10);
                    om.group_id = cast(uint)strtoul(header.group_id.ptr, &endptr, 10);
                    om.file_mode = cast(uint)strtoul(header.file_mode.ptr, &endptr, 8);
                    om.scan = 0; // don't scan object module for symbols
                    objmodules.push(om);
                }
                offset += (size + 1) & ~1;
            }
            if (offset != buflen)
                return corrupt(__LINE__);
            /* Scan the library's symbol table, and insert it into our own.
             * We use this instead of rescanning the object module, because
             * the library's creator may have a different idea of what symbols
             * go into the symbol table than we do.
             * This is also probably faster.
             */
            uint nsymbols = Port.readlongLE(symtab) / 8;
            char* s = symtab + 4 + nsymbols * 8 + 4;
            if (4 + nsymbols * 8 + 4 > symtab_size)
                return corrupt(__LINE__);
            for (uint i = 0; i < nsymbols; i++)
            {
                uint soff = Port.readlongLE(symtab + 4 + i * 8);
                const(char)* name = s + soff;
                size_t namelen = strlen(name);
                //printf("soff = x%x name = %s\n", soff, name);
                if (s + namelen + 1 - symtab > symtab_size)
                    return corrupt(__LINE__);
                uint moff = Port.readlongLE(symtab + 4 + i * 8 + 4);
                //printf("symtab[%d] moff = x%x  x%x, name = %s\n", i, moff, moff + sizeof(Header), name);
                for (uint m = mstart; 1; m++)
                {
                    if (m == objmodules.dim)
                        return corrupt(__LINE__);       // didn't find it
                    MachObjModule* om = objmodules[m];
                    //printf("\tom offset = x%x\n", (char *)om.base - (char *)buf);
                    if (moff == cast(char*)om.base - cast(char*)buf)
                    {
                        addSymbol(om, name[0 .. namelen], 1);
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
        auto om = new MachObjModule();
        om.base = cast(ubyte*)buf;
        om.length = cast(uint)buflen;
        om.offset = 0;
        const n = cast(const(char)*)FileName.name(module_name); // remove path, but not extension
        om.name = n[0 .. strlen(n)];
        om.scan = 1;
        if (fromfile)
        {
            stat_t statbuf;
            int i = stat(module_name, &statbuf);
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
            static __gshared uid_t uid;
            static __gshared gid_t gid;
            static __gshared int _init;
            if (!_init)
            {
                _init = 1;
                uid = getuid();
                gid = getgid();
            }
            time(&om.file_time);
            om.user_id = uid;
            om.group_id = gid;
            om.file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644
        }
        objmodules.push(om);
    }

    /*****************************************************************************/

    void addSymbol(MachObjModule* om, const(char)[] name, int pickAny = 0)
    {
        static if (LOG)
        {
            printf("LibMach::addSymbol(%s, %s, %d)\n", om.name.ptr, name.ptr, pickAny);
        }
        version (none)
        {
            // let linker sort out duplicates
            StringValue* s = tab.insert(name.ptr, name.length, null);
            if (!s)
            {
                // already in table
                if (!pickAny)
                {
                    s = tab.lookup(name.ptr, name.length);
                    assert(s);
                    MachObjSymbol* os = cast(MachObjSymbol*)s.ptrvalue;
                    error("multiple definition of %s: %s and %s: %s", om.name.ptr, name.ptr, os.om.name.ptr, os.name.ptr);
                }
            }
            else
            {
                auto os = new MachObjSymbol();
                os.name = xarraydup(name);
                os.om = om;
                s.ptrvalue = cast(void*)os;
                objsymbols.push(os);
            }
        }
        else
        {
            auto os = new MachObjSymbol();
            os.name = xarraydup(name);
            os.om = om;
            objsymbols.push(os);
        }
    }

private:
    /************************************
     * Scan single object module for dictionary symbols.
     * Send those symbols to LibMach::addSymbol().
     */
    void scanObjModule(MachObjModule* om)
    {
        static if (LOG)
        {
            printf("LibMach::scanObjModule(%s)\n", om.name.ptr);
        }

        extern (D) void addSymbol(const(char)[] name, int pickAny)
        {
            this.addSymbol(om, name, pickAny);
        }

        scanMachObjModule(&addSymbol, om.base[0 .. om.length], om.name.ptr, loc);
    }

    /*****************************************************************************/
    /*****************************************************************************/
    /**********************************************
     * Create and write library to libbuf.
     * The library consists of:
     *      !<arch>\n
     *      header
     *      dictionary
     *      object modules...
     */
    protected override void WriteLibToBuffer(OutBuffer* libbuf)
    {
        static if (LOG)
        {
            printf("LibMach::WriteLibToBuffer()\n");
        }
        static __gshared char* pad = [0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A];
        /************* Scan Object Modules for Symbols ******************/
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            MachObjModule* om = objmodules[i];
            if (om.scan)
            {
                scanObjModule(om);
            }
        }
        /************* Determine module offsets ******************/
        uint moffset = 8 + MachLibHeader.sizeof + 4 + 4;
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            MachObjSymbol* os = objsymbols[i];
            moffset += 8 + os.name.length + 1;
        }
        moffset = (moffset + 3) & ~3;
        //if (moffset & 4)
        //    moffset += 4;
        uint hoffset = moffset;
        static if (LOG)
        {
            printf("\tmoffset = x%x\n", moffset);
        }
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            MachObjModule* om = objmodules[i];
            moffset += moffset & 1;
            om.offset = moffset;
            if (om.scan)
            {
                const slen = om.name.length;
                int nzeros = 8 - ((slen + 4) & 7);
                if (nzeros < 4)
                    nzeros += 8; // emulate mysterious behavior of ar
                int filesize = om.length;
                filesize = (filesize + 7) & ~7;
                moffset += MachLibHeader.sizeof + slen + nzeros + filesize;
            }
            else
            {
                moffset += om.length;
            }
        }
        libbuf.reserve(moffset);
        /************* Write the library ******************/
        libbuf.write(cast(const(char)*)"!<arch>\n", 8);
        MachObjModule om;
        om.base = null;
        om.length = cast(uint)(hoffset - (8 + MachLibHeader.sizeof));
        om.offset = 8;
        om.name = "";
        .time(&om.file_time);
        om.user_id = getuid();
        om.group_id = getgid();
        om.file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644
        MachLibHeader h;
        MachOmToHeader(&h, &om);
        memcpy(h.object_name.ptr, cast(const(char)*)"__.SYMDEF", 9);
        int len = sprintf(h.file_size.ptr, "%u", om.length);
        assert(len <= 10);
        memset(h.file_size.ptr + len, ' ', 10 - len);
        libbuf.write(&h, h.sizeof);
        char[4] buf;
        Port.writelongLE(cast(uint)(objsymbols.dim * 8), buf.ptr);
        libbuf.write(buf.ptr, 4);
        int stringoff = 0;
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            MachObjSymbol* os = objsymbols[i];
            Port.writelongLE(stringoff, buf.ptr);
            libbuf.write(buf.ptr, 4);
            Port.writelongLE(os.om.offset, buf.ptr);
            libbuf.write(buf.ptr, 4);
            stringoff += os.name.length + 1;
        }
        Port.writelongLE(stringoff, buf.ptr);
        libbuf.write(buf.ptr, 4);
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            MachObjSymbol* os = objsymbols[i];
            libbuf.writestring(os.name);
            libbuf.writeByte(0);
        }
        while (libbuf.offset & 3)
            libbuf.writeByte(0);
        //if (libbuf.offset & 4)
        //    libbuf.write(pad, 4);
        static if (LOG)
        {
            printf("\tlibbuf.moffset = x%x\n", libbuf.offset);
        }
        assert(libbuf.offset == hoffset);
        /* Write out each of the object modules
         */
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            MachObjModule* om2 = objmodules[i];
            if (libbuf.offset & 1)
                libbuf.writeByte('\n'); // module alignment
            assert(libbuf.offset == om2.offset);
            if (om2.scan)
            {
                MachOmToHeader(&h, om2);
                libbuf.write(&h, h.sizeof); // module header
                libbuf.write(om2.name.ptr, om2.name.length);
                int nzeros = 8 - ((om2.name.length + 4) & 7);
                if (nzeros < 4)
                    nzeros += 8; // emulate mysterious behavior of ar
                libbuf.fill0(nzeros);
                libbuf.write(om2.base, om2.length); // module contents
                // obj modules are padded out to 8 bytes in length with 0x0A
                int filealign = om2.length & 7;
                if (filealign)
                {
                    libbuf.write(pad, 8 - filealign);
                }
            }
            else
            {
                libbuf.write(om2.base, om2.length); // module contents
            }
        }
        static if (LOG)
        {
            printf("moffset = x%x, libbuf.offset = x%x\n", moffset, libbuf.offset);
        }
        assert(libbuf.offset == moffset);
    }
}

extern (C++) Library LibMach_factory()
{
    return new LibMach();
}

/*****************************************************************************/
/*****************************************************************************/
struct MachObjModule
{
    ubyte* base; // where are we holding it in memory
    uint length; // in bytes
    uint offset; // offset from start of library
    const(char)[] name; // module name (file name) with terminating 0
    c_long file_time; // file time
    uint user_id;
    uint group_id;
    uint file_mode;
    int scan; // 1 means scan for symbols
}

enum MACH_OBJECT_NAME_SIZE = 16;

struct MachLibHeader
{
    char[MACH_OBJECT_NAME_SIZE] object_name;
    char[12] file_time;
    char[6] user_id;
    char[6] group_id;
    char[8] file_mode; // in octal
    char[10] file_size;
    char[2] trailer;
}

extern (C++) void MachOmToHeader(MachLibHeader* h, MachObjModule* om)
{
    const slen = om.name.length;
    int nzeros = 8 - ((slen + 4) & 7);
    if (nzeros < 4)
        nzeros += 8; // emulate mysterious behavior of ar
    size_t len = sprintf(h.object_name.ptr, "#1/%ld", slen + nzeros);
    memset(h.object_name.ptr + len, ' ', MACH_OBJECT_NAME_SIZE - len);
    /* In the following sprintf's, don't worry if the trailing 0
     * that sprintf writes goes off the end of the field. It will
     * write into the next field, which we will promptly overwrite
     * anyway. (So make sure to write the fields in ascending order.)
     */
    len = sprintf(h.file_time.ptr, "%llu", cast(long)om.file_time);
    assert(len <= 12);
    memset(h.file_time.ptr + len, ' ', 12 - len);
    if (om.user_id > 999999) // yes, it happens
        om.user_id = 0; // don't really know what to do here
    len = sprintf(h.user_id.ptr, "%u", om.user_id);
    assert(len <= 6);
    memset(h.user_id.ptr + len, ' ', 6 - len);
    if (om.group_id > 999999) // yes, it happens
        om.group_id = 0; // don't really know what to do here
    len = sprintf(h.group_id.ptr, "%u", om.group_id);
    assert(len <= 6);
    memset(h.group_id.ptr + len, ' ', 6 - len);
    len = sprintf(h.file_mode.ptr, "%o", om.file_mode);
    assert(len <= 8);
    memset(h.file_mode.ptr + len, ' ', 8 - len);
    int filesize = om.length;
    filesize = (filesize + 7) & ~7;
    len = sprintf(h.file_size.ptr, "%lu", slen + nzeros + filesize);
    assert(len <= 10);
    memset(h.file_size.ptr + len, ' ', 10 - len);
    h.trailer[0] = '`';
    h.trailer[1] = '\n';
}
