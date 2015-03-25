
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/libmach.c
 */

/* Implements object library reading and writing in the Mach-O object
 * module format. While the format is
 * equivalent to the Linux arch format, it differs in many details.
 * This format is described in the Apple document
 * "Mac OS X ABI Mach-O File Format Reference" dated 2007-04-26
 * in the section "Static Archive Libraries".
 * That specification is only about half complete and has numerous
 * errors, so use the source code here as a better guide.
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

class LibMach : public Library
{
  public:
    File *libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    LibMach();
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

Library *LibMach_factory()
{
    return new LibMach();
}

LibMach::LibMach()
{
    libfile = NULL;
    tab._init(14000);
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void LibMach::setFilename(const char *dir, const char *filename)
{
#if LOG
    printf("LibMach::setFilename(dir = '%s', filename = '%s')\n",
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

void LibMach::write()
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

void LibMach::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

struct ObjModule
{
    unsigned char *base;        // where are we holding it in memory
    unsigned length;            // in bytes
    unsigned offset;            // offset from start of library
    char *name;                 // module name (file name)
    long file_time;             // file time
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

void OmToHeader(Header *h, ObjModule *om)
{
    size_t slen = strlen(om->name);
    int nzeros = 8 - ((slen + 4) & 7);
    if (nzeros < 4)
        nzeros += 8;            // emulate mysterious behavior of ar

    size_t len = sprintf(h->object_name, "#1/%ld", slen + nzeros);
    memset(h->object_name + len, ' ', OBJECT_NAME_SIZE - len);

    /* In the following sprintf's, don't worry if the trailing 0
     * that sprintf writes goes off the end of the field. It will
     * write into the next field, which we will promptly overwrite
     * anyway. (So make sure to write the fields in ascending order.)
     */
    len = sprintf(h->file_time, "%llu", (longlong)om->file_time);
    assert(len <= 12);
    memset(h->file_time + len, ' ', 12 - len);

    if (om->user_id > 999999)           // yes, it happens
        om->user_id = 0;                // don't really know what to do here
    len = sprintf(h->user_id, "%u", om->user_id);
    assert(len <= 6);
    memset(h->user_id + len, ' ', 6 - len);

    if (om->group_id > 999999)          // yes, it happens
        om->group_id = 0;               // don't really know what to do here
    len = sprintf(h->group_id, "%u", om->group_id);
    assert(len <= 6);
    memset(h->group_id + len, ' ', 6 - len);

    len = sprintf(h->file_mode, "%o", om->file_mode);
    assert(len <= 8);
    memset(h->file_mode + len, ' ', 8 - len);

    int filesize = om->length;
    filesize = (filesize + 7) & ~7;
    len = sprintf(h->file_size, "%lu", slen + nzeros + filesize);
    assert(len <= 10);
    memset(h->file_size + len, ' ', 10 - len);

    h->trailer[0] = '`';
    h->trailer[1] = '\n';
}

void LibMach::addSymbol(ObjModule *om, char *name, int pickAny)
{
#if LOG
    printf("LibMach::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
#endif
#if 0 // let linker sort out duplicates
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
#else
    ObjSymbol *os = new ObjSymbol();
    os->name = strdup(name);
    os->om = om;
    objsymbols.push(os);
#endif
}

/************************************
 * Scan single object module for dictionary symbols.
 * Send those symbols to LibMach::addSymbol().
 */

void LibMach::scanObjModule(ObjModule *om)
{
#if LOG
    printf("LibMach::scanObjModule(%s)\n", om->name);
#endif


    struct Context
    {
        LibMach *lib;
        ObjModule *om;

        Context(LibMach *lib, ObjModule *om)
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

    extern void scanMachObjModule(void*, void (*pAddSymbol)(void*, char*, int), void *, size_t, const char *, Loc loc);
    scanMachObjModule(&ctx, &Context::addSymbol, om->base, om->length, om->name, loc);
}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void LibMach::addObject(const char *module_name, void *buf, size_t buflen)
{
    if (!module_name)
        module_name = "";
#if LOG
    printf("LibMach::addObject(%s)\n", module_name);
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

            if (memcmp(header->object_name, "__.SYMDEF       ", 16) == 0 ||
                memcmp(header->object_name, "__.SYMDEF SORTED", 16) == 0)
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
            else
            {
                ObjModule *om = new ObjModule();
                om->base = (unsigned char *)buf + offset - sizeof(Header);
                om->length = size + sizeof(Header);
                om->offset = 0;
                om->name = (char *)(om->base + sizeof(Header));
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
        unsigned nsymbols = Port::readlongLE(symtab) / 8;
        char *s = symtab + 4 + nsymbols * 8 + 4;
        if (4 + nsymbols * 8 + 4 > symtab_size)
        {   reason = __LINE__;
            goto Lcorrupt;
        }
        for (unsigned i = 0; i < nsymbols; i++)
        {
            unsigned soff = Port::readlongLE(symtab + 4 + i * 8);
            char *name = s + soff;
            //printf("soff = x%x name = %s\n", soff, name);
            if (s + strlen(name) + 1 - symtab > symtab_size)
            {   reason = __LINE__;
                goto Lcorrupt;
            }
            unsigned moff = Port::readlongLE(symtab + 4 + i * 8 + 4);
            //printf("symtab[%d] moff = x%x  x%x, name = %s\n", i, moff, moff + sizeof(Header), name);
            for (unsigned m = mstart; 1; m++)
            {   if (m == objmodules.dim)
                {   reason = __LINE__;
                    goto Lcorrupt;              // didn't find it
                }
                ObjModule *om = objmodules[m];
                //printf("\tom offset = x%x\n", (char *)om->base - (char *)buf);
                if (moff == (char *)om->base - (char *)buf)
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
        om->file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644
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

void LibMach::WriteLibToBuffer(OutBuffer *libbuf)
{
#if LOG
    printf("LibMach::WriteLibToBuffer()\n");
#endif
    static char pad[7] = { 0x0A,0x0A,0x0A,0x0A,0x0A,0x0A,0x0A, };

    /************* Scan Object Modules for Symbols ******************/

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];
        if (om->scan)
        {
            scanObjModule(om);
        }
    }

    /************* Determine module offsets ******************/

    unsigned moffset = 8 + sizeof(Header) + 4 + 4;

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        moffset += 8 + strlen(os->name) + 1;
    }
    moffset = (moffset + 3) & ~3;
//    if (moffset & 4)
//      moffset += 4;
    unsigned hoffset = moffset;

#if LOG
    printf("\tmoffset = x%x\n", moffset);
#endif

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        moffset += moffset & 1;
        om->offset = moffset;
        if (om->scan)
        {
            size_t slen = strlen(om->name);
            int nzeros = 8 - ((slen + 4) & 7);
            if (nzeros < 4)
                nzeros += 8;            // emulate mysterious behavior of ar
            int filesize = om->length;
            filesize = (filesize + 7) & ~7;
            moffset += sizeof(Header) + slen + nzeros + filesize;
        }
        else
        {
            moffset += om->length;
        }
    }

    libbuf->reserve(moffset);

    /************* Write the library ******************/
    libbuf->write("!<arch>\n", 8);

    ObjModule om;
    om.base = NULL;
    om.length = hoffset - (8 + sizeof(Header));
    om.offset = 8;
    om.name = (char*)"";
    ::time(&om.file_time);
    om.user_id = getuid();
    om.group_id = getgid();
    om.file_mode = (1 << 15) | (6 << 6) | (4 << 3) | (4 << 0); // 0100644

    Header h;
    OmToHeader(&h, &om);
    memcpy(h.object_name, "__.SYMDEF", 9);
    int len = sprintf(h.file_size, "%u", om.length);
    assert(len <= 10);
    memset(h.file_size + len, ' ', 10 - len);

    libbuf->write(&h, sizeof(h));

    char buf[4];

    Port::writelongLE(objsymbols.dim * 8, buf);
    libbuf->write(buf, 4);

    int stringoff = 0;
    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        Port::writelongLE(stringoff, buf);
        libbuf->write(buf, 4);

        Port::writelongLE(os->om->offset, buf);
        libbuf->write(buf, 4);

        stringoff += strlen(os->name) + 1;
    }

    Port::writelongLE(stringoff, buf);
    libbuf->write(buf, 4);

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        libbuf->writestring(os->name);
        libbuf->writeByte(0);
    }
    while (libbuf->offset & 3)
        libbuf->writeByte(0);

//    if (libbuf->offset & 4)
//      libbuf->write(pad, 4);

#if LOG
    printf("\tlibbuf->moffset = x%x\n", libbuf->offset);
#endif
    assert(libbuf->offset == hoffset);

    /* Write out each of the object modules
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        if (libbuf->offset & 1)
            libbuf->writeByte('\n');    // module alignment

        assert(libbuf->offset == om->offset);

        if (om->scan)
        {
            OmToHeader(&h, om);
            libbuf->write(&h, sizeof(h));       // module header

            size_t len = strlen(om->name);
            libbuf->write(om->name, len);

            int nzeros = 8 - ((len + 4) & 7);
            if (nzeros < 4)
                nzeros += 8;            // emulate mysterious behavior of ar
            libbuf->fill0(nzeros);

            libbuf->write(om->base, om->length);        // module contents

            // obj modules are padded out to 8 bytes in length with 0x0A
            int filealign = om->length & 7;
            if (filealign)
            {
                libbuf->write(pad, 8 - filealign);
            }
        }
        else
        {
            libbuf->write(om->base, om->length);        // module contents
        }
    }

#if LOG
    printf("moffset = x%x, libbuf->offset = x%x\n", moffset, libbuf->offset);
#endif
    assert(libbuf->offset == moffset);
}
