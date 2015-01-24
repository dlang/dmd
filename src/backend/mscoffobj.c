// Compiler implementation of the D programming language
// Copyright (c) 2009-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/backend/mscoffobj.c


#if MARS
#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <sys/types.h>
#include        <sys/stat.h>
#include        <fcntl.h>
#include        <ctype.h>
#include        <time.h>

#if _WIN32 || __linux__
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

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"

#define DEST_LEN (IDMAX + IDOHD + 1)
char *obj_mangle2(Symbol *s,char *dest);

/******************************************
 */

static long elf_align(int size, long offset);

// The object file is built ib several separate pieces


// String Table  - String table for all other names
static Outbuffer *string_table;

// Section Headers
Outbuffer  *ScnhdrBuf;             // Buffer to build section table in
// The -1 is because it is 1 based indexing
#define ScnhdrTab   (((struct scnhdr *)ScnhdrBuf->buf)-1)

static int scnhdr_cnt;          // Number of sections in table
#define SCNHDR_TAB_INITSIZE 16  // Initial number of sections in buffer
#define SCNHDR_TAB_INC  4       // Number of sections to increment buffer by

#define SYM_TAB_INIT 100        // Initial number of symbol entries in buffer
#define SYM_TAB_INC  50         // Number of symbols to increment buffer by

// The symbol table
static Outbuffer *symbuf;

static Outbuffer *syment_buf;   // array of struct syment

struct Comdef { symbol *sym; targ_size_t size; int count; };
static Outbuffer *comdef_symbuf;        // Comdef's are stored here

static segidx_t segidx_drectve;         // contents of ".drectve" section
static segidx_t segidx_debugS = UNKNOWN;
static segidx_t segidx_xdata = UNKNOWN;
static segidx_t segidx_pdata = UNKNOWN;

static int jumpTableSeg;                // segment index for __jump_table

static Outbuffer *indirectsymbuf2;      // indirect symbol table of Symbol*'s
static int pointersSeg;                 // segment index for __pointers

static int floatused;

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
    return (ScnhdrTab[SDshtidx].s_flags & IMAGE_SCN_CNT_CODE) != 0;
}


// already in cgobj.c (should be part of objmod?):
// seg_data **SegData;
int seg_count;
int seg_max;
segidx_t seg_tlsseg = UNKNOWN;
segidx_t seg_tlsseg_bss = UNKNOWN;

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
#define RELseg  2       // 2 byte section
#define RELaddr32 3     // 4 byte offset
    short val;          // 0, -1, -2, -3, -4, -5
};


/*******************************
 * Output a string into a string table
 * Input:
 *      strtab  =       string table for entry
 *      str     =       string to add
 *
 * Returns offset into the specified string table.
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
    const char *ent = (char *)strtab->buf+4;
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
 * Returns offset of the string in string table (offset of the string).
 */

static IDXSTR elf_addmangled(Symbol *s)
{
    //printf("elf_addmangled(%s)\n", s->Sident);
    char dest[DEST_LEN];

    IDXSTR namidx = string_table->size();
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
    string_table->reserve(len+1);
    strcpy((char *)string_table->p,name);
    string_table->setsize(namidx+len+1);
    if (destr != dest)                  // if we resized result
        mem_free(destr);
    //dbg_printf("\telf_addmagled string_table %s namidx %d len %d size %d\n",name, namidx,len,string_table->size());
    return namidx;
}

/**************************
 * Output read only data and generate a symbol for it.
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
        MsCoffObj::pubdef(CDATA, s, CDoffset);
        MsCoffObj::bytes(CDATA, CDoffset, len, p);
    }

    s->Sfl = FLdata; //FLextern;
    return s;
}

/**************************
 * Ouput read only data for data
 *
 */

int MsCoffObj::data_readonly(char *p, int len, segidx_t *pseg)
{
    int oldoff;
#if !MARS
    if (I64 || I32)
    {
        oldoff = Doffset;
        SegData[DATA]->SDbuf->reserve(len);
        SegData[DATA]->SDbuf->writen(p,len);
        Doffset += len;
        *pseg = DATA;
    }
    else
#endif
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
    segidx_t pseg;

    return MsCoffObj::data_readonly(p, len, &pseg);
}

/******************************
 * Start a .obj file.
 * Called before any other obj_xxx routines.
 * One source file can generate multiple .obj files.
 */

MsCoffObj *MsCoffObj::init(Outbuffer *objbuf, const char *filename, const char *csegname)
{
    //printf("MsCoffObj::init()\n");
    MsCoffObj *obj = new MsCoffObj();

    cseg = CODE;
    fobjbuf = objbuf;
    assert(objbuf->size() == 0);

    floatused = 0;

    seg_tlsseg = UNKNOWN;
    seg_tlsseg_bss = UNKNOWN;

    segidx_pdata = UNKNOWN;
    segidx_xdata = UNKNOWN;

    // Initialize buffers

    if (!string_table)
    {   string_table = new Outbuffer(1024);
        string_table->reserve(2048);
    }
    string_table->setsize(0);
    string_table->write32(4);           // first 4 bytes are length of string table

    if (!symbuf)
        symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    symbuf->setsize(0);

    if (!syment_buf)
        syment_buf = new Outbuffer(sizeof(struct syment) * SYM_TAB_INIT);
    syment_buf->setsize(0);

    if (!comdef_symbuf)
        comdef_symbuf = new Outbuffer(sizeof(symbol *) * SYM_TAB_INIT);
    comdef_symbuf->setsize(0);

    extdef = 0;

    pointersSeg = 0;

    // Initialize segments for CODE, DATA, UDATA and CDATA
    if (!ScnhdrBuf)
    {
        ScnhdrBuf = new Outbuffer(SYM_TAB_INC * sizeof(struct scnhdr));
        ScnhdrBuf->reserve(SCNHDR_TAB_INITSIZE * sizeof(struct scnhdr));
    }
    ScnhdrBuf->setsize(0);
    scnhdr_cnt = 0;

    /* Define sections. Although the order should not matter, we duplicate
     * the same order VC puts out just to avoid trouble.
     */

    int alignText = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_8BYTES;
    int alignData = IMAGE_SCN_ALIGN_16BYTES;
    addScnhdr(".drectve", IMAGE_SCN_LNK_INFO |
                          IMAGE_SCN_ALIGN_1BYTES |
                          IMAGE_SCN_LNK_REMOVE);        // linker commands
    addScnhdr(".debug$S", IMAGE_SCN_CNT_INITIALIZED_DATA |
                          IMAGE_SCN_ALIGN_1BYTES |
                          IMAGE_SCN_MEM_READ |
                          IMAGE_SCN_MEM_DISCARDABLE);
    addScnhdr(".data",    IMAGE_SCN_CNT_INITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ |
                          IMAGE_SCN_MEM_WRITE);             // DATA
    addScnhdr(".text",    IMAGE_SCN_CNT_CODE |
                          alignText |
                          IMAGE_SCN_MEM_EXECUTE |
                          IMAGE_SCN_MEM_READ);              // CODE
    addScnhdr(".bss",     IMAGE_SCN_CNT_UNINITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ |
                          IMAGE_SCN_MEM_WRITE);             // UDATA
    addScnhdr(".rdata",   IMAGE_SCN_CNT_INITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ);              // CONST

    seg_count = 0;

#define SHI_DRECTVE     1
#define SHI_DEBUGS      2
#define SHI_DATA        3
#define SHI_TEXT        4
#define SHI_UDATA       5
#define SHI_CDATA       6

    getsegment2(SHI_TEXT);
    assert(SegData[CODE]->SDseg == CODE);

    getsegment2(SHI_DATA);
    assert(SegData[DATA]->SDseg == DATA);

    getsegment2(SHI_CDATA);
    assert(SegData[CDATA]->SDseg == CDATA);

    getsegment2(SHI_UDATA);
    assert(SegData[UDATA]->SDseg == UDATA);

    segidx_drectve = getsegment2(SHI_DRECTVE);

    segidx_debugS  = getsegment2(SHI_DEBUGS);

    SegData[segidx_drectve]->SDbuf->setsize(0);
    SegData[segidx_drectve]->SDbuf->write("  ", 2);

    if (config.fulltypes)
        cv8_initfile(filename);
    assert(objbuf->size() == 0);
    return obj;
}

/**************************
 * Start a module within a .obj file.
 * There can be multiple modules within a single .obj file.
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
        newtextsec = &ScnhdrTab[newsecidx];
        newtextsec->sh_addralign = 4;
        SegData[cseg]->SDsymidx =
            elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, newsecidx);
    }
#endif
    if (config.fulltypes)
        cv8_initmodule(filename, modname);
}

/************************************
 * Patch pseg/offset by adding in the vmaddr difference from
 * pseg/offset to start of seg.
 */

int32_t *patchAddr(int seg, targ_size_t offset)
{
    return(int32_t *)(fobjbuf->buf + ScnhdrTab[SegData[seg]->SDshtidx].s_scnptr + offset);
}

int32_t *patchAddr64(int seg, targ_size_t offset)
{
    return(int32_t *)(fobjbuf->buf + ScnhdrTab[SegData[seg]->SDshtidx].s_scnptr + offset);
}

void patch(seg_data *pseg, targ_size_t offset, int seg, targ_size_t value)
{
    //printf("patch(offset = x%04x, seg = %d, value = x%llx)\n", (unsigned)offset, seg, value);
    if (I64)
    {
        int32_t *p = (int32_t *)(fobjbuf->buf + ScnhdrTab[pseg->SDshtidx].s_scnptr  + offset);
#if 0
        printf("\taddr1 = x%llx\n\taddr2 = x%llx\n\t*p = x%llx\n\tdelta = x%llx\n",
            ScnhdrTab[pseg->SDshtidx].s_vaddr,
            ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr,
            *p,
            ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr -
            (ScnhdrTab[pseg->SDshtidx].s_vaddr + offset));
#endif
        *p += ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr -
              (ScnhdrTab[pseg->SDshtidx].s_vaddr - value);
    }
    else
    {
        int32_t *p = (int32_t *)(fobjbuf->buf + ScnhdrTab[pseg->SDshtidx].s_scnptr + offset);
#if 0
        printf("\taddr1 = x%x\n\taddr2 = x%x\n\t*p = x%x\n\tdelta = x%x\n",
            ScnhdrTab[pseg->SDshtidx].s_vaddr,
            ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr,
            *p,
            ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr -
            (ScnhdrTab[pseg->SDshtidx].s_vaddr + offset));
#endif
        *p += ScnhdrTab[SegData[seg]->SDshtidx].s_vaddr -
              (ScnhdrTab[pseg->SDshtidx].s_vaddr - value);
    }
}


/*********************************
 * Build syment[], the array of symbols.
 * Store them in syment_buf.
 */

static void syment_set_name(syment *sym, const char *name)
{
    size_t len = strlen(name);
    if (len > 8)
    {   // Use offset into string table
        IDXSTR idx = MsCoffObj::addstr(string_table, name);
        sym->n_zeroes = 0;
        sym->n_offset = idx;
    }
    else
    {   memcpy(sym->n_name, name, len);
        if (len < 8)
            memset(sym->n_name + len, 0, 8 - len);
    }
}

void build_syment_table()
{
    /* The @comp.id symbol appears to be the version of VC that generated the .obj file.
     * Anything we put in there would have no relevance, so we'll not put out this symbol.
     */

    /* Now goes one symbol per section.
     */
    for (segidx_t seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &ScnhdrTab[pseg->SDshtidx];   // corresponding section

        struct syment sym;
        memcpy(sym.n_name, psechdr->s_name, 8);
        sym.n_value = 0;
        sym.n_scnum = pseg->SDshtidx;
        sym.n_type = 0;
        sym.n_sclass = IMAGE_SYM_CLASS_STATIC;
        sym.n_numaux = 1;

        assert(sizeof(sym) == 18);
        syment_buf->write(&sym, sizeof(sym));

        union auxent aux;
        memset(&aux, 0, sizeof(aux));

        // s_size is not set yet
        //aux.x_section.length = psechdr->s_size;
        if (pseg->SDbuf && pseg->SDbuf->size())
            aux.x_section.length = pseg->SDbuf->size();
        else
            aux.x_section.length = pseg->SDoffset;

        if (pseg->SDrel)
            aux.x_section.NumberOfRelocations = pseg->SDrel->size() / sizeof(struct Relocation);

        if (psechdr->s_flags & IMAGE_SCN_LNK_COMDAT)
        {
            aux.x_section.Selection = IMAGE_COMDAT_SELECT_ANY;
            if (pseg->SDassocseg)
            {   aux.x_section.Selection = IMAGE_COMDAT_SELECT_ASSOCIATIVE;
                aux.x_section.Number = pseg->SDassocseg;
            }
        }

        syment_buf->write(&aux, sizeof(aux));
        //printf("%d %d %d %d %d %d\n", sizeof(aux.x_fd), sizeof(aux.x_bf), sizeof(aux.x_ef),
        //     sizeof(aux.x_weak), sizeof(aux.x_filename), sizeof(aux.x_section));
        assert(sizeof(aux) == 18);
    }

    /* Add symbols from symbuf[]
     */

    int n = seg_count + 1;
    size_t dim = symbuf->size() / sizeof(symbol *);
    for (size_t i = 0; i < dim; i++)
    {   symbol *s = ((symbol **)symbuf->buf)[i];
        s->Sxtrnnum = syment_buf->size() / sizeof(syment);
        n++;

        struct syment sym;

        char dest[DEST_LEN+1];
        char *destr = obj_mangle2(s, dest);
        syment_set_name(&sym, destr);

        sym.n_value = 0;
        switch (s->Sclass)
        {
            case SCextern:
                sym.n_scnum = IMAGE_SYM_UNDEFINED;
                break;

            default:
                sym.n_scnum = SegData[s->Sseg]->SDshtidx;
                break;

            case SCcomdef:
                assert(0);      // comdef's should be in comdef_symbuf[]
                break;
        }
        sym.n_type = tyfunc(s->Stype->Tty) ? 0x20 : 0;
        switch (s->Sclass)
        {
            case SCstatic:
            case SClocstat:
                sym.n_sclass = IMAGE_SYM_CLASS_STATIC;
                sym.n_value = s->Soffset;
                break;

            default:
                sym.n_sclass = IMAGE_SYM_CLASS_EXTERNAL;
                if (sym.n_scnum != IMAGE_SYM_UNDEFINED)
                    sym.n_value = s->Soffset;
                break;
        }
        sym.n_numaux = 0;

        syment_buf->write(&sym, sizeof(sym));
    }

    /* Add comdef symbols from comdef_symbuf[]
     */

    dim = comdef_symbuf->size() / sizeof(Comdef);
    for (size_t i = 0; i < dim; i++)
    {   Comdef *c = ((Comdef *)comdef_symbuf->buf) + i;
        symbol *s = c->sym;
        s->Sxtrnnum = syment_buf->size() / sizeof(syment);
        n++;

        struct syment sym;

        char dest[DEST_LEN+1];
        char *destr = obj_mangle2(s, dest);
        syment_set_name(&sym, destr);

        sym.n_scnum = IMAGE_SYM_UNDEFINED;
        sym.n_type = 0;
        sym.n_sclass = IMAGE_SYM_CLASS_EXTERNAL;
        sym.n_value = c->size * c->count;
        sym.n_numaux = 0;

        syment_buf->write(&sym, sizeof(sym));
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
        cv8_termmodule();
    }
}

/*********************************
 * Terminate package.
 */

void MsCoffObj::term(const char *objfilename)
{
    //printf("MsCoffObj::term()\n");
    assert(fobjbuf->size() == 0);
#if SCPP
    if (!errcnt)
#endif
    {
        outfixlist();           // backpatches
    }

    if (configv.addlinenumbers)
    {
        cv8_termfile(objfilename);
    }

#if SCPP
    if (errcnt)
        return;
#endif

    build_syment_table();

    /* Write out the object file in the following order:
     *  Header
     *  Section Headers
     *  Symbol table
     *  String table
     *  Section data
     */

    unsigned foffset;

    // Write out the bytes for the header

    struct filehdr header;

    header.f_magic = I64 ? IMAGE_FILE_MACHINE_AMD64 : IMAGE_FILE_MACHINE_I386;
    header.f_nscns = scnhdr_cnt;
    time_t f_timedat = 0;
    time(&f_timedat);
    header.f_timdat = (long)f_timedat;
    header.f_symptr = 0;        // offset to symbol table
    header.f_nsyms = 0;
    header.f_opthdr = 0;
    header.f_flags = 0;

    foffset = sizeof(header);       // start after header

    foffset += ScnhdrBuf->size();   // section headers

    header.f_symptr = foffset;
    header.f_nsyms = syment_buf->size() / sizeof(struct syment);
    foffset += header.f_nsyms * sizeof(struct syment);  // symbol table

    unsigned string_table_offset = foffset;
    foffset += string_table->size();            // string table

    // Compute file offsets of all the section data

    for (segidx_t seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &ScnhdrTab[pseg->SDshtidx];   // corresponding section

        int align = pseg->SDalignment;
        if (align > 1)
            foffset = (foffset + align - 1) & ~(align - 1);

        if (pseg->SDbuf && pseg->SDbuf->size())
        {
            psechdr->s_scnptr = foffset;
            //printf("seg = %2d SDshtidx = %2d psechdr = %p s_scnptr = x%x\n", seg, pseg->SDshtidx, psechdr, (unsigned)psechdr->s_scnptr);
            psechdr->s_size = pseg->SDbuf->size();
            foffset += psechdr->s_size;
        }
        else
            psechdr->s_size = pseg->SDoffset;
    }

    // Compute file offsets of the relocation data
    for (segidx_t seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &ScnhdrTab[pseg->SDshtidx];   // corresponding section
        if (pseg->SDrel)
        {
            foffset = (foffset + 3) & ~3;
            assert(psechdr->s_relptr == 0);
            unsigned nreloc = pseg->SDrel->size() / sizeof(struct Relocation);
            if (nreloc)
            {
                psechdr->s_relptr = foffset;
                //printf("seg = %d SDshtidx = %d psechdr = %p s_relptr = x%x\n", seg, pseg->SDshtidx, psechdr, (unsigned)psechdr->s_relptr);
                psechdr->s_nreloc = nreloc;
                foffset += nreloc * sizeof(struct reloc);
            }
        }
    }

    assert(fobjbuf->size() == 0);

    // Write the header
    fobjbuf->write(&header, sizeof(header));
    foffset = sizeof(header);

    // Write the section headers
    fobjbuf->write(ScnhdrBuf);
    foffset += ScnhdrBuf->size();

    // Write the symbol table
    assert(foffset == header.f_symptr);
    fobjbuf->write(syment_buf);
    foffset += syment_buf->size();

    // Write the string table
    assert(foffset == string_table_offset);
    *(unsigned *)(string_table->buf) = string_table->size();
    fobjbuf->write(string_table);
    foffset += string_table->size();

    // Write the section data
    for (segidx_t seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &ScnhdrTab[pseg->SDshtidx];   // corresponding section
        foffset = elf_align(pseg->SDalignment, foffset);
        if (pseg->SDbuf && pseg->SDbuf->size())
        {
            //printf("seg = %2d SDshtidx = %2d psechdr = %p s_scnptr = x%x, foffset = x%x\n", seg, pseg->SDshtidx, psechdr, (unsigned)psechdr->s_scnptr, (unsigned)foffset);
            assert(pseg->SDbuf->size() == psechdr->s_size);
            assert(foffset == psechdr->s_scnptr);
            fobjbuf->write(pseg->SDbuf);
            foffset += pseg->SDbuf->size();
        }
    }

    // Compute the relocations, write them out
    assert(sizeof(struct reloc) == 10);
    for (segidx_t seg = 1; seg <= seg_count; seg++)
    {
        seg_data *pseg = SegData[seg];
        scnhdr *psechdr = &ScnhdrTab[pseg->SDshtidx];   // corresponding section
        if (pseg->SDrel)
        {   Relocation *r = (Relocation *)pseg->SDrel->buf;
            size_t sz = pseg->SDrel->size();
            bool pdata = (strcmp(psechdr->s_name, ".pdata") == 0);
            Relocation *rend = (Relocation *)(pseg->SDrel->buf + sz);
            foffset = elf_align(4, foffset);
#ifdef DEBUG
            if (sz && foffset != psechdr->s_relptr)
                printf("seg = %d SDshtidx = %d psechdr = %p s_relptr = x%x, foffset = x%x\n", seg, pseg->SDshtidx, psechdr, (unsigned)psechdr->s_relptr, (unsigned)foffset);
#endif
            assert(sz == 0 || foffset == psechdr->s_relptr);
            for (; r != rend; r++)
            {   reloc rel;
                rel.r_vaddr = 0;
                rel.r_symndx = 0;
                rel.r_type = 0;

                symbol *s = r->targsym;
                const char *rs = r->rtype == RELaddr ? "addr" : "rel";
                //printf("%d:x%04lx : tseg %d tsym %s REL%s\n", seg, (int)r->offset, r->targseg, s ? s->Sident : "0", rs);
                if (s)
                {
                    //printf("Relocation\n");
                    //symbol_print(s);
                    if (pseg->isCode())
                    {
                        if (I64)
                        {
//printf("test1 %s %d\n", s->Sident, r->val);
#if 1
                            rel.r_type = (r->rtype == RELrel)
                                    ? IMAGE_REL_AMD64_REL32
                                    : IMAGE_REL_AMD64_REL32;

                            if (s->Stype->Tty & mTYthread)
                                rel.r_type = IMAGE_REL_AMD64_SECREL;

                            if (r->val == -1)
                                rel.r_type = IMAGE_REL_AMD64_REL32_1;
                            else if (r->val == -2)
                                rel.r_type = IMAGE_REL_AMD64_REL32_2;
                            else if (r->val == -3)
                                rel.r_type = IMAGE_REL_AMD64_REL32_3;
                            else if (r->val == -4)
                                rel.r_type = IMAGE_REL_AMD64_REL32_4;
                            else if (r->val == -5)
                                rel.r_type = IMAGE_REL_AMD64_REL32_5;

                            if (s->Sclass == SCextern ||
                                s->Sclass == SCcomdef ||
                                s->Sclass == SCcomdat ||
                                s->Sclass == SCglobal)
                            {
                                rel.r_vaddr = r->offset;
                                rel.r_symndx = s->Sxtrnnum;
                            }
                            else
                            {
                                rel.r_vaddr = r->offset;
                                rel.r_symndx = s->Sxtrnnum;
#if 0
                                int32_t *p = patchAddr(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
//printf("*p = x%x, .s_vaddr = x%x, Soffset = x%x\n", *p, (int)ScnhdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr, (int)s->Soffset);
//printf("pseg = x%x, r->offset = x%x\n", (int)ScnhdrTab[pseg->SDshtidx].s_vaddr, (int)r->offset);
                                *p += ScnhdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr;
                                *p += s->Soffset;
                                *p -= ScnhdrTab[pseg->SDshtidx].s_vaddr + r->offset + 4;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
#endif
                            }
#endif
                        }
                        else if (I32)
                        {
                            rel.r_type = (r->rtype == RELrel)
                                    ? IMAGE_REL_I386_REL32
                                    : IMAGE_REL_I386_DIR32;

                            if (s->Stype->Tty & mTYthread)
                                rel.r_type = IMAGE_REL_I386_SECREL;

                            if (s->Sclass == SCextern ||
                                s->Sclass == SCcomdef ||
                                s->Sclass == SCcomdat ||
                                s->Sclass == SCglobal)
                            {
                                rel.r_vaddr = r->offset;
                                rel.r_symndx = s->Sxtrnnum;
                            }
                            else
                            {
                                rel.r_vaddr = r->offset;
                                rel.r_symndx = s->Sxtrnnum;
                            }
                        }
                        else
                            assert(false); // not implemented for I16
                    }
                    else
                    {
//printf("test2\n");
                        if (I64)
                        {
                            if (pdata)
                                rel.r_type = IMAGE_REL_AMD64_ADDR32NB;
                            else
                                rel.r_type = IMAGE_REL_AMD64_ADDR64;

                            if (r->rtype == RELseg)
                                rel.r_type = IMAGE_REL_AMD64_SECTION;
                            else if (r->rtype == RELaddr32)
                                rel.r_type = IMAGE_REL_AMD64_SECREL;
                        }
                        else if (I32)
                        {
                            if (pdata)
                                rel.r_type = IMAGE_REL_I386_DIR32NB;
                            else
                                rel.r_type = IMAGE_REL_I386_DIR32;

                            if (r->rtype == RELseg)
                                rel.r_type = IMAGE_REL_I386_SECTION;
                            else if (r->rtype == RELaddr32)
                                rel.r_type = IMAGE_REL_I386_SECREL;
                        }
                        else
                            assert(false); // not implemented for I16

                        rel.r_vaddr = r->offset;
                        rel.r_symndx = s->Sxtrnnum;
#if 0
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
                            if (I64)
                            {
                                rel.r_length = 3;
                                int32_t *p = patchAddr64(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
                                *p += ScnhdrTab64[SegData[s->Sseg]->SDshtidx].s_vaddr + s->Soffset;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
                            }
                            else
                            {
                                int32_t *p = patchAddr(seg, r->offset);
                                // Absolute address; add in addr of start of targ seg
                                *p += ScnhdrTab[SegData[s->Sseg]->SDshtidx].s_vaddr + s->Soffset;
                                //patch(pseg, r->offset, s->Sseg, s->Soffset);
                            }
                        }
#endif
                    }
                }
                else if (r->rtype == RELaddr && pseg->isCode())
                {
printf("test3\n");
#if 1
                    int32_t *p = NULL;
                    p = patchAddr(seg, r->offset);

                    rel.r_vaddr = r->offset;
                    rel.r_symndx = s ? s->Sxtrnnum : 0;

                    if (I64)
                    {
                        rel.r_type = IMAGE_REL_AMD64_REL32;
                        //srel.r_value = ScnhdrTab[SegData[r->targseg]->SDshtidx].s_vaddr + *p;
                        //printf("SECTDIFF: x%llx + x%llx = x%x\n", ScnhdrTab[SegData[r->targseg]->SDshtidx].s_vaddr, *p, srel.r_value);
                    }
                    else
                    {
                        rel.r_type = IMAGE_REL_I386_SECREL;
                        //srel.r_value = ScnhdrTab[SegData[r->targseg]->SDshtidx].s_vaddr + *p;
                        //printf("SECTDIFF: x%x + x%x = x%x\n", ScnhdrTab[SegData[r->targseg]->SDshtidx].s_vaddr, *p, srel.r_value);
                    }
#endif
                }
                else
                {
printf("test4\n");
#if 0
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

                    if (I64)
                    {
                        int32_t *p64 = patchAddr64(seg, r->offset);
                        //int64_t before = *p64;
                        if (rel.r_pcrel)
                            // Relative address
                            patch(pseg, r->offset, r->targseg, 0);
                        else
                        {   // Absolute address; add in addr of start of targ seg
//printf("*p = x%x, targ.s_vaddr = x%x\n", *p64, (int)ScnhdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr);
//printf("pseg = x%x, r->offset = x%x\n", (int)ScnhdrTab64[pseg->SDshtidx].s_vaddr, (int)r->offset);
                            *p64 += ScnhdrTab64[SegData[r->targseg]->SDshtidx].s_vaddr;
                            //*p64 -= ScnhdrTab64[pseg->SDshtidx].s_vaddr;
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
                            *p += ScnhdrTab[SegData[r->targseg]->SDshtidx].s_vaddr;
                        //printf("%d:x%04x before = x%04x, after = x%04x pcrel = %d\n", seg, r->offset, before, *p, rel.r_pcrel);
                    }
#endif
                }

                /* Some programs do generate a lot of symbols.
                 * Note that MS-Link can get pretty slow with large numbers of symbols.
                 */
                //assert(rel.r_symndx <= 20000);

                assert(rel.r_type <= 0x14);
                fobjbuf->write(&rel, sizeof(rel));
                foffset += sizeof(rel);
            }
        }
    }

    fobjbuf->flush();
}

/*****************************
 * Line number support.
 */

/***************************
 * Record file and line number at segment and offset.
 * Input:
 *      cseg    current code segment
 */

void MsCoffObj::linnum(Srcpos srcpos, targ_size_t offset)
{
    if (srcpos.Slinnum == 0 || !srcpos.Sfilename)
        return;

    cv8_linnum(srcpos, offset);
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
    SegData[segidx_drectve]->SDbuf->write(" /DEFAULTLIB:\"", 14);
    SegData[segidx_drectve]->SDbuf->write(name, strlen(name));
    SegData[segidx_drectve]->SDbuf->writeByte('"');
    return true;
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
    //printf("MsCoffObj::ehtables(func = %s, handler table = %s) \n",sfunc->Sident, ehsym->Sident);

    /* BUG: this should go into a COMDAT if sfunc is in a COMDAT
     * otherwise the duplicates aren't removed.
     */

    int align = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;  // align to NPTRSIZE

    // The size is sizeof(struct FuncTable) in deh2.d
    const int seg =
    MsCoffObj::getsegment("._deh$B", IMAGE_SCN_CNT_INITIALIZED_DATA |
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
 * This gets called if this is the module with "extern (D) main()" in it.
 */

void MsCoffObj::ehsections()
{
    //printf("MsCoffObj::ehsections()\n");

  {
    int align = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;

    const int segdeh_bg =
    MsCoffObj::getsegment("._deh$A", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                     align |
                                     IMAGE_SCN_MEM_READ);

    const int segdeh_en =
    MsCoffObj::getsegment("._deh$C", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                     align |
                                     IMAGE_SCN_MEM_READ);

    /* Create symbol _eh_beg that sits just before the ._deh$B section
     */
    symbol *eh_beg = symbol_name("_deh_beg", SCglobal, tspvoid);
    eh_beg->Sseg = segdeh_bg;
    eh_beg->Soffset = 0;
    symbuf->write(&eh_beg, sizeof(eh_beg));
    MsCoffObj::bytes(segdeh_bg, 0, I64 ? 8 * 3 : 4 * 3, NULL);

    /* Create symbol _eh_end that sits just after the ._deh$B section
     */
    symbol *eh_end = symbol_name("_deh_end", SCglobal, tspvoid);
    eh_end->Sseg = segdeh_en;
    eh_end->Soffset = 0;
    symbuf->write(&eh_end, sizeof(eh_end));
    MsCoffObj::bytes(segdeh_en, 0, I64 ? 8 : 4, NULL);
  }

    /*************************************************************************/

  {
    /* Module info sections
     */
    int align = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;

    const int segbg =
    MsCoffObj::getsegment(".minfo$A", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align |
                                      IMAGE_SCN_MEM_READ);
    const int segen =
    MsCoffObj::getsegment(".minfo$C", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align |
                                      IMAGE_SCN_MEM_READ);

    /* Create symbol _minfo_beg that sits just before the .minfo$B section
     */
    symbol *minfo_beg = symbol_name("_minfo_beg", SCglobal, tspvoid);
    minfo_beg->Sseg = segbg;
    minfo_beg->Soffset = 0;
    symbuf->write(&minfo_beg, sizeof(minfo_beg));
    MsCoffObj::bytes(segbg, 0, I64 ? 8 : 4, NULL);

    /* Create symbol _minfo_end that sits just after the .minfo$B section
     */
    symbol *minfo_end = symbol_name("_minfo_end", SCglobal, tspvoid);
    minfo_end->Sseg = segen;
    minfo_end->Soffset = 0;
    symbuf->write(&minfo_end, sizeof(minfo_end));
    MsCoffObj::bytes(segen, 0, I64 ? 8 : 4, NULL);
  }

    /*************************************************************************/

#if 0
  {
    /* TLS sections
     */
    int align = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_4BYTES;

    int segbg =
    MsCoffObj::getsegment(".tls$AAA", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align |
                                      IMAGE_SCN_MEM_READ |
                                      IMAGE_SCN_MEM_WRITE);
    int segen =
    MsCoffObj::getsegment(".tls$AAC", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align |
                                      IMAGE_SCN_MEM_READ |
                                      IMAGE_SCN_MEM_WRITE);

    /* Create symbol _minfo_beg that sits just before the .tls$AAB section
     */
    symbol *minfo_beg = symbol_name("_tlsstart", SCglobal, tspvoid);
    minfo_beg->Sseg = segbg;
    minfo_beg->Soffset = 0;
    symbuf->write(&minfo_beg, sizeof(minfo_beg));
    MsCoffObj::bytes(segbg, 0, I64 ? 8 : 4, NULL);

    /* Create symbol _minfo_end that sits just after the .tls$AAB section
     */
    symbol *minfo_end = symbol_name("_tlsend", SCglobal, tspvoid);
    minfo_end->Sseg = segen;
    minfo_end->Soffset = 0;
    symbuf->write(&minfo_end, sizeof(minfo_end));
    MsCoffObj::bytes(segen, 0, I64 ? 8 : 4, NULL);
  }
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
    //symbol_debug(s);

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
        s->Sseg = MsCoffObj::getsegment(".tls$AAB", IMAGE_SCN_CNT_INITIALIZED_DATA |
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
    {   SegData[s->Sseg]->SDalignment = s->Salignment;
        assert(s->Salignment >= -1);
    }
    s->Soffset = SegData[s->Sseg]->SDoffset;
    if (s->Sfl == FLdata || s->Sfl == FLtlsdata)
    {   // Code symbols are 'published' by MsCoffObj::func_start()

        MsCoffObj::pubdef(s->Sseg,s,s->Soffset);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    return s->Sseg;
}

/**********************************
 * Get segment, which may already exist.
 * Input:
 *      flags2  put out some data for this, so the linker will keep things in order
 * Returns:
 *      segment index of found or newly created segment
 */

segidx_t MsCoffObj::getsegment(const char *sectname, unsigned long flags)
{
    //printf("getsegment(%s)\n", sectname);
    assert(strlen(sectname) <= 8);      // so it won't go into string_table
    if (!(flags & IMAGE_SCN_LNK_COMDAT))
    {
        for (segidx_t seg = 1; seg <= seg_count; seg++)
        {   seg_data *pseg = SegData[seg];
            if (!(ScnhdrTab[pseg->SDshtidx].s_flags & IMAGE_SCN_LNK_COMDAT) &&
                strncmp(ScnhdrTab[pseg->SDshtidx].s_name, sectname, 8) == 0)
            {
                //printf("\t%s\n", sectname);
                return seg;         // return existing segment
            }
        }
    }

    segidx_t seg = getsegment2(addScnhdr(sectname, flags));

    //printf("\tseg_count = %d\n", seg_count);
    //printf("\tseg = %d, %d, %s\n", seg, SegData[seg]->SDshtidx, ScnhdrTab[SegData[seg]->SDshtidx].s_name);
    return seg;
}

/******************************************
 * Create a new segment corresponding to an existing scnhdr index shtidx
 */

segidx_t MsCoffObj::getsegment2(IDXSEC shtidx)
{
    segidx_t seg = ++seg_count;
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
        if (!(ScnhdrTab[shtidx].s_flags & IMAGE_SCN_CNT_UNINITIALIZED_DATA))
        {   pseg->SDbuf = new Outbuffer(4096);
            pseg->SDbuf->reserve(4096);
        }
    }

    //dbg_printf("\tNew segment - %d size %d\n", seg,SegData[seg]->SDbuf);
    seg_data *pseg = SegData[seg];

    pseg->SDseg = seg;
    pseg->SDoffset = 0;

    pseg->SDshtidx = shtidx;
    pseg->SDaranges_offset = 0;
    pseg->SDlinnum_count = 0;

    //printf("seg_count = %d\n", seg_count);
    return seg;
}

/********************************************
 * Add new scnhdr.
 * Returns:
 *      scnhdr number for added scnhdr
 */

IDXSEC MsCoffObj::addScnhdr(const char *scnhdr_name, unsigned long flags)
{
    struct scnhdr sec;
    memset(&sec, 0, sizeof(sec));
    size_t len = strlen(scnhdr_name);
    if (len > 8)
    {   // Use /nnnn form
        IDXSTR idx = addstr(string_table, scnhdr_name);
        sprintf(sec.s_name, "/%d", idx);
    }
    else
        memcpy(sec.s_name, scnhdr_name, len);
    sec.s_flags = flags;
    ScnhdrBuf->write((void *)&sec, sizeof(sec));
    return ++scnhdr_cnt;
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
    //printf("MsCoffObj::tlsseg\n");

    if (seg_tlsseg == UNKNOWN)
    {
        seg_tlsseg = MsCoffObj::getsegment(".tls$AAB", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                              IMAGE_SCN_ALIGN_16BYTES |
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

/*************************************
 * Return segment indices for .pdata and .xdata sections
 */

segidx_t MsCoffObj::seg_pdata()
{
    if (segidx_pdata == UNKNOWN)
    {
        segidx_pdata = MsCoffObj::getsegment(".pdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ);
    }
    return segidx_pdata;
}

segidx_t MsCoffObj::seg_xdata()
{
    if (segidx_xdata == UNKNOWN)
    {
        segidx_xdata = MsCoffObj::getsegment(".xdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ);
    }
    return segidx_xdata;
}

segidx_t MsCoffObj::seg_pdata_comdat(symbol *sfunc)
{
    segidx_t seg = MsCoffObj::getsegment(".pdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT);
    SegData[seg]->SDassocseg = sfunc->Sseg;
    return seg;
}

segidx_t MsCoffObj::seg_xdata_comdat(symbol *sfunc)
{
    segidx_t seg = MsCoffObj::getsegment(".xdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT);
    SegData[seg]->SDassocseg = sfunc->Sseg;
    return seg;
}

segidx_t MsCoffObj::seg_debugS()
{
    // Probably should generate this lazilly, too.
    return segidx_debugS;
}


segidx_t MsCoffObj::seg_debugS_comdat(symbol *sfunc)
{
    //printf("associated with seg %d\n", sfunc->Sseg);
    segidx_t seg = MsCoffObj::getsegment(".debug$S", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT |
                                          IMAGE_SCN_MEM_DISCARDABLE);
    SegData[seg]->SDassocseg = sfunc->Sseg;
    return seg;
}

segidx_t MsCoffObj::seg_debugT()
{
    segidx_t seg = MsCoffObj::getsegment(".debug$T", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_MEM_DISCARDABLE);
    return seg;
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
                size_t prelen = I32 ? 1 : 0;
                size_t destlen = prelen + len + 1 + pstrlen + 1;

                if (destlen > DEST_LEN)
                    dest = (char *)mem_malloc(destlen);
                dest[0] = '_';
                memcpy(dest + prelen,name,len);
                dest[prelen + len] = '@';
                memcpy(dest + prelen + 1 + len, pstr, pstrlen + 1);
                break;
            }
        case mTYman_cpp:
        case mTYman_d:
        case mTYman_sys:
        case_mTYman_c64:
        case 0:
            if (len >= DEST_LEN)
                dest = (char *)mem_malloc(len + 1);
            memcpy(dest,name,len+1);// copy in name and trailing 0
            break;

        case mTYman_c:
            if(I64)
                goto case_mTYman_c64;
            // Prepend _ to identifier
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
    char dest[DEST_LEN+1];
    char *destr = obj_mangle2(s, dest);

    //printf("MsCoffObj::export_symbol(%s,%d)\n",s->Sident,argsize);
    SegData[segidx_drectve]->SDbuf->write(" /EXPORT:", 9);
    SegData[segidx_drectve]->SDbuf->write(dest, strlen(dest));
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

segidx_t MsCoffObj::data_start(Symbol *sdata, targ_size_t datasize, segidx_t seg)
{
    targ_size_t alignbytes;

    //printf("MsCoffObj::data_start(%s,size %d,seg %d)\n",sdata->Sident,(int)datasize,seg);
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
        alignbytes = ((offset + sdata->Salignment - 1) & ~(sdata->Salignment - 1)) - offset;
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

    if (config.fulltypes)
        cv8_func_start(sfunc);
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
    if (config.fulltypes)
        cv8_func_term(sfunc);
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s ->            symbol
 *      offset =        offset of name within segment
 */

void MsCoffObj::pubdef(segidx_t seg, Symbol *s, targ_size_t offset)
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
            symbuf->write(&s, sizeof(s));
            break;
        case SCcomdat:
        case SCcomdef:
            symbuf->write(&s, sizeof(s));
            break;
        default:
            symbuf->write(&s, sizeof(s));
            break;
    }
    //printf("%p\n", *(void**)symbuf->buf);
    s->Sxtrnnum = 1;
}

void MsCoffObj::pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
{
    pubdef(seg, s, offset);
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

int MsCoffObj::external_def(const char *name)
{
    //printf("MsCoffObj::external_def('%s')\n",name);
    assert(name);
    symbol *s = symbol_name(name, SCextern, tspvoid);
    symbuf->write(&s, sizeof(s));
    return 0;
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
    symbuf->write(&s, sizeof(s));
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

    /* A common block looks like this in the symbol table:
     *  n_name    = s->Sident
     *  n_value   = size * count
     *  n_scnum   = IMAGE_SYM_UNDEFINED
     *  n_type    = x0000
     *  n_sclass  = IMAGE_SYM_CLASS_EXTERNAL
     *  n_numaux  = 0
     */

    struct Comdef comdef;
    comdef.sym = s;
    comdef.size = size;
    comdef.count = count;
    comdef_symbuf->write(&comdef, sizeof(comdef));

    s->Sxtrnnum = 1;
    if (!s->Sseg)
        s->Sseg = UDATA;
    return 1;           // should return void
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

void MsCoffObj::lidata(segidx_t seg,targ_size_t offset,targ_size_t count)
{
    //printf("MsCoffObj::lidata(%d,%x,%d)\n",seg,offset,count);
    size_t idx = SegData[seg]->SDshtidx;
    if ((ScnhdrTab[idx].s_flags) & IMAGE_SCN_CNT_UNINITIALIZED_DATA)
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

void MsCoffObj::byte(segidx_t seg,targ_size_t offset,unsigned byte)
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

unsigned MsCoffObj::bytes(segidx_t seg, targ_size_t offset, unsigned nbytes, void *p)
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

void MsCoffObj::addrel(segidx_t seg, targ_size_t offset, symbol *targsym,
        unsigned targseg, int rtype, int val)
{
    //printf("addrel()\n");
    if (!targsym)
    {   // Generate one
        targsym = symbol_generate(SCstatic, tsint);
        targsym->Sseg = targseg;
        targsym->Soffset = val;
        symbuf->write(&targsym, sizeof(targsym));
    }

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

#if 0
void MsCoffObj::addrel(segidx_t seg, targ_size_t offset, unsigned type,
                                        IDXSYM symidx, targ_size_t val)
{
    printf("addrel2()\n");
}
#endif

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

void MsCoffObj::reftodatseg(segidx_t seg,targ_size_t offset,targ_size_t val,
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
    MsCoffObj::addrel(seg, offset, NULL, targetdatum, RELaddr, 0);
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

void MsCoffObj::reftocodeseg(segidx_t seg,targ_size_t offset,targ_size_t val)
{
    //printf("MsCoffObj::reftocodeseg(seg=%d, offset=x%lx, val=x%lx )\n",seg,(unsigned long)offset,(unsigned long)val);
    assert(seg > 0);
    Outbuffer *buf = SegData[seg]->SDbuf;
    int save = buf->size();
    buf->setsize(offset);
    val -= funcsym_p->Soffset;
    if (I32)
        MsCoffObj::addrel(seg, offset, funcsym_p, 0, RELaddr, 0);
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

int MsCoffObj::reftoident(segidx_t seg, targ_size_t offset, Symbol *s, targ_size_t val,
        int flags)
{
    int retsize = (flags & CFoffset64) ? 8 : 4;
    if (flags & CFseg)
        retsize += 2;
#if 0
    printf("\nMsCoffObj::reftoident('%s' seg %d, offset x%llx, val x%llx, flags x%x)\n",
        s->Sident,seg,(unsigned long long)offset,(unsigned long long)val,flags);
    //printf("retsize = %d\n", retsize);
    //dbg_printf("Sseg = %d, Sxtrnnum = %d\n",s->Sseg,s->Sxtrnnum);
    //symbol_print(s);
#endif
    assert(seg > 0);
    if (s->Sclass != SClocstat && !s->Sxtrnnum)
    {   // It may get defined later as public or local, so defer
        size_t numbyteswritten = addtofixlist(s, offset, seg, val, flags);
        assert(numbyteswritten == retsize);
    }
    else
    {
        if (I64 || I32)
        {
            //if (s->Sclass != SCcomdat)
                //val += s->Soffset;
            int v = 0;
            if (flags & CFpc32)
            {
                v = -((flags & CFREL) >> 24);
                assert(v >= -5 && v <= 0);
            }
            if (flags & CFselfrel)
            {
                MsCoffObj::addrel(seg, offset, s, 0, RELrel, v);
            }
            else if ((flags & (CFseg | CFoff)) == (CFseg | CFoff))
            {
                MsCoffObj::addrel(seg, offset,     s, 0, RELaddr32, v);
                MsCoffObj::addrel(seg, offset + 4, s, 0, RELseg, v);
                retsize = 6;    // 4 bytes for offset, 2 for section
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
//                ScnhdrTab[pseg->SDshtidx].reserved2 = 5;

#if 0
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
#endif
             L1:
                val -= offset + 4;
                MsCoffObj::addrel(seg, offset, NULL, jumpTableSeg, RELrel, 0);
            }
            else if (SegData[seg]->isCode() &&
                    ((s->Sclass != SCextern && SegData[s->Sseg]->isCode()) || s->Sclass == SClocstat || s->Sclass == SCstatic))
            {
                val += s->Soffset;
                MsCoffObj::addrel(seg, offset, NULL, s->Sseg, RELaddr, 0);
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
                MsCoffObj::addrel(seg, offset, NULL, pointersSeg, RELaddr, 0);
            }
            else
            {   //val -= s->Soffset;
//                MsCoffObj::addrel(seg, offset, s, 0, RELaddr, 0);
            }
        }

        Outbuffer *buf = SegData[seg]->SDbuf;
        int save = buf->size();
        buf->setsize(offset);
        //printf("offset = x%llx, val = x%llx\n", offset, val);
        if (retsize == 8)
            buf->write64(val);
        else if (retsize == 4)
            buf->write32(val);
        else if (retsize == 6)
        {
            buf->write32(val);
            buf->writeWord(0);
        }
        else
            assert(0);
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
    /* Otherwise, we'll get the dreaded
     *    "runtime error R6002 - floating point support not loaded"
     */
    if (!floatused)
    {
        external_def("_fltused");
        floatused = 1;
    }
}


long elf_align(int size, long foffset)
{
    if (size <= 1)
        return foffset;
    long offset = (foffset + size - 1) & ~(size - 1);
    //printf("offset = x%lx, foffset = x%lx, size = x%lx\n", offset, foffset, (long)size);
    if (offset > foffset)
        fobjbuf->writezeros(offset - foffset);
    return offset;
}

/***************************************
 * Stuff pointer to ModuleInfo in its own segment.
 * Input:
 *      scc     symbol for ModuleInfo
 */

#if MARS

void MsCoffObj::moduleinfo(Symbol *scc)
{
    int align = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;

    /* Module info sections
     */
    const int seg =
    MsCoffObj::getsegment(".minfo$B", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align |
                                      IMAGE_SCN_MEM_READ);
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

/**********************************
 * Reset code seg to existing seg.
 * Used after a COMDAT for a function is done.
 */

void MsCoffObj::setcodeseg(int seg)
{
    assert(0 < seg && seg <= seg_count);
    cseg = seg;
}


#endif
#endif
