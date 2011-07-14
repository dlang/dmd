
// Compiler implementation of the D programming language
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "rmem.h"
#include "root.h"
#include "stringtable.h"

#include "mars.h"
#include "lib.h"
#include "melf.h"

#define LOG 0

Library::Library()
{
    libfile = NULL;
}

/***********************************
 * Set the library file name based on the output directory
 * and the filename.
 * Add default library file name extension.
 */

void Library::setFilename(char *dir, char *filename)
{
#if LOG
    printf("Library::setFilename(dir = '%s', filename = '%s')\n",
        dir ? dir : "", filename ? filename : "");
#endif
    char *arg = filename;
    if (!arg || !*arg)
    {   // Generate lib file name from first obj name
        char *n = global.params.objfiles->tdata()[0];

        n = FileName::name(n);
        FileName *fn = FileName::forceExt(n, global.lib_ext);
        arg = fn->toChars();
    }
    if (!FileName::absolute(arg))
        arg = FileName::combine(dir, arg);
    FileName *libfilename = FileName::defaultExt(arg, global.lib_ext);

    libfile = new File(libfilename);
}

void Library::write()
{
    if (global.params.verbose)
        printf("library   %s\n", libfile->name->toChars());

    OutBuffer libbuf;
    WriteLibToBuffer(&libbuf);

    // Transfer image to file
    libfile->setbuffer(libbuf.data, libbuf.offset);
    libbuf.extractData();


    char *p = FileName::path(libfile->name->toChars());
    FileName::ensurePathExists(p);
    //mem.free(p);

    libfile->writev();
}

/*****************************************************************************/

void Library::addLibrary(void *buf, size_t buflen)
{
    addObject(NULL, buf, buflen);
}


/*****************************************************************************/
/*****************************************************************************/

static char elf[4] = { 0x7F, 'E', 'L', 'F' };   // ELF file signature

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

    len = sprintf(h->file_time, "%lu", om->file_time);
    assert(len <= 12);
    memset(h->file_time + len, ' ', 12 - len);

    if (om->user_id > 999999)
        om->user_id = 0;
    len = sprintf(h->user_id, "%u", om->user_id);
    assert(len <= 6);
    memset(h->user_id + len, ' ', 6 - len);

    len = sprintf(h->group_id, "%u", om->group_id);
    assert(len <= 6);
    memset(h->group_id + len, ' ', 6 - len);

    len = sprintf(h->file_mode, "%o", om->file_mode);
    assert(len <= 8);
    memset(h->file_mode + len, ' ', 8 - len);

    len = sprintf(h->file_size, "%u", om->length);
    assert(len <= 10);
    memset(h->file_size + len, ' ', 10 - len);

    h->trailer[0] = '`';
    h->trailer[1] = '\n';
}

void Library::addSymbol(ObjModule *om, char *name, int pickAny)
{
#if LOG
    printf("Library::addSymbol(%s, %s, %d)\n", om->name, name, pickAny);
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
 * Send those symbols to Library::addSymbol().
 */

void Library::scanObjModule(ObjModule *om)
{
#if LOG
    printf("Library::scanObjModule(%s)\n", om->name);
#endif
    unsigned char *buf = (unsigned char *)om->base;
    size_t buflen = om->length;
    int reason = 0;

    if (buflen < EI_NIDENT + sizeof(Elf32_Hdr))
    {
      Lcorrupt:
        error("corrupt ELF object module %s %d", om->name, reason);
        return;
    }

    if (memcmp(buf, elf, 4))
    {   reason = 1;
        goto Lcorrupt;
    }
    if (buf[EI_VERSION] != EV_CURRENT)
    {
        error("ELF object module %s has EI_VERSION = %d, should be %d", om->name, buf[EI_VERSION], EV_CURRENT);
        return;
    }
    if (buf[EI_DATA] != ELFDATA2LSB)
    {
        error("ELF object module %s is byte swapped and unsupported", om->name);
        return;
    }
    if (buf[EI_CLASS] == ELFCLASS32)
    {
        Elf32_Hdr *eh = (Elf32_Hdr *)(buf + EI_NIDENT);
        if (eh->e_type != ET_REL)
        {
            error("ELF object module %s is not relocatable", om->name);
            return;                             // not relocatable object module
        }
        if (eh->e_version != EV_CURRENT)
            goto Lcorrupt;

        /* For each Section
         */
        for (unsigned u = 0; u < eh->e_shnum; u++)
        {   Elf32_Shdr *section = (Elf32_Shdr *)(buf + eh->e_shoff + eh->e_shentsize * u);

            if (section->sh_type == SHT_SYMTAB)
            {   /* sh_link gives the particular string table section
                 * used for the symbol names.
                 */
                Elf32_Shdr *string_section = (Elf32_Shdr *)(buf + eh->e_shoff +
                    eh->e_shentsize * section->sh_link);
                if (string_section->sh_type != SHT_STRTAB)
                {
                    reason = 3;
                    goto Lcorrupt;
                }
                char *string_tab = (char *)(buf + string_section->sh_offset);

                for (unsigned offset = 0; offset < section->sh_size; offset += sizeof(Elf32_Sym))
                {   Elf32_Sym *sym = (Elf32_Sym *)(buf + section->sh_offset + offset);

                    if (((sym->st_info >> 4) == STB_GLOBAL ||
                         (sym->st_info >> 4) == STB_WEAK) &&
                        sym->st_shndx != SHT_UNDEF)     // not extern
                    {
                        char *name = string_tab + sym->st_name;
                        //printf("sym st_name = x%x\n", sym->st_name);
                        addSymbol(om, name, 1);
                    }
                }
            }
        }
    }
    else if (buf[EI_CLASS] == ELFCLASS64)
    {
        Elf64_Ehdr *eh = (Elf64_Ehdr *)(buf + EI_NIDENT);
        if (buflen < EI_NIDENT + sizeof(Elf64_Ehdr))
            goto Lcorrupt;
        if (eh->e_type != ET_REL)
        {
            error("ELF object module %s is not relocatable", om->name);
            return;                             // not relocatable object module
        }
        if (eh->e_version != EV_CURRENT)
            goto Lcorrupt;

        /* For each Section
         */
        for (unsigned u = 0; u < eh->e_shnum; u++)
        {   Elf64_Shdr *section = (Elf64_Shdr *)(buf + eh->e_shoff + eh->e_shentsize * u);

            if (section->sh_type == SHT_SYMTAB)
            {   /* sh_link gives the particular string table section
                 * used for the symbol names.
                 */
                Elf64_Shdr *string_section = (Elf64_Shdr *)(buf + eh->e_shoff +
                    eh->e_shentsize * section->sh_link);
                if (string_section->sh_type != SHT_STRTAB)
                {
                    reason = 3;
                    goto Lcorrupt;
                }
                char *string_tab = (char *)(buf + string_section->sh_offset);

                for (unsigned offset = 0; offset < section->sh_size; offset += sizeof(Elf64_Sym))
                {   Elf64_Sym *sym = (Elf64_Sym *)(buf + section->sh_offset + offset);

                    if (((sym->st_info >> 4) == STB_GLOBAL ||
                         (sym->st_info >> 4) == STB_WEAK) &&
                        sym->st_shndx != SHT_UNDEF)     // not extern
                    {
                        char *name = string_tab + sym->st_name;
                        //printf("sym st_name = x%x\n", sym->st_name);
                        addSymbol(om, name, 1);
                    }
                }
            }
        }
    }
    else
    {
        error("ELF object module %s is unrecognized class %d", om->name, buf[EI_CLASS]);
        return;
    }

#if 0
    /* String table section
     */
    Elf32_Shdr *string_section = (Elf32_Shdr *)(buf + eh->e_shoff +
        eh->e_shentsize * eh->e_shstrndx);
    if (string_section->sh_type != SHT_STRTAB)
    {
        //printf("buf = %p, e_shentsize = %d, e_shstrndx = %d\n", buf, eh->e_shentsize, eh->e_shstrndx);
        //printf("sh_type = %d, SHT_STRTAB = %d\n", string_section->sh_type, SHT_STRTAB);
        reason = 2;
        goto Lcorrupt;
    }
    printf("strtab sh_offset = x%x\n", string_section->sh_offset);
    char *string_tab = (char *)(buf + string_section->sh_offset);
#endif

}

/***************************************
 * Add object module or library to the library.
 * Examine the buffer to see which it is.
 * If the buffer is NULL, use module_name as the file name
 * and load the file.
 */

void Library::addObject(const char *module_name, void *buf, size_t buflen)
{
    if (!module_name)
        module_name = "";
#if LOG
    printf("Library::addObject(%s)\n", module_name);
#endif
    int fromfile = 0;
    if (!buf)
    {   assert(module_name[0]);
        FileName f((char *)module_name, 0);
        File file(&f);
        file.readv();
        buf = file.buffer;
        buflen = file.len;
        file.ref = 1;
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
            {   reason = 1;
                goto Lcorrupt;
            }
            Header *header = (Header *)((unsigned char *)buf + offset);
            offset += sizeof(Header);
            char *endptr = NULL;
            unsigned long size = strtoul(header->file_size, &endptr, 10);
            if (endptr >= &header->file_size[10] || *endptr != ' ')
            {   reason = 2;
                goto Lcorrupt;
            }
            if (offset + size > buflen)
            {   reason = 3;
                goto Lcorrupt;
            }

            if (header->object_name[0] == '/' &&
                header->object_name[1] == ' ')
            {
                /* Instead of rescanning the object modules we pull from a
                 * library, just use the already created symbol table.
                 */
                if (symtab)
                {   reason = 4;
                    goto Lcorrupt;
                }
                symtab = (char *)buf + offset;
                symtab_size = size;
                if (size < 4)
                {   reason = 5;
                    goto Lcorrupt;
                }
            }
            else if (header->object_name[0] == '/' &&
                     header->object_name[1] == '/')
            {
                /* This is the file name table, save it for later.
                 */
                if (filenametab)
                {   reason = 6;
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
                        {   reason = 8;
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
                om->scan = 0;
                objmodules.push(om);
            }
            offset += (size + 1) & ~1;
        }
        if (offset != buflen)
        {   reason = 9;
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
        {   reason = 10;
            goto Lcorrupt;
        }
        for (unsigned i = 0; i < nsymbols; i++)
        {   char *name = s;
            s += strlen(name) + 1;
            if (s - symtab > symtab_size)
            {   reason = 11;
                goto Lcorrupt;
            }
            unsigned moff = sgetl(symtab + 4 + i * 4);
//printf("symtab[%d] moff = %x  %x, name = %s\n", i, moff, moff + sizeof(Header), name);
            for (unsigned m = mstart; 1; m++)
            {   if (m == objmodules.dim)
                {   reason = 12;
                    goto Lcorrupt;              // didn't find it
                }
                ObjModule *om = objmodules.tdata()[m];
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

    if (memcmp(buf, elf, 4) != 0)
    {   reason = 13;
        goto Lcorrupt;
    }

    /* It's an ELF object module
     */
    ObjModule *om = new ObjModule();
    om->base = (unsigned char *)buf;
    om->length = buflen;
    om->offset = 0;
    om->name = FileName::name(module_name);     // remove path, but not extension
    om->name_offset = -1;
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

void Library::WriteLibToBuffer(OutBuffer *libbuf)
{
#if LOG
    printf("Library::WriteLibToBuffer()\n");
#endif

    /************* Scan Object Modules for Symbols ******************/

    for (int i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];
        if (om->scan)
        {
            scanObjModule(om);
        }
    }

    /************* Determine string section ******************/

    /* The string section is where we store long file names.
     */
    unsigned noffset = 0;
    for (int i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];
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

    for (int i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols.tdata()[i];

        moffset += 4 + strlen(os->name) + 1;
    }
    unsigned hoffset = moffset;

#if LOG
    printf("\tmoffset = x%x\n", moffset);
#endif

    moffset += moffset & 1;
    if (noffset)
         moffset += sizeof(Header) + noffset;

    for (int i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

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

    for (int i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols.tdata()[i];

        sputl(os->om->offset, buf);
        libbuf->write(buf, 4);
    }

    for (int i = 0; i < objsymbols.dim; i++)
    {   ObjSymbol *os = objsymbols.tdata()[i];

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

        for (int i = 0; i < objmodules.dim; i++)
        {   ObjModule *om = objmodules.tdata()[i];
            if (om->name_offset >= 0)
            {   libbuf->writestring(om->name);
                libbuf->writeByte('/');
                libbuf->writeByte('\n');
            }
        }
    }

    /* Write out each of the object modules
     */
    for (int i = 0; i < objmodules.dim; i++)
    {   ObjModule *om = objmodules.tdata()[i];

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
