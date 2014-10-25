
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/libmscoff.c
 */

/* Implements object library reading and writing in the MS-COFF object
 * module format.
 * This format is described in the Microsoft document
 * "Microsoft Portable Executable and Common Object File Format Specification"
 * Revision 8.2 September 21, 2010
 * chapter 6 "Archive (Library) File Format"
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <time.h>
//#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "rmem.h"
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

/*********
 * Do lexical comparison of ObjSymbol's for qsort()
 */
int ObjSymbol_cmp(const void *p, const void *q)
{
    ObjSymbol *s1 = *(ObjSymbol **)p;
    ObjSymbol *s2 = *(ObjSymbol **)q;
    return strcmp(s1->name, s2->name);
}

#include "arraytypes.h"

typedef Array<ObjModule *> ObjModules;
typedef Array<ObjSymbol *> ObjSymbols;

class LibMSCoff : public Library
{
  public:
    File *libfile;
    ObjModules objmodules;   // ObjModule[]
    ObjSymbols objsymbols;   // ObjSymbol[]

    StringTable tab;

    LibMSCoff();
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

#if 0 // TODO: figure out how to initialize
Library *Library::factory()
{
    return new LibMSCoff();
}
#endif

Library *LibMSCoff_factory()
{
    return new LibMSCoff();
}

LibMSCoff::LibMSCoff()
{
    libfile = NULL;
    tab._init(14000);
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void LibMSCoff::setFilename(const char *dir, const char *filename)
{
#if LOG
    printf("LibMSCoff::setFilename(dir = '%s', filename = '%s')\n",
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

void LibMSCoff::write()
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

void LibMSCoff::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

// Little endian
void sputl(int value, void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    p[3] = (unsigned char)(value >> 24);
    p[2] = (unsigned char)(value >> 16);
    p[1] = (unsigned char)(value >> 8);
    p[0] = (unsigned char)(value);
}

// Little endian
int sgetl(void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    return (((((p[3] << 8) | p[2]) << 8) | p[1]) << 8) | p[0];
}

// Big endian
void sputl_big(int value, void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    p[0] = (unsigned char)(value >> 24);
    p[1] = (unsigned char)(value >> 16);
    p[2] = (unsigned char)(value >> 8);
    p[3] = (unsigned char)(value);
}

// Big endian
int sgetl_big(void* buffer)
{
    unsigned char *p = (unsigned char*)buffer;
    return (((((p[0] << 8) | p[1]) << 8) | p[2]) << 8) | p[3];
}


struct ObjModule
{
    unsigned char *base;        // where are we holding it in memory
    unsigned length;            // in bytes
    unsigned offset;            // offset from start of library
    unsigned short index;       // index in Second Linker Member
    const char *name;           // module name (file name)
    int name_offset;            // if not -1, offset into string table of name
    long file_time;             // file time
    unsigned user_id;
    unsigned group_id;
    unsigned file_mode;
    int scan;                   // 1 means scan for symbols
};

/*********
 * Do module offset comparison of ObjSymbol's for qsort()
 */
int ObjSymbol_offset_cmp(const void *p, const void *q)
{
    ObjSymbol *s1 = *(ObjSymbol **)p;
    ObjSymbol *s2 = *(ObjSymbol **)q;
    return s1->om->offset - s2->om->offset;
}

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
    size_t len;
    if (om->name_offset == -1)
    {
        len = strlen(om->name);
        memcpy(h->object_name, om->name, len);
        h->object_name[len] = '/';
    }
    else
    {
        len = sprintf(h->object_name, "/%d", om->name_offset);
        h->object_name[len] = ' ';
    }
    assert(len < OBJECT_NAME_SIZE);
    memset(h->object_name + len + 1, ' ', OBJECT_NAME_SIZE - (len + 1));

    /* In the following sprintf's, don't worry if the trailing 0
     * that sprintf writes goes off the end of the field. It will
     * write into the next field, which we will promptly overwrite
     * anyway. (So make sure to write the fields in ascending order.)
     */
    len = sprintf(h->file_time, "%llu", (longlong)om->file_time);
    assert(len <= 12);
    memset(h->file_time + len, ' ', 12 - len);

    // Match what MS tools do (set to all blanks)
    memset(h->user_id, ' ', sizeof(h->user_id));
    memset(h->group_id, ' ', sizeof(h->group_id));

    len = sprintf(h->file_mode, "%o", om->file_mode);
    assert(len <= 8);
    memset(h->file_mode + len, ' ', 8 - len);

    len = sprintf(h->file_size, "%u", om->length);
    assert(len <= 10);
    memset(h->file_size + len, ' ', 10 - len);

    h->trailer[0] = '`';
    h->trailer[1] = '\n';
}

void LibMSCoff::addSymbol(ObjModule *om, char *name, int pickAny)
{
#if LOG
    printf("LibMSCoff::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
#endif
    ObjSymbol *os = new ObjSymbol();
    os->name = strdup(name);
    os->om = om;
    objsymbols.push(os);
}

/************************************
 * Scan single object module for dictionary symbols.
 * Send those symbols to LibMSCoff::addSymbol().
 */

void LibMSCoff::scanObjModule(ObjModule *om)
{
#if LOG
    printf("LibMSCoff::scanObjModule(%s)\n", om->name);
#endif

    struct Context
    {
        LibMSCoff *lib;
        ObjModule *om;

        Context(LibMSCoff *lib, ObjModule *om)
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

    extern void scanMSCoffObjModule(void*, void (*pAddSymbol)(void*, char*, int), void *, size_t, const char *, Loc loc);
    scanMSCoffObjModule(&ctx, &Context::addSymbol, om->base, om->length, om->name, loc);
}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void LibMSCoff::addObject(const char *module_name, void *buf, size_t buflen)
{
    if (!module_name)
        module_name = "";
#if LOG
    printf("LibMSCoff::addObject(%s)\n", module_name);
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
        exit(EXIT_FAILURE);
    }

    if (memcmp(buf, "!<arch>\n", 8) == 0)
    {   /* It's a library file.
         * Pull each object module out of the library and add it
         * to the object module array.
         */
#if LOG
        printf("archive, buf = %p, buflen = %d\n", buf, buflen);
#endif
        Header *flm = NULL;     // first linker member

        Header *slm = NULL;     // second linker member
        unsigned number_of_members = 0;
        unsigned *member_file_offsets = NULL;
        unsigned number_of_symbols = 0;
        unsigned short *indices = NULL;
        char *string_table = NULL;
        size_t string_table_length = 0;

        Header *lnm = NULL;     // longname member
        char *longnames = NULL;
        size_t longnames_length = 0;

        size_t offset = 8;
        char *symtab = NULL;
        unsigned symtab_size = 0;
        size_t mstart = objmodules.dim;
        while (1)
        {
            offset = (offset + 1) & ~1;         // round to even boundary
            if (offset >= buflen)
                break;
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

            //printf("header->object_name = '%.*s'\n", OBJECT_NAME_SIZE, header->object_name);

            if (memcmp(header->object_name, "/               ", OBJECT_NAME_SIZE) == 0)
            {
                if (!flm)
                {   // First Linker Member, which is ignored
                    flm = header;
                }
                else if (!slm)
                {   // Second Linker Member, which we require even though the format doesn't require it
                    slm = header;
                    if (size < 4 + 4)
                    {   reason = __LINE__;
                        goto Lcorrupt;
                    }
                    number_of_members = sgetl((char *)buf + offset);
                    member_file_offsets = (unsigned *)((char *)buf + offset + 4);
                    if (size < 4 + number_of_members * 4 + 4)
                    {   reason = __LINE__;
                        goto Lcorrupt;
                    }
                    number_of_symbols = sgetl((char *)buf + offset + 4 + number_of_members * 4);
                    indices = (unsigned short *)((char *)buf + offset + 4 + number_of_members * 4 + 4);
                    string_table = (char *)((char *)buf + offset + 4 + number_of_members * 4 + 4 + number_of_symbols * 2);
                    if (size <= (4 + number_of_members * 4 + 4 + number_of_symbols * 2))
                    {   reason = __LINE__;
                        goto Lcorrupt;
                    }
                    string_table_length = size - (4 + number_of_members * 4 + 4 + number_of_symbols * 2);

                    /* The number of strings in the string_table must be number_of_symbols; check it
                     * The strings must also be in ascending lexical order; not checked.
                     */
                    size_t i = 0;
                    for (unsigned n = 0; n < number_of_symbols; n++)
                    {
                        while (1)
                        {
                            if (i >= string_table_length)
                            {   reason = __LINE__;
                                goto Lcorrupt;
                            }
                            if (!string_table[i++])
                                break;
                        }
                    }
                    if (i != string_table_length)
                    {   reason = __LINE__;
                        goto Lcorrupt;
                    }
                }
            }
            else if (memcmp(header->object_name, "//              ", OBJECT_NAME_SIZE) == 0)
            {
                if (!lnm)
                {   lnm = header;
                    longnames = (char *)buf + offset;
                    longnames_length = size;
                }
            }
            else
            {
                if (!slm)
                {   reason = __LINE__;
                    goto Lcorrupt;
                }
#if 0 // Microsoft Spec says longnames member must appear, but Microsoft Lib says otherwise
                if (!lnm)
                {   reason = __LINE__;
                    goto Lcorrupt;
                }
#endif
                ObjModule *om = new ObjModule();
                // Include Header in base[0..length], so we don't have to repro it
                om->base = (unsigned char *)buf + offset - sizeof(Header);
                om->length = size + sizeof(Header);
                om->offset = 0;
                if (header->object_name[0] == '/')
                {   /* Pick long name out of longnames[]
                     */
                    unsigned foff = strtoul(header->object_name + 1, &endptr, 10);
                    unsigned i;
                    for (i = 0; 1; i++)
                    {   if (foff + i >= longnames_length)
                        {   reason = __LINE__;
                            goto Lcorrupt;
                        }
                        char c = longnames[foff + i];
                        if (c == 0)
                            break;
                    }
                    char* oname = (char *)malloc(i + 1);
                    assert(oname);
                    memcpy(oname, longnames + foff, i);
                    oname[i] = 0;
                    om->name = oname;
                    //printf("\tname = '%s'\n", om->name);
                }
                else
                {   /* Pick short name out of header
                     */
                    char* oname = (char *)malloc(OBJECT_NAME_SIZE);
                    assert(oname);
                    for (int i = 0; 1; i++)
                    {   if (i == OBJECT_NAME_SIZE)
                        {   reason = __LINE__;
                            goto Lcorrupt;
                        }
                        char c = header->object_name[i];
                        if (c == '/')
                        {   oname[i] = 0;
                            break;
                        }
                        oname[i] = c;
                    }
                    om->name = oname;
                }
                om->file_time = strtoul(header->file_time, &endptr, 10);
                om->user_id   = strtoul(header->user_id, &endptr, 10);
                om->group_id  = strtoul(header->group_id, &endptr, 10);
                om->file_mode = strtoul(header->file_mode, &endptr, 8);
                om->scan = 0;                   // don't scan object module for symbols
                objmodules.push(om);
            }
            offset += size;
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
        if (!slm)
        {   reason = __LINE__;
            goto Lcorrupt;
        }

        char *s = string_table;
        for (unsigned i = 0; i < number_of_symbols; i++)
        {
            char *name = s;
            s += strlen(s) + 1;

            unsigned memi = indices[i] - 1;
            if (memi >= number_of_members)
            {   reason = __LINE__;
                goto Lcorrupt;
            }
            unsigned moff = member_file_offsets[memi];
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
    om->name = global.params.preservePaths ? module_name : FileName::name(module_name);     // remove path, but not extension
    om->scan = 1;
    if (fromfile)
    {   struct stat statbuf;
        int i = stat(module_name, &statbuf);
        if (i == -1)            // error, errno is set
        {   reason = 14;
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
        time_t file_time = 0;
        time(&file_time);
        om->file_time = (long)file_time;
        om->user_id = 0;                // meaningless on Windows
        om->group_id = 0;               // meaningless on Windows
        om->file_mode = 0100644;
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
 *      1st Linker Member
 *      Header
 *      2nd Linker Member
 *      Header
 *      Longnames Member
 *      object modules...
 */

void LibMSCoff::WriteLibToBuffer(OutBuffer *libbuf)
{
#if LOG
    printf("LibElf::WriteLibToBuffer()\n");
#endif

    assert(sizeof(Header) == 60);

    /************* Scan Object Modules for Symbols ******************/

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];
        if (om->scan)
        {
            scanObjModule(om);
        }
    }

    /************* Determine longnames size ******************/

    /* The longnames section is where we store long file names.
     */
    unsigned noffset = 0;
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];
        size_t len = strlen(om->name);
        if (len >= OBJECT_NAME_SIZE)
        {
            om->name_offset = noffset;
            noffset += len + 1;
        }
        else
            om->name_offset = -1;
    }

#if LOG
    printf("\tnoffset = x%x\n", noffset);
#endif

    /************* Determine string table length ******************/

    size_t slength = 0;

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        slength += strlen(os->name) + 1;
    }

    /************* Offset of first module ***********************/

    size_t moffset = 8;       // signature

    size_t firstLinkerMemberOffset = moffset;
    moffset += sizeof(Header) + 4 + objsymbols.dim * 4 + slength;       // 1st Linker Member
    moffset += moffset & 1;

    size_t secondLinkerMemberOffset = moffset;
    moffset += sizeof(Header) + 4 + objmodules.dim * 4 + 4 + objsymbols.dim * 2 + slength;
    moffset += moffset & 1;

    size_t LongnamesMemberOffset = moffset;
    moffset += sizeof(Header) + noffset;                        // Longnames Member size

#if LOG
    printf("\tmoffset = x%x\n", moffset);
#endif

    /************* Offset of each module *************************/

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        moffset += moffset & 1;
        om->offset = moffset;
        if (om->scan)
            moffset += sizeof(Header) + om->length;
        else
            moffset += om->length;
    }

    libbuf->reserve(moffset);

    /************* Write the library ******************/
    libbuf->write("!<arch>\n", 8);

    ObjModule om;
    om.name_offset = -1;
    om.base = NULL;
    om.length = 4 + objsymbols.dim * 4 + slength;
    om.offset = 8;
    om.name = (char*)"";
    time_t file_time = 0;
    ::time(&file_time);
    om.file_time = (long)file_time;
    om.user_id = 0;
    om.group_id = 0;
    om.file_mode = 0;

    /*** Write out First Linker Member ***/

    assert(libbuf->offset == firstLinkerMemberOffset);

    Header h;
    OmToHeader(&h, &om);
    libbuf->write(&h, sizeof(h));

    char buf[4];
    sputl_big(objsymbols.dim, buf);
    libbuf->write(buf, 4);

    // Sort objsymbols[] in module offset order
    qsort(objsymbols.data, objsymbols.dim, sizeof(objsymbols.data[0]), &ObjSymbol_offset_cmp);

    unsigned lastoffset;
    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        //printf("objsymbols[%d] = '%s', offset = %u\n", i, os->name, os->om->offset);
        if (i)
            // Should be sorted in module order
            assert(lastoffset <= os->om->offset);
        lastoffset = os->om->offset;
        sputl_big(lastoffset, buf);
        libbuf->write(buf, 4);
    }

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        libbuf->writestring(os->name);
        libbuf->writeByte(0);
    }

    /*** Write out Second Linker Member ***/

    if (libbuf->offset & 1)
        libbuf->writeByte('\n');

    assert(libbuf->offset == secondLinkerMemberOffset);

    om.length = 4 + objmodules.dim * 4 + 4 + objsymbols.dim * 2 + slength;
    OmToHeader(&h, &om);
    libbuf->write(&h, sizeof(h));

    sputl(objmodules.dim, buf);
    libbuf->write(buf, 4);

    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        om->index = i;
        sputl(om->offset, buf);
        libbuf->write(buf, 4);
    }

    sputl(objsymbols.dim, buf);
    libbuf->write(buf, 4);

    // Sort objsymbols[] in lexical order
    qsort(objsymbols.data, objsymbols.dim, sizeof(objsymbols.data[0]), &ObjSymbol_cmp);

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        sputl(os->om->index + 1, buf);
        libbuf->write(buf, 2);
    }

    for (size_t i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols[i];

        libbuf->writestring(os->name);
        libbuf->writeByte(0);
    }

    /*** Write out longnames Member ***/

    if (libbuf->offset & 1)
        libbuf->writeByte('\n');

    //printf("libbuf %x longnames %x\n", (int)libbuf->offset, (int)LongnamesMemberOffset);
    assert(libbuf->offset == LongnamesMemberOffset);

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
            libbuf->writeByte(0);
        }
    }

    /* Write out each of the object modules
     */
    for (size_t i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules[i];

        if (libbuf->offset & 1)
            libbuf->writeByte('\n');    // module alignment

        //printf("libbuf %x om %x\n", (int)libbuf->offset, (int)om->offset);
        assert(libbuf->offset == om->offset);

        if (om->scan)
        {
            OmToHeader(&h, om);
            libbuf->write(&h, sizeof(h));   // module header

            libbuf->write(om->base, om->length);    // module contents
        }
        else
        {   // Header is included in om->base[0..length]
            libbuf->write(om->base, om->length);    // module contents
        }
    }

#if LOG
    printf("moffset = x%x, libbuf->offset = x%x\n", (unsigned)moffset, (unsigned)libbuf->offset);
#endif
    assert(libbuf->offset == moffset);
}
