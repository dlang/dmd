// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.libelf;

import core.stdc.time;
import core.stdc.string;
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.stdarg;
import core.sys.posix.sys.stat;
import core.sys.posix.unistd;
import ddmd.globals;
import ddmd.lib;
import ddmd.root.array;
import ddmd.root.file;
import ddmd.root.outbuffer;
import ddmd.root.stringtable;
import ddmd.root.filename;
import ddmd.root.port;
import ddmd.mars;
import ddmd.scanelf;
import ddmd.errors;

enum LOG = false;

struct ElfObjSymbol
{
    char* name;
    ElfObjModule* om;
}

alias ElfObjModules = Array!(ElfObjModule*);
alias ElfObjSymbols = Array!(ElfObjSymbol*);

extern (C++) final class LibElf : Library
{
public:
    File* libfile;
    ElfObjModules objmodules; // ElfObjModule[]
    ElfObjSymbols objsymbols; // ElfObjSymbol[]
    StringTable tab;

    extern (D) this()
    {
        libfile = null;
        tab._init(14000);
    }

    /***********************************
     * Set the library file name based on the output directory
     * and the filename.
     * Add default library file name extension.
     */
    void setFilename(const(char)* dir, const(char)* filename)
    {
        static if (LOG)
        {
            printf("LibElf::setFilename(dir = '%s', filename = '%s')\n", dir ? dir : "", filename ? filename : "");
        }
        const(char)* arg = filename;
        if (!arg || !*arg)
        {
            // Generate lib file name from first obj name
            const(char)* n = (*global.params.objfiles)[0];
            n = FileName.name(n);
            arg = FileName.forceExt(n, global.lib_ext);
        }
        if (!FileName.absolute(arg))
            arg = FileName.combine(dir, arg);
        const(char)* libfilename = FileName.defaultExt(arg, global.lib_ext);
        libfile = File.create(libfilename);
        loc.filename = libfile.name.toChars();
        loc.linnum = 0;
        loc.charnum = 0;
    }

    /***************************************
     * Add object module or library to the library.
     * Examine the buffer to see which it is.
     * If the buffer is NULL, use module_name as the file name
     * and load the file.
     */
    void addObject(const(char)* module_name, void* buf, size_t buflen)
    {
        if (!module_name)
            module_name = "";
        static if (LOG)
        {
            printf("LibElf::addObject(%s)\n", module_name);
        }
        int fromfile = 0;
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
        Lcorrupt:
            error("corrupt object module %s %d", module_name, reason);
            return;
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
            char* filenametab = null;
            uint filenametab_size = 0;
            uint mstart = cast(uint)objmodules.dim;
            while (offset < buflen)
            {
                if (offset + ElfLibHeader.sizeof >= buflen)
                {
                    reason = __LINE__;
                    goto Lcorrupt;
                }
                ElfLibHeader* header = cast(ElfLibHeader*)(cast(ubyte*)buf + offset);
                offset += ElfLibHeader.sizeof;
                char* endptr = null;
                uint size = cast(uint)strtoul(header.file_size.ptr, &endptr, 10);
                if (endptr >= header.file_size.ptr + 10 || *endptr != ' ')
                {
                    reason = __LINE__;
                    goto Lcorrupt;
                }
                if (offset + size > buflen)
                {
                    reason = __LINE__;
                    goto Lcorrupt;
                }
                if (header.object_name[0] == '/' && header.object_name[1] == ' ')
                {
                    /* Instead of rescanning the object modules we pull from a
                     * library, just use the already created symbol table.
                     */
                    if (symtab)
                    {
                        reason = __LINE__;
                        goto Lcorrupt;
                    }
                    symtab = cast(char*)buf + offset;
                    symtab_size = size;
                    if (size < 4)
                    {
                        reason = __LINE__;
                        goto Lcorrupt;
                    }
                }
                else if (header.object_name[0] == '/' && header.object_name[1] == '/')
                {
                    /* This is the file name table, save it for later.
                     */
                    if (filenametab)
                    {
                        reason = __LINE__;
                        goto Lcorrupt;
                    }
                    filenametab = cast(char*)buf + offset;
                    filenametab_size = size;
                }
                else
                {
                    auto om = new ElfObjModule();
                    om.base = cast(ubyte*)buf + offset; /*- sizeof(ElfLibHeader)*/
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
                            {
                                reason = 7;
                                goto Lcorrupt;
                            }
                            char c = filenametab[foff + i];
                            if (c == '/')
                                break;
                        }
                        om.name = cast(char*)malloc(i + 1);
                        assert(om.name);
                        memcpy(om.name, filenametab + foff, i);
                        om.name[i] = 0;
                    }
                    else
                    {
                        /* Pick short name out of header
                         */
                        om.name = cast(char*)malloc(ELF_OBJECT_NAME_SIZE);
                        assert(om.name);
                        for (int i = 0; 1; i++)
                        {
                            if (i == ELF_OBJECT_NAME_SIZE)
                            {
                                reason = __LINE__;
                                goto Lcorrupt;
                            }
                            char c = header.object_name[i];
                            if (c == '/')
                            {
                                om.name[i] = 0;
                                break;
                            }
                            om.name[i] = c;
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
            if (offset != buflen)
            {
                reason = __LINE__;
                goto Lcorrupt;
            }
            /* Scan the library's symbol table, and insert it into our own.
             * We use this instead of rescanning the object module, because
             * the library's creator may have a different idea of what symbols
             * go into the symbol table than we do.
             * This is also probably faster.
             */
            uint nsymbols = Port.readlongBE(symtab);
            char* s = symtab + 4 + nsymbols * 4;
            if (4 + nsymbols * (4 + 1) > symtab_size)
            {
                reason = __LINE__;
                goto Lcorrupt;
            }
            for (uint i = 0; i < nsymbols; i++)
            {
                char* name = s;
                s += strlen(name) + 1;
                if (s - symtab > symtab_size)
                {
                    reason = __LINE__;
                    goto Lcorrupt;
                }
                uint moff = Port.readlongBE(symtab + 4 + i * 4);
                //printf("symtab[%d] moff = %x  %x, name = %s\n", i, moff, moff + sizeof(Header), name);
                for (uint m = mstart; 1; m++)
                {
                    if (m == objmodules.dim)
                    {
                        reason = __LINE__;
                        goto Lcorrupt;
                        // didn't find it
                    }
                    ElfObjModule* om = objmodules[m];
                    //printf("\t%x\n", (char *)om->base - (char *)buf);
                    if (moff + ElfLibHeader.sizeof == cast(char*)om.base - cast(char*)buf)
                    {
                        addSymbol(om, name, 1);
                        //                  if (mstart == m)
                        //                      mstart++;
                        break;
                    }
                }
            }
            return;
        }
        /* It's an object module
         */
        auto om = new ElfObjModule();
        om.base = cast(ubyte*)buf;
        om.length = cast(uint)buflen;
        om.offset = 0;
        om.name = cast(char*)FileName.name(module_name); // remove path, but not extension
        om.name_offset = -1;
        om.scan = 1;
        if (fromfile)
        {
            stat_t statbuf;
            int i = stat(module_name, &statbuf);
            if (i == -1) // error, errno is set
            {
                reason = __LINE__;
                goto Lcorrupt;
            }
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
            om.file_mode = (1 << 15) | (6 << 6) | (4 << 3); // 0100640
        }
        objmodules.push(om);
    }

    /*****************************************************************************/
    void addLibrary(void* buf, size_t buflen)
    {
        addObject(null, buf, buflen);
    }

    void write()
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "library   %s\n", libfile.name.toChars());
        OutBuffer libbuf;
        WriteLibToBuffer(&libbuf);
        // Transfer image to file
        libfile.setbuffer(libbuf.data, libbuf.offset);
        libbuf.extractData();
        ensurePathToNameExists(Loc(), libfile.name.toChars());
        writeFile(Loc(), libfile);
    }

    void addSymbol(ElfObjModule* om, char* name, int pickAny = 0)
    {
        static if (LOG)
        {
            printf("LibElf::addSymbol(%s, %s, %d)\n", om.name, name, pickAny);
        }
        StringValue* s = tab.insert(name, strlen(name));
        if (!s)
        {
            // already in table
            if (!pickAny)
            {
                s = tab.lookup(name, strlen(name));
                assert(s);
                ElfObjSymbol* os = cast(ElfObjSymbol*)s.ptrvalue;
                error("multiple definition of %s: %s and %s: %s", om.name, name, os.om.name, os.name);
            }
        }
        else
        {
            auto os = new ElfObjSymbol();
            os.name = strdup(name);
            os.om = om;
            s.ptrvalue = cast(void*)os;
            objsymbols.push(os);
        }
    }

private:
    /************************************
     * Scan single object module for dictionary symbols.
     * Send those symbols to LibElf::addSymbol().
     */
    void scanObjModule(ElfObjModule* om)
    {
        static if (LOG)
        {
            printf("LibElf::scanObjModule(%s)\n", om.name);
        }
        struct Context
        {
            LibElf lib;
            ElfObjModule* om;

            extern (D) this(LibElf lib, ElfObjModule* om)
            {
                this.lib = lib;
                this.om = om;
            }

            extern (C++) static void addSymbol(void* pctx, char* name, int pickAny)
            {
                (cast(Context*)pctx).lib.addSymbol((cast(Context*)pctx).om, name, pickAny);
            }
        }

        auto ctx = Context(this, om);
        scanElfObjModule(&ctx, &Context.addSymbol, om.base, om.length, om.name, loc);
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
    void WriteLibToBuffer(OutBuffer* libbuf)
    {
        static if (LOG)
        {
            printf("LibElf::WriteLibToBuffer()\n");
        }
        /************* Scan Object Modules for Symbols ******************/
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            ElfObjModule* om = objmodules[i];
            if (om.scan)
            {
                scanObjModule(om);
            }
        }
        /************* Determine string section ******************/
        /* The string section is where we store long file names.
         */
        uint noffset = 0;
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            ElfObjModule* om = objmodules[i];
            size_t len = strlen(om.name);
            if (len >= ELF_OBJECT_NAME_SIZE)
            {
                om.name_offset = noffset;
                noffset += len + 2;
            }
            else
                om.name_offset = -1;
        }
        static if (LOG)
        {
            printf("\tnoffset = x%x\n", noffset);
        }
        /************* Determine module offsets ******************/
        uint moffset = 8 + ElfLibHeader.sizeof + 4;
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            ElfObjSymbol* os = objsymbols[i];
            moffset += 4 + strlen(os.name) + 1;
        }
        uint hoffset = moffset;
        static if (LOG)
        {
            printf("\tmoffset = x%x\n", moffset);
        }
        moffset += moffset & 1;
        if (noffset)
            moffset += ElfLibHeader.sizeof + noffset;
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            ElfObjModule* om = objmodules[i];
            moffset += moffset & 1;
            om.offset = moffset;
            moffset += ElfLibHeader.sizeof + om.length;
        }
        libbuf.reserve(moffset);
        /************* Write the library ******************/
        libbuf.write("!<arch>\n".ptr, 8);
        ElfObjModule om;
        om.name_offset = -1;
        om.base = null;
        om.length = cast(uint)(hoffset - (8 + ElfLibHeader.sizeof));
        om.offset = 8;
        om.name = cast(char*)"";
        .time(&om.file_time);
        om.user_id = 0;
        om.group_id = 0;
        om.file_mode = 0;
        ElfLibHeader h;
        ElfOmToHeader(&h, &om);
        libbuf.write(&h, h.sizeof);
        char[4] buf;
        Port.writelongBE(cast(uint)objsymbols.dim, buf.ptr);
        libbuf.write(buf.ptr, 4);
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            ElfObjSymbol* os = objsymbols[i];
            Port.writelongBE(os.om.offset, buf.ptr);
            libbuf.write(buf.ptr, 4);
        }
        for (size_t i = 0; i < objsymbols.dim; i++)
        {
            ElfObjSymbol* os = objsymbols[i];
            libbuf.writestring(os.name);
            libbuf.writeByte(0);
        }
        static if (LOG)
        {
            printf("\tlibbuf->moffset = x%x\n", libbuf.offset);
        }
        /* Write out the string section
         */
        if (noffset)
        {
            if (libbuf.offset & 1)
                libbuf.writeByte('\n');
            // header
            memset(&h, ' ', ElfLibHeader.sizeof);
            h.object_name[0] = '/';
            h.object_name[1] = '/';
            size_t len = sprintf(h.file_size.ptr, "%u", noffset);
            assert(len < 10);
            h.file_size[len] = ' ';
            h.trailer[0] = '`';
            h.trailer[1] = '\n';
            libbuf.write(&h, h.sizeof);
            for (size_t i = 0; i < objmodules.dim; i++)
            {
                ElfObjModule* om2 = objmodules[i];
                if (om2.name_offset >= 0)
                {
                    libbuf.writestring(om2.name);
                    libbuf.writeByte('/');
                    libbuf.writeByte('\n');
                }
            }
        }
        /* Write out each of the object modules
         */
        for (size_t i = 0; i < objmodules.dim; i++)
        {
            ElfObjModule* om2 = objmodules[i];
            if (libbuf.offset & 1)
                libbuf.writeByte('\n'); // module alignment
            assert(libbuf.offset == om2.offset);
            ElfOmToHeader(&h, om2);
            libbuf.write(&h, h.sizeof); // module header
            libbuf.write(om2.base, om2.length); // module contents
        }
        static if (LOG)
        {
            printf("moffset = x%x, libbuf->offset = x%x\n", moffset, libbuf.offset);
        }
        assert(libbuf.offset == moffset);
    }

    void error(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .verror(loc, format, ap);
        va_end(ap);
    }

    Loc loc;
}

extern (C++) Library LibElf_factory()
{
    return new LibElf();
}

/*****************************************************************************/
/*****************************************************************************/
struct ElfObjModule
{
    ubyte* base; // where are we holding it in memory
    uint length; // in bytes
    uint offset; // offset from start of library
    char* name; // module name (file name)
    int name_offset; // if not -1, offset into string table of name
    time_t file_time; // file time
    uint user_id;
    uint group_id;
    uint file_mode;
    int scan; // 1 means scan for symbols
}

enum ELF_OBJECT_NAME_SIZE = 16;

struct ElfLibHeader
{
    char[ELF_OBJECT_NAME_SIZE] object_name;
    char[12] file_time;
    char[6] user_id;
    char[6] group_id;
    char[8] file_mode; // in octal
    char[10] file_size;
    char[2] trailer;
}

extern (C++) void ElfOmToHeader(ElfLibHeader* h, ElfObjModule* om)
{
    char* buffer = cast(char*)h;
    // user_id and group_id are padded on 6 characters in Header struct.
    // Squashing to 0 if more than 999999.
    if (om.user_id > 999999)
        om.user_id = 0;
    if (om.group_id > 999999)
        om.group_id = 0;
    size_t len;
    if (om.name_offset == -1)
    {
        // "name/           1423563789  5000  5000  100640  3068      `\n"
        //  |^^^^^^^^^^^^^^^|^^^^^^^^^^^|^^^^^|^^^^^|^^^^^^^|^^^^^^^^^|^^
        //        name       file_time   u_id gr_id  fmode    fsize   trailer
        len = snprintf(buffer, ElfLibHeader.sizeof, "%-16s%-12llu%-6u%-6u%-8o%-10u`", om.name, cast(long)om.file_time, om.user_id, om.group_id, om.file_mode, om.length);
        // adding '/' after the name field
        const(size_t) name_length = strlen(om.name);
        assert(name_length < ELF_OBJECT_NAME_SIZE);
        buffer[name_length] = '/';
    }
    else
    {
        // "/162007         1423563789  5000  5000  100640  3068      `\n"
        //  |^^^^^^^^^^^^^^^|^^^^^^^^^^^|^^^^^|^^^^^|^^^^^^^|^^^^^^^^^|^^
        //     name_offset   file_time   u_id gr_id  fmode    fsize   trailer
        len = snprintf(buffer, ElfLibHeader.sizeof, "/%-15d%-12llu%-6u%-6u%-8o%-10u`", om.name_offset, cast(long)om.file_time, om.user_id, om.group_id, om.file_mode, om.length);
    }
    assert(ElfLibHeader.sizeof > 0 && len == ElfLibHeader.sizeof - 1);
    // replace trailing \0 with \n
    buffer[len] = '\n';
}
