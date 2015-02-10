
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/libelf.c
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "root.h"
#include "stringtable.h"

#include "mars.h"
#include "lib.h"

#define LOG 0

struct ObjModule;

struct ObjSymbol
{
    char *name;
    ObjModule *om;
};

#include "arraytypes.h"

typedef Array<ObjModule *> ObjModules;
typedef Array<ObjSymbol *> ObjSymbols;

class LibElf : public Library
{
  public:
    File *libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    LibElf();
    void setFilename(const char *dir, const char *filename);
    void addObject(const char *module_name, void *buf, size_t buflen);
    void addLibrary(void *buf, size_t buflen);
    void write();

    void addSymbol(ObjModule *om, char *name, int pickAny = 0);
  private:
    void scanObjModule(ObjModule *om);
    void WriteLibToBuffer(OutBuffer *libbuf);

    void error(const char *format, ...)
    {
        va_list ap;
        va_start(ap, format);
        ::verror(loc, format, ap);
        va_end(ap);
    }

    Loc loc;
};

Library *LibElf_factory()
{
    return new LibElf();
}

LibElf::LibElf()
{
    libfile = NULL;
    tab._init(14000);
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void LibElf::setFilename(const char *dir, const char *filename)
{
#if LOG
    printf("LibElf::setFilename(dir = '%s', filename = '%s')\n",
        dir ? dir : "", filename ? filename : "");
#endif
    const char *arg = filename;
    if (!arg || !*arg)
    {   // Generate lib file name from first obj name
        const char *n = (*global.params.objfiles)[0];

        n = FileName::name(n);
        arg = FileName::forceExt(n, global.lib_ext);
    }
    if (!FileName::absolute(arg))
        arg = FileName::combine(dir, arg);
    const char *libfilename = FileName::defaultExt(arg, global.lib_ext);

    libfile = File::create(libfilename);

    loc.filename = libfile->name->toChars();
    loc.linnum = 0;
    loc.charnum = 0;
}

void LibElf::write()
{
    if (global.params.verbose)
        fprintf(global.stdmsg, "library   %s\n", libfile->name->toChars());

    OutBuffer libbuf;
    WriteLibToBuffer(&libbuf);

    // Transfer image to file
    libfile->setbuffer(libbuf.data, libbuf.offset);
    libbuf.extractData();


    ensurePathToNameExists(Loc(), libfile->name->toChars());

    writeFile(Loc(), libfile);
}

/*****************************************************************************/

void LibElf::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

void sputl(int value, void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    p[0] = (unsigned char)(value >> 24);
    p[1] = (unsigned char)(value >> 16);
    p[2] = (unsigned char)(value >> 8);
    p[3] = (unsigned char)(value);
}

int sgetl(void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
}


struct ObjModule
{
    unsigned char *base;        // where are we holding it in memory
    unsigned length;            // in bytes
    unsigned offset;            // offset from start of library
    char *name;                 // module name (file name)
    int name_offset;            // if not -1, offset into string table of name
    time_t file_time;           // file time
    unsigned user_id;
    unsigned group_id;
    unsigned file_mode;
    int scan;                   // 1 means scan for symbols
};

struct Header
{
    #define OBJECT_NAME_SIZE 16
    char object_name[OBJECT_NAME_SIZE];
    char file_time[12];
    char user_id[6];
    char group_id[6];
    char file_mode[8];          // in octal
    char file_size[10];
    char trailer[2];
};

void OmToHeader(Header *h, ObjModule *om) {
    char* buffer = reinterpret_cast<char*>(h);
    // user_id and group_id are padded on 6 characters.
    // Squashing to 0 if more than allocated space.
    if (om->user_id > 999999)
        om->user_id = 0;
    if (om->group_id > 999999)
        om->group_id = 0;
    size_t len;
    if (om->name_offset == -1)
    {   // "name/           1423563789  5000  5000  100640  3068      `\n"
        //  |^^^^^^^^^^^^^^^|^^^^^^^^^^^|^^^^^|^^^^^|^^^^^^^|^^^^^^^^^|^^
        //        name       file_time   u_id gr_id  fmode    fsize   trailer
        len = sprintf(buffer, "%-16s%-12llu%-6u%-6u%-8o%-10u`", om->name,
                (longlong) om->file_time, om->user_id, om->group_id,
                om->file_mode, om->length);
        // adding '/' after the name field
        const size_t name_length = strlen(om->name);
        assert(name_length < OBJECT_NAME_SIZE);
        buffer[name_length] = '/';
    } else
    {   // "/162007         1423563789  5000  5000  100640  3068      `\n"
        //  |^^^^^^^^^^^^^^^|^^^^^^^^^^^|^^^^^|^^^^^|^^^^^^^|^^^^^^^^^|^^
        //     name_offset   file_time   u_id gr_id  fmode    fsize   trailer
        len = sprintf(buffer, "/%-15d%-12llu%-6u%-6u%-8o%-10u`",
                om->name_offset, (longlong) om->file_time, om->user_id,
                om->group_id, om->file_mode, om->length);

    }
    assert(sizeof(Header) > 0 && len == sizeof(Header) - 1);
    buffer[len] = '\n';
}

void LibElf::addSymbol(ObjModule *om, char *name, int pickAny)
{
#if LOG
    printf("LibElf::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
#endif
    StringValue *s = tab.insert(name, strlen(name));
    if (!s)
    {   // already in table
        if (!pickAny)
        {   s = tab.lookup(name, strlen(name));
            assert(s);
            ObjSymbol *os = (ObjSymbol *)s->ptrvalue;
            error("multiple definition of %s: %s and %s: %s",
                om->name, name, os->om->name, os->name);
        }
    }
    else
    {
        ObjSymbol *os = new ObjSymbol();
        os->name = strdup(name);
        os->om = om;
        s->ptrvalue = (void *)os;

        objsymbols.push(os);
    }
}

/************************************
 * Scan single object module for dictionary symbols.
 * Send those symbols to LibElf::addSymbol().
 */

void LibElf::scanObjModule(ObjModule *om)
{
#if LOG
    printf("LibElf::scanObjModule(%s)\n", om->name);
#endif


    struct Context
    {
        LibElf *lib;
        ObjModule *om;

        Context(LibElf *lib, ObjModule *om)
        {
            this->lib = lib;
            this->om = om;
        }

        static void addSymbol(void *pctx, char *name, int pickAny)
        {
            ((Context *)pctx)->lib->addSymbol(((Context *)pctx)->om, name, pickAny);
        }
    };

    Context ctx(this, om);

    extern void scanElfObjModule(void*, void (*pAddSymbol)(void*, char*, int), void *, size_t, const char *, Loc loc);
    scanElfObjModule(&ctx, &Context::addSymbol, om->base, om->length, om->name, loc);
}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void LibElf::addObject(const char *module_name, void *buf, size_t buflen)
{
    if (!module_name)
        module_name = "";
#if LOG
    printf("LibElf::addObject(%s)\n", module_name);
#endif
    int fromfile = 0;
    if (!buf)
    {   assert(module_name[0]);
        File *file = File::create((char *)module_name);
        readFile(Loc(), file);
        buf = file->buffer;
        buflen = file->len;
        file->ref = 1;
        fromfile = 1;
    }
    int reason = 0;

    if (buflen < 16)
    {
#if LOG
        printf("buf = %p, buflen = %d\n", buf, buflen);
#endif
      Lcorrupt:
        error("corrupt object module %s %d", module_name, reason);
        return;
    }

    if (memcmp(buf, "!<arch>\n", 8) == 0)
    {   /* Library file.
         * Pull each object module out of the library and add it
         * to the object module array.
         */
#if LOG
        printf("archive, buf = %p, buflen = %d\n", buf, buflen);
#endif
        unsigned offset = 8;
        char *symtab = NULL;
        unsigned symtab_size = 0;
        char *filenametab = NULL;
        unsigned filenametab_size = 0;
        unsigned mstart = objmodules.dim;
        while (offset < buflen)
        {
            if (offset + sizeof(Header) >= buflen)
            {   reason = __LINE__;
                goto Lcorrupt;
            }
            Header *header = (Header *)((unsigned char *)buf + offset);
            offset += sizeof(Header);
            char *endptr = NULL;
            unsigned long size = strtoul(header->file_size, &endptr, 10);
            if (endptr >= &header->file_size[10] || *endptr != ' ')
            {   reason = __LINE__;
                goto Lcorrupt;
            }
            if (offset + size > buflen)
            {   reason = __LINE__;
                goto Lcorrupt;
            }

            if (header->object_name[0] == '/' &&
                header->object_name[1] == ' ')
            {
                /* Instead of rescanning the object modules we pull from a
                 * library, just use the already created symbol table.
                 */
                if (symtab)
                {   reason = __LINE__;
                    goto Lcorrupt;
                }
                symtab = (char *)buf + offset;
                symtab_size = size;
                if (size < 4)
                {   reason = __LINE__;
                    goto Lcorrupt;
                }
            }
            else if (header->object_name[0] == '/' &&
                     header->object_name[1] == '/')
            {
                /* This is the file name table, save it for later.
                 */
                if (filenametab)
                {   reason = __LINE__;
                    goto Lcorrupt;
                }
                filenametab = (char *)buf + offset;
                filenametab_size = size;
            }
            else
            {
                ObjModule *om = new ObjModule();
                om->base = (unsigned char *)buf + offset /*- sizeof(Header)*/;
                om->length = size;
                om->offset = 0;
                if (header->object_name[0] == '/')
                {   /* Pick long name out of file name table
                     */
                    unsigned foff = strtoul(header->object_name + 1, &endptr, 10);
                    unsigned i;
                    for (i = 0; 1; i++)
                    {   if (foff + i >= filenametab_size)
                        {   reason = 7;
                            goto Lcorrupt;
                        }
                        char c = filenametab[foff + i];
                        if (c == '/')
                            break;
                    }
                    om->name = (char *)malloc(i + 1);
                    assert(om->name);
                    memcpy(om->name, filenametab + foff, i);
                    om->name[i] = 0;
                }
                else
                {   /* Pick short name out of header
                     */
                    om->name = (char *)malloc(OBJECT_NAME_SIZE);
                    assert(om->name);
                    for (int i = 0; 1; i++)
                    {   if (i == OBJECT_NAME_SIZE)
                        {   reason = __LINE__;
                            goto Lcorrupt;
                        }
                        char c = header->object_name[i];
                        if (c == '/')
                        {   om->name[i] = 0;
                            break;
                        }
                        om->name[i] = c;
                    }
                }
                om->name_offset = -1;
                om->file_time = strtoul(header->file_time, &endptr, 10);
                om->user_id   = strtoul(header->user_id, &endptr, 10);
                om->group_id  = strtoul(header->group_id, &endptr, 10);
                om->file_mode = strtoul(header->file_mode, &endptr, 8);
                om->scan = 0;                   // don't scan object module for symbols
                objmodules.push(om);
            }
            offset += (size + 1) & ~1;
        }
        if (offset != buflen)
        {   reason = __LINE__;
            goto Lcorrupt;
        }

        /* Scan the library's symbol table, and insert it into our own.
         * We use this instead of rescanning the object module, because
         * the library's creator may have a different idea of what symbols
         * go into the symbol table than we do.
         * This is also probably faster.
         */
        unsigned nsymbols = sgetl(symtab);
        char *s = symtab + 4 + nsymbols * 4;
        if (4 + nsymbols * (4 + 1) > symtab_size)
        {   reason = __LINE__;
            goto Lcorrupt;
        }
        for (unsigned i = 0; i < nsymbols; i++)
        {   char *name = s;
            s += strlen(name) + 1;
            if (s - symtab > symtab_size)
            {   reason = __LINE__;
                goto Lcorrupt;
            }
            unsigned moff = sgetl(symtab + 4 + i * 4);
//printf("symtab[%d] moff = %x  %x, name = %s\n", i, moff, moff + sizeof(Header), name);
            for (unsigned m = mstart; 1; m++)
            {   if (m == objmodules.dim)
                {   reason = __LINE__;
                    goto Lcorrupt;              // didn't find it
                }
                ObjModule *om = objmodules[m];
//printf("\t%x\n", (char *)om->base - (char *)buf);
                if (moff + sizeof(Header) == (char *)om->base - (char *)buf)
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
    ObjModule *om = new ObjModule();
    om->base = (unsigned char *)buf;
    om->length = buflen;
    om->offset = 0;
    om->name = (char *)FileName::name(module_name);     // remove path, but not extension
    om->name_offset = -1;
    om->scan = 1;
    if (fromfile)
    {   struct stat statbuf;
        int i = stat(module_name, &statbuf);
        if (i == -1)            // error, errno is set
        {   reason = __LINE__;
            goto Lcorrupt;
        }
        om->file_time = statbuf.st_ctime;
        om->user_id   = statbuf.st_uid;
        om->group_id  = statbuf.st_gid;
        om->file_mode = statbuf.st_mode;
    }
    else
    {   /* Mock things up for the object module file that never was
         * actually written out.
         */
        static uid_t uid;
        static gid_t gid;
        static int init;
        if (!init)
        {   init = 1;
            uid = getuid();
            gid = getgid();
        }
        time(&om->file_time);
        om->user_id = uid;
        om->group_id = gid;
        om->file_mode = 0100640;
    }
    objmodules.push(om);
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

void LibElf::WriteLibToBuffer(OutBuffer *libbuf)
{
#if LOG
    printf("LibElf::WriteLibToBuffer()\n");
#endif

    /************* Scan Object Modules for Symbols ******************/

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];
        if (om->scan)
        {
            scanObjModule(om);
        }
    }

    /************* Determine string section ******************/

    /* The string section is where we store long file names.
     */
    unsigned noffset = 0;
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];
        size_t len = strlen(om->name);
        if (len >= OBJECT_NAME_SIZE)
        {
            om->name_offset = noffset;
            noffset += len + 2;
        }
        else
            om->name_offset = -1;
    }

#if LOG
    printf("\tnoffset = x%x\n", noffset);
#endif

    /************* Determine module offsets ******************/

    unsigned moffset = 8 + sizeof(Header) + 4;

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        moffset += 4 + strlen(os->name) + 1;
    }
    unsigned hoffset = moffset;

#if LOG
    printf("\tmoffset = x%x\n", moffset);
#endif

    moffset += moffset & 1;
    if (noffset)
         moffset += sizeof(Header) + noffset;

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        moffset += moffset & 1;
        om->offset = moffset;
        moffset += sizeof(Header) + om->length;
    }

    libbuf->reserve(moffset);

    /************* Write the library ******************/
    libbuf->write("!<arch>\n", 8);

    ObjModule om;
    om.name_offset = -1;
    om.base = NULL;
    om.length = hoffset - (8 + sizeof(Header));
    om.offset = 8;
    om.name = (char*)"";
    ::time(&om.file_time);
    om.user_id = 0;
    om.group_id = 0;
    om.file_mode = 0;

    Header h;
    OmToHeader(&h, &om);
    libbuf->write(&h, sizeof(h));
    char buf[4];
    sputl(objsymbols.dim, buf);
    libbuf->write(buf, 4);

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        sputl(os->om->offset, buf);
        libbuf->write(buf, 4);
    }

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        libbuf->writestring(os->name);
        libbuf->writeByte(0);
    }

#if LOG
    printf("\tlibbuf->moffset = x%x\n", libbuf->offset);
#endif

    /* Write out the string section
     */
    if (noffset)
    {
        if (libbuf->offset & 1)
            libbuf->writeByte('\n');

        // header
        memset(&h, ' ', sizeof(Header));
        h.object_name[0] = '/';
        h.object_name[1] = '/';
        size_t len = sprintf(h.file_size, "%u", noffset);
        assert(len < 10);
        h.file_size[len] = ' ';
        h.trailer[0] = '`';
        h.trailer[1] = '\n';
        libbuf->write(&h, sizeof(h));

    for (size_t i = 0; i < objmodules.dim; i++)
        {   ObjModule *om = objmodules[i];
            if (om->name_offset >= 0)
            {   libbuf->writestring(om->name);
                libbuf->writeByte('/');
                libbuf->writeByte('\n');
            }
        }
    }

    /* Write out each of the object modules
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        if (libbuf->offset & 1)
            libbuf->writeByte('\n');    // module alignment

        assert(libbuf->offset == om->offset);

        OmToHeader(&h, om);
        libbuf->write(&h, sizeof(h));   // module header

        libbuf->write(om->base, om->length);    // module contents
    }

#if LOG
    printf("moffset = x%x, libbuf->offset = x%x\n", moffset, libbuf->offset);
#endif
    assert(libbuf->offset == moffset);
}
