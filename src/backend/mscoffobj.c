
// Copyright (c) 2009-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gpl.txt.
// See the included readme.txt for details.


#if SCPP || MARS
#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <sys/types.h>
#include        <sys/stat.h>
#include        <fcntl.h>
#include        <ctype.h>

#if _WIN32 || linux
#include        <malloc.h>
#endif

#include        "cc.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"
#include        "mach.h"
#include        "outbuf.h"
#include        "filespec.h"
#include        "cv4.h"
#include        "cgcv.h"
#include        "dt.h"

#include        "aa.h"
#include        "tinfo.h"

#if OMFOBJ

#if MARS
#include        "mars.h"
#endif

#include        "mscoff.h"

static Outbuffer *fobjbuf;

//regm_t BYTEREGS = BYTEREGS_INIT;
//regm_t ALLREGS = ALLREGS_INIT;

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"

#define DEST_LEN (IDMAX + IDOHD + 1)
char *obj_mangle2(Symbol *s,char *dest);

#if MARS
// C++ name mangling is handled by front end
#define cpp_mangle(s) ((s)->Sident)
#endif


/******************************************
 */

static long elf_align(targ_size_t size, long offset);

// The object file is built ib several separate pieces


// String Table  - String table for all other names
static Outbuffer *symtab_strings;

// Section Headers
Outbuffer  *SECbuf;             // Buffer to build section table in
#define SecHdrTab   ((struct scnhdr *)SECbuf->buf)

// The relocation for text and data seems to get lost.
// Try matching the order gcc output them
// This means defining the sections and then removing them if they are
// not used.
static int section_cnt;         // Number of sections in table
#define SEC_TAB_INIT 16         // Initial number of sections in buffer
#define SEC_TAB_INC  4          // Number of sections to increment buffer by

#define SYM_TAB_INIT 100        // Initial number of symbol entries in buffer
#define SYM_TAB_INC  50         // Number of symbols to increment buffer by

/* Three symbol tables, because the different types of symbols
 * are grouped into 3 different types (and a 4th for comdef's).
 */

static Outbuffer *local_symbuf;
static Outbuffer *public_symbuf;
static Outbuffer *extern_symbuf;

struct Comdef { symbol *sym; targ_size_t size; int count; };
static Outbuffer *comdef_symbuf;        // Comdef's are stored here

static Outbuffer *indirectsymbuf1;      // indirect symbol table of Symbol*'s
static int jumpTableSeg;                // segment index for __jump_table

static Outbuffer *indirectsymbuf2;      // indirect symbol table of Symbol*'s
static int pointersSeg;                 // segment index for __pointers

/* If an MsCoffObj::external_def() happens, set this to the string index,
 * to be added last to the symbol table.
 * Obviously, there can be only one.
 */
static IDXSTR extdef;

// Each compiler segment is a section
// Predefined compiler segments CODE,DATA,CDATA,UDATA map to indexes
//      into SegData[]
//      New compiler segments are added to end.

/******************************
 * Returns !=0 if this segment is a code segment.
 */

int seg_data::isCode()
{
    return (SecHdrTab[SDshtidx].s_flags & IMAGE_SCN_CNT_CODE) != 0;
}


seg_data **SegData;
int seg_count;
int seg_max;
int seg_tlsseg = UNKNOWN;
int seg_tlsseg_bss = UNKNOWN;

/*******************************************************
 * Because the mscoff relocations cannot be computed until after
 * all the segments are written out, and we need more information
 * than the mscoff relocations provide, make our own relocation
 * type. Later, translate to mscoff relocation structure.
 */

struct Relocation
{   // Relocations are attached to the struct seg_data they refer to
    targ_size_t offset; // location in segment to be fixed up
    symbol *funcsym;    // function in which offset lies, if any
    symbol *targsym;    // if !=NULL, then location is to be fixed up
                        // to address of this symbol
    unsigned targseg;   // if !=0, then location is to be fixed up
                        // to address of start of this segment
    unsigned char rtype;   // RELxxxx
#define RELaddr 0       // straight address
#define RELrel  1       // relative to location to be fixed up
    short val;          // 0, -1, -2, -4
};


/*******************************
 * Output a string into a string table
 * Input:
 *      strtab  =       string table for entry
 *      str     =       string to add
 *
 * Returns index into the specified string table.
 */

IDXSTR MsCoffObj::addstr(Outbuffer *strtab, const char *str)
{
    //printf("MsCoffObj::addstr(strtab = %p str = '%s')\n",strtab,str);
    IDXSTR idx = strtab->size();        // remember starting offset
    strtab->writeString(str);
    //printf("\tidx %d, new size %d\n",idx,strtab->size());
    return idx;
}

/*******************************
 * Find a string in a string table
 * Input:
 *      strtab  =       string table for entry
 *      str     =       string to find
 *
 * Returns index into the specified string table or 0.
 */

static IDXSTR elf_findstr(Outbuffer *strtab, const char *str, const char *suffix)
{
    const char *ent = (char *)strtab->buf+1;
    const char *pend = ent+strtab->size() - 1;
    const char *s = str;
    const char *sx = suffix;
    int len = strlen(str);

    if (suffix)
        len += strlen(suffix);

    while(ent < pend)
    {
        if(*ent == 0)                   // end of table entry
        {
            if(*s == 0 && !sx)          // end of string - found a match
            {
                return ent - (const char *)strtab->buf - len;
            }
            else                        // table entry too short
            {
                s = str;                // back to beginning of string
                sx = suffix;
                ent++;                  // start of next table entry
            }
        }
        else if (*s == 0 && sx && *sx == *ent)
        {                               // matched first string
            s = sx+1;                   // switch to suffix
            ent++;
            sx = NULL;
        }
        else                            // continue comparing
        {
            if (*ent == *s)
            {                           // Have a match going
                ent++;
                s++;
            }
            else                        // no match
            {
                while(*ent != 0)        // skip to end of entry
                    ent++;
                ent++;                  // start of next table entry
                s = str;                // back to beginning of string
                sx = suffix;
            }
        }
    }
    return 0;                   // never found match
}

/*******************************
 * Output a mangled string into the symbol string table
 * Input:
 *      str     =       string to add
 *
 * Returns index into the table.
 */

static IDXSTR elf_addmangled(Symbol *s)
{
    //printf("elf_addmangled(%s)\n", s->Sident);
    char dest[DEST_LEN];

    IDXSTR namidx = symtab_strings->size();
    char *destr = obj_mangle2(s, dest);
    const char *name = destr;
    if (CPP && name[0] == '_' && name[1] == '_')
    {
        if (strncmp(name,"__ct__",6) == 0)
            name += 4;
#if 0
        switch(name[2])
        {
            case 'c':
                if (strncmp(name,"__ct__",6) == 0)
                    name += 4;
                break;
            case 'd':
                if (strcmp(name,"__dl__FvP") == 0)
                    name = "__builtin_delete";
                break;
            case 'v':
                //if (strcmp(name,"__vec_delete__FvPiUIPi") == 0)
                    //name = "__builtin_vec_del";
                //else
                //if (strcmp(name,"__vn__FPUI") == 0)
                    //name = "__builtin_vec_new";
                break;
            case 'n':
                if (strcmp(name,"__nw__FPUI") == 0)
                    name = "__builtin_new";
                break;
        }
#endif
    }
    else if (tyfunc(s->ty()) && s->Sfunc && s->Sfunc->Fredirect)
        name = s->Sfunc->Fredirect;
    size_t len = strlen(name);
    symtab_strings->reserve(len+1);
    strcpy((char *)symtab_strings->p,name);
    symtab_strings->setsize(namidx+len+1);
    if (destr != dest)                  // if we resized result
        mem_free(destr);
    //dbg_printf("\telf_addmagled symtab_strings %s namidx %d len %d size %d\n",name, namidx,len,symtab_strings->size());
    return namidx;
}

/**************************
 * Ouput read only data and generate a symbol for it.
 *
 */

symbol * MsCoffObj::sym_cdata(tym_t ty,char *p,int len)
{
    symbol *s;

#if 0
    if (I64)
    {
        alignOffset(DATA, tysize(ty));
        s = symboldata(Doffset, ty);
        SegData[DATA]->SDbuf->write(p,len);
        s->Sseg = DATA;
        s->Soffset = Doffset;   // Remember its offset into DATA section
        Doffset += len;
    }
    else
#endif
    {
        //printf("MsCoffObj::sym_cdata(ty = %x, p = %x, len = %d, CDoffset = %x)\n", ty, p, len, CDoffset);
        alignOffset(CDATA, tysize(ty));
        s = symboldata(CDoffset, ty);
        s->Sseg = CDATA;
        //MsCoffObj::pubdef(CDATA, s, CDoffset);
        MsCoffObj::bytes(CDATA, CDoffset, len, p);
    }

    s->Sfl = FLextern;
    return s;
}

/**************************
 * Ouput read only data for data
 *
 */

int MsCoffObj::data_readonly(char *p, int len, int *pseg)
{
    int oldoff;
    if (I64)
    {
        oldoff = Doffset;
        SegData[DATA]->SDbuf->reserve(len);
        SegData[DATA]->SDbuf->writen(p,len);
        Doffset += len;
        *pseg = DATA;
    }
    else
    {
        oldoff = CDoffset;
        SegData[CDATA]->SDbuf->reserve(len);
        SegData[CDATA]->SDbuf->writen(p,len);
        CDoffset += len;
        *pseg = CDATA;
    }
    return oldoff;
}

int MsCoffObj::data_readonly(char *p, int len)
{
    int pseg;

    return MsCoffObj::data_readonly(p, len, &pseg);
}

/******************************
 * Perform initialization that applies to all .o output files.
 *      Called before any other obj_xxx routines
 */

MsCoffObj *MsCoffObj::init(Outbuffer *objbuf, const char *filename, const char *csegname)
{
    //printf("MsCoffObj::init()\n");
    MsCoffObj *obj = new MsCoffObj();

    cseg = CODE;
    fobjbuf = objbuf;

    seg_tlsseg = UNKNOWN;
    seg_tlsseg_bss = UNKNOWN;

    // Initialize buffers

    if (symtab_strings)
        symtab_strings->setsize(1);
    else
    {   symtab_strings = new Outbuffer(1024);
        symtab_strings->reserve(2048);
        symtab_strings->writeByte(0);
    }

    if (!local_symbuf)
        local_symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    local_symbuf->setsize(0);

    if (!public_symbuf)
        public_symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    public_symbuf->setsize(0);

    if (!extern_symbuf)
        extern_symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    extern_symbuf->setsize(0);

    if (!comdef_symbuf)
        comdef_symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    comdef_symbuf->setsize(0);

    extdef = 0;

    if (indirectsymbuf1)
        indirectsymbuf1->setsize(0);
    jumpTableSeg = 0;

    if (indirectsymbuf2)
        indirectsymbuf2->setsize(0);
    pointersSeg = 0;

    // Initialize segments for CODE, DATA, UDATA and CDATA
    size_t struct_section_size = sizeof(struct scnhdr);
    if (SECbuf)
    {
        SECbuf->setsize(struct_section_size);
    }
    else
    {
        SECbuf = new Outbuffer(SYM_TAB_INC * struct_section_size);
        SECbuf->reserve(SEC_TAB_INIT * struct_section_size);
        // Ignore the first section - section numbers start at 1
        SECbuf->writezeros(struct_section_size);
    }
    section_cnt = 1;

    seg_count = 0;
    int align = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_8BYTES;
    MsCoffObj::getsegment(".text",  IMAGE_SCN_CNT_CODE |
                              align |
                              IMAGE_SCN_MEM_EXECUTE |
                              IMAGE_SCN_MEM_READ);              // CODE
    MsCoffObj::getsegment(".data",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                              IMAGE_SCN_ALIGN_4BYTES |
                              IMAGE_SCN_MEM_READ |
                              IMAGE_SCN_MEM_WRITE);             // DATA
    MsCoffObj::getsegment(".rdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                              IMAGE_SCN_ALIGN_4BYTES |
                              IMAGE_SCN_MEM_READ);              // CDATA
    MsCoffObj::getsegment(".bss",   IMAGE_SCN_CNT_UNINITIALIZED_DATA |
                              IMAGE_SCN_ALIGN_4BYTES |
                              IMAGE_SCN_MEM_READ |
                              IMAGE_SCN_MEM_WRITE);        // UDATA

//    if (config.fulltypes)
//        dwarf_initfile(filename);
    return obj;
}

/**************************
 * Initialize the start of object output for this particular .o file.
 *
 * Input:
 *      filename:       Name of source file
 *      csegname:       User specified default code segment name
 */

void MsCoffObj::initfile(const char *filename, const char *csegname, const char *modname)
{
    //dbg_printf("MsCoffObj::initfile(filename = %s, modname = %s)\n",filename,modname);
#if SCPP
    if (csegname && *csegname && strcmp(csegname,".text"))
    {   // Define new section and make it the default for cseg segment
        // NOTE: cseg is initialized to CODE
        IDXSEC newsecidx;
        Elf32_Shdr *newtextsec;
        IDXSYM newsymidx;
        assert(!I64);      // fix later
        SegData[cseg]->SDshtidx = newsecidx =
            elf_newsection(csegname,0,SHT_PROGDEF,SHF_ALLOC|SHF_EXECINSTR);
        newtextsec = &SecHdrTab[newsecidx];
        newtextsec->sh_addralign = 4;
        SegData[cseg]->SDsymidx =
            elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, newsecidx);
    }
#endif
//    if (config.fulltypes)
//        dwarf_initmodule(filename, modname);
}

/************************************
 * Patch pseg/offset by adding in the vmaddr difference from
 * pseg/offset to start of seg.
 */

int32_t *patchAddr(int seg, targ_size_t offset)
{
    return(int32_t *)(fobjbuf->buf + SecHdrTab[SegData[seg]->SDshtidx].s_scnptr + offset);
}

int32_t *patchAddr64(int seg, targ_size_t offset)
{
    return(int32_t *)(fobjbuf->buf + SecHdrTab[SegData[seg]->SDshtidx].s_scnptr + offset);
}

void patch(seg_data *pseg, targ_size_t offset, int seg, targ_size_t value)
{
    //printf("patch(offset = x%04x, seg = %d, value = x%llx)\n", (unsigned)offset, seg, value);
    if (I64)
    {
        int32_t *p = (int32_t *)(fobjbuf->buf + SecHdrTab[pseg->SDshtidx].s_scnptr  + offset);
#if 0
        printf("\taddr1 = x%llx\n\taddr2 = x%llx\n\t*p = x%llx\n\tdelta = x%llx\n",
            SecHdrTab[pseg->SDshtidx].s_vaddr,
            SecHdrTab[SegData[seg]->SDshtidx].s_vaddr,
            *p,
            SecHdrTab[SegData[seg]->SDshtidx].s_vaddr -
            (SecHdrTab[pseg->SDshtidx].s_vaddr + offset));
#endif
        *p += SecHdrTab[SegData[seg]->SDshtidx].s_vaddr -
              (SecHdrTab[pseg->SDshtidx].s_vaddr - value);
    }
    else
    {
        int32_t *p = (int32_t *)(fobjbuf->buf + SecHdrTab[pseg->SDshtidx].s_scnptr + offset);
#if 0
        printf("\taddr1 = x%x\n\taddr2 = x%x\n\t*p = x%x\n\tdelta = x%x\n",
            SecHdrTab[pseg->SDshtidx].s_vaddr,
            SecHdrTab[SegData[seg]->SDshtidx].s_vaddr,
            *p,
            SecHdrTab[SegData[seg]->SDshtidx].s_vaddr -
            (SecHdrTab[pseg->SDshtidx].s_vaddr + offset));
#endif
        *p += SecHdrTab[SegData[seg]->SDshtidx].s_vaddr -
              (SecHdrTab[pseg->SDshtidx].s_vaddr - value);
    }
}

/***************************
 * Number symbols so they are
 * ordered as locals, public and then extern/comdef
 */

void mach_numbersyms()
{
    //printf("mach_numbersyms()\n");
    int n = 0;

    int dim;
    dim = local_symbuf->size() / sizeof(symbol *);
    for (int i = 0; i < dim; i++)
    {   symbol *s = ((symbol **)local_symbuf->buf)[i];
        s->Sxtrnnum = n;
        n++;
    }

    dim = public_symbuf->size() / sizeof(symbol *);
    for (int i = 0; i < dim; i++)
    {   symbol *s = ((symbol **)public_symbuf->buf)[i];
        s->Sxtrnnum = n;
        n++;
    }

    dim = extern_symbuf->size() / sizeof(symbol *);
    for (int i = 0; i < dim; i++)
    {   symbol *s = ((symbol **)extern_symbuf->buf)[i];
        s->Sxtrnnum = n;
        n++;
    }

    dim = comdef_symbuf->size() / sizeof(Comdef);
    for (int i = 0; i < dim; i++)
    {   Comdef *c = ((Comdef *)comdef_symbuf->buf) + i;
        c->sym->Sxtrnnum = n;
        n++;
    }
}


/***************************
 * Fixup and terminate object file.
 */

void MsCoffObj::termfile()
{
    //dbg_printf("MsCoffObj::termfile\n");
    if (configv.addlinenumbers)
    {
        //dwarf_termmodule();
    }
}

/*********************************
 * Terminate package.
 */

void MsCoffObj::term()
{
    //printf("MsCoffObj::term()\n");
#if SCPP
    if (!errcnt)
#endif
    {
        outfixlist();           // backpatches
    }

    if (configv.addlinenumbers)
    {
        //dwarf_termfile();
    }

#if SCPP
    if (errcnt)
        return;
#endif

    /* Write out the object file in the following order:
     *  header
     *  commands
     *          segment_command
     *                  { sections }
     *          symtab_command
     *          dysymtab_command
     *  { segment contents }
     *  { relocations }
     *  symbol table
     *  string table
     *  indirect symbol table
     */

    unsigned foffset;
    unsigned headersize;
    unsigned sizeofcmds;

    // Write out the bytes for the header
    if (I64)
    {
        struct filehdr header;

        header.f_magic = IMAGE_FILE_MACHINE_AMD64;
        header.f_nscns = section_cnt - 1;
        header.f_timdat = 0;
        header.f_symptr = 0;
        header.f_nsyms = 0;
        header.f_opthdr = 0;
        header.f_flags = 0;
        fobjbuf->write(&header, sizeof(header));

        foffset = sizeof(header);       // start after header
        headersize = sizeof(header);
//        sizeofcmds = header.sizeofcmds;

        // Write the actual data later
//        fobjbuf->writezeros(header.sizeofcmds);
//        foffset += header.sizeofcmds;
    }
    else
    {
        struct filehdr header;

        header.f_magic = IMAGE_FILE_MACHINE_I386;
        header.f_nscns = section_cnt - 1;
        header.f_timdat = 0;
        header.f_symptr = 0;
        header.f_nsyms = 0;
        header.f_opthdr = 0;
        header.f_flags = 0;
        fobjbuf->write(&header, sizeof(header));

        fobjbuf->write(&header, sizeof(header));
        foffset = sizeof(header);       // start after header
        headersize = sizeof(header);
//        sizeofcmds = header.sizeofcmds;

        // Write the actual data later
//        fobjbuf->writezeros(header.sizeofcmds);
//        foffset += header.sizeofcmds;
    }

    struct syment segment_cmd;
    struct symtab_command symtab_cmd;
    struct dysymtab_command dysymtab_cmd;

    memset(&segment_cmd, 0, sizeof(segment_cmd));
    memset(&symtab_cmd, 0, sizeof(symtab_cmd));
    memset(&dysymtab_cmd, 0, sizeof(dysymtab_cmd));

#if 0
    segment_cmd.cmd = LC_SEGMENT;
    segment_cmd.cmdsize = sizeof(segment_cmd) +
                                (section_cnt - 1) * sizeof(struct section);
    segment_cmd.nsects = section_cnt - 1;
    segment_cmd.maxprot = 7;
    segment_cmd.initprot = 7;

    symtab_cmd.cmd = LC_SYMTAB;
    symtab_cmd.cmdsize = sizeof(symtab_cmd);

    dysymtab_cmd.cmd = LC_DYSYMTAB;
    dysymtab_cmd.cmdsize = sizeof(dysymtab_cmd);

    /* If a __pointers section was emitted, need to set the .reserved1
     * field to the symbol index in the indirect symbol table of the
     * start of the __pointers symbols.
     */
    if (pointersSeg)
    {
        seg_data *pseg = SegData[pointersSeg];
        if (I64)
        {
            struct section_64 *psechdr = &SecHdrTab64[pseg->SDshtidx]; // corresponding section
            psechdr->reserved1 = indirectsymbuf1
                ? indirectsymbuf1->size() / sizeof(Symbol *)
                : 0;
        }
        else
        {
            struct section *psechdr = &SecHdrTab[pseg->SDshtidx]; // corresponding section
            psechdr->reserved1 = indirectsymbuf1
                ? indirectsymbuf1->size() / sizeof(Symbol *)
                : 0;
        }
    }

    // Walk through sections determining size and file offsets

    //
    // First output individual section data associate with program
    //  code and data
    //
    foffset = elf_align(I64 ? 8 : 4, foffset);
    segment_cmd.fileoff = foffset;
    unsigned vmaddr = 0;

    //printf("Setup offsets and sizes foffset %d\n\tsection_cnt %d, seg_count %d\n",foffset,section_cnt,seg_count);
    // Zero filled segments go at the end, so go through segments twice
    for (int i = 0; i < 2; i++)
    {
        for (int seg = 1; seg <= seg_count; seg++)
        {
            seg_data *pseg = SegData[seg];
            if (I64)
            {
                struct section_64 *psechdr = &SecHdrTab64[pseg->SDshtidx]; // corresponding section

                // Do zero-fill the second time through this loop
                if (i ^ (psechdr->flags == S_ZEROFILL))
                    continue;

                int align = 1 << psechdr->align;
                while (align < pseg->SDalignment)
                {
                    psechdr->align += 1;
                    align <<= 1;
                }
                foffset = elf_align(align, foffset);
                vmaddr = (vmaddr + align - 1) & ~(align - 1);
                if (psechdr->flags == S_ZEROFILL)
                {
                    psechdr->offset = 0;
                    psechdr->size = pseg->SDoffset; // accumulated size
                }
                else
                {
                    psechdr->offset = foffset;
                    psechdr->size = 0;
                    //printf("\tsection name %s,", psechdr->sectname);
                    if (pseg->SDbuf && pseg->SDbuf->size())
                    {
                        //printf("\tsize %d\n", pseg->SDbuf->size());
                        psechdr->size = pseg->SDbuf->size();
                        fobjbuf->write(pseg->SDbuf->buf, psechdr->size);
                        foffset += psechdr->size;
                    }
                }
                psechdr->addr = vmaddr;
                vmaddr += psechdr->size;
                //printf(" assigned offset %d, size %d\n", foffset, psechdr->sh_size);
            }
            else
            {
                struct section *psechdr = &SecHdrTab[pseg->SDshtidx]; // corresponding section

                // Do zero-fill the second time through this loop
                if (i ^ (psechdr->flags == S_ZEROFILL))
                    continue;

                int align = 1 << psechdr->align;
                while (align < pseg->SDalignment)
                {
                    psechdr->align += 1;
                    align <<= 1;
                }
                foffset = elf_align(align, foffset);
                vmaddr = (vmaddr + align - 1) & ~(align - 1);
                if (psechdr->flags == S_ZEROFILL)
                {
                    psechdr->offset = 0;
                    psechdr->size = pseg->SDoffset; // accumulated size
                }
                else
                {
                    psechdr->offset = foffset;
                    psechdr->size = 0;
                    //printf("\tsection name %s,", psechdr->sectname);
                    if (pseg->SDbuf && pseg->SDbuf->size())
                    {
                        //printf("\tsize %d\n", pseg->SDbuf->size());
                        psechdr->size = pseg->SDbuf->size();
                        fobjbuf->write(pseg->SDbuf->buf, psechdr->size);
                        foffset += psechdr->size;
                    }
                }
                psechdr->addr = vmaddr;
                vmaddr += psechdr->size;
                //printf(" assigned offset %d, size %d\n", foffset, psechdr->sh_size);
            }
        }
    }

    if (I64)
    {
        segment_cmd64.vmsize = vmaddr;
        segment_cmd64.filesize = foffset - segment_cmd64.fileoff;
        /* Bugzilla 5331: Apparently having the filesize field greater than the vmsize field is an
         * error, and is happening sometimes.
         */
        if (segment_cmd64.filesize > vmaddr)
            segment_cmd64.vmsize = segment_cmd64.filesize;
    }
    else
    {
        segment_cmd.vmsize = vmaddr;
        segment_cmd.filesize = foffset - segment_cmd.fileoff;
        /* Bugzilla 5331: Apparently having the filesize field greater than the vmsize field is an
         * error, and is happening sometimes.
         */
        if (segment_cmd.filesize > vmaddr)
            segment_cmd.vmsize = segment_cmd.filesize;
    }

    // Put out relocation data
    mach_numbersyms();
    for (int seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &SecHdrTab[pseg->SDshtidx];   // corresponding section
        //printf("psechdr->addr = x%x\n", psechdr->addr);

        foffset = elf_align(I64 ? 8 : 4, foffset);
        unsigned reloff = foffset;
        unsigned nreloc = 0;
        if (pseg->SDrel)
        {   Relocation *r = (Relocation *)pseg->SDrel->buf;
            Relocation *rend = (Relocation *)(pseg->SDrel->buf + pseg->SDrel->size());
            for (; r != rend; r++)
            {   symbol *s = r->targsym;
                const char *rs = r->rtype == RELaddr ? "addr" : "rel";
                //printf("%d:x%04llx : tseg %d tsym %s REL%s\n", seg, r->offset, r->targseg, s ? s->Sident : "0", rs);
                relocation_info rel;
                scattered_relocation_info srel;
                if (s)
                {
                    //printf("Relocation\n");
                    //symbol_print(s);
                    if (pseg->isCode())
                    {
                        if (I64)
                        {
                            rel.r_type = (r->rtype == RELrel)
                                    ? IMAGE_REL_AMD64_REL32
                                    : IMAGE_REL_AMD64_SREL32;
                            if (r->val == -1)
                                rel.r_type = IMAGE_REL_AMD64_SREL32_1;
                            else if (r->val == -2)
                                rel.r_type = IMAGE_REL_AMD64_SREL32_2;
                            if (r->val == -4)
                                rel.r_type = IMAGE_REL_AMD64_SREL32_4;

                            if (s->Sclass == SCextern ||
                                s->Sclass == SCcomdef ||
                                s->Sclass == SCcomdat ||
                                s->Sclass == SCglobal)
                            {
                                if ((s->Sfl == FLfunc ||
                                     s->Sfl == FLextern ||
                                     s->Sclass == SCglobal ||
                                     s->Sclass == SCcomdat ||
                                     s->Sclass == SCcomdef) && r->rtype == RELaddr)
                                    rel.r_type = IMAGE_REL_AMD64_GOT_LOAD;
                                rel.r_address = r->offset;
                                rel.r_symbolnum = s->Sxtrnnum;
                                rel.r_pcrel = 1;
                                rel.r_length = 2;
                                rel.r_extern = 1;
                                fobjbuf->write(&rel, sizeof(rel));
                                foffset += sizeof(rel);
                                nreloc++;
                                continue;
                            }
                            else
                            {
                                rel.r_address = r->offset;
                                rel.r_symbolnum = s->Sseg;
                                rel.r_pcrel = 1;
                                rel.r_length = 2;
                                rel.r_extern = 0;
                                fobjbuf->write(&rel, sizeof(rel));
                                foffset += sizeof(rel);
                                nreloc++;

                                int32_t *p = patchAddr64(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
//printf("*p = x%x, .s_vaddr = x%x, Soffset = x%x\n", *p, (int)SecHdrTab64[SegData[s->Sseg]->SDshtidx].s_vaddr, (int)s->Soffset);
//printf("pseg = x%x, r->offset = x%x\n", (int)SecHdrTab64[pseg->SDshtidx].s_vaddr, (int)r->offset);
                                *p += SecHdrTab64[SegData[s->Sseg]->SDshtidx].s_vaddr;
                                *p += s->Soffset;
                                *p -= SecHdrTab64[pseg->SDshtidx].s_vaddr + r->offset + 4;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
                                continue;
                            }
                        }
                    }
                    else
                    {
                        if (s->Sclass == SCextern ||
                            s->Sclass == SCcomdef ||
                            s->Sclass == SCcomdat)
                        {
                            rel.r_address = r->offset;
                            rel.r_symbolnum = s->Sxtrnnum;
                            rel.r_pcrel = 0;
                            rel.r_length = 2;
                            rel.r_extern = 1;
                            rel.r_type = IMAGE_REL_I386_DIR32;
                            if (I64)
                            {
                                rel.r_type = IMAGE_REL_AMD64_ADDR32;
                                rel.r_length = 3;
                            }
                            fobjbuf->write(&rel, sizeof(rel));
                            foffset += sizeof(rel);
                            nreloc++;
                            continue;
                        }
                        else
                        {
                            rel.r_address = r->offset;
                            rel.r_symbolnum = s->Sseg;
                            rel.r_pcrel = 0;
                            rel.r_length = 2;
                            rel.r_extern = 0;
                            rel.r_type = IMAGE_REL_I386_DIR32;
                            if (I64)
                            {
                                rel.r_type = IMAGE_REL_AMD64_ADDR32;
                                rel.r_length = 3;
                                if (0 && s->Sseg != seg)
                                    rel.r_type = IMAGE_REL_AMD64_REL32;
                            }
                            fobjbuf->write(&rel, sizeof(rel));
                            foffset += sizeof(rel);
                            nreloc++;
                            if (I64)
                            {
                                rel.r_length = 3;
                                int32_t *p = patchAddr64(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
                                *p += SecHdrTab64[SegData[s->Sseg]->SDshtidx].s_vaddr + s->Soffset;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
                            }
                            else
                            {
                                int32_t *p = patchAddr(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
                                *p += SecHdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr + s->Soffset;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
                            }
                            continue;
                        }
                    }
                }
                else if (r->rtype == RELaddr && pseg->isCode())
                {
                    int32_t *p = NULL;
                    int32_t *p64 = NULL;
                    if (I64)
                        p64 = patchAddr64(seg, r->offset);
                    else
                        p = patchAddr(seg, r->offset);
                    srel.r_scattered = 1;

                    srel.r_address = r->offset;
                    srel.r_length = 2;
                    if (I64)
                    {
                        srel.r_type = IMAGE_REL_AMD64_SSPAN32;
                        srel.r_value = SecHdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr + *p64;
                        //printf("SECTDIFF: x%llx + x%llx = x%x\n", SecHdrTab[SegData[r->targseg]->SDshtidx].s_vaddr, *p, srel.r_value);
                    }
                    else
                    {
                        srel.r_type = IMAGE_REL_I386_SECREL;
                        srel.r_value = SecHdrTab[SegData[r->targseg]->SDshtidx].s_vaddr + *p;
                        //printf("SECTDIFF: x%x + x%x = x%x\n", SecHdrTab[SegData[r->targseg]->SDshtidx].s_vaddr, *p, srel.r_value);
                    }
                    srel.r_pcrel = 0;
                    fobjbuf->write(&srel, sizeof(srel));
                    foffset += sizeof(srel);
                    nreloc++;

                    srel.r_address = 0;
                    //srel.r_type = GENERIC_RELOC_PAIR;
                    srel.r_length = 2;
                    if (I64)
                        srel.r_value = SecHdrTab64[pseg->SDshtidx].s_vaddr +
                                r->funcsym->Slocalgotoffset + NPTRSIZE;
                    else
                        srel.r_value = SecHdrTab[pseg->SDshtidx].s_vaddr +
                                r->funcsym->Slocalgotoffset + NPTRSIZE;
                    srel.r_pcrel = 0;
                    fobjbuf->write(&srel, sizeof(srel));
                    foffset += sizeof(srel);
                    nreloc++;

                    // Recalc due to possible realloc of fobjbuf->buf
                    if (I64)
                    {
                        p64 = patchAddr64(seg, r->offset);
                        //printf("address = x%x, p64 = %p *p64 = x%llx\n", r->offset, p64, *p64);
                        *p64 += SecHdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr -
                              (SecHdrTab64[pseg->SDshtidx].s_vaddr + r->funcsym->Slocalgotoffset + NPTRSIZE);
                    }
                    else
                    {
                        p = patchAddr(seg, r->offset);
                        //printf("address = x%x, p = %p *p = x%x\n", r->offset, p, *p);
                        *p += SecHdrTab[SegData[r->targseg]->SDshtidx].s_vaddr -
                              (SecHdrTab[pseg->SDshtidx].s_vaddr + r->funcsym->Slocalgotoffset + NPTRSIZE);
                    }
                    continue;
                }
                else
                {
                    rel.r_address = r->offset;
                    rel.r_symbolnum = r->targseg;
                    rel.r_pcrel = (r->rtype == RELaddr) ? 0 : 1;
                    rel.r_length = 2;
                    rel.r_extern = 0;
                    rel.r_type = GENERIC_RELOC_VANILLA;
                    if (I64)
                    {
                        rel.r_type = IMAGE_REL_AMD64_SECREL;
                        rel.r_length = 3;
                        if (0 && r->targseg != seg)
                            rel.r_type = IMAGE_REL_AMD64_REL32;
                    }
                    fobjbuf->write(&rel, sizeof(rel));
                    foffset += sizeof(rel);
                    nreloc++;
                    if (I64)
                    {
                        int32_t *p64 = patchAddr64(seg, r->offset);
                        //int64_t before = *p64;
                        if (rel.r_pcrel)
                            // Relative address
                            patch(pseg, r->offset, r->targseg, 0);
                        else
                        {   // Absolute address; add in addr of start of targ seg
//printf("*p = x%x, targ.s_vaddr = x%x\n", *p64, (int)SecHdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr);
//printf("pseg = x%x, r->offset = x%x\n", (int)SecHdrTab64[pseg->SDshtidx].s_vaddr, (int)r->offset);
                            *p64 += SecHdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr;
                            //*p64 -= SecHdrTab64[pseg->SDshtidx].s_vaddr;
                        }
                        //printf("%d:x%04x before = x%04llx, after = x%04llx pcrel = %d\n", seg, r->offset, before, *p64, rel.r_pcrel);
                    }
                    else
                    {
                        int32_t *p = patchAddr(seg, r->offset);
                        //int32_t before = *p;
                        if (rel.r_pcrel)
                            // Relative address
                            patch(pseg, r->offset, r->targseg, 0);
                        else
                            // Absolute address; add in addr of start of targ seg
                            *p += SecHdrTab[SegData[r->targseg]->SDshtidx].s_vaddr;
                        //printf("%d:x%04x before = x%04x, after = x%04x pcrel = %d\n", seg, r->offset, before, *p, rel.r_pcrel);
                    }
                    continue;
                }
            }
        }
        if (nreloc)
        {
            if (I64)
            {
                psechdr64->reloff = reloff;
                psechdr64->nreloc = nreloc;
            }
            else
            {
                psechdr->reloff = reloff;
                psechdr->nreloc = nreloc;
            }
        }
    }

    // Put out symbol table
    foffset = elf_align(I64 ? 8 : 4, foffset);
    symtab_cmd.symoff = foffset;
    dysymtab_cmd.ilocalsym = 0;
    dysymtab_cmd.nlocalsym  = local_symbuf->size() / sizeof(symbol *);
    dysymtab_cmd.iextdefsym = dysymtab_cmd.nlocalsym;
    dysymtab_cmd.nextdefsym = public_symbuf->size() / sizeof(symbol *);
    dysymtab_cmd.iundefsym = dysymtab_cmd.iextdefsym + dysymtab_cmd.nextdefsym;
    int nexterns = extern_symbuf->size() / sizeof(symbol *);
    int ncomdefs = comdef_symbuf->size() / sizeof(Comdef);
    dysymtab_cmd.nundefsym  = nexterns + ncomdefs;
    symtab_cmd.nsyms =  dysymtab_cmd.nlocalsym +
                        dysymtab_cmd.nextdefsym +
                        dysymtab_cmd.nundefsym;
    fobjbuf->reserve(symtab_cmd.nsyms * sizeof(struct nlist));
    for (int i = 0; i < dysymtab_cmd.nlocalsym; i++)
    {   symbol *s = ((symbol **)local_symbuf->buf)[i];
        struct nlist sym;
        sym.n_un.n_strx = elf_addmangled(s);
        sym.n_type = N_SECT;
        sym.n_desc = 0;
        if (s->Sclass == SCcomdat)
            sym.n_desc = N_WEAK_DEF;
        sym.n_sect = s->Sseg;
        sym.n_value = s->Soffset + SecHdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr;
        fobjbuf->write(&sym, sizeof(sym));
    }
    for (int i = 0; i < dysymtab_cmd.nextdefsym; i++)
    {   symbol *s = ((symbol **)public_symbuf->buf)[i];

        //printf("Writing public symbol %d:x%x %s\n", s->Sseg, s->Soffset, s->Sident);
        struct nlist sym;
        sym.n_un.n_strx = elf_addmangled(s);
        sym.n_type = N_EXT | N_SECT;
        sym.n_desc = 0;
        if (s->Sclass == SCcomdat)
            sym.n_desc = N_WEAK_DEF;
        sym.n_sect = s->Sseg;
        sym.n_value = s->Soffset + SecHdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr;
        fobjbuf->write(&sym, sizeof(sym));
    }
    for (int i = 0; i < nexterns; i++)
    {   symbol *s = ((symbol **)extern_symbuf->buf)[i];
        struct nlist sym;
        sym.n_un.n_strx = elf_addmangled(s);
        sym.n_value = s->Soffset;
        sym.n_type = N_EXT | N_UNDF;
        sym.n_desc = tyfunc(s->ty()) ? REFERENCE_FLAG_UNDEFINED_LAZY
                                     : REFERENCE_FLAG_UNDEFINED_NON_LAZY;
        sym.n_sect = 0;
        fobjbuf->write(&sym, sizeof(sym));
    }
    for (int i = 0; i < ncomdefs; i++)
    {   Comdef *c = ((Comdef *)comdef_symbuf->buf) + i;
        struct nlist sym;
        sym.n_un.n_strx = elf_addmangled(c->sym);
        sym.n_value = c->size * c->count;
        sym.n_scnum = IMAGE_SYM_UNDEFINED;
        sym.n_type = 0;
        sym.n_sclass = IMAGE_SYM_CLASS_EXTERNAL;
        sym.n_numaux = 0;

        fobjbuf->write(&sym, sizeof(sym));
    }
    if (extdef)
    {
        struct nlist_64 sym;
        sym.n_un.n_strx = extdef;
        sym.n_value = 0;
        sym.n_type = N_EXT | N_UNDF;
        sym.n_desc = 0;
        sym.n_sect = 0;
        sym.n_numaux = 0;

        fobjbuf->write(&sym, sizeof(sym));
        symtab_cmd.nsyms++;
    }
    foffset += symtab_cmd.nsyms * sizeof(struct nlist);

    // Put out string table
    foffset = elf_align(I64 ? 8 : 4, foffset);
    symtab_cmd.stroff = foffset;
    symtab_cmd.strsize = symtab_strings->size();
    fobjbuf->write(symtab_strings->buf, symtab_cmd.strsize);
    foffset += symtab_cmd.strsize;

    // Put out indirectsym table, which is in two parts
    foffset = elf_align(I64 ? 8 : 4, foffset);
    dysymtab_cmd.indirectsymoff = foffset;
    if (indirectsymbuf1)
    {   dysymtab_cmd.nindirectsyms += indirectsymbuf1->size() / sizeof(Symbol *);
        for (int i = 0; i < dysymtab_cmd.nindirectsyms; i++)
        {   Symbol *s = ((Symbol **)indirectsymbuf1->buf)[i];
            fobjbuf->write32(s->Sxtrnnum);
        }
    }
    if (indirectsymbuf2)
    {   int n = indirectsymbuf2->size() / sizeof(Symbol *);
        dysymtab_cmd.nindirectsyms += n;
        for (int i = 0; i < n; i++)
        {   Symbol *s = ((Symbol **)indirectsymbuf2->buf)[i];
            fobjbuf->write32(s->Sxtrnnum);
        }
    }
    foffset += dysymtab_cmd.nindirectsyms * 4;

    /* The correct offsets are now determined, so
     * rewind and fix the header.
     */
    fobjbuf->position(headersize, sizeofcmds);
    if (I64)
    {
        fobjbuf->write(&segment_cmd64, sizeof(segment_cmd64));
        fobjbuf->write(SECbuf->buf + sizeof(struct section_64), (section_cnt - 1) * sizeof(struct section_64));
    }
    else
    {
        fobjbuf->write(&segment_cmd, sizeof(segment_cmd));
        fobjbuf->write(SECbuf->buf + sizeof(struct section), (section_cnt - 1) * sizeof(struct section));
    }
    fobjbuf->write(&symtab_cmd, sizeof(symtab_cmd));
    fobjbuf->write(&dysymtab_cmd, sizeof(dysymtab_cmd));
    fobjbuf->position(foffset, 0);
    fobjbuf->flush();
#endif
}

/*****************************
 * Line number support.
 */

/***************************
 * Record file and line number at segment and offset.
 * The actual .debug_line segment is put out by dwarf_termfile().
 * Input:
 *      cseg    current code segment
 */

void MsCoffObj::linnum(Srcpos srcpos, targ_size_t offset)
{
    if (srcpos.Slinnum == 0)
        return;

#if 0
#if MARS || SCPP
    printf("MsCoffObj::linnum(cseg=%d, offset=x%lx) ", cseg, offset);
#endif
    srcpos.print("");
#endif

#if MARS
    if (!srcpos.Sfilename)
        return;
#endif
#if SCPP
    if (!srcpos.Sfilptr)
        return;
    sfile_debug(&srcpos_sfile(srcpos));
    Sfile *sf = *srcpos.Sfilptr;
#endif

    size_t i;
    seg_data *seg = SegData[cseg];

    // Find entry i in SDlinnum_data[] that corresponds to srcpos filename
    for (i = 0; 1; i++)
    {
        if (i == seg->SDlinnum_count)
        {   // Create new entry
            if (seg->SDlinnum_count == seg->SDlinnum_max)
            {   // Enlarge array
                unsigned newmax = seg->SDlinnum_max * 2 + 1;
                //printf("realloc %d\n", newmax * sizeof(linnum_data));
                seg->SDlinnum_data = (linnum_data *)mem_realloc(
                    seg->SDlinnum_data, newmax * sizeof(linnum_data));
                memset(seg->SDlinnum_data + seg->SDlinnum_max, 0,
                    (newmax - seg->SDlinnum_max) * sizeof(linnum_data));
                seg->SDlinnum_max = newmax;
            }
            seg->SDlinnum_count++;
#if MARS
            seg->SDlinnum_data[i].filename = srcpos.Sfilename;
#endif
#if SCPP
            seg->SDlinnum_data[i].filptr = sf;
#endif
            break;
        }
#if MARS
        if (seg->SDlinnum_data[i].filename == srcpos.Sfilename)
#endif
#if SCPP
        if (seg->SDlinnum_data[i].filptr == sf)
#endif
            break;
    }

    linnum_data *ld = &seg->SDlinnum_data[i];
//    printf("i = %d, ld = x%x\n", i, ld);
    if (ld->linoff_count == ld->linoff_max)
    {
        if (!ld->linoff_max)
            ld->linoff_max = 8;
        ld->linoff_max *= 2;
        ld->linoff = (unsigned (*)[2])mem_realloc(ld->linoff, ld->linoff_max * sizeof(unsigned) * 2);
    }
    ld->linoff[ld->linoff_count][0] = srcpos.Slinnum;
    ld->linoff[ld->linoff_count][1] = offset;
    ld->linoff_count++;
}


/*******************************
 * Set start address
 */

void MsCoffObj::startaddress(Symbol *s)
{
    //dbg_printf("MsCoffObj::startaddress(Symbol *%s)\n",s->Sident);
    //obj.startaddress = s;
}

/*******************************
 * Output library name.
 */

bool MsCoffObj::includelib(const char *name)
{
    //dbg_printf("MsCoffObj::includelib(name *%s)\n",name);
    return false;
}

/**********************************
 * Do we allow zero sized objects?
 */

bool MsCoffObj::allowZeroSize()
{
    return true;
}

/**************************
 * Embed string in executable.
 */

void MsCoffObj::exestr(const char *p)
{
    //dbg_printf("MsCoffObj::exestr(char *%s)\n",p);
}

/**************************
 * Embed string in obj.
 */

void MsCoffObj::user(const char *p)
{
    //dbg_printf("MsCoffObj::user(char *%s)\n",p);
}

/*******************************
 * Output a weak extern record.
 */

void MsCoffObj::wkext(Symbol *s1,Symbol *s2)
{
    //dbg_printf("MsCoffObj::wkext(Symbol *%s,Symbol *s2)\n",s1->Sident,s2->Sident);
}

/*******************************
 * Output file name record.
 *
 * Currently assumes that obj_filename will not be called
 *      twice for the same file.
 */

void obj_filename(const char *modname)
{
    //dbg_printf("obj_filename(char *%s)\n",modname);
    // Not supported by mscoff
}

/*******************************
 * Embed compiler version in .obj file.
 */

void MsCoffObj::compiler()
{
    //dbg_printf("MsCoffObj::compiler\n");
}

//#if NEWSTATICDTOR

/**************************************
 * Symbol is the function that calls the static constructors.
 * Put a pointer to it into a special segment that the startup code
 * looks at.
 * Input:
 *      s       static constructor function
 *      dtor    !=0 if leave space for static destructor
 *      seg     1:      user
 *              2:      lib
 *              3:      compiler
 */

void MsCoffObj::staticctor(Symbol *s,int dtor,int none)
{
#if 0
    IDXSEC seg;
    Outbuffer *buf;

    //dbg_printf("MsCoffObj::staticctor(%s) offset %x\n",s->Sident,s->Soffset);
    //symbol_print(s);
    s->Sseg = seg =
        MsCoffObj::getsegment(".ctors", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE, 4);
    buf = SegData[seg]->SDbuf;
    if (I64)
        buf->write64(s->Soffset);
    else
        buf->write32(s->Soffset);
    MsCoffObj::addrel(seg, SegData[seg]->SDoffset, s, RELaddr);
    SegData[seg]->SDoffset = buf->size();
#endif
}

/**************************************
 * Symbol is the function that calls the static destructors.
 * Put a pointer to it into a special segment that the exit code
 * looks at.
 * Input:
 *      s       static destructor function
 */

void MsCoffObj::staticdtor(Symbol *s)
{
#if 0
    IDXSEC seg;
    Outbuffer *buf;

    //dbg_printf("MsCoffObj::staticdtor(%s) offset %x\n",s->Sident,s->Soffset);
    //symbol_print(s);
    seg = MsCoffObj::getsegment(".dtors", NULL, SHT_PROGDEF, SHF_ALLOC|SHF_WRITE, 4);
    buf = SegData[seg]->SDbuf;
    if (I64)
        buf->write64(s->Soffset);
    else
        buf->write32(s->Soffset);
    MsCoffObj::addrel(seg, SegData[seg]->SDoffset, s, RELaddr);
    SegData[seg]->SDoffset = buf->size();
#endif
}

//#else

/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

void MsCoffObj::funcptr(Symbol *s)
{
    //dbg_printf("MsCoffObj::funcptr(%s) \n",s->Sident);
}

//#endif

/***************************************
 * Stuff the following data (instance of struct FuncTable) in a separate segment:
 *      pointer to function
 *      pointer to ehsym
 *      length of function
 */

void MsCoffObj::ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym)
{
    //dbg_printf("MsCoffObj::ehtables(%s) \n",sfunc->Sident);

    /* BUG: this should go into a COMDAT if sfunc is in a COMDAT
     * otherwise the duplicates aren't removed.
     */

    int align = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;  // align to NPTRSIZE
    // The size is sizeof(struct FuncTable) in deh2.d
    int seg = MsCoffObj::getsegment("._deh_eh", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          align |
                                          IMAGE_SCN_MEM_READ);

    Outbuffer *buf = SegData[seg]->SDbuf;
    if (I64)
    {   MsCoffObj::reftoident(seg, buf->size(), sfunc, 0, CFoff | CFoffset64);
        MsCoffObj::reftoident(seg, buf->size(), ehsym, 0, CFoff | CFoffset64);
        buf->write64(sfunc->Ssize);
    }
    else
    {   MsCoffObj::reftoident(seg, buf->size(), sfunc, 0, CFoff);
        MsCoffObj::reftoident(seg, buf->size(), ehsym, 0, CFoff);
        buf->write32(sfunc->Ssize);
    }
}

/*********************************************
 * Put out symbols that define the beginning/end of the .deh_eh section.
 * This gets called if this is the module with "main()" in it.
 */

void MsCoffObj::ehsections()
{
    //printf("MsCoffObj::ehsections()\n");
#if 0
    /* Determine Mac OSX version, and put out the sections slightly differently for each.
     * This is needed because the linker on OSX 10.5 behaves differently than
     * the linker on 10.6.
     * See Bugzilla 3502 for more information.
     */
    static SInt32 MacVersion;
    if (!MacVersion)
        Gestalt(gestaltSystemVersion, &MacVersion);

    /* Exception handling sections
     */
    // 12 is size of struct FuncTable in D runtime
    MsCoffObj::getsegment("__deh_beg", "__DATA", 2, S_COALESCED, 12);
    int seg = MsCoffObj::getsegment("__deh_eh", "__DATA", 2, S_REGULAR);
    Outbuffer *buf = SegData[seg]->SDbuf;
    buf->writezeros(12);                // 12 is size of struct FuncTable in D runtime,
                                        // this entry gets skipped over by __eh_finddata()

    MsCoffObj::getsegment("__deh_end", "__DATA", 2, S_COALESCED, 4);

    /* Thread local storage sections
     */
    MsCoffObj::getsegment("__tls_beg", "__DATA", 2, S_COALESCED, 4);
    MsCoffObj::getsegment("__tls_data", "__DATA", 2, S_REGULAR, 4);
    MsCoffObj::getsegment("__tlscoal_nt", "__DATA", 4, S_COALESCED, 4);
    MsCoffObj::getsegment("__tls_end", "__DATA", 2, S_COALESCED, 4);

    /* Module info sections
     */
    MsCoffObj::getsegment("__minfo_beg", "__DATA", 2, S_COALESCED, 4);
    MsCoffObj::getsegment("__minfodata", "__DATA", 2, S_REGULAR, 4);
    MsCoffObj::getsegment("__minfo_end", "__DATA", 2, S_COALESCED, 4);
#endif
}

/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *      cseg            segment index of new current code segment
 *      Coffset         starting offset in cseg
 * Returns:
 *      "segment index" of COMDAT
 */

int MsCoffObj::comdatsize(Symbol *s, targ_size_t symsize)
{
    return MsCoffObj::comdat(s);
}

int MsCoffObj::comdat(Symbol *s)
{
    unsigned align;

    //printf("MsCoffObj::comdat(Symbol* %s)\n",s->Sident);
    //symbol_print(s);
    symbol_debug(s);

    if (tyfunc(s->ty()))
    {
        align = I64 ? 16 : 4;
        s->Sseg = MsCoffObj::getsegment(".text", IMAGE_SCN_CNT_CODE |
                                           IMAGE_SCN_LNK_COMDAT |
                                           (I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_4BYTES) |
                                           IMAGE_SCN_MEM_EXECUTE |
                                           IMAGE_SCN_MEM_READ);
    }
    else if ((s->ty() & mTYLINK) == mTYthread)
    {
        s->Sfl = FLtlsdata;
        align = 16;
        s->Sseg = MsCoffObj::getsegment(".tls$",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                                            IMAGE_SCN_LNK_COMDAT |
                                            IMAGE_SCN_ALIGN_16BYTES |
                                            IMAGE_SCN_MEM_READ |
                                            IMAGE_SCN_MEM_WRITE);
        MsCoffObj::data_start(s, align, s->Sseg);
    }
    else
    {
        s->Sfl = FLdata;
        align = 16;
        s->Sseg = MsCoffObj::getsegment(".data",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                                            IMAGE_SCN_LNK_COMDAT |
                                            IMAGE_SCN_ALIGN_16BYTES |
                                            IMAGE_SCN_MEM_READ |
                                            IMAGE_SCN_MEM_WRITE);
    }
                                // find or create new segment
    if (s->Salignment > align)
        SegData[s->Sseg]->SDalignment = s->Salignment;
    s->Soffset = SegData[s->Sseg]->SDoffset;
    if (s->Sfl == FLdata || s->Sfl == FLtlsdata)
    {   // Code symbols are 'published' by MsCoffObj::func_start()

        MsCoffObj::pubdef(s->Sseg,s,s->Soffset);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    return s->Sseg;
}

/**********************************
 * Get segment.
 * Input:
 *      flags2  put out some data for this, so the linker will keep things in order
 *      align   segment alignment as power of 2
 * Returns:
 *      segment index of found or newly created segment
 */

int MsCoffObj::getsegment(const char *sectname, unsigned long flags)
{
    assert(strlen(sectname) <= 16);
    for (int seg = 1; seg <= seg_count; seg++)
    {   seg_data *pseg = SegData[seg];
        if (!(flags & IMAGE_SCN_LNK_COMDAT) &&
            strncmp(SecHdrTab[pseg->SDshtidx].s_name, sectname, 8) == 0)
            return seg;         // return existing segment
    }

    int seg = ++seg_count;
    if (seg_count >= seg_max)
    {                           // need more room in segment table
        seg_max += 10;
        SegData = (seg_data **)mem_realloc(SegData,seg_max * sizeof(seg_data *));
        memset(&SegData[seg_count], 0, (seg_max - seg_count) * sizeof(seg_data *));
    }
    assert(seg_count < seg_max);
    if (SegData[seg])
    {   seg_data *pseg = SegData[seg];
        Outbuffer *b1 = pseg->SDbuf;
        Outbuffer *b2 = pseg->SDrel;
        memset(pseg, 0, sizeof(seg_data));
        if (b1)
            b1->setsize(0);
        if (b2)
            b2->setsize(0);
        pseg->SDbuf = b1;
        pseg->SDrel = b2;
    }
    else
    {
        seg_data *pseg = (seg_data *)mem_calloc(sizeof(seg_data));
        SegData[seg] = pseg;
        if (!(flags & IMAGE_SCN_CNT_UNINITIALIZED_DATA))
        {   pseg->SDbuf = new Outbuffer(4096);
            pseg->SDbuf->reserve(4096);
        }
    }

    //dbg_printf("\tNew segment - %d size %d\n", seg,SegData[seg]->SDbuf);
    seg_data *pseg = SegData[seg];

    pseg->SDseg = seg;
    pseg->SDoffset = 0;

    struct scnhdr *sec = (struct scnhdr *)
        SECbuf->writezeros(sizeof(struct section));
    strncpy(sec->s_name, sectname, 8);
    sec->s_flags = flags;

    pseg->SDshtidx = section_cnt++;
    pseg->SDaranges_offset = 0;
    pseg->SDlinnum_count = 0;

    //printf("seg_count = %d\n", seg_count);
    return seg;
}

/********************************
 * Define a new code segment.
 * Input:
 *      name            name of segment, if NULL then revert to default
 *      suffix  0       use name as is
 *              1       append "_TEXT" to name
 * Output:
 *      cseg            segment index of new current code segment
 *      Coffset         starting offset in cseg
 * Returns:
 *      segment index of newly created code segment
 */

int MsCoffObj::codeseg(char *name,int suffix)
{
    //dbg_printf("MsCoffObj::codeseg(%s,%x)\n",name,suffix);
    return 0;
}

/*********************************
 * Define segments for Thread Local Storage.
 * Output:
 *      seg_tlsseg      set to segment number for TLS segment.
 * Returns:
 *      segment for TLS segment
 */

seg_data *MsCoffObj::tlsseg()
{
    //printf("MsCoffObj::tlsseg(\n");

    if (seg_tlsseg == UNKNOWN)
    {
        int align = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_8BYTES;
        seg_tlsseg = MsCoffObj::getsegment(".tls$", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                              align |
                                              IMAGE_SCN_MEM_READ |
                                              IMAGE_SCN_MEM_WRITE);
    }
    return SegData[seg_tlsseg];
}


/*********************************
 * Define segments for Thread Local Storage.
 * Output:
 *      seg_tlsseg_bss  set to segment number for TLS segment.
 * Returns:
 *      segment for TLS segment
 */

seg_data *MsCoffObj::tlsseg_bss()
{
    /* No thread local bss for MS-COFF
     */
    return MsCoffObj::tlsseg();
}


/*******************************
 * Output an alias definition record.
 */

void MsCoffObj::alias(const char *n1,const char *n2)
{
    //printf("MsCoffObj::alias(%s,%s)\n",n1,n2);
    assert(0);
#if NOT_DONE
    unsigned len;
    char *buffer;

    buffer = (char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
#endif
}

char *unsstr(unsigned value)
{
    static char buffer [64];

    sprintf (buffer, "%d", value);
    return buffer;
}

/*******************************
 * Mangle a name.
 * Returns:
 *      mangled name
 */

char *obj_mangle2(Symbol *s,char *dest)
{
    size_t len;
    char *name;

    //printf("MsCoffObj::mangle(s = %p, '%s'), mangle = x%x\n",s,s->Sident,type_mangle(s->Stype));
    symbol_debug(s);
    assert(dest);
#if SCPP
    name = CPP ? cpp_mangle(s) : s->Sident;
#elif MARS
    name = cpp_mangle(s);
#else
    name = s->Sident;
#endif
    len = strlen(name);                 // # of bytes in name
    //dbg_printf("len %d\n",len);
    switch (type_mangle(s->Stype))
    {
        case mTYman_pas:                // if upper case
        case mTYman_for:
            if (len >= DEST_LEN)
                dest = (char *)mem_malloc(len + 1);
            memcpy(dest,name,len + 1);  // copy in name and ending 0
            strupr(dest);               // to upper case
            break;
        case mTYman_std:
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
            if (tyfunc(s->ty()) && !variadic(s->Stype))
#else
            if (!(config.flags4 & CFG4oldstdmangle) &&
                config.exe == EX_NT && tyfunc(s->ty()) &&
                !variadic(s->Stype))
#endif
            {
                char *pstr = unsstr(type_paramsize(s->Stype));
                size_t pstrlen = strlen(pstr);
                size_t destlen = len + 1 + pstrlen + 1;

                if (destlen > DEST_LEN)
                    dest = (char *)mem_malloc(destlen);
                memcpy(dest,name,len);
                dest[len] = '@';
                memcpy(dest + 1 + len, pstr, pstrlen + 1);
                break;
            }
        case mTYman_cpp:
        case mTYman_d:
        case mTYman_sys:
        case 0:
            if (len >= DEST_LEN)
                dest = (char *)mem_malloc(len + 1);
            memcpy(dest,name,len+1);// copy in name and trailing 0
            break;

        case mTYman_c:
            if (len >= DEST_LEN - 1)
                dest = (char *)mem_malloc(1 + len + 1);
            dest[0] = '_';
            memcpy(dest + 1,name,len+1);// copy in name and trailing 0
            break;


        default:
#ifdef DEBUG
            printf("mangling %x\n",type_mangle(s->Stype));
            symbol_print(s);
#endif
            printf("%d\n", type_mangle(s->Stype));
            assert(0);
    }
    //dbg_printf("\t %s\n",dest);
    return dest;
}

/*******************************
 * Export a function name.
 */

void MsCoffObj::export_symbol(Symbol *s,unsigned argsize)
{
    //dbg_printf("MsCoffObj::export_symbol(%s,%d)\n",s->Sident,argsize);
}

/*******************************
 * Update data information about symbol
 *      align for output and assign segment
 *      if not already specified.
 *
 * Input:
 *      sdata           data symbol
 *      datasize        output size
 *      seg             default seg if not known
 * Returns:
 *      actual seg
 */

int MsCoffObj::data_start(Symbol *sdata, targ_size_t datasize, int seg)
{
    targ_size_t alignbytes;

    //printf("MsCoffObj::data_start(%s,size %d,seg %d)\n",sdata->Sident,datasize,seg);
    //symbol_print(sdata);

    assert(sdata->Sseg);
    if (sdata->Sseg == UNKNOWN) // if we don't know then there
        sdata->Sseg = seg;      // wasn't any segment override
    else
        seg = sdata->Sseg;
    targ_size_t offset = Offset(seg);
    if (sdata->Salignment > 0)
    {   if (SegData[seg]->SDalignment < sdata->Salignment)
            SegData[seg]->SDalignment = sdata->Salignment;
        alignbytes = (offset + sdata->Salignment - 1) & ~(sdata->Salignment - 1);
    }
    else
        alignbytes = align(datasize, offset) - offset;
    if (alignbytes)
        MsCoffObj::lidata(seg, offset, alignbytes);
    sdata->Soffset = offset + alignbytes;
    return seg;
}

/*******************************
 * Update function info before codgen
 *
 * If code for this function is in a different segment
 * than the current default in cseg, switch cseg to new segment.
 */

void MsCoffObj::func_start(Symbol *sfunc)
{
    //printf("MsCoffObj::func_start(%s)\n",sfunc->Sident);
    symbol_debug(sfunc);

    assert(sfunc->Sseg);
    if (sfunc->Sseg == UNKNOWN)
        sfunc->Sseg = CODE;
    //printf("sfunc->Sseg %d CODE %d cseg %d Coffset x%x\n",sfunc->Sseg,CODE,cseg,Coffset);
    cseg = sfunc->Sseg;
    assert(cseg == CODE || cseg > UDATA);
    MsCoffObj::pubdef(cseg, sfunc, Coffset);
    sfunc->Soffset = Coffset;

//    if (config.fulltypes)
//        dwarf_func_start(sfunc);
}

/*******************************
 * Update function info after codgen
 */

void MsCoffObj::func_term(Symbol *sfunc)
{
    //dbg_printf("MsCoffObj::func_term(%s) offset %x, Coffset %x symidx %d\n",
//          sfunc->Sident, sfunc->Soffset,Coffset,sfunc->Sxtrnnum);

#if 0
    // fill in the function size
    if (I64)
        SymbolTable64[sfunc->Sxtrnnum].st_size = Coffset - sfunc->Soffset;
    else
        SymbolTable[sfunc->Sxtrnnum].st_size = Coffset - sfunc->Soffset;
#endif
//    if (config.fulltypes)
//        dwarf_func_term(sfunc);
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s ->            symbol
 *      offset =        offset of name within segment
 */

void MsCoffObj::pubdef(int seg, Symbol *s, targ_size_t offset)
{
#if 0
    printf("MsCoffObj::pubdef(%d:x%x s=%p, %s)\n", seg, offset, s, s->Sident);
    //symbol_print(s);
#endif
    symbol_debug(s);

    s->Soffset = offset;
    s->Sseg = seg;
    switch (s->Sclass)
    {
        case SCglobal:
        case SCinline:
            public_symbuf->write(&s, sizeof(s));
            break;
        case SCcomdat:
        case SCcomdef:
            public_symbuf->write(&s, sizeof(s));
            break;
        default:
            local_symbuf->write(&s, sizeof(s));
            break;
    }
    //printf("%p\n", *(void**)public_symbuf->buf);
    s->Sxtrnnum = 1;
}

/*******************************
 * Output an external symbol for name.
 * Input:
 *      name    Name to do EXTDEF on
 *              (Not to be mangled)
 * Returns:
 *      Symbol table index of the definition
 *      NOTE: Numbers will not be linear.
 */

int MsCoffObj::external(const char *name)
{
    //printf("MsCoffObj::external_def('%s')\n",name);
    assert(name);
    assert(extdef == 0);
    extdef = MsCoffObj::addstr(symtab_strings, name);
    return 0;
}

int MsCoffObj::external_def(const char *name)
{
    return MsCoffObj::external(name);
}

/*******************************
 * Output an external for existing symbol.
 * Input:
 *      s       Symbol to do EXTDEF on
 *              (Name is to be mangled)
 * Returns:
 *      Symbol table index of the definition
 *      NOTE: Numbers will not be linear.
 */

int MsCoffObj::external(Symbol *s)
{
    //printf("MsCoffObj::external('%s') %x\n",s->Sident,s->Svalue);
    symbol_debug(s);
    extern_symbuf->write(&s, sizeof(s));
    s->Sxtrnnum = 1;
    return 1;
}

/*******************************
 * Output a common block definition.
 * Input:
 *      p ->    external identifier
 *      size    size in bytes of each elem
 *      count   number of elems
 * Returns:
 *      Symbol table index for symbol
 */

int MsCoffObj::common_block(Symbol *s,targ_size_t size,targ_size_t count)
{
    //printf("MsCoffObj::common_block('%s', size=%d, count=%d)\n",s->Sident,size,count);
    symbol_debug(s);

    // can't have code or thread local comdef's
    assert(!(s->ty() & mTYthread));

    struct Comdef comdef;
    comdef.sym = s;
    comdef.size = size;
    comdef.count = count;
    comdef_symbuf->write(&comdef, sizeof(comdef));
    s->Sxtrnnum = 1;
    if (!s->Sseg)
        s->Sseg = UDATA;
    return 0;           // should return void
}

int MsCoffObj::common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
{
    return MsCoffObj::common_block(s, size, count);
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void MsCoffObj::write_zeros(seg_data *pseg, targ_size_t count)
{
    MsCoffObj::lidata(pseg->SDseg, pseg->SDoffset, count);
}

/***************************************
 * Output an iterated data block of 0s.
 *
 *      For boundary alignment and initialization
 */

void MsCoffObj::lidata(int seg,targ_size_t offset,targ_size_t count)
{
    //printf("MsCoffObj::lidata(%d,%x,%d)\n",seg,offset,count);
    size_t idx = SegData[seg]->SDshtidx;
    if ((SecHdrTab[idx].s_flags) & IMAGE_SCN_CNT_UNINITIALIZED_DATA)
    {   // Use SDoffset to record size of bss section
        SegData[seg]->SDoffset += count;
    }
    else
    {
        MsCoffObj::bytes(seg, offset, count, NULL);
    }
}

/***********************************
 * Append byte to segment.
 */

void MsCoffObj::write_byte(seg_data *pseg, unsigned byte)
{
    MsCoffObj::byte(pseg->SDseg, pseg->SDoffset, byte);
}

/************************************
 * Output byte to object file.
 */

void MsCoffObj::byte(int seg,targ_size_t offset,unsigned byte)
{
    Outbuffer *buf = SegData[seg]->SDbuf;
    int save = buf->size();
    //dbg_printf("MsCoffObj::byte(seg=%d, offset=x%lx, byte=x%x)\n",seg,offset,byte);
    buf->setsize(offset);
    buf->writeByte(byte);
    if (save > offset+1)
        buf->setsize(save);
    else
        SegData[seg]->SDoffset = offset+1;
    //dbg_printf("\tsize now %d\n",buf->size());
}

/***********************************
 * Append bytes to segment.
 */

void MsCoffObj::write_bytes(seg_data *pseg, unsigned nbytes, void *p)
{
    MsCoffObj::bytes(pseg->SDseg, pseg->SDoffset, nbytes, p);
}

/************************************
 * Output bytes to object file.
 * Returns:
 *      nbytes
 */

unsigned MsCoffObj::bytes(int seg, targ_size_t offset, unsigned nbytes, void *p)
{
#if 0
    if (!(seg >= 0 && seg <= seg_count))
    {   printf("MsCoffObj::bytes: seg = %d, seg_count = %d\n", seg, seg_count);
        *(char*)0=0;
    }
#endif
    assert(seg >= 0 && seg <= seg_count);
    Outbuffer *buf = SegData[seg]->SDbuf;
    if (buf == NULL)
    {
        //dbg_printf("MsCoffObj::bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n", seg, offset, nbytes, p);
        //raise(SIGSEGV);
if (!buf) halt();
        assert(buf != NULL);
    }
    int save = buf->size();
    //dbg_printf("MsCoffObj::bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n",
            //seg,offset,nbytes,p);
    buf->setsize(offset);
    buf->reserve(nbytes);
    if (p)
    {
        buf->writen(p,nbytes);
    }
    else
    {   // Zero out the bytes
        buf->clearn(nbytes);
    }
    if (save > offset+nbytes)
        buf->setsize(save);
    else
        SegData[seg]->SDoffset = offset+nbytes;
    return nbytes;
}

/*********************************************
 * Add a relocation entry for seg/offset.
 */

void MsCoffObj::addrel(int seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val)
{
    Relocation rel;
    rel.offset = offset;
    rel.targsym = targsym;
    rel.targseg = targseg;
    rel.rtype = rtype;
    rel.funcsym = funcsym_p;
    rel.val = val;
    seg_data *pseg = SegData[seg];
    if (!pseg->SDrel)
        pseg->SDrel = new Outbuffer();
    pseg->SDrel->write(&rel, sizeof(rel));
}

/****************************************
 * Sort the relocation entry buffer.
 */

#if __DMC__
static int __cdecl rel_fp(const void *e1, const void *e2)
{   Relocation *r1 = (Relocation *)e1;
    Relocation *r2 = (Relocation *)e2;

    return r1->offset - r2->offset;
}
#else
extern "C" {
static int rel_fp(const void *e1, const void *e2)
{   Relocation *r1 = (Relocation *)e1;
    Relocation *r2 = (Relocation *)e2;

    return r1->offset - r2->offset;
}
}
#endif

void mach_relsort(Outbuffer *buf)
{
    qsort(buf->buf, buf->size() / sizeof(Relocation), sizeof(Relocation), &rel_fp);
}

/*******************************
 * Output a relocation entry for a segment
 * Input:
 *      seg =           where the address is going
 *      offset =        offset within seg
 *      type =          ELF relocation type
 *      index =         Related symbol table index
 *      val =           addend or displacement from address
 */

void MsCoffObj::addrel(int seg, targ_size_t offset, unsigned type,
                                        IDXSYM symidx, targ_size_t val)
{
}

/*******************************
 * Refer to address that is in the data segment.
 * Input:
 *      seg:offset =    the address being fixed up
 *      val =           displacement from start of target segment
 *      targetdatum =   target segment number (DATA, CDATA or UDATA, etc.)
 *      flags =         CFoff, CFseg
 * Example:
 *      int *abc = &def[3];
 *      to allocate storage:
 *              MsCoffObj::reftodatseg(DATA,offset,3 * sizeof(int *),UDATA);
 */

void MsCoffObj::reftodatseg(int seg,targ_size_t offset,targ_size_t val,
        unsigned targetdatum,int flags)
{
    Outbuffer *buf = SegData[seg]->SDbuf;
    int save = buf->size();
    buf->setsize(offset);
#if 0
    printf("MsCoffObj::reftodatseg(seg:offset=%d:x%llx, val=x%llx, targetdatum %x, flags %x )\n",
        seg,offset,val,targetdatum,flags);
#endif
    assert(seg != 0);
    if (SegData[seg]->isCode() && SegData[targetdatum]->isCode())
    {
        assert(0);
    }
    MsCoffObj::addrel(seg, offset, NULL, targetdatum, RELaddr);
    if (I64)
    {
        if (flags & CFoffset64)
        {
            buf->write64(val);
            if (save > offset + 8)
                buf->setsize(save);
            return;
        }
    }
    buf->write32(val);
    if (save > offset + 4)
        buf->setsize(save);
}

/*******************************
 * Refer to address that is in the current function code (funcsym_p).
 * Only offsets are output, regardless of the memory model.
 * Used to put values in switch address tables.
 * Input:
 *      seg =           where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      val =           displacement from start of this module
 */

void MsCoffObj::reftocodeseg(int seg,targ_size_t offset,targ_size_t val)
{
    //printf("MsCoffObj::reftocodeseg(seg=%d, offset=x%lx, val=x%lx )\n",seg,(unsigned long)offset,(unsigned long)val);
    assert(seg > 0);
    Outbuffer *buf = SegData[seg]->SDbuf;
    int save = buf->size();
    buf->setsize(offset);
    val -= funcsym_p->Soffset;
//    MsCoffObj::addrel(seg, offset, funcsym_p, 0, RELaddr);
//    if (I64)
//        buf->write64(val);
//    else
        buf->write32(val);
    if (save > offset + 4)
        buf->setsize(save);
}

/*******************************
 * Refer to an identifier.
 * Input:
 *      seg =   where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      s ->            Symbol table entry for identifier
 *      val =           displacement from identifier
 *      flags =         CFselfrel: self-relative
 *                      CFseg: get segment
 *                      CFoff: get offset
 *                      CFpc32: [RIP] addressing, val is 0, -1, -2 or -4
 *                      CFoffset64: 8 byte offset for 64 bit builds
 * Returns:
 *      number of bytes in reference (4 or 8)
 */

int MsCoffObj::reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val,
        int flags)
{
    int retsize = (flags & CFoffset64) ? 8 : 4;
#if 0
    dbg_printf("\nMsCoffObj::reftoident('%s' seg %d, offset x%llx, val x%llx, flags x%x)\n",
        s->Sident,seg,(unsigned long long)offset,(unsigned long long)val,flags);
    printf("retsize = %d\n", retsize);
    //dbg_printf("Sseg = %d, Sxtrnnum = %d\n",s->Sseg,s->Sxtrnnum);
    symbol_print(s);
#endif
    assert(seg > 0);
    if (s->Sclass != SClocstat && !s->Sxtrnnum)
    {   // It may get defined later as public or local, so defer
        addtofixlist(s, offset, seg, val, flags);
    }
    else
    {
        if (I64)
        {
            //if (s->Sclass != SCcomdat)
                //val += s->Soffset;
            int v = 0;
            if (flags & CFpc32)
                v = (int)val;
            if (flags & CFselfrel)
            {
                MsCoffObj::addrel(seg, offset, s, 0, RELrel, v);
            }
            else
            {
                MsCoffObj::addrel(seg, offset, s, 0, RELaddr, v);
            }
        }
        else
        {
            if (SegData[seg]->isCode() && flags & CFselfrel)
            {
#if 0
                if (!jumpTableSeg)
                {
                    jumpTableSeg =
                        MsCoffObj::getsegment("__jump_table", "__IMPORT",  0, S_SYMBOL_STUBS | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS | S_ATTR_SELF_MODIFYING_CODE);
                }
#endif
                seg_data *pseg = SegData[jumpTableSeg];
//                SecHdrTab[pseg->SDshtidx].reserved2 = 5;

                if (!indirectsymbuf1)
                    indirectsymbuf1 = new Outbuffer();
                else
                {   // Look through indirectsym to see if it is already there
                    int n = indirectsymbuf1->size() / sizeof(Symbol *);
                    Symbol **psym = (Symbol **)indirectsymbuf1->buf;
                    for (int i = 0; i < n; i++)
                    {   // Linear search, pretty pathetic
                        if (s == psym[i])
                        {   val = i * 5;
                            goto L1;
                        }
                    }
                }

                val = pseg->SDbuf->size();
                static char halts[5] = { 0xF4,0xF4,0xF4,0xF4,0xF4 };
                pseg->SDbuf->write(halts, 5);

                // Add symbol s to indirectsymbuf1
                indirectsymbuf1->write(&s, sizeof(Symbol *));
             L1:
                val -= offset + 4;
                MsCoffObj::addrel(seg, offset, NULL, jumpTableSeg, RELrel);
            }
            else if (SegData[seg]->isCode() &&
                    ((s->Sclass != SCextern && SegData[s->Sseg]->isCode()) || s->Sclass == SClocstat || s->Sclass == SCstatic))
            {
                val += s->Soffset;
                MsCoffObj::addrel(seg, offset, NULL, s->Sseg, RELaddr);
            }
            else if (SegData[seg]->isCode() && !tyfunc(s->ty()))
            {
                if (!pointersSeg)
                {
//                    pointersSeg =
//                        MsCoffObj::getsegment("__pointers", "__IMPORT",  0, S_NON_LAZY_SYMBOL_POINTERS);
                }
                seg_data *pseg = SegData[pointersSeg];

                if (!indirectsymbuf2)
                    indirectsymbuf2 = new Outbuffer();
                else
                {   // Look through indirectsym to see if it is already there
                    int n = indirectsymbuf2->size() / sizeof(Symbol *);
                    Symbol **psym = (Symbol **)indirectsymbuf2->buf;
                    for (int i = 0; i < n; i++)
                    {   // Linear search, pretty pathetic
                        if (s == psym[i])
                        {   val = i * 4;
                            goto L2;
                        }
                    }
                }

                val = pseg->SDbuf->size();
                pseg->SDbuf->writezeros(NPTRSIZE);

                // Add symbol s to indirectsymbuf2
                indirectsymbuf2->write(&s, sizeof(Symbol *));

             L2:
                //printf("MsCoffObj::reftoident: seg = %d, offset = x%x, s = %s, val = x%x, pointersSeg = %d\n", seg, offset, s->Sident, val, pointersSeg);
                MsCoffObj::addrel(seg, offset, NULL, pointersSeg, RELaddr);
            }
            else
            {   //val -= s->Soffset;
//                MsCoffObj::addrel(seg, offset, s, 0, RELaddr);
            }
        }

        Outbuffer *buf = SegData[seg]->SDbuf;
        int save = buf->size();
        buf->setsize(offset);
        //printf("offset = x%llx, val = x%llx\n", offset, val);
        if (retsize == 8)
            buf->write64(val);
        else
            buf->write32(val);
        if (save > offset + retsize)
            buf->setsize(save);
    }
    return retsize;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *      s       Symbol to generate a thunk for
 */

void MsCoffObj::far16thunk(Symbol *s)
{
    //dbg_printf("MsCoffObj::far16thunk('%s')\n", s->Sident);
    assert(0);
}

/**************************************
 * Mark object file as using floating point.
 */

void MsCoffObj::fltused()
{
    //dbg_printf("MsCoffObj::fltused()\n");
}


long elf_align(targ_size_t size, long foffset)
{
    if (size <= 1)
        return foffset;
    long offset = (foffset + size - 1) & ~(size - 1);
    if (offset > foffset)
        fobjbuf->writezeros(offset - foffset);
    return offset;
}

/***************************************
 * Stuff pointer to ModuleInfo in its own segment.
 */

#if MARS

void MsCoffObj::moduleinfo(Symbol *scc)
{
    int align = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_4BYTES;

    int seg = MsCoffObj::getsegment("._minfodata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                             align |
                                             IMAGE_SCN_MEM_READ |
                                             IMAGE_SCN_MEM_WRITE);
    //printf("MsCoffObj::moduleinfo(%s) seg = %d:x%x\n", scc->Sident, seg, Offset(seg));

    int flags = CFoff;
    if (I64)
        flags |= CFoffset64;
    SegData[seg]->SDoffset += MsCoffObj::reftoident(seg, Offset(seg), scc, 0, flags);
}

#endif

/*************************************
 */

#if 0
void MsCoffObj::gotref(symbol *s)
{
    //printf("MsCoffObj::gotref(%x '%s', %d)\n",s,s->Sident, s->Sclass);
    switch(s->Sclass)
    {
        case SCstatic:
        case SClocstat:
            s->Sfl = FLgotoff;
            break;

        case SCextern:
        case SCglobal:
        case SCcomdat:
        case SCcomdef:
            s->Sfl = FLgot;
            break;

        default:
            break;
    }
}
#endif

#endif
#endif
