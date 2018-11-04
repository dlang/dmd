/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) ?-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/elfobj.d, backend/elfobj.d)
 */

module dmd.backend.elfobj;

/****
 * Output to ELF object files
 * http://www.sco.com/developers/gabi/2003-12-17/ch4.sheader.html
 */

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.memh;
import dmd.backend.aarray;
import dmd.backend.dlist;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.outbuf;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

static if (ELFOBJ)
{

import dmd.backend.dwarf;
import dmd.backend.melf;

extern bool symbol_iscomdat2(Symbol* s);

static if (TARGET_LINUX)
    enum ELFOSABI = ELFOSABI_LINUX;
else static if (TARGET_FREEBSD)
    enum ELFOSABI = ELFOSABI_FREEBSD;
else static if (TARGET_SOLARIS)
    enum ELFOSABI = ELFOSABI_SYSV;
else static if (TARGET_OPENBSD)
    enum ELFOSABI = ELFOSABI_OPENBSD;
else static if (TARGET_DRAGONFLYBSD)
    enum ELFOSABI = ELFOSABI_SYSV;
else
    static assert(0, "No ELF OS ABI defined.  Please fix");

//#define DEBSYM 0x7E

private __gshared Outbuffer *fobjbuf;

enum MATCH_SECTION = 1;

enum DEST_LEN = (IDMAX + IDOHD + 1);
char *obj_mangle2(Symbol *s,char *dest, size_t *destlen);

version (MARS)
// C++ name mangling is handled by front end
const(char)* cpp_mangle2(Symbol* s) { return s.Sident.ptr; }
else
const(char)* cpp_mangle2(Symbol* s) { return cpp_mangle(s); }


void addSegmentToComdat(segidx_t seg, segidx_t comdatseg);

/**
 * If set the compiler requires full druntime support of the new
 * section registration.
 */
//version (DMDV2)
static if (1)
    enum DMDV2 = true;
else
    enum DMDV2 = false;
enum REQUIRE_DSO_REGISTRY = (DMDV2 && (TARGET_LINUX || TARGET_FREEBSD || TARGET_DRAGONFLYBSD));

/******
 * FreeBSD uses ELF, but the linker crashes with Elf comdats with the following message:
 *  /usr/bin/ld: BFD 2.15 [FreeBSD] 2004-05-23 internal error, aborting at
 *  /usr/src/gnu/usr.bin/binutils/libbfd/../../../../contrib/binutils/bfd/elfcode.h
 *  line 213 in bfd_elf32_swap_symbol_out
 * For the time being, just stick with Linux.
 */

enum ELF_COMDAT = TARGET_LINUX;

/***************************************************
 * Correspondence of relocation types
 *      386             32 bit in 64      64 in 64
 *      R_386_32        R_X86_64_32       R_X86_64_64
 *      R_386_GOTOFF    R_X86_64_PC32     R_X86_64_
 *      R_386_GOTPC     R_X86_64_         R_X86_64_
 *      R_386_GOT32     R_X86_64_         R_X86_64_
 *      R_386_TLS_GD    R_X86_64_TLSGD    R_X86_64_
 *      R_386_TLS_IE    R_X86_64_GOTTPOFF R_X86_64_
 *      R_386_TLS_LE    R_X86_64_TPOFF32  R_X86_64_
 *      R_386_PLT32     R_X86_64_PLT32    R_X86_64_
 *      R_386_PC32      R_X86_64_PC32     R_X86_64_
 */

/******************************************
 */

__gshared Symbol *GOTsym; // global offset table reference

Symbol *Obj_getGOTsym()
{
    if (!GOTsym)
    {
        GOTsym = symbol_name("_GLOBAL_OFFSET_TABLE_",SCglobal,tspvoid);
    }
    return GOTsym;
}

void Obj_refGOTsym()
{
    if (!GOTsym)
    {
        Symbol *s = Obj_getGOTsym();
        Obj_external(s);
    }
}

//private void objfile_write(FILE *fd, void *buffer, uint len);

// The object file is built is several separate pieces

// Non-repeatable section types have single output buffers
//      Pre-allocated buffers are defined for:
//              Section Names string table
//              Section Headers table
//              Symbol table
//              String table
//              Notes section
//              Comment data

// Section Names  - String table for section names only
private __gshared Outbuffer *section_names;
enum SEC_NAMES_INIT = 800;
enum SEC_NAMES_INC  = 400;

// Hash table for section_names
__gshared AApair *section_names_hashtable;

__gshared int jmpseg;

/* ======================================================================== */

// String Table  - String table for all other names
private __gshared Outbuffer *symtab_strings;


// Section Headers
__gshared Outbuffer  *SECbuf;             // Buffer to build section table in

Elf32_Shdr* SecHdrTab() { return cast(Elf32_Shdr *)SECbuf.buf; }
Elf32_Shdr* GET_SECTION(int secidx) { return SecHdrTab() + secidx; }

const(char)* GET_SECTION_NAME(int secidx)
{
    return cast(const(char)*)section_names.buf + SecHdrTab[secidx].sh_name;
}

// The relocation for text and data seems to get lost.
// Try matching the order gcc output them
// This means defining the sections and then removing them if they are
// not used.
private __gshared int section_cnt; // Number of sections in table

enum
{
    SHN_TEXT        = 1,
    SHN_RELTEXT     = 2,
    SHN_DATA        = 3,
    SHN_RELDATA     = 4,
    SHN_BSS         = 5,
    SHN_RODAT       = 6,
    SHN_STRINGS     = 7,
    SHN_SYMTAB      = 8,
    SHN_SECNAMES    = 9,
    SHN_COM         = 10,
    SHN_NOTE        = 11,
    SHN_GNUSTACK    = 12,
    SHN_CDATAREL    = 13,
}

__gshared IDXSYM *mapsec2sym;
enum S2S_INC = 20;

Elf32_Sym* SymbolTable()   { return cast(Elf32_Sym *)SYMbuf.buf; }
Elf64_Sym* SymbolTable64() { return cast(Elf64_Sym *)SYMbuf.buf; }
private __gshared int symbol_idx;          // Number of symbols in symbol table
private __gshared int local_cnt;           // Number of symbols with STB_LOCAL

enum
{
    STI_FILE     = 1,       // Where file symbol table entry is
    STI_TEXT     = 2,
    STI_DATA     = 3,
    STI_BSS      = 4,
    STI_GCC      = 5,       // Where "gcc2_compiled" symbol is */
    STI_RODAT    = 6,       // Symbol for readonly data
    STI_NOTE     = 7,       // Where note symbol table entry is
    STI_COM      = 8,
    STI_CDATAREL = 9,       // Symbol for readonly data with relocations
}

// NOTE: There seems to be a requirement that the read-only data have the
// same symbol table index and section index. Use section NOTE as a place
// holder. When a read-only string section is required, swap to NOTE.

__gshared
{

// Symbol Table
Outbuffer  *SYMbuf;             // Buffer to build symbol table in

// This should be renamed, even though it is private it conflicts with other reset_symbuf's
extern (D) private Outbuffer *reset_symbuf; // Keep pointers to reset symbols

// Extended section header indices
private Outbuffer *shndx_data;
private const IDXSEC secidx_shndx = SHN_HIRESERVE + 1;

// Notes data (note currently used)
private Outbuffer *note_data;
private IDXSEC secidx_note;      // Final table index for note data

// Comment data for compiler version
private Outbuffer *comment_data;
private const(char)* compiler = "\0Digital Mars C/C++" ~
        " 2.083" //VERSION
        ;       // compiled by ...

// Each compiler segment is an elf section
// Predefined compiler segments CODE,DATA,CDATA,UDATA map to indexes
//      into SegData[]
//      An additionl index is reserved for comment data
//      New compiler segments are added to end.
//
// There doesn't seem to be any way to get reserved data space in the
//      same section as initialized data or code, so section offsets should
//      be continuous when adding data. Fix-ups anywhere withing existing data.

enum COMD = CDATAREL+1;

enum
{
    OB_SEG_SIZ      = 10,          // initial number of segments supported
    OB_SEG_INC      = 10,          // increment for additional segments

    OB_CODE_STR     = 100000,      // initial size for code
    OB_CODE_INC     = 100000,      // increment for additional code
    OB_DATA_STR     = 100000,      // initial size for data
    OB_DATA_INC     = 100000,      // increment for additional data
    OB_CDATA_STR    =   1024,      // initial size for data
    OB_CDATA_INC    =   1024,      // increment for additional data
    OB_COMD_STR     =    256,      // initial size for comments
                                   // increment as needed
    OB_XTRA_STR     =    250,      // initial size for extra segments
    OB_XTRA_INC     =  10000,      // increment size
}

IDXSEC      MAP_SEG2SECIDX(int seg) { return SegData[seg].SDshtidx; }
extern (D)
IDXSYM      MAP_SEG2SYMIDX(int seg) { return SegData[seg].SDsymidx; }
Elf32_Shdr* MAP_SEG2SEC(int seg)    { return &SecHdrTab[MAP_SEG2SECIDX(seg)]; }
int         MAP_SEG2TYP(int seg)    { return MAP_SEG2SEC(seg).sh_flags & SHF_EXECINSTR ? CODE : DATA; }

public seg_data **SegData;
public int seg_count;
int seg_max;
int seg_tlsseg = UNKNOWN;
int seg_tlsseg_bss = UNKNOWN;

}


/*******************************
 * Output a string into a string table
 * Input:
 *      strtab  =       string table for entry
 *      str     =       string to add
 *
 * Returns index into the specified string table.
 */

IDXSTR Obj_addstr(Outbuffer *strtab, const(char)* str)
{
    //dbg_printf("Obj_addstr(strtab = x%x str = '%s')\n",strtab,str);
    IDXSTR idx = cast(IDXSTR)strtab.size();        // remember starting offset
    strtab.writeString(str);
    //dbg_printf("\tidx %d, new size %d\n",idx,strtab.size());
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

private IDXSTR elf_findstr(Outbuffer *strtab, const(char)* str, const(char)* suffix)
{
    //printf("elf_findstr(strtab = %p, str = %s, suffix = %s\n", strtab, str ? str : "", suffix ? suffix : "");

    size_t len = strlen(str);

    // Combine str~suffix and have buf point to the combination
debug
    char[25] tmpbuf = void;    // to exercise the malloc() code path
else
    char[1024] tmpbuf = void;  // the malloc() code path is slow

    const(char)* buf;
    if (suffix)
    {
        size_t suffixlen = strlen(suffix);
        if (len + suffixlen >= (tmpbuf).sizeof)
        {
             buf = cast(char *)malloc(len + suffixlen + 1);
             assert(buf);
        }
        else
        {
             buf = &tmpbuf[0];
        }
        memcpy(cast(char *)buf, str, len);
        memcpy(cast(char *)buf + len, suffix, suffixlen + 1);
        len += suffixlen;
    }
    else
        buf = str;

    // Linear search, slow
    const(char)* ent = cast(char *)strtab.buf+1;
    const(char)* pend = ent+strtab.size() - 1;
    while (ent + len < pend)
    {
        if (memcmp(buf, ent, len + 1) == 0)
            return cast(uint)(ent - cast(const(char)* )strtab.buf);
        ent = cast(const(char)* )memchr(ent, 0, pend - ent);
        ent += 1;
    }
    if (buf != &tmpbuf[0])
        free(cast(char*)buf);
    return 0;                   // never found match
}

/*******************************
 * Output a mangled string into the symbol string table
 * Input:
 *      str     =       string to add
 *
 * Returns index into the table.
 */

private IDXSTR elf_addmangled(Symbol *s)
{
    //printf("elf_addmangled(%s)\n", s.Sident.ptr);
    char[DEST_LEN] dest = void;

    IDXSTR namidx = cast(IDXSTR)symtab_strings.size();
    size_t len;
    char *destr = obj_mangle2(s, dest.ptr, &len);
    const(char)* name = destr;
    if (CPP && name[0] == '_' && name[1] == '_')
    {
        if (strncmp(name,"__ct__",6) == 0)
        {
            name += 4;
            len -= 4;
        }
static if (0)
{
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

            default:
                break;
        }
}
    }
    else if (tyfunc(s.ty()) && s.Sfunc && s.Sfunc.Fredirect)
    {
        name = s.Sfunc.Fredirect;
        len = strlen(name);
    }
    symtab_strings.reserve(cast(uint)len+1);
    memcpy(cast(char *)symtab_strings.p, name, len + 1);
    symtab_strings.setsize(cast(uint)(namidx+len+1));
    if (destr != dest.ptr)                  // if we resized result
        mem_free(destr);
    //dbg_printf("\telf_addmagled symtab_strings %s namidx %d len %d size %d\n",name, namidx,len,symtab_strings.size());
    return namidx;
}

/*******************************
 * Output a symbol into the symbol table
 * Input:
 *      stridx  =       string table index for name
 *      val     =       value associated with symbol
 *      sz      =       symbol size
 *      typ     =       symbol type
 *      bind    =       symbol binding
 *      sec     =       index of section where symbol is defined
 *      visibility  =   visibility of symbol (STV_xxxx)
 *
 * Returns the symbol table index for the symbol
 */

private IDXSYM elf_addsym(IDXSTR nam, targ_size_t val, uint sz,
                         uint typ, uint bind, IDXSEC sec,
                         ubyte visibility = STV_DEFAULT)
{
    //dbg_printf("elf_addsym(nam %d, val %d, sz %x, typ %x, bind %x, sec %d\n",
            //nam,val,sz,typ,bind,sec);

    /* We want globally defined data symbols to have a size because
     * zero sized symbols break copy relocations for shared libraries.
     */
    if(sz == 0 && (bind == STB_GLOBAL || bind == STB_WEAK) &&
       (typ == STT_OBJECT || typ == STT_TLS) &&
       sec != SHN_UNDEF)
       sz = 1; // so fake it if it doesn't

    if (sec > SHN_HIRESERVE)
    {   // If the section index is too big we need to store it as
        // extended section header index.
        if (!shndx_data)
        {
            shndx_data = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(shndx_data);
            shndx_data.enlarge(50 * (Elf64_Word).sizeof);
        }
        // fill with zeros up to symbol_idx
        const size_t shndx_idx = shndx_data.size() / Elf64_Word.sizeof;
        shndx_data.writezeros(cast(uint)((symbol_idx - shndx_idx) * Elf64_Word.sizeof));

        shndx_data.write32(sec);
        sec = SHN_XINDEX;
    }

    if (I64)
    {
        if (!SYMbuf)
        {
            SYMbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(SYMbuf);
            SYMbuf.enlarge(50 * Elf64_Sym.sizeof);

            SYMbuf.reserve(100 * Elf64_Sym.sizeof);
        }
        Elf64_Sym sym;
        sym.st_name = nam;
        sym.st_value = val;
        sym.st_size = sz;
        sym.st_info = cast(ubyte)ELF64_ST_INFO(cast(ubyte)bind,cast(ubyte)typ);
        sym.st_other = visibility;
        sym.st_shndx = cast(ushort)sec;
        SYMbuf.write(&sym,sym.sizeof);
    }
    else
    {
        if (!SYMbuf)
        {
            SYMbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(SYMbuf);
            SYMbuf.enlarge(50 * Elf32_Sym.sizeof);

            SYMbuf.reserve(100 * Elf32_Sym.sizeof);
        }
        Elf32_Sym sym;
        sym.st_name = nam;
        sym.st_value = cast(uint)val;
        sym.st_size = sz;
        sym.st_info = ELF32_ST_INFO(cast(ubyte)bind,cast(ubyte)typ);
        sym.st_other = visibility;
        sym.st_shndx = cast(ushort)sec;
        SYMbuf.write(&sym,sym.sizeof);
    }
    if (bind == STB_LOCAL)
        local_cnt++;
    //dbg_printf("\treturning symbol table index %d\n",symbol_idx);
    return symbol_idx++;
}

/*******************************
 * Create a new section header table entry.
 *
 * Input:
 *      name    =       section name
 *      suffix  =       suffix for name or null
 *      type    =       type of data in section sh_type
 *      flags   =       attribute flags sh_flags
 * Output:
 *      section_cnt = assigned number for this section
 *              Note: Sections will be reordered on output
 */

private IDXSEC elf_newsection2(
        Elf32_Word name,
        Elf32_Word type,
        Elf32_Word flags,
        Elf32_Addr addr,
        Elf32_Off offset,
        Elf32_Word size,
        Elf32_Word link,
        Elf32_Word info,
        Elf32_Word addralign,
        Elf32_Word entsize)
{
    Elf32_Shdr sec;

    sec.sh_name = name;
    sec.sh_type = type;
    sec.sh_flags = flags;
    sec.sh_addr = addr;
    sec.sh_offset = offset;
    sec.sh_size = size;
    sec.sh_link = link;
    sec.sh_info = info;
    sec.sh_addralign = addralign;
    sec.sh_entsize = entsize;

    if (!SECbuf)
    {
        SECbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(SECbuf);
        SECbuf.enlarge(50 * Elf32_Shdr.sizeof);

        SECbuf.reserve(16 * Elf32_Shdr.sizeof);
    }
    if (section_cnt == SHN_LORESERVE)
    {   // insert dummy null sections to skip reserved section indices
        section_cnt = SHN_HIRESERVE + 1;
        SECbuf.writezeros((SHN_HIRESERVE + 1 - SHN_LORESERVE) * sec.sizeof);
        // shndx itself becomes the first section with an extended index
        IDXSTR namidx = Obj_addstr(section_names, ".symtab_shndx");
        elf_newsection2(namidx,SHT_SYMTAB_SHNDX,0,0,0,0,SHN_SYMTAB,0,4,4);
    }
    SECbuf.write(cast(void *)&sec, sec.sizeof);
    return section_cnt++;
}

/**
Add a new section name or get the string table index of an existing entry.

Params:
    name = name of section
    suffix = append to name
    padded = set to true when entry was newly added
Returns:
    String index of new or existing section name.
 */
private IDXSTR elf_addsectionname(const(char)* name, const(char)* suffix = null, bool *padded = null)
{
    IDXSTR namidx = cast(IDXSTR)section_names.size();
    section_names.writeString(name);
    if (suffix)
    {   // Append suffix string
        section_names.setsize(cast(uint)section_names.size() - 1);  // back up over terminating 0
        section_names.writeString(suffix);
    }
    IDXSTR *pidx = section_names_hashtable.get(namidx, cast(uint)section_names.size() - 1);
    //IDXSTR *pidx = cast(IDXSTR *)section_names_hashtable.get(&namidx);
    if (*pidx)
    {
        // this section name already exists, remove addition
        section_names.setsize(namidx);
        return *pidx;
    }
    if (padded)
        *padded = true;
    return *pidx = namidx;
}

private IDXSEC elf_newsection(const(char)* name, const(char)* suffix,
        Elf32_Word type, Elf32_Word flags)
{
    // dbg_printf("elf_newsection(%s,%s,type %d, flags x%x)\n",
    //        name?name:"",suffix?suffix:"",type,flags);
    bool added = false;
    IDXSTR namidx = elf_addsectionname(name, suffix, &added);
    assert(added);

    return elf_newsection2(namidx,type,flags,0,0,0,0,0,0,0);
}

/**************************
 * Ouput read only data and generate a symbol for it.
 *
 */

Symbol *Obj_sym_cdata(tym_t ty,char *p,int len)
{
    Symbol *s;

static if (0)
{
    if (OPT_IS_SET(OPTfwritable_strings))
    {
        alignOffset(DATA, tysize(ty));
        s = symboldata(Offset(DATA), ty);
        SegData[DATA].SDbuf.write(p,len);
        s.Sseg = DATA;
        s.Soffset = Offset(DATA);   // Remember its offset into DATA section
        Offset(DATA) += len;
        s.Sfl = /*(config.flags3 & CFG3pic) ? FLgotoff :*/ FLextern;
        return s;
    }
}

    //printf("Obj_sym_cdata(ty = %x, p = %x, len = %d, Offset(CDATA) = %x)\n", ty, p, len, Offset(CDATA));
    alignOffset(CDATA, tysize(ty));
    s = symboldata(Offset(CDATA), ty);
    Obj_bytes(CDATA, Offset(CDATA), len, p);
    s.Sseg = CDATA;

    s.Sfl = /*(config.flags3 & CFG3pic) ? FLgotoff :*/ FLextern;
    return s;
}

/**************************
 * Ouput read only data for data.
 * Output:
 *      *pseg   segment of that data
 * Returns:
 *      offset of that data
 */

int Obj_data_readonly(char *p, int len, int *pseg)
{
    int oldoff = cast(int)Offset(CDATA);
    SegData[CDATA].SDbuf.reserve(len);
    SegData[CDATA].SDbuf.writen(p,len);
    Offset(CDATA) += len;
    *pseg = CDATA;
    return oldoff;
}

int Obj_data_readonly(char *p, int len)
{
    int pseg;

    return Obj_data_readonly(p, len, &pseg);
}

/******************************
 * Get segment for readonly string literals.
 * The linker will pool strings in this section.
 * Params:
 *    sz = number of bytes per character (1, 2, or 4)
 * Returns:
 *    segment index
 */
int Obj_string_literal_segment(uint sz)
{
    /* Elf special sections:
     * .rodata.strM.N - M is size of character
     *                  N is alignment
     * .rodata.cstN   - N fixed size readonly constants N bytes in size,
     *              aligned to the same size
     */
    static immutable char[4][3] name = [ "1.1", "2.2", "4.4" ];
    const int i = (sz == 4) ? 2 : sz - 1;
    const IDXSEC seg =
        Obj_getsegment(".rodata.str".ptr, name[i].ptr, SHT_PROGBITS, SHF_ALLOC | SHF_MERGE | SHF_STRINGS, sz);
    return seg;
}

/******************************
 * Perform initialization that applies to all .o output files.
 *      Called before any other obj_xxx routines
 */

Obj Obj_init(Outbuffer *objbuf, const(char)* filename, const(char)* csegname)
{
    //printf("Obj_init()\n");
    Obj obj = cast(Obj)mem_calloc(__traits(classInstanceSize, Obj));

    cseg = CODE;
    fobjbuf = objbuf;

    mapsec2sym = null;
    note_data = null;
    secidx_note = 0;
    comment_data = null;
    seg_tlsseg = UNKNOWN;
    seg_tlsseg_bss = UNKNOWN;
    GOTsym = null;

    // Initialize buffers

    if (symtab_strings)
        symtab_strings.setsize(1);
    else
    {
        symtab_strings = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(symtab_strings);
        symtab_strings.enlarge(1024);

        symtab_strings.reserve(2048);
        symtab_strings.writeByte(0);
    }

    if (SECbuf)
        SECbuf.setsize(0);
    section_cnt = 0;

    enum
    {
        NAMIDX_NONE      =   0,
        NAMIDX_SYMTAB    =   1,    // .symtab
        NAMIDX_STRTAB    =   9,    // .strtab
        NAMIDX_SHSTRTAB  =  17,    // .shstrtab
        NAMIDX_TEXT      =  27,    // .text
        NAMIDX_DATA      =  33,    // .data
        NAMIDX_BSS       =  39,    // .bss
        NAMIDX_NOTE      =  44,    // .note
        NAMIDX_COMMENT   =  50,    // .comment
        NAMIDX_RODATA    =  59,    // .rodata
        NAMIDX_GNUSTACK  =  67,    // .note.GNU-stack
        NAMIDX_CDATAREL  =  83,    // .data.rel.ro
        NAMIDX_RELTEXT   =  96,    // .rel.text and .rela.text
        NAMIDX_RELDATA   = 106,    // .rel.data
        NAMIDX_RELDATA64 = 107,    // .rela.data
    }

    if (I64)
    {
        static immutable char[107 + 12] section_names_init64 =
          "\0.symtab\0.strtab\0.shstrtab\0.text\0.data\0.bss\0.note" ~
          "\0.comment\0.rodata\0.note.GNU-stack\0.data.rel.ro\0.rela.text\0.rela.data";

        if (section_names)
            section_names.setsize(section_names_init64.sizeof);
        else
        {
            section_names = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(section_names);
            section_names.enlarge(512);

            section_names.reserve(1024);
            section_names.writen(section_names_init64.ptr, section_names_init64.sizeof);
        }

        if (section_names_hashtable)
            AApair.destroy(section_names_hashtable);
            //delete section_names_hashtable;
        section_names_hashtable = AApair.create(&section_names.buf);
        //section_names_hashtable = new AArray(&ti_idxstr, IDXSTR.sizeof);

        // name,type,flags,addr,offset,size,link,info,addralign,entsize
        elf_newsection2(0,               SHT_NULL,   0,                 0,0,0,0,0, 0,0);
        elf_newsection2(NAMIDX_TEXT,SHT_PROGBITS,SHF_ALLOC|SHF_EXECINSTR,0,0,0,0,0, 4,0);
        elf_newsection2(NAMIDX_RELTEXT,SHT_RELA, 0,0,0,0,SHN_SYMTAB,     SHN_TEXT, 8,0x18);
        elf_newsection2(NAMIDX_DATA,SHT_PROGBITS,SHF_ALLOC|SHF_WRITE,   0,0,0,0,0, 8,0);
        elf_newsection2(NAMIDX_RELDATA64,SHT_RELA, 0,0,0,0,SHN_SYMTAB,   SHN_DATA, 8,0x18);
        elf_newsection2(NAMIDX_BSS, SHT_NOBITS,SHF_ALLOC|SHF_WRITE,     0,0,0,0,0, 16,0);
        elf_newsection2(NAMIDX_RODATA,SHT_PROGBITS,SHF_ALLOC,           0,0,0,0,0, 16,0);
        elf_newsection2(NAMIDX_STRTAB,SHT_STRTAB, 0,                    0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_SYMTAB,SHT_SYMTAB, 0,                    0,0,0,0,0, 8,0);
        elf_newsection2(NAMIDX_SHSTRTAB,SHT_STRTAB, 0,                  0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_COMMENT, SHT_PROGBITS,0,                 0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_NOTE,SHT_NOTE,   0,                      0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_GNUSTACK,SHT_PROGBITS,0,                 0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_CDATAREL,SHT_PROGBITS,SHF_ALLOC|SHF_WRITE,0,0,0,0,0, 16,0);

        IDXSTR namidx;
        namidx = NAMIDX_TEXT;      *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_RELTEXT;   *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_DATA;      *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_RELDATA64; *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_BSS;       *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_RODATA;    *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_STRTAB;    *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_SYMTAB;    *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_SHSTRTAB;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_COMMENT;   *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_NOTE;      *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_GNUSTACK;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
        namidx = NAMIDX_CDATAREL;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init64.ptr + namidx)) = namidx;
    }
    else
    {
        static immutable char[106 + 12] section_names_init =
          "\0.symtab\0.strtab\0.shstrtab\0.text\0.data\0.bss\0.note" ~
          "\0.comment\0.rodata\0.note.GNU-stack\0.data.rel.ro\0.rel.text\0.rel.data";

        if (section_names)
            section_names.setsize(section_names_init.sizeof);
        else
        {
            section_names = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(section_names);
            section_names.enlarge(512);

            section_names.reserve(100*1024);
            section_names.writen(section_names_init.ptr, section_names_init.sizeof);
        }

        if (section_names_hashtable)
            AApair.destroy(section_names_hashtable);
            //delete section_names_hashtable;
        section_names_hashtable = AApair.create(&section_names.buf);
        //section_names_hashtable = new AArray(&ti_idxstr, (IDXSTR).sizeof);

        // name,type,flags,addr,offset,size,link,info,addralign,entsize
        elf_newsection2(0,               SHT_NULL,   0,                 0,0,0,0,0, 0,0);
        elf_newsection2(NAMIDX_TEXT,SHT_PROGBITS,SHF_ALLOC|SHF_EXECINSTR,0,0,0,0,0, 16,0);
        elf_newsection2(NAMIDX_RELTEXT,SHT_REL, 0,0,0,0,SHN_SYMTAB,      SHN_TEXT, 4,8);
        elf_newsection2(NAMIDX_DATA,SHT_PROGBITS,SHF_ALLOC|SHF_WRITE,   0,0,0,0,0, 4,0);
        elf_newsection2(NAMIDX_RELDATA,SHT_REL, 0,0,0,0,SHN_SYMTAB,      SHN_DATA, 4,8);
        elf_newsection2(NAMIDX_BSS, SHT_NOBITS,SHF_ALLOC|SHF_WRITE,     0,0,0,0,0, 32,0);
        elf_newsection2(NAMIDX_RODATA,SHT_PROGBITS,SHF_ALLOC,           0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_STRTAB,SHT_STRTAB, 0,                    0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_SYMTAB,SHT_SYMTAB, 0,                    0,0,0,0,0, 4,0);
        elf_newsection2(NAMIDX_SHSTRTAB,SHT_STRTAB, 0,                  0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_COMMENT, SHT_PROGBITS,0,                 0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_NOTE,SHT_NOTE,   0,                      0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_GNUSTACK,SHT_PROGBITS,0,                 0,0,0,0,0, 1,0);
        elf_newsection2(NAMIDX_CDATAREL,SHT_PROGBITS,SHF_ALLOC|SHF_WRITE,0,0,0,0,0, 1,0);

        IDXSTR namidx;
        namidx = NAMIDX_TEXT;     *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_RELTEXT;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_DATA;     *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_RELDATA;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_BSS;      *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_RODATA;   *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_STRTAB;   *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_SYMTAB;   *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_SHSTRTAB; *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_COMMENT;  *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_NOTE;     *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_GNUSTACK; *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
        namidx = NAMIDX_CDATAREL; *section_names_hashtable.get(namidx, namidx + cast(uint)strlen(section_names_init.ptr + namidx)) = namidx;
    }

    if (SYMbuf)
        SYMbuf.setsize(0);
    if (reset_symbuf)
    {
        Symbol **p = cast(Symbol **)reset_symbuf.buf;
        const size_t n = reset_symbuf.size() / (Symbol *).sizeof;
        for (size_t i = 0; i < n; ++i)
            symbol_reset(p[i]);
        reset_symbuf.setsize(0);
    }
    else
    {
        reset_symbuf = cast(Outbuffer*) calloc(1, (Outbuffer).sizeof);
        assert(reset_symbuf);
        reset_symbuf.enlarge(50 * (Symbol *).sizeof);
    }
    if (shndx_data)
        shndx_data.setsize(0);
    symbol_idx = 0;
    local_cnt = 0;
    // The symbols that every object file has
    elf_addsym(0, 0, 0, STT_NOTYPE,  STB_LOCAL, 0);
    elf_addsym(0, 0, 0, STT_FILE,    STB_LOCAL, SHN_ABS);       // STI_FILE
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_TEXT);      // STI_TEXT
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_DATA);      // STI_DATA
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_BSS);       // STI_BSS
    elf_addsym(0, 0, 0, STT_NOTYPE,  STB_LOCAL, SHN_TEXT);      // STI_GCC
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_RODAT);     // STI_RODAT
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_NOTE);      // STI_NOTE
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_COM);       // STI_COM
    elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, SHN_CDATAREL);  // STI_CDATAREL

    // Initialize output buffers for CODE, DATA and COMMENTS
    //      (NOTE not supported, BSS not required)

    seg_count = 0;

    elf_addsegment2(SHN_TEXT, STI_TEXT, SHN_RELTEXT);
    assert(SegData[CODE].SDseg == CODE);

    elf_addsegment2(SHN_DATA, STI_DATA, SHN_RELDATA);
    assert(SegData[DATA].SDseg == DATA);

    elf_addsegment2(SHN_RODAT, STI_RODAT, 0);
    assert(SegData[CDATA].SDseg == CDATA);

    elf_addsegment2(SHN_BSS, STI_BSS, 0);
    assert(SegData[UDATA].SDseg == UDATA);

    elf_addsegment2(SHN_CDATAREL, STI_CDATAREL, 0);
    assert(SegData[CDATAREL].SDseg == CDATAREL);

    elf_addsegment2(SHN_COM, STI_COM, 0);
    assert(SegData[COMD].SDseg == COMD);

    dwarf_initfile(filename);
    return obj;
}

/**************************
 * Initialize the start of object output for this particular .o file.
 *
 * Input:
 *      filename:       Name of source file
 *      csegname:       User specified default code segment name
 */

void Obj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
{
    //dbg_printf("Obj_initfile(filename = %s, modname = %s)\n",filename,modname);

    IDXSTR name = Obj_addstr(symtab_strings, filename);
    if (I64)
        SymbolTable64[STI_FILE].st_name = name;
    else
        SymbolTable[STI_FILE].st_name = name;

static if (0)
{
    // compiler flag for linker
    if (I64)
        SymbolTable64[STI_GCC].st_name = Obj_addstr(symtab_strings,"gcc2_compiled.");
    else
        SymbolTable[STI_GCC].st_name = Obj_addstr(symtab_strings,"gcc2_compiled.");
}

    if (csegname && *csegname && strcmp(csegname,".text"))
    {   // Define new section and make it the default for cseg segment
        // NOTE: cseg is initialized to CODE
        IDXSEC newsecidx;
        Elf32_Shdr *newtextsec;
        IDXSYM newsymidx;
        SegData[cseg].SDshtidx = newsecidx =
            elf_newsection(csegname,null,SHT_PROGBITS,SHF_ALLOC|SHF_EXECINSTR);
        newtextsec = &SecHdrTab[newsecidx];
        newtextsec.sh_addralign = 4;
        SegData[cseg].SDsymidx =
            elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, newsecidx);
    }
    if (config.fulltypes)
        dwarf_initmodule(filename, modname);
}

/***************************
 * Renumber symbols so they are
 * ordered as locals, weak and then global
 * Returns:
 *      sorted symbol table, caller must free with util_free()
 */

void *elf_renumbersyms()
{   void *symtab;
    int nextlocal = 0;
    int nextglobal = local_cnt;

    SYMIDX *sym_map = cast(SYMIDX *)util_malloc(SYMIDX.sizeof,symbol_idx);

    if (I64)
    {
        Elf64_Sym *oldsymtab = cast(Elf64_Sym *)SYMbuf.buf;
        Elf64_Sym *symtabend = oldsymtab+symbol_idx;

        symtab = util_malloc(Elf64_Sym.sizeof,symbol_idx);

        Elf64_Sym *sl = cast(Elf64_Sym *)symtab;
        Elf64_Sym *sg = sl + local_cnt;

        int old_idx = 0;
        for(Elf64_Sym *s = oldsymtab; s != symtabend; s++)
        {   // reorder symbol and map new #s to old
            int bind = ELF64_ST_BIND(s.st_info);
            if (bind == STB_LOCAL)
            {
                *sl++ = *s;
                sym_map[old_idx] = nextlocal++;
            }
            else
            {
                *sg++ = *s;
                sym_map[old_idx] = nextglobal++;
            }
            old_idx++;
        }
    }
    else
    {
        Elf32_Sym *oldsymtab = cast(Elf32_Sym *)SYMbuf.buf;
        Elf32_Sym *symtabend = oldsymtab+symbol_idx;

        symtab = util_malloc(Elf32_Sym.sizeof,symbol_idx);

        Elf32_Sym *sl = cast(Elf32_Sym *)symtab;
        Elf32_Sym *sg = sl + local_cnt;

        int old_idx = 0;
        for(Elf32_Sym *s = oldsymtab; s != symtabend; s++)
        {   // reorder symbol and map new #s to old
            int bind = ELF32_ST_BIND(s.st_info);
            if (bind == STB_LOCAL)
            {
                *sl++ = *s;
                sym_map[old_idx] = nextlocal++;
            }
            else
            {
                *sg++ = *s;
                sym_map[old_idx] = nextglobal++;
            }
            old_idx++;
        }
    }

    // Reorder extended section header indices
    if (shndx_data && shndx_data.size())
    {
        // fill with zeros up to symbol_idx
        const size_t shndx_idx = shndx_data.size() / Elf64_Word.sizeof;
        shndx_data.writezeros(cast(uint)((symbol_idx - shndx_idx) * Elf64_Word.sizeof));

        Elf64_Word *old_buf = cast(Elf64_Word *)shndx_data.buf;
        Elf64_Word *tmp_buf = cast(Elf64_Word *)util_malloc(Elf64_Word.sizeof, symbol_idx);
        for (SYMIDX old_idx = 0; old_idx < symbol_idx; ++old_idx)
        {
            const SYMIDX new_idx = sym_map[old_idx];
            tmp_buf[new_idx] = old_buf[old_idx];
        }
        memcpy(old_buf, tmp_buf, Elf64_Word.sizeof * symbol_idx);
        util_free(tmp_buf);
    }

    // Renumber the relocations
    for (int i = 1; i <= seg_count; i++)
    {                           // Map indicies in the segment table
        seg_data *pseg = SegData[i];
        pseg.SDsymidx = sym_map[pseg.SDsymidx];

        if (SecHdrTab[pseg.SDshtidx].sh_type == SHT_GROUP)
        {   // map symbol index of group section header
            uint oidx = SecHdrTab[pseg.SDshtidx].sh_info;
            assert(oidx < symbol_idx);
            // we only have one symbol table
            assert(SecHdrTab[pseg.SDshtidx].sh_link == SHN_SYMTAB);
            SecHdrTab[pseg.SDshtidx].sh_info = sym_map[oidx];
        }

        if (pseg.SDrel)
        {
            if (I64)
            {
                Elf64_Rela *rel = cast(Elf64_Rela *) pseg.SDrel.buf;
                for (int r = 0; r < pseg.SDrelcnt; r++)
                {
                    uint t = ELF64_R_TYPE(rel.r_info);
                    uint si = ELF64_R_SYM(rel.r_info);
                    assert(si < symbol_idx);
                    rel.r_info = ELF64_R_INFO(sym_map[si],t);
                    rel++;
                }
            }
            else
            {
                Elf32_Rel *rel = cast(Elf32_Rel *) pseg.SDrel.buf;
                assert(pseg.SDrelcnt == pseg.SDrel.size() / Elf32_Rel.sizeof);
                for (int r = 0; r < pseg.SDrelcnt; r++)
                {
                    uint t = ELF32_R_TYPE(rel.r_info);
                    uint si = ELF32_R_SYM(rel.r_info);
                    assert(si < symbol_idx);
                    rel.r_info = ELF32_R_INFO(sym_map[si],t);
                    rel++;
                }
            }
        }
    }

    return symtab;
}


/***************************
 * Fixup and terminate object file.
 */

void Obj_termfile()
{
    //dbg_printf("Obj_termfile\n");
    if (configv.addlinenumbers)
    {
        dwarf_termmodule();
    }
}

/*********************************
 * Terminate package.
 */

void Obj_term(const(char)* objfilename)
{
    //printf("Obj_term()\n");
version (SCPP)
{
    if (!errcnt)
    {
        outfixlist();           // backpatches
    }
}
else
{
    outfixlist();           // backpatches
}

    if (configv.addlinenumbers)
    {
        dwarf_termfile();
    }

version (MARS)
{
    if (config.useModuleInfo)
        obj_rtinit();
}

version (SCPP)
{
    if (errcnt)
        return;
}

    int foffset;
    Elf32_Shdr *sechdr;
    seg_data *seg;
    void *symtab = elf_renumbersyms();
    FILE *fd = null;

    int hdrsize = (I64 ? Elf64_Ehdr.sizeof : Elf32_Ehdr.sizeof);

    ushort e_shnum;
    if (section_cnt < SHN_LORESERVE)
        e_shnum = cast(ushort)section_cnt;
    else
    {
        e_shnum = SHN_UNDEF;
        SecHdrTab[0].sh_size = section_cnt;
    }
    // uint16_t e_shstrndx = SHN_SECNAMES;
    fobjbuf.writezeros(hdrsize);

            // Walk through sections determining size and file offsets
            // Sections will be output in the following order
            //  Null segment
            //  For each Code/Data Segment
            //      code/data to load
            //      relocations without addens
            //  .bss
            //  notes
            //  comments
            //  section names table
            //  symbol table
            //  strings table

    foffset = hdrsize;      // start after header
                                    // section header table at end

    //
    // First output individual section data associate with program
    //  code and data
    //
    //printf("Setup offsets and sizes foffset %d\n\tsection_cnt %d, seg_count %d\n",foffset,section_cnt,seg_count);
    for (int i=1; i<= seg_count; i++)
    {
        seg_data *pseg = SegData[i];
        Elf32_Shdr *sechdr2 = MAP_SEG2SEC(i);        // corresponding section
        if (sechdr2.sh_addralign < pseg.SDalignment)
            sechdr2.sh_addralign = pseg.SDalignment;
        foffset = elf_align(sechdr2.sh_addralign,foffset);
        if (i == UDATA) // 0, BSS never allocated
        {   // but foffset as if it has
            sechdr2.sh_offset = foffset;
            sechdr2.sh_size = cast(uint)pseg.SDoffset;
                                // accumulated size
            continue;
        }
        else if (sechdr2.sh_type == SHT_NOBITS) // .tbss never allocated
        {
            sechdr2.sh_offset = foffset;
            sechdr2.sh_size = cast(uint)pseg.SDoffset;
                                // accumulated size
            continue;
        }
        else if (!pseg.SDbuf)
            continue;           // For others leave sh_offset as 0

        sechdr2.sh_offset = foffset;
        //printf("\tsection name %d,",sechdr2.sh_name);
        if (pseg.SDbuf && pseg.SDbuf.size())
        {
            //printf(" - size %d\n",pseg.SDbuf.size());
            const size_t size = pseg.SDbuf.size();
            fobjbuf.write(pseg.SDbuf.buf, cast(uint)size);
            const int nfoffset = elf_align(sechdr2.sh_addralign, cast(uint)(foffset + size));
            sechdr2.sh_size = nfoffset - foffset;
            foffset = nfoffset;
        }
        //printf(" assigned offset %d, size %d\n",foffset,sechdr2.sh_size);
    }

    //
    // Next output any notes or comments
    //
    if (note_data)
    {
        sechdr = &SecHdrTab[secidx_note];               // Notes
        sechdr.sh_size = cast(uint)note_data.size();
        sechdr.sh_offset = foffset;
        fobjbuf.write(note_data.buf, sechdr.sh_size);
        foffset += sechdr.sh_size;
    }

    if (comment_data)
    {
        sechdr = &SecHdrTab[SHN_COM];           // Comments
        sechdr.sh_size = cast(uint)comment_data.size();
        sechdr.sh_offset = foffset;
        fobjbuf.write(comment_data.buf, sechdr.sh_size);
        foffset += sechdr.sh_size;
    }

    //
    // Then output string table for section names
    //
    sechdr = &SecHdrTab[SHN_SECNAMES];  // Section Names
    sechdr.sh_size = cast(uint)section_names.size();
    sechdr.sh_offset = foffset;
    //dbg_printf("section names offset %d\n",foffset);
    fobjbuf.write(section_names.buf, sechdr.sh_size);
    foffset += sechdr.sh_size;

    //
    // Symbol table and string table for symbols next
    //
    //dbg_printf("output symbol table size %d\n",SYMbuf.size());
    sechdr = &SecHdrTab[SHN_SYMTAB];    // Symbol Table
    sechdr.sh_size = cast(uint)SYMbuf.size();
    sechdr.sh_entsize = I64 ? (Elf64_Sym).sizeof : (Elf32_Sym).sizeof;
    sechdr.sh_link = SHN_STRINGS;
    sechdr.sh_info = local_cnt;
    foffset = elf_align(4,foffset);
    sechdr.sh_offset = foffset;
    fobjbuf.write(symtab, sechdr.sh_size);
    foffset += sechdr.sh_size;
    util_free(symtab);

    if (shndx_data && shndx_data.size())
    {
        assert(section_cnt >= secidx_shndx);
        sechdr = &SecHdrTab[secidx_shndx];
        sechdr.sh_size = cast(uint)shndx_data.size();
        sechdr.sh_offset = foffset;
        fobjbuf.write(shndx_data.buf, sechdr.sh_size);
        foffset += sechdr.sh_size;
    }

    //dbg_printf("output section strings size 0x%x,offset 0x%x\n",symtab_strings.size(),foffset);
    sechdr = &SecHdrTab[SHN_STRINGS];   // Symbol Strings
    sechdr.sh_size = cast(uint)symtab_strings.size();
    sechdr.sh_offset = foffset;
    fobjbuf.write(symtab_strings.buf, sechdr.sh_size);
    foffset += sechdr.sh_size;

    //
    // Now the relocation data for program code and data sections
    //
    foffset = elf_align(4,foffset);
    //dbg_printf("output relocations size 0x%x, foffset 0x%x\n",section_names.size(),foffset);
    for (int i=1; i<= seg_count; i++)
    {
        seg = SegData[i];
        if (!seg.SDbuf)
        {
//            sechdr = &SecHdrTab[seg.SDrelidx];
//          if (I64 && sechdr.sh_type == SHT_RELA)
//              sechdr.sh_offset = foffset;
            continue;           // 0, BSS never allocated
        }
        if (seg.SDrel && seg.SDrel.size())
        {
            assert(seg.SDrelidx);
            sechdr = &SecHdrTab[seg.SDrelidx];
            sechdr.sh_size = cast(uint)seg.SDrel.size();
            sechdr.sh_offset = foffset;
            if (I64)
            {
                assert(seg.SDrelcnt == seg.SDrel.size() / Elf64_Rela.sizeof);
debug
{
                for (size_t j = 0; j < seg.SDrelcnt; ++j)
                {   Elf64_Rela *p = (cast(Elf64_Rela *)seg.SDrel.buf) + j;
                    if (ELF64_R_TYPE(p.r_info) == R_X86_64_64)
                        assert(*cast(Elf64_Xword *)(seg.SDbuf.buf + p.r_offset) == 0);
                }
}
            }
            else
                assert(seg.SDrelcnt == seg.SDrel.size() / Elf32_Rel.sizeof);
            fobjbuf.write(seg.SDrel.buf, sechdr.sh_size);
            foffset += sechdr.sh_size;
        }
    }

    //
    // Finish off with the section header table
    //
    ulong e_shoff = foffset;       // remember location in elf header
    //dbg_printf("output section header table\n");

    // Output the completed Section Header Table
    if (I64)
    {   // Translate section headers to 64 bits
        int sz = cast(int)(section_cnt * Elf64_Shdr.sizeof);
        fobjbuf.reserve(sz);
        for (int i = 0; i < section_cnt; i++)
        {
            Elf32_Shdr *p = SecHdrTab + i;
            Elf64_Shdr s;
            s.sh_name      = p.sh_name;
            s.sh_type      = p.sh_type;
            s.sh_flags     = p.sh_flags;
            s.sh_addr      = p.sh_addr;
            s.sh_offset    = p.sh_offset;
            s.sh_size      = p.sh_size;
            s.sh_link      = p.sh_link;
            s.sh_info      = p.sh_info;
            s.sh_addralign = p.sh_addralign;
            s.sh_entsize   = p.sh_entsize;
            fobjbuf.write(&s, s.sizeof);
        }
        foffset += sz;
    }
    else
    {
        fobjbuf.write(SecHdrTab, cast(uint)(section_cnt * Elf32_Shdr.sizeof));
        foffset += section_cnt * Elf32_Shdr.sizeof;
    }

    //
    // Now that we have correct offset to section header table, e_shoff,
    //  go back and re-output the elf header
    //
    fobjbuf.position(0, hdrsize);
    if (I64)
    {
        __gshared Elf64_Ehdr h64 =
        {
            [
                ELFMAG0,ELFMAG1,ELFMAG2,ELFMAG3,
                ELFCLASS64,             // EI_CLASS
                ELFDATA2LSB,            // EI_DATA
                EV_CURRENT,             // EI_VERSION
                ELFOSABI,0,             // EI_OSABI,EI_ABIVERSION
                0,0,0,0,0,0,0
            ],
            ET_REL,                         // e_type
            EM_X86_64,                      // e_machine
            EV_CURRENT,                     // e_version
            0,                              // e_entry
            0,                              // e_phoff
            0,                              // e_shoff
            0,                              // e_flags
            Elf64_Ehdr.sizeof,              // e_ehsize
            Elf64_Phdr.sizeof,              // e_phentsize
            0,                              // e_phnum
            Elf64_Shdr.sizeof,              // e_shentsize
            0,                              // e_shnum
            SHN_SECNAMES                    // e_shstrndx
        };
        h64.e_shoff     = e_shoff;
        h64.e_shnum     = e_shnum;
        fobjbuf.write(&h64, hdrsize);
    }
    else
    {
        __gshared Elf32_Ehdr h32 =
        {
            [
                ELFMAG0,ELFMAG1,ELFMAG2,ELFMAG3,
                ELFCLASS32,             // EI_CLASS
                ELFDATA2LSB,            // EI_DATA
                EV_CURRENT,             // EI_VERSION
                ELFOSABI,0,             // EI_OSABI,EI_ABIVERSION
                0,0,0,0,0,0,0
            ],
            ET_REL,                         // e_type
            EM_386,                         // e_machine
            EV_CURRENT,                     // e_version
            0,                              // e_entry
            0,                              // e_phoff
            0,                              // e_shoff
            0,                              // e_flags
            Elf32_Ehdr.sizeof,              // e_ehsize
            Elf32_Phdr.sizeof,              // e_phentsize
            0,                              // e_phnum
            Elf32_Shdr.sizeof,              // e_shentsize
            0,                              // e_shnum
            SHN_SECNAMES                    // e_shstrndx
        };
        h32.e_shoff     = cast(uint)e_shoff;
        h32.e_shnum     = e_shnum;
        fobjbuf.write(&h32, hdrsize);
    }
    fobjbuf.position(foffset, 0);
    fobjbuf.flush();
}

/*****************************
 * Line number support.
 */

/***************************
 * Record file and line number at segment and offset.
 * The actual .debug_line segment is put out by dwarf_termfile().
 * Params:
 *      srcpos = source file position
 *      seg = segment it corresponds to
 *      offset = offset within seg
 */

void Obj_linnum(Srcpos srcpos, int seg, targ_size_t offset)
{
    if (srcpos.Slinnum == 0)
        return;

static if (0)
{
    printf("Obj_linnum(seg=%d, offset=0x%lx) ", seg, offset);
    srcpos.print("");
}

version (MARS)
{
    if (!srcpos.Sfilename)
        return;
}
version (SCPP)
{
    if (!srcpos.Sfilptr)
        return;
    sfile_debug(&srcpos_sfile(srcpos));
    Sfile *sf = *srcpos.Sfilptr;
}

    size_t i;
    seg_data *pseg = SegData[seg];

    // Find entry i in SDlinnum_data[] that corresponds to srcpos filename
    for (i = 0; 1; i++)
    {
        if (i == pseg.SDlinnum_count)
        {   // Create new entry
            if (pseg.SDlinnum_count == pseg.SDlinnum_max)
            {   // Enlarge array
                uint newmax = pseg.SDlinnum_max * 2 + 1;
                //printf("realloc %d\n", newmax * linnum_data.sizeof);
                pseg.SDlinnum_data = cast(linnum_data *)mem_realloc(
                    pseg.SDlinnum_data, newmax * linnum_data.sizeof);
                memset(pseg.SDlinnum_data + pseg.SDlinnum_max, 0,
                    (newmax - pseg.SDlinnum_max) * linnum_data.sizeof);
                pseg.SDlinnum_max = newmax;
            }
            pseg.SDlinnum_count++;

version (MARS)
            pseg.SDlinnum_data[i].filename = srcpos.Sfilename;

version (SCPP)
            pseg.SDlinnum_data[i].filptr = sf;

            break;
        }
version (MARS)
{
        if (pseg.SDlinnum_data[i].filename == srcpos.Sfilename)
            break;
}
version (SCPP)
{
        if (pseg.SDlinnum_data[i].filptr == sf)
            break;
}
    }

    linnum_data *ld = &pseg.SDlinnum_data[i];
//    printf("i = %d, ld = x%x\n", i, ld);
    if (ld.linoff_count == ld.linoff_max)
    {
        if (!ld.linoff_max)
            ld.linoff_max = 8;
        ld.linoff_max *= 2;
        ld.linoff = cast(uint[2]*)mem_realloc(ld.linoff, ld.linoff_max * uint.sizeof * 2);
    }
    ld.linoff[ld.linoff_count][0] = srcpos.Slinnum;
    ld.linoff[ld.linoff_count][1] = cast(uint)offset;
    ld.linoff_count++;
}


/*******************************
 * Set start address
 */

void Obj_startaddress(Symbol *s)
{
    //dbg_printf("Obj_startaddress(Symbol *%s)\n",s.Sident.ptr);
    //obj.startaddress = s;
}

/*******************************
 * Output library name.
 */

bool Obj_includelib(const(char)* name)
{
    //dbg_printf("Obj_includelib(name *%s)\n",name);
    return false;
}

/*******************************
* Output linker directive.
*/

bool Obj_linkerdirective(const(char)* name)
{
    return false;
}

/**********************************
 * Do we allow zero sized objects?
 */

bool Obj_allowZeroSize()
{
    return true;
}

/**************************
 * Embed string in executable.
 */

void Obj_exestr(const(char)* p)
{
    //dbg_printf("Obj_exestr(char *%s)\n",p);
}

/**************************
 * Embed string in obj.
 */

void Obj_user(const(char)* p)
{
    //dbg_printf("Obj_user(char *%s)\n",p);
}

/*******************************
 * Output a weak extern record.
 */

void Obj_wkext(Symbol *s1,Symbol *s2)
{
    //dbg_printf("Obj_wkext(Symbol *%s,Symbol *s2)\n",s1.Sident.ptr,s2.Sident.ptr);
}

/*******************************
 * Output file name record.
 *
 * Currently assumes that obj_filename will not be called
 *      twice for the same file.
 */

void obj_filename(const(char)* modname)
{
    //dbg_printf("obj_filename(char *%s)\n",modname);
    uint strtab_idx = Obj_addstr(symtab_strings,modname);
    elf_addsym(strtab_idx,0,0,STT_FILE,STB_LOCAL,SHN_ABS);
}

/*******************************
 * Embed compiler version in .obj file.
 */

void Obj_compiler()
{
    //dbg_printf("Obj_compiler\n");
    comment_data = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
    assert(comment_data);


    comment_data.write(.compiler,(.compiler).sizeof);
    //dbg_printf("Comment data size %d\n",comment_data.size());
}


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

void Obj_staticctor(Symbol *s, int, int)
{
    Obj_setModuleCtorDtor(s, true);
}

/**************************************
 * Symbol is the function that calls the static destructors.
 * Put a pointer to it into a special segment that the exit code
 * looks at.
 * Input:
 *      s       static destructor function
 */

void Obj_staticdtor(Symbol *s)
{
    Obj_setModuleCtorDtor(s, false);
}

/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

void Obj_setModuleCtorDtor(Symbol *sfunc, bool isCtor)
{
    IDXSEC seg = Obj_getsegment(isCtor ? ".ctors" : ".dtors", null, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE, _tysize[TYnptr]);
    const uint reltype = I64 ? R_X86_64_64 : R_386_32;
    const size_t sz = Obj_writerel(seg, cast(uint)SegData[seg].SDoffset, reltype, sfunc.Sxtrnnum, 0);
    SegData[seg].SDoffset += sz;
}


/***************************************
 * Stuff the following data in a separate segment:
 *      pointer to function
 *      pointer to ehsym
 *      length of function
 */

void Obj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
{
    assert(0);                  // converted to Dwarf EH debug format
}

/*********************************************
 * Don't need to generate section brackets, use __start_SEC/__stop_SEC instead.
 */

void Obj_ehsections()
{
    obj_tlssections();
}

/*********************************************
 * Put out symbols that define the beginning/end of the thread local storage sections.
 */

private void obj_tlssections()
{
    IDXSTR namidx;
    int align_ = I64 ? 16 : 4;

    int sec = Obj_getsegment(".tdata", null, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, align_);
    Obj_bytes(sec, 0, align_, null);

    namidx = Obj_addstr(symtab_strings,"_tlsstart");
    elf_addsym(namidx, 0, align_, STT_TLS, STB_GLOBAL, MAP_SEG2SECIDX(sec));

    Obj_getsegment(".tdata.", null, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, align_);

    sec = Obj_getsegment(".tcommon", null, SHT_NOBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, align_);
    namidx = Obj_addstr(symtab_strings,"_tlsend");
    elf_addsym(namidx, 0, align_, STT_TLS, STB_GLOBAL, MAP_SEG2SECIDX(sec));
}

/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *      cseg            segment index of new current code segment
 *      Offset(cseg)         starting offset in cseg
 * Returns:
 *      "segment index" of COMDAT
 * References:
 *      Section Groups http://www.sco.com/developers/gabi/2003-12-17/ch4.sheader.html#section_groups
 *      COMDAT section groups https://www.airs.com/blog/archives/52
 */

private void setup_comdat(Symbol *s)
{
    const(char)* prefix;
    int type;
    int flags;
    int align_ = 4;

    //printf("Obj_comdat(Symbol *%s\n",s.Sident.ptr);
    //symbol_print(s);
    symbol_debug(s);
    if (tyfunc(s.ty()))
    {
static if (!ELF_COMDAT)
{
        prefix = ".text.";              // undocumented, but works
        type = SHT_PROGBITS;
        flags = SHF_ALLOC|SHF_EXECINSTR;
}
else
{
        reset_symbuf.write(&s, s.sizeof);

        const(char)* p = cpp_mangle2(s);

        bool added = false;
        IDXSTR namidx = elf_addsectionname(".text.", p, &added);
        int groupseg;
        if (added)
        {
            // Create a new COMDAT section group
            const IDXSTR grpnamidx = elf_addsectionname(".group");
            groupseg = elf_addsegment(grpnamidx, SHT_GROUP, 0, (IDXSYM).sizeof);
            MAP_SEG2SEC(groupseg).sh_link = SHN_SYMTAB;
            MAP_SEG2SEC(groupseg).sh_entsize = (IDXSYM).sizeof;
            // Create a new TEXT section for the comdat symbol with the SHF_GROUP bit set
            s.Sseg = elf_addsegment(namidx, SHT_PROGBITS, SHF_ALLOC|SHF_EXECINSTR|SHF_GROUP, align_);
            // add TEXT section to COMDAT section group
            SegData[groupseg].SDbuf.write32(GRP_COMDAT);
            SegData[groupseg].SDbuf.write32(MAP_SEG2SECIDX(s.Sseg));
            SegData[s.Sseg].SDassocseg = groupseg;
        }
        else
        {
            /* If the section already existed, we've hit one of the few
             * occurences of different symbols with identical mangling. This should
             * not happen, but as a workaround we just use the existing sections.
             * Also see https://issues.dlang.org/show_bug.cgi?id=17352,
             * https://issues.dlang.org/show_bug.cgi?id=14831, and
             * https://issues.dlang.org/show_bug.cgi?id=17339.
             */
            s.Sseg = elf_getsegment(namidx);
            groupseg = SegData[s.Sseg].SDassocseg;
            assert(groupseg);
        }

        // Create a weak symbol for the comdat
        namidx = Obj_addstr(symtab_strings, p);
        s.Sxtrnnum = elf_addsym(namidx, 0, 0, STT_FUNC, STB_WEAK, MAP_SEG2SECIDX(s.Sseg));

        if (added)
        {
            /* Set the weak symbol as comdat group symbol. This symbol determines
             * whether all or none of the sections in the group get linked. It's
             * also the only symbol in all group sections that might be referenced
             * from outside of the group.
             */
            MAP_SEG2SEC(groupseg).sh_info = s.Sxtrnnum;
            SegData[s.Sseg].SDsym = s;
        }
        else
        {
            // existing group symbol, and section symbol
            assert(MAP_SEG2SEC(groupseg).sh_info);
            assert(MAP_SEG2SEC(groupseg).sh_info == SegData[s.Sseg].SDsym.Sxtrnnum);
        }
        if (s.Salignment > align_)
            SegData[s.Sseg].SDalignment = s.Salignment;
        return;
}
    }
    else if ((s.ty() & mTYLINK) == mTYthread)
    {
        /* Ensure that ".tdata" precedes any other .tdata. section, as the ld
         * linker script fails to work right.
         */
        if (I64)
            align_ = 16;
        Obj_getsegment(".tdata", null, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, align_);

        s.Sfl = FLtlsdata;
        prefix = ".tdata.";
        type = SHT_PROGBITS;
        flags = SHF_ALLOC|SHF_WRITE|SHF_TLS;
    }
    else
    {
        if (I64)
            align_ = 16;
        s.Sfl = FLdata;
        //prefix = ".gnu.linkonce.d.";
        prefix = ".data.";
        type = SHT_PROGBITS;
        flags = SHF_ALLOC|SHF_WRITE;
    }

    s.Sseg = Obj_getsegment(prefix, cpp_mangle2(s), type, flags, align_);
                                // find or create new segment
    if (s.Salignment > align_)
        SegData[s.Sseg].SDalignment = s.Salignment;
    SegData[s.Sseg].SDsym = s;
}

int Obj_comdat(Symbol *s)
{
    setup_comdat(s);
    if (s.Sfl == FLdata || s.Sfl == FLtlsdata)
    {
        Obj_pubdef(s.Sseg,s,0);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    return s.Sseg;
}

int Obj_comdatsize(Symbol *s, targ_size_t symsize)
{
    setup_comdat(s);
    if (s.Sfl == FLdata || s.Sfl == FLtlsdata)
    {
        Obj_pubdefsize(s.Sseg,s,0,symsize);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    s.Soffset = 0;
    return s.Sseg;
}

int Obj_readonly_comdat(Symbol *s)
{
    assert(0);
}

int Obj_jmpTableSegment(Symbol *s)
{
    segidx_t seg = jmpseg;
    if (seg)                            // memoize the jmpseg on a per-function basis
        return seg;

    if (config.flags & CFGromable)
        seg = cseg;
    else
    {
        seg_data *pseg = SegData[s.Sseg];
        if (pseg.SDassocseg)
        {
            /* `s` is in a COMDAT, so the jmp table segment must also
             * go into its own segment in the same group.
             */
            seg = Obj_getsegment(".rodata.", s.Sident.ptr, SHT_PROGBITS, SHF_ALLOC|SHF_GROUP, _tysize[TYnptr]);
            addSegmentToComdat(seg, s.Sseg);
        }
        else
            seg = CDATA;
    }
    jmpseg = seg;
    return seg;
}

/****************************************
 * If `comdatseg` has a group, add `secidx` to the group.
 * Params:
 *      secidx = section to add to the group
 *      comdatseg = comdat that started the group
 */

private void addSectionToComdat(IDXSEC secidx, segidx_t comdatseg)
{
    seg_data *pseg = SegData[comdatseg];
    segidx_t groupseg = pseg.SDassocseg;
    if (groupseg)
    {
        seg_data *pgroupseg = SegData[groupseg];

        /* Don't write it if it is already there
         */
        Outbuffer *buf = pgroupseg.SDbuf;
        assert(int.sizeof == 4);               // loop depends on this
        for (size_t i = buf.size(); i > 4;)
        {
            /* A linear search, but shouldn't be more than 4 items
             * in it.
             */
            i -= 4;
            if (*cast(int*)(buf.buf + i) == secidx)
                return;
        }
        buf.write32(secidx);
    }
}

/***********************************
 * Returns:
 *      jump table segment for function s
 */
void addSegmentToComdat(segidx_t seg, segidx_t comdatseg)
{
    addSectionToComdat(SegData[seg].SDshtidx, comdatseg);
}

private int elf_addsegment2(IDXSEC shtidx, IDXSYM symidx, IDXSEC relidx)
{
    //printf("SegData = %p\n", SegData);
    int seg = ++seg_count;
    if (seg_count >= seg_max)
    {                           // need more room in segment table
        seg_max += OB_SEG_INC;
        SegData = cast(seg_data **)mem_realloc(SegData,seg_max * (seg_data *).sizeof);
        memset(&SegData[seg_count], 0, (seg_max - seg_count) * (seg_data *).sizeof);
    }
    assert(seg_count < seg_max);
    if (!SegData[seg])
    {   SegData[seg] = cast(seg_data *)mem_calloc((seg_data).sizeof);
        //printf("test2: SegData[%d] = %p\n", seg, SegData[seg]);
    }

    seg_data *pseg = SegData[seg];
    pseg.SDseg = seg;
    pseg.SDshtidx = shtidx;
    pseg.SDoffset = 0;
    if (pseg.SDbuf)
        pseg.SDbuf.setsize(0);
    else
    {   if (SecHdrTab[shtidx].sh_type != SHT_NOBITS)
        {
            pseg.SDbuf = cast(Outbuffer*) calloc(1, (Outbuffer).sizeof);
            assert(pseg.SDbuf);
            pseg.SDbuf.enlarge(OB_XTRA_STR);

            pseg.SDbuf.reserve(1024);
        }
    }
    if (pseg.SDrel)
        pseg.SDrel.setsize(0);
    pseg.SDsymidx = symidx;
    pseg.SDrelidx = relidx;
    pseg.SDrelmaxoff = 0;
    pseg.SDrelindex = 0;
    pseg.SDrelcnt = 0;
    pseg.SDshtidxout = 0;
    pseg.SDsym = null;
    pseg.SDaranges_offset = 0;
    pseg.SDlinnum_count = 0;
    return seg;
}

/********************************
 * Add a new section and get corresponding seg_data entry.
 *
 * Input:
 *     nameidx = string index of section name
 *        type = section header type, e.g. SHT_PROGBITS
 *       flags = section header flags, e.g. SHF_ALLOC
 *       align_ = section alignment
 * Returns:
 *      SegData index of newly created section.
 */
private int elf_addsegment(IDXSTR namidx, int type, int flags, int align_)
{
    //dbg_printf("\tNew segment - %d size %d\n", seg,SegData[seg].SDbuf);
    IDXSEC shtidx = elf_newsection2(namidx,type,flags,0,0,0,0,0,0,0);
    SecHdrTab[shtidx].sh_addralign = align_;
    IDXSYM symidx = elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, shtidx);
    int seg = elf_addsegment2(shtidx, symidx, 0);
    //printf("-Obj_getsegment() = %d\n", seg);
    return seg;
}

/********************************
 * Find corresponding seg_data entry for existing section.
 *
 * Input:
 *     nameidx = string index of section name
 * Returns:
 *      SegData index of found section or 0 if none was found.
 */
private int elf_getsegment(IDXSTR namidx)
{
    // find existing section
    for (int seg = CODE; seg <= seg_count; seg++)
    {                               // should be in segment table
        if (MAP_SEG2SEC(seg).sh_name == namidx)
        {
            return seg;             // found section for segment
        }
    }
    return 0;
}

/********************************
 * Get corresponding seg_data entry for an existing or newly added section.
 *
 * Input:
 *        name = name of section
 *      suffix = append to name
 *        type = section header type, e.g. SHT_PROGBITS
 *       flags = section header flags, e.g. SHF_ALLOC
 *       align_ = section alignment
 * Returns:
 *      SegData index of found or newly created section.
 */
int Obj_getsegment(const(char)* name, const(char)* suffix, int type, int flags,
        int align_)
{
    //printf("Obj_getsegment(%s,%s,flags %x, align_ %d)\n",name,suffix,flags,align_);
    bool added = false;
    IDXSEC namidx = elf_addsectionname(name, suffix, &added);
    if (!added)
    {
        int seg = elf_getsegment(namidx);
        assert(seg);
        return seg;
    }
    return elf_addsegment(namidx, type, flags, align_);
}

/**********************************
 * Reset code seg to existing seg.
 * Used after a COMDAT for a function is done.
 */

void Obj_setcodeseg(int seg)
{
    cseg = seg;
}

/********************************
 * Define a new code segment.
 * Input:
 *      name            name of segment, if null then revert to default
 *      suffix  0       use name as is
 *              1       append "_TEXT" to name
 * Output:
 *      cseg            segment index of new current code segment
 *      Offset(cseg)         starting offset in cseg
 * Returns:
 *      segment index of newly created code segment
 */

int Obj_codeseg(char *name,int suffix)
{
    int seg;
    const(char)* sfx;

    //dbg_printf("Obj_codeseg(%s,%x)\n",name,suffix);

    sfx = (suffix) ? "_TEXT".ptr : null;

    if (!name)                          // returning to default code segment
    {
        if (cseg != CODE)               // not the current default
        {
            SegData[cseg].SDoffset = Offset(cseg);
            Offset(cseg) = SegData[CODE].SDoffset;
            cseg = CODE;
        }
        return cseg;
    }

    seg = Obj_getsegment(name, sfx, SHT_PROGBITS, SHF_ALLOC|SHF_EXECINSTR, 4);
                                    // find or create code segment

    cseg = seg;                         // new code segment index
    Offset(cseg) = 0;

    return seg;
}

/*********************************
 * Define segments for Thread Local Storage.
 * Here's what the elf tls spec says:
 *      Field           .tbss                   .tdata
 *      sh_name         .tbss                   .tdata
 *      sh_type         SHT_NOBITS              SHT_PROGBITS
 *      sh_flags        SHF_ALLOC|SHF_WRITE|    SHF_ALLOC|SHF_WRITE|
 *                      SHF_TLS                 SHF_TLS
 *      sh_addr         virtual addr of section virtual addr of section
 *      sh_offset       0                       file offset of initialization image
 *      sh_size         size of section         size of section
 *      sh_link         SHN_UNDEF               SHN_UNDEF
 *      sh_info         0                       0
 *      sh_addralign    alignment of section    alignment of section
 *      sh_entsize      0                       0
 * We want _tlsstart and _tlsend to bracket all the D tls data.
 * The default linker script (ld -verbose) says:
 *  .tdata      : { *(.tdata .tdata.* .gnu.linkonce.td.*) }
 *  .tbss       : { *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon) }
 * so if we assign names:
 *      _tlsstart .tdata
 *      symbols   .tdata.
 *      symbols   .tbss
 *      _tlsend   .tbss.
 * this should work.
 * Don't care about sections emitted by other languages, as we presume they
 * won't be storing D gc roots in their tls.
 * Output:
 *      seg_tlsseg      set to segment number for TLS segment.
 * Returns:
 *      segment for TLS segment
 */

seg_data *Obj_tlsseg()
{
    /* Ensure that ".tdata" precedes any other .tdata. section, as the ld
     * linker script fails to work right.
     */
    Obj_getsegment(".tdata", null, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, 4);

    static immutable char[8] tlssegname = ".tdata.";
    //dbg_printf("Obj_tlsseg(\n");

    if (seg_tlsseg == UNKNOWN)
    {
        seg_tlsseg = Obj_getsegment(tlssegname.ptr, null, SHT_PROGBITS,
            SHF_ALLOC|SHF_WRITE|SHF_TLS, I64 ? 16 : 4);
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

seg_data *Obj_tlsseg_bss()
{
    static immutable char[6] tlssegname = ".tbss";
    //dbg_printf("Obj_tlsseg_bss(\n");

    if (seg_tlsseg_bss == UNKNOWN)
    {
        seg_tlsseg_bss = Obj_getsegment(tlssegname.ptr, null, SHT_NOBITS,
            SHF_ALLOC|SHF_WRITE|SHF_TLS, I64 ? 16 : 4);
    }
    return SegData[seg_tlsseg_bss];
}

seg_data *Obj_tlsseg_data()
{
    // specific for Mach-O
    assert(0);
}


/*******************************
 * Output an alias definition record.
 */

void Obj_alias(const(char)* n1,const(char)* n2)
{
    //printf("Obj_alias(%s,%s)\n",n1,n2);
    assert(0);
static if (0)
{
    char *buffer = cast(char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    uint len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
}
}

char *unsstr(uint value)
{
    __gshared char[64] buffer = void;

    sprintf(buffer.ptr, "%d", value);
    return buffer.ptr;
}

/*******************************
 * Mangle a name.
 * Returns:
 *      mangled name
 */

char *obj_mangle2(Symbol *s,char *dest, size_t *destlen)
{
    char *name;

    //dbg_printf("Obj_mangle('%s'), mangle = x%x\n",s.Sident.ptr,type_mangle(s.Stype));
    symbol_debug(s);
    assert(dest);

version (SCPP)
    name = CPP ? cpp_mangle2(s) : s.Sident.ptr;
else version (MARS)
    // C++ name mangling is handled by front end
    name = s.Sident.ptr;
else
    name = s.Sident.ptr;

    size_t len = strlen(name);                 // # of bytes in name
    //dbg_printf("len %d\n",len);
    switch (type_mangle(s.Stype))
    {
        case mTYman_pas:                // if upper case
        case mTYman_for:
            if (len >= DEST_LEN)
                dest = cast(char *)mem_malloc(len + 1);
            memcpy(dest,name,len + 1);  // copy in name and ending 0
            for (int i = 0; 1; i++)
            {   char c = dest[i];
                if (!c)
                    break;
                if (c >= 'a' && c <= 'z')
                    dest[i] = cast(char)(c + 'A' - 'a');
            }
            break;
        case mTYman_std:
        {
static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_DRAGONFLYBSD || TARGET_SOLARIS)
            bool cond = (tyfunc(s.ty()) && !variadic(s.Stype));
else
            bool cond = (!(config.flags4 & CFG4oldstdmangle) &&
                config.exe == EX_WIN32 && tyfunc(s.ty()) &&
                !variadic(s.Stype));

            if (cond)
            {
                char *pstr = unsstr(type_paramsize(s.Stype));
                size_t pstrlen = strlen(pstr);
                size_t dlen = len + 1 + pstrlen;

                if (dlen >= DEST_LEN)
                    dest = cast(char *)mem_malloc(dlen + 1);
                memcpy(dest,name,len);
                dest[len] = '@';
                memcpy(dest + 1 + len, pstr, pstrlen + 1);
                len = dlen;
                break;
            }
        }
            goto case;

        case mTYman_cpp:
        case mTYman_c:
        case mTYman_d:
        case mTYman_sys:
        case 0:
            if (len >= DEST_LEN)
                dest = cast(char *)mem_malloc(len + 1);
            memcpy(dest,name,len+1);// copy in name and trailing 0
            break;

        default:
debug
{
            printf("mangling %x\n",type_mangle(s.Stype));
            symbol_print(s);
}
            printf("%d\n", type_mangle(s.Stype));
            assert(0);
    }
    //dbg_printf("\t %s\n",dest);
    *destlen = len;
    return dest;
}

/*******************************
 * Export a function name.
 */

void Obj_export_symbol(Symbol *s,uint argsize)
{
    //dbg_printf("Obj_export_symbol(%s,%d)\n",s.Sident.ptr,argsize);
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

int Obj_data_start(Symbol *sdata, targ_size_t datasize, int seg)
{
    targ_size_t alignbytes;
    //printf("Obj_data_start(%s,size %llx,seg %d)\n",sdata.Sident.ptr,datasize,seg);
    //symbol_print(sdata);

    if (sdata.Sseg == UNKNOWN) // if we don't know then there
        sdata.Sseg = seg;      // wasn't any segment override
    else
        seg = sdata.Sseg;
    targ_size_t offset = Offset(seg);
    if (sdata.Salignment > 0)
    {   if (SegData[seg].SDalignment < sdata.Salignment)
            SegData[seg].SDalignment = sdata.Salignment;
        alignbytes = ((offset + sdata.Salignment - 1) & ~(sdata.Salignment - 1)) - offset;
    }
    else
        alignbytes = _align(datasize, offset) - offset;
    if (alignbytes)
        Obj_lidata(seg, offset, alignbytes);
    sdata.Soffset = offset + alignbytes;
    return seg;
}

/*******************************
 * Update function info before codgen
 *
 * If code for this function is in a different segment
 * than the current default in cseg, switch cseg to new segment.
 */

void Obj_func_start(Symbol *sfunc)
{
    //dbg_printf("Obj_func_start(%s)\n",sfunc.Sident.ptr);
    symbol_debug(sfunc);

    if ((tybasic(sfunc.ty()) == TYmfunc) && (sfunc.Sclass == SCextern))
    {                                   // create a new code segment
        sfunc.Sseg =
            Obj_getsegment(".gnu.linkonce.t.", cpp_mangle2(sfunc), SHT_PROGBITS, SHF_ALLOC|SHF_EXECINSTR,4);

    }
    else if (sfunc.Sseg == UNKNOWN)
        sfunc.Sseg = CODE;
    //dbg_printf("sfunc.Sseg %d CODE %d cseg %d Coffset %d\n",sfunc.Sseg,CODE,cseg,Offset(cseg));
    cseg = sfunc.Sseg;
    jmpseg = 0;                         // only 1 jmp seg per function
    assert(cseg == CODE || cseg > COMD);
static if (ELF_COMDAT)
{
    if (!symbol_iscomdat2(sfunc))
    {
        Obj_pubdef(cseg, sfunc, Offset(cseg));
    }
}
else
{
    Obj_pubdef(cseg, sfunc, Offset(cseg));
}
    sfunc.Soffset = Offset(cseg);

    dwarf_func_start(sfunc);
}

/*******************************
 * Update function info after codgen
 */

void Obj_func_term(Symbol *sfunc)
{
    //dbg_printf("Obj_func_term(%s) offset %x, Coffset %x symidx %d\n",
//          sfunc.Sident.ptr, sfunc.Soffset,Offset(cseg),sfunc.Sxtrnnum);

    // fill in the function size
    if (I64)
        SymbolTable64[sfunc.Sxtrnnum].st_size = Offset(cseg) - sfunc.Soffset;
    else
        SymbolTable[sfunc.Sxtrnnum].st_size = cast(uint)(Offset(cseg) - sfunc.Soffset);
    dwarf_func_term(sfunc);
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s .            symbol
 *      offset =        offset of name within segment
 */

void Obj_pubdef(int seg, Symbol *s, targ_size_t offset)
{
    const targ_size_t symsize=
        tyfunc(s.ty()) ? Offset(s.Sseg) - offset : type_size(s.Stype);
    Obj_pubdefsize(seg, s, offset, symsize);
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s .            symbol
 *      offset =        offset of name within segment
 *      symsize         size of symbol
 */

void Obj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
{
    int bind;
    ubyte visibility = STV_DEFAULT;
    switch (s.Sclass)
    {
        case SCglobal:
        case SCinline:
            bind = STB_GLOBAL;
            break;
        case SCcomdat:
        case SCcomdef:
            bind = STB_WEAK;
            break;
        case SCstatic:
            if (s.Sflags & SFLhidden)
            {
                visibility = STV_HIDDEN;
                bind = STB_GLOBAL;
                break;
            }
            goto default;

        default:
            bind = STB_LOCAL;
            break;
    }

    //printf("\nObj_pubdef(%d,%s,%d)\n",seg,s.Sident.ptr,offset);
    //symbol_print(s);

    symbol_debug(s);
    reset_symbuf.write(&s, s.sizeof);
    IDXSTR namidx = elf_addmangled(s);
    //printf("\tnamidx %d,section %d\n",namidx,MAP_SEG2SECIDX(seg));
    if (tyfunc(s.ty()))
    {
        s.Sxtrnnum = elf_addsym(namidx, offset, cast(uint)symsize,
            STT_FUNC, bind, MAP_SEG2SECIDX(seg), visibility);
    }
    else
    {
        const uint typ = (s.ty() & mTYthread) ? STT_TLS : STT_OBJECT;
        s.Sxtrnnum = elf_addsym(namidx, offset, cast(uint)symsize,
            typ, bind, MAP_SEG2SECIDX(seg), visibility);
    }
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

int Obj_external_def(const(char)* name)
{
    //dbg_printf("Obj_external_def('%s')\n",name);
    assert(name);
    IDXSTR namidx = Obj_addstr(symtab_strings,name);
    IDXSYM symidx = elf_addsym(namidx, 0, 0, STT_NOTYPE, STB_GLOBAL, SHN_UNDEF);
    return symidx;
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

int Obj_external(Symbol *s)
{
    int symtype,sectype;
    uint size;

    //dbg_printf("Obj_external('%s') %x\n",s.Sident.ptr,s.Svalue);
    symbol_debug(s);
    reset_symbuf.write(&s, s.sizeof);
    IDXSTR namidx = elf_addmangled(s);

version (SCPP)
{
    if (s.Sscope && !tyfunc(s.ty()))
    {
        symtype = STT_OBJECT;
        sectype = SHN_COMMON;
        size = type_size(s.Stype);
    }
    else
    {
        symtype = STT_NOTYPE;
        sectype = SHN_UNDEF;
        size = 0;
    }
}
else
{
    symtype = STT_NOTYPE;
    sectype = SHN_UNDEF;
    size = 0;
}
    if (s.ty() & mTYthread)
    {
        //printf("Obj_external('%s') %x TLS\n",s.Sident.ptr,s.Svalue);
        symtype = STT_TLS;
    }

    s.Sxtrnnum = elf_addsym(namidx, size, size, symtype,
        /*(s.ty() & mTYweak) ? STB_WEAK : */STB_GLOBAL, sectype);
    return s.Sxtrnnum;

}

/*******************************
 * Output a common block definition.
 * Input:
 *      p .    external identifier
 *      size    size in bytes of each elem
 *      count   number of elems
 * Returns:
 *      Symbol table index for symbol
 */

int Obj_common_block(Symbol *s,targ_size_t size,targ_size_t count)
{
    //printf("Obj_common_block('%s',%d,%d)\n",s.Sident.ptr,size,count);
    symbol_debug(s);

    int align_ = I64 ? 16 : 4;
    if (s.ty() & mTYthread)
    {
        s.Sseg = Obj_getsegment(".tbss.", cpp_mangle2(s),
                SHT_NOBITS, SHF_ALLOC|SHF_WRITE|SHF_TLS, align_);
        s.Sfl = FLtlsdata;
        SegData[s.Sseg].SDsym = s;
        SegData[s.Sseg].SDoffset += size * count;
        Obj_pubdefsize(s.Sseg, s, 0, size * count);
        searchfixlist(s);
        return s.Sseg;
    }
    else
    {
        s.Sseg = Obj_getsegment(".bss.", cpp_mangle2(s),
                SHT_NOBITS, SHF_ALLOC|SHF_WRITE, align_);
        s.Sfl = FLudata;
        SegData[s.Sseg].SDsym = s;
        SegData[s.Sseg].SDoffset += size * count;
        Obj_pubdefsize(s.Sseg, s, 0, size * count);
        searchfixlist(s);
        return s.Sseg;
    }
static if (0)
{
    reset_symbuf.write(s);
    IDXSTR namidx = elf_addmangled(s);
    alignOffset(UDATA,size);
    IDXSYM symidx = elf_addsym(namidx, SegData[UDATA].SDoffset, size*count,
                    (s.ty() & mTYthread) ? STT_TLS : STT_OBJECT,
                    STB_WEAK, SHN_BSS);
    //dbg_printf("\tObj_common_block returning symidx %d\n",symidx);
    s.Sseg = UDATA;
    s.Sfl = FLudata;
    SegData[UDATA].SDoffset += size * count;
    return symidx;
}
}

int Obj_common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
{
    return Obj_common_block(s, size, count);
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void Obj_write_zeros(seg_data *pseg, targ_size_t count)
{
    Obj_lidata(pseg.SDseg, pseg.SDoffset, count);
}

/***************************************
 * Output an iterated data block of 0s.
 *
 *      For boundary alignment and initialization
 */

void Obj_lidata(int seg,targ_size_t offset,targ_size_t count)
{
    //printf("Obj_lidata(%d,%x,%d)\n",seg,offset,count);
    if (seg == UDATA || seg == UNKNOWN)
    {   // Use SDoffset to record size of .BSS section
        SegData[UDATA].SDoffset += count;
    }
    else if (MAP_SEG2SEC(seg).sh_type == SHT_NOBITS)
    {   // Use SDoffset to record size of .TBSS section
        SegData[seg].SDoffset += count;
    }
    else
    {
        Obj_bytes(seg, offset, cast(uint)count, null);
    }
}

/***********************************
 * Append byte to segment.
 */

void Obj_write_byte(seg_data *pseg, uint byte_)
{
    Obj_byte(pseg.SDseg, pseg.SDoffset, byte_);
}

/************************************
 * Output byte to object file.
 */

void Obj_byte(int seg,targ_size_t offset,uint byte_)
{
    Outbuffer *buf = SegData[seg].SDbuf;
    int save = cast(int)buf.size();
    //dbg_printf("Obj_byte(seg=%d, offset=x%lx, byte_=x%x)\n",seg,offset,byte_);
    buf.setsize(cast(uint)offset);
    buf.writeByte(byte_);
    if (save > offset+1)
        buf.setsize(save);
    else
        SegData[seg].SDoffset = offset+1;
    //dbg_printf("\tsize now %d\n",buf.size());
}

/***********************************
 * Append bytes to segment.
 */

void Obj_write_bytes(seg_data *pseg, uint nbytes, void *p)
{
    Obj_bytes(pseg.SDseg, pseg.SDoffset, nbytes, p);
}

/************************************
 * Output bytes to object file.
 * Returns:
 *      nbytes
 */

uint Obj_bytes(int seg, targ_size_t offset, uint nbytes, void *p)
{
static if (0)
{
    if (!(seg >= 0 && seg <= seg_count))
    {   printf("Obj_bytes: seg = %d, seg_count = %d\n", seg, seg_count);
        *cast(char*)0=0;
    }
}
    assert(seg >= 0 && seg <= seg_count);
    Outbuffer *buf = SegData[seg].SDbuf;
    if (buf == null)
    {
        //dbg_printf("Obj_bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n", seg, offset, nbytes, p);
        //raise(SIGSEGV);
        assert(buf != null);
    }
    int save = cast(int)buf.size();
    //dbg_printf("Obj_bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n",
            //seg,offset,nbytes,p);
    buf.position(cast(uint)offset, nbytes);
    if (p)
    {
        buf.writen(p,nbytes);
    }
    else
    {   // Zero out the bytes
        buf.clearn(nbytes);
    }
    if (save > offset+nbytes)
        buf.setsize(save);
    else
        SegData[seg].SDoffset = offset+nbytes;
    return nbytes;
}

/*******************************
 * Output a relocation entry for a segment
 * Input:
 *      seg =           where the address is going
 *      offset =        offset within seg
 *      type =          ELF relocation type R_ARCH_XXXX
 *      index =         Related symbol table index
 *      val =           addend or displacement from address
 */

__gshared int relcnt=0;

void Obj_addrel(int seg, targ_size_t offset, uint type,
                    IDXSYM symidx, targ_size_t val)
{
    seg_data *segdata;
    Outbuffer *buf;
    IDXSEC secidx;

    //assert(val == 0);
    relcnt++;
    //dbg_printf("%d-Obj_addrel(seg %d,offset x%x,type x%x,symidx %d,val %d)\n",
            //relcnt,seg, offset, type, symidx,val);

    assert(seg >= 0 && seg <= seg_count);
    segdata = SegData[seg];
    secidx = MAP_SEG2SECIDX(seg);
    assert(secidx != 0);

    if (segdata.SDrel == null)
    {
        segdata.SDrel = cast(Outbuffer*) calloc(1, (Outbuffer).sizeof);
        assert(segdata.SDrel);
    }

    if (segdata.SDrel.size() == 0)
    {   IDXSEC relidx;

        if (secidx == SHN_TEXT)
            relidx = SHN_RELTEXT;
        else if (secidx == SHN_DATA)
            relidx = SHN_RELDATA;
        else
        {
            // Get the section name, and make a copy because
            // elf_newsection() may reallocate the string buffer.
            char *section_name = cast(char *)GET_SECTION_NAME(secidx);
            size_t len = strlen(section_name) + 1;
            char[20] buf2 = void;
            char *p = len <= buf2.sizeof ? &buf2[0] : cast(char *)malloc(len);
            assert(p);
            memcpy(p, section_name, len);

            relidx = elf_newsection(I64 ? ".rela" : ".rel", p, I64 ? SHT_RELA : SHT_REL, 0);
            if (p != &buf2[0])
                free(p);
            segdata.SDrelidx = relidx;
            addSectionToComdat(relidx,seg);
        }

        if (I64)
        {
            /* Note that we're using Elf32_Shdr here instead of Elf64_Shdr. This is to make
             * the code a bit simpler. In Obj_term(), we translate the Elf32_Shdr into the proper
             * Elf64_Shdr.
             */
            Elf32_Shdr *relsec = &SecHdrTab[relidx];
            relsec.sh_link = SHN_SYMTAB;
            relsec.sh_info = secidx;
            relsec.sh_entsize = Elf64_Rela.sizeof;
            relsec.sh_addralign = 8;
        }
        else
        {
            Elf32_Shdr *relsec = &SecHdrTab[relidx];
            relsec.sh_link = SHN_SYMTAB;
            relsec.sh_info = secidx;
            relsec.sh_entsize = Elf32_Rel.sizeof;
            relsec.sh_addralign = 4;
        }
    }

    if (I64)
    {
        Elf64_Rela rel;
        rel.r_offset = offset;          // build relocation information
        rel.r_info = ELF64_R_INFO(symidx,type);
        rel.r_addend = val;
        buf = segdata.SDrel;
        buf.write(&rel,(rel).sizeof);
        segdata.SDrelcnt++;

        if (offset >= segdata.SDrelmaxoff)
            segdata.SDrelmaxoff = offset;
        else
        {   // insert numerically
            Elf64_Rela *relbuf = cast(Elf64_Rela *)buf.buf;
            int i = relbuf[segdata.SDrelindex].r_offset > offset ? 0 : segdata.SDrelindex;
            while (i < segdata.SDrelcnt)
            {
                if (relbuf[i].r_offset > offset)
                    break;
                i++;
            }
            assert(i != segdata.SDrelcnt);     // slide greater offsets down
            memmove(relbuf+i+1,relbuf+i,Elf64_Rela.sizeof * (segdata.SDrelcnt - i - 1));
            *(relbuf+i) = rel;          // copy to correct location
            segdata.SDrelindex = i;    // next entry usually greater
        }
    }
    else
    {
        Elf32_Rel rel;
        rel.r_offset = cast(uint)offset;          // build relocation information
        rel.r_info = ELF32_R_INFO(symidx,type);
        buf = segdata.SDrel;
        buf.write(&rel,rel.sizeof);
        segdata.SDrelcnt++;

        if (offset >= segdata.SDrelmaxoff)
            segdata.SDrelmaxoff = offset;
        else
        {   // insert numerically
            Elf32_Rel *relbuf = cast(Elf32_Rel *)buf.buf;
            int i = relbuf[segdata.SDrelindex].r_offset > offset ? 0 : segdata.SDrelindex;
            while (i < segdata.SDrelcnt)
            {
                if (relbuf[i].r_offset > offset)
                    break;
                i++;
            }
            assert(i != segdata.SDrelcnt);     // slide greater offsets down
            memmove(relbuf+i+1,relbuf+i,Elf32_Rel.sizeof * (segdata.SDrelcnt - i - 1));
            *(relbuf+i) = rel;          // copy to correct location
            segdata.SDrelindex = i;    // next entry usually greater
        }
    }
}

private size_t relsize64(uint type)
{
    assert(I64);
    switch (type)
    {
        case R_X86_64_NONE:      return 0;
        case R_X86_64_64:        return 8;
        case R_X86_64_PC32:      return 4;
        case R_X86_64_GOT32:     return 4;
        case R_X86_64_PLT32:     return 4;
        case R_X86_64_COPY:      return 0;
        case R_X86_64_GLOB_DAT:  return 8;
        case R_X86_64_JUMP_SLOT: return 8;
        case R_X86_64_RELATIVE:  return 8;
        case R_X86_64_GOTPCREL:  return 4;
        case R_X86_64_32:        return 4;
        case R_X86_64_32S:       return 4;
        case R_X86_64_16:        return 2;
        case R_X86_64_PC16:      return 2;
        case R_X86_64_8:         return 1;
        case R_X86_64_PC8:       return 1;
        case R_X86_64_DTPMOD64:  return 8;
        case R_X86_64_DTPOFF64:  return 8;
        case R_X86_64_TPOFF64:   return 8;
        case R_X86_64_TLSGD:     return 4;
        case R_X86_64_TLSLD:     return 4;
        case R_X86_64_DTPOFF32:  return 4;
        case R_X86_64_GOTTPOFF:  return 4;
        case R_X86_64_TPOFF32:   return 4;
        case R_X86_64_PC64:      return 8;
        case R_X86_64_GOTOFF64:  return 8;
        case R_X86_64_GOTPC32:   return 4;

        default:
            assert(0);
    }
}

private size_t relsize32(uint type)
{
    assert(I32);
    switch (type)
    {
        case R_386_NONE:         return 0;
        case R_386_32:           return 4;
        case R_386_PC32:         return 4;
        case R_386_GOT32:        return 4;
        case R_386_PLT32:        return 4;
        case R_386_COPY:         return 0;
        case R_386_GLOB_DAT:     return 4;
        case R_386_JMP_SLOT:     return 4;
        case R_386_RELATIVE:     return 4;
        case R_386_GOTOFF:       return 4;
        case R_386_GOTPC:        return 4;
        case R_386_TLS_TPOFF:    return 4;
        case R_386_TLS_IE:       return 4;
        case R_386_TLS_GOTIE:    return 4;
        case R_386_TLS_LE:       return 4;
        case R_386_TLS_GD:       return 4;
        case R_386_TLS_LDM:      return 4;
        case R_386_TLS_GD_32:    return 4;
        case R_386_TLS_GD_PUSH:  return 4;
        case R_386_TLS_GD_CALL:  return 4;
        case R_386_TLS_GD_POP:   return 4;
        case R_386_TLS_LDM_32:   return 4;
        case R_386_TLS_LDM_PUSH: return 4;
        case R_386_TLS_LDM_CALL: return 4;
        case R_386_TLS_LDM_POP:  return 4;
        case R_386_TLS_LDO_32:   return 4;
        case R_386_TLS_IE_32:    return 4;
        case R_386_TLS_LE_32:    return 4;
        case R_386_TLS_DTPMOD32: return 4;
        case R_386_TLS_DTPOFF32: return 4;
        case R_386_TLS_TPOFF32:  return 4;

        default:
            assert(0);
    }
}

/*******************************
 * Write/Append a value to the given segment and offset.
 *      targseg =       the target segment for the relocation
 *      offset =        offset within target segment
 *      val =           addend or displacement from symbol
 *      size =          number of bytes to write
 */
private size_t writeaddrval(int targseg, size_t offset, targ_size_t val, size_t size)
{
    assert(targseg >= 0 && targseg <= seg_count);

    Outbuffer *buf = SegData[targseg].SDbuf;
    const save = buf.size();
    buf.setsize(cast(uint)offset);
    buf.write(&val, cast(uint)size);
    // restore Outbuffer position
    if (save > offset + size)
        buf.setsize(cast(uint)save);
    return size;
}

/*******************************
 * Write/Append a relocatable value to the given segment and offset.
 * Input:
 *      targseg =       the target segment for the relocation
 *      offset =        offset within target segment
 *      reltype =       ELF relocation type R_ARCH_XXXX
 *      symidx =        symbol base for relocation
 *      val =           addend or displacement from symbol
 */
size_t Obj_writerel(int targseg, size_t offset, uint reltype,
                        IDXSYM symidx, targ_size_t val)
{
    assert(reltype != R_X86_64_NONE);

    size_t sz;
    if (I64)
    {
        // Elf64_Rela stores addend in Rela.r_addend field
        sz = relsize64(reltype);
        writeaddrval(targseg, offset, 0, sz);
        Obj_addrel(targseg, offset, reltype, symidx, val);
    }
    else
    {
        assert(I32);
        // Elf32_Rel stores addend in target location
        sz = relsize32(reltype);
        writeaddrval(targseg, offset, val, sz);
        Obj_addrel(targseg, offset, reltype, symidx, 0);
    }
    return sz;
}

/*******************************
 * Refer to address that is in the data segment.
 * Input:
 *      seg =           where the address is going
 *      offset =        offset within seg
 *      val =           displacement from address
 *      targetdatum =   DATA, CDATA or UDATA, depending where the address is
 *      flags =         CFoff, CFseg, CFoffset64, CFswitch
 * Example:
 *      int *abc = &def[3];
 *      to allocate storage:
 *              Obj_reftodatseg(DATA,offset,3 * (int *).sizeof,UDATA);
 * Note:
 *      For I64 && (flags & CFoffset64) && (flags & CFswitch)
 *      targetdatum is a symidx rather than a segment.
 */

void Obj_reftodatseg(int seg,targ_size_t offset,targ_size_t val,
        uint targetdatum,int flags)
{
static if (0)
{
    printf("Obj_reftodatseg(seg=%d, offset=x%llx, val=x%llx,data %x, flags %x)\n",
        seg,cast(ulong)offset,cast(ulong)val,targetdatum,flags);
}

    int relinfo;
    IDXSYM targetsymidx = STI_RODAT;
    if (I64)
    {

        if (flags & CFoffset64)
        {
            relinfo = R_X86_64_64;
            if (flags & CFswitch) targetsymidx = targetdatum;
        }
        else if (flags & CFswitch)
        {
            relinfo = R_X86_64_PC32;
            targetsymidx = MAP_SEG2SYMIDX(targetdatum);
        }
        else if (MAP_SEG2TYP(seg) == CODE && config.flags3 & CFG3pic)
        {
            relinfo = R_X86_64_PC32;
            val -= 4;
            targetsymidx = MAP_SEG2SYMIDX(targetdatum);
        }
        else if (MAP_SEG2SEC(targetdatum).sh_flags & SHF_TLS)
            relinfo = config.flags3 & CFG3pic ? R_X86_64_TLSGD : R_X86_64_TPOFF32;
        else
        {
            relinfo = targetdatum == CDATA ? R_X86_64_32 : R_X86_64_32S;
            targetsymidx = MAP_SEG2SYMIDX(targetdatum);
        }
    }
    else
    {
        if (MAP_SEG2TYP(seg) == CODE && config.flags3 & CFG3pic)
            relinfo = R_386_GOTOFF;
        else if (MAP_SEG2SEC(targetdatum).sh_flags & SHF_TLS)
            relinfo = config.flags3 & CFG3pic ? R_386_TLS_GD : R_386_TLS_LE;
        else
            relinfo = R_386_32;
        targetsymidx = MAP_SEG2SYMIDX(targetdatum);
    }
    Obj_writerel(seg, cast(uint)offset, relinfo, targetsymidx, val);
}

/*******************************
 * Refer to address that is in the code segment.
 * Only offsets are output, regardless of the memory model.
 * Used to put values in switch address tables.
 * Input:
 *      seg =           where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      val =           displacement from start of this module
 */

void Obj_reftocodeseg(int seg,targ_size_t offset,targ_size_t val)
{
    //dbg_printf("Obj_reftocodeseg(seg=%d, offset=x%lx, val=x%lx )\n",seg,offset,val);

    int relinfo;
static if (0)
{
    if (MAP_SEG2TYP(seg) == CODE)
    {
        relinfo = RI_TYPE_PC32;
        Obj_writerel(seg, offset, relinfo, funcsym_p.Sxtrnnum, val - funcsym_p.Soffset);
        return;
    }
}

    if (I64)
        relinfo = (config.flags3 & CFG3pic) ? R_X86_64_PC32 : R_X86_64_32;
    else
        relinfo = (config.flags3 & CFG3pic) ? R_386_GOTOFF : R_386_32;
    Obj_writerel(seg, cast(uint)offset, relinfo, funcsym_p.Sxtrnnum, val - funcsym_p.Soffset);
}

/*******************************
 * Refer to an identifier.
 * Input:
 *      segtyp =        where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      s .            Symbol table entry for identifier
 *      val =           displacement from identifier
 *      flags =         CFselfrel: self-relative
 *                      CFseg: get segment
 *                      CFoff: get offset
 *                      CFoffset64: 64 bit fixup
 *                      CFpc32: I64: PC relative 32 bit fixup
 * Returns:
 *      number of bytes in reference (4 or 8)
 */

int Obj_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val,
        int flags)
{
    bool external = true;
    Outbuffer *buf;
    Elf32_Word relinfo=R_X86_64_NONE,refseg;
    int segtyp = MAP_SEG2TYP(seg);
    //assert(val == 0);
    int retsize = (flags & CFoffset64) ? 8 : 4;

static if (0)
{
    printf("\nObj_reftoident('%s' seg %d, offset x%llx, val x%llx, flags x%x)\n",
        s.Sident.ptr,seg,offset,val,flags);
    printf("Sseg = %d, Sxtrnnum = %d, retsize = %d\n",s.Sseg,s.Sxtrnnum,retsize);
    symbol_print(s);
}

    tym_t ty = s.ty();
    if (s.Sxtrnnum)
    {                           // identifier is defined somewhere else
        if (I64)
        {
            if (SymbolTable64[s.Sxtrnnum].st_shndx != SHN_UNDEF)
                external = false;
        }
        else
        {
            if (SymbolTable[s.Sxtrnnum].st_shndx != SHN_UNDEF)
                external = false;
        }
    }

    switch (s.Sclass)
    {
        case SClocstat:
            if (I64)
            {
                if (s.Sfl == FLtlsdata)
                    relinfo = config.flags3 & CFG3pic ? R_X86_64_TLSGD : R_X86_64_TPOFF32;
                else
                {   relinfo = config.flags3 & CFG3pic ? R_X86_64_PC32 : R_X86_64_32;
                    if (flags & CFpc32)
                        relinfo = R_X86_64_PC32;
                }
            }
            else
            {
                if (s.Sfl == FLtlsdata)
                    relinfo = config.flags3 & CFG3pic ? R_386_TLS_GD : R_386_TLS_LE;
                else
                    relinfo = config.flags3 & CFG3pic ? R_386_GOTOFF : R_386_32;
            }
            if (flags & CFoffset64 && relinfo == R_X86_64_32)
            {
                relinfo = R_X86_64_64;
                retsize = 8;
            }
            refseg = STI_RODAT;
            val += s.Soffset;
            goto outrel;

        case SCcomdat:
        case_SCcomdat:
        case SCstatic:
static if (0)
{
            if ((s.Sflags & SFLthunk) && s.Soffset)
            {                   // A thunk symbol that has be defined
                assert(s.Sseg == seg);
                val = (s.Soffset+val) - (offset+4);
                goto outaddrval;
            }
}
            goto case;

        case SCextern:
        case SCcomdef:
        case_extern:
        case SCglobal:
            if (!s.Sxtrnnum)
            {   // not in symbol table yet - class might change
                //printf("\tadding %s to fixlist\n",s.Sident.ptr);
                size_t numbyteswritten = addtofixlist(s,offset,seg,val,flags);
                assert(numbyteswritten == retsize);
                return retsize;
            }
            else
            {
                refseg = s.Sxtrnnum;       // default to name symbol table entry

                if (flags & CFselfrel)
                {               // only for function references within code segments
                    if (!external &&            // local definition found
                         s.Sseg == seg &&      // within same code segment
                          (!(config.flags3 & CFG3pic) ||        // not position indp code
                           s.Sclass == SCstatic)) // or is pic, but declared static
                    {                   // Can use PC relative
                        //dbg_printf("\tdoing PC relative\n");
                        val = (s.Soffset+val) - (offset+4);
                    }
                    else
                    {
                        //dbg_printf("\tadding relocation\n");
                        if (I64)
                            relinfo = config.flags3 & CFG3pic ?  R_X86_64_PLT32 : R_X86_64_PC32;
                        else
                            relinfo = config.flags3 & CFG3pic ?  R_386_PLT32 : R_386_PC32;
                        val = -cast(targ_size_t)4;
                    }
                }
                else
                {       // code to code code to data, data to code, data to data refs
                    if (s.Sclass == SCstatic)
                    {                           // offset into .data or .bss seg
                        refseg = MAP_SEG2SYMIDX(s.Sseg);
                                                // use segment symbol table entry
                        val += s.Soffset;
                        if (!(config.flags3 & CFG3pic) ||       // all static refs from normal code
                             segtyp == DATA)    // or refs from data from posi indp
                        {
                            if (I64)
                                relinfo = (flags & CFpc32) ? R_X86_64_PC32 : R_X86_64_32;
                            else
                                relinfo = R_386_32;
                        }
                        else
                        {
                            relinfo = I64 ? R_X86_64_PC32 : R_386_GOTOFF;
                        }
                    }
                    else if (config.flags3 & CFG3pic && s == GOTsym)
                    {                   // relocation for Gbl Offset Tab
                        relinfo =  I64 ? R_X86_64_NONE : R_386_GOTPC;
                    }
                    else if (segtyp == DATA)
                    {                   // relocation from within DATA seg
                        relinfo = I64 ? R_X86_64_32 : R_386_32;
                        if (I64 && flags & CFpc32)
                            relinfo = R_X86_64_PC32;
                    }
                    else
                    {                   // relocation from within CODE seg
                        if (I64)
                        {   if (config.flags3 & CFG3pic)
                                relinfo = R_X86_64_GOTPCREL;
                            else
                                relinfo = (flags & CFpc32) ? R_X86_64_PC32 : R_X86_64_32;
                        }
                        else
                            relinfo = config.flags3 & CFG3pic ? R_386_GOT32 : R_386_32;
                    }
                    if ((s.ty() & mTYLINK) & mTYthread)
                    {
                        if (I64)
                        {
                            if (config.flags3 & CFG3pic)
                            {
                                /+if (s.Sclass == SCstatic || s.Sclass == SClocstat)
                                    // Could use 'local dynamic (LD)' to optimize multiple local TLS reads
                                    relinfo = R_X86_64_TLSGD;
                                else+/
                                    relinfo = R_X86_64_TLSGD;
                            }
                            else
                            {
                                if (s.Sclass == SCstatic || s.Sclass == SClocstat)
                                    relinfo = R_X86_64_TPOFF32;
                                else
                                    relinfo = R_X86_64_GOTTPOFF;
                            }
                        }
                        else
                        {
                            if (config.flags3 & CFG3pic)
                            {
                                /+if (s.Sclass == SCstatic)
                                    // Could use 'local dynamic (LD)' to optimize multiple local TLS reads
                                    relinfo = R_386_TLS_GD;
                                else+/
                                    relinfo = R_386_TLS_GD;
                            }
                            else
                            {
                                if (s.Sclass == SCstatic)
                                    relinfo = R_386_TLS_LE;
                                else
                                    relinfo = R_386_TLS_IE;
                            }
                        }
                    }
                    if (flags & CFoffset64 && relinfo == R_X86_64_32)
                    {
                        relinfo = R_X86_64_64;
                    }
                }
                if (relinfo == R_X86_64_NONE)
                {
                outaddrval:
                    writeaddrval(seg, cast(uint)offset, val, retsize);
                }
                else
                {
                outrel:
                    //printf("\t\t************* adding relocation\n");
                    const size_t nbytes = Obj_writerel(seg, cast(uint)offset, relinfo, refseg, val);
                    assert(nbytes == retsize);
                }
            }
            break;

        case SCsinline:
        case SCeinline:
            printf ("Undefined inline value <<fixme>>\n");
            //warerr(WM_undefined_inline,s.Sident.ptr);
            goto  case;

        case SCinline:
            if (tyfunc(ty))
            {
                s.Sclass = SCextern;
                goto case_extern;
            }
            else if (config.flags2 & CFG2comdat)
                goto case_SCcomdat;     // treat as initialized common block
            goto default;

        default:
            //symbol_print(s);
            assert(0);
    }
    return retsize;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *      s       Symbol to generate a thunk for
 */

void Obj_far16thunk(Symbol *s)
{
    //dbg_printf("Obj_far16thunk('%s')\n", s.Sident.ptr);
    assert(0);
}

/**************************************
 * Mark object file as using floating point.
 */

void Obj_fltused()
{
    //dbg_printf("Obj_fltused()\n");
}

/************************************
 * Close and delete .OBJ file.
 */

void objfile_delete()
{
    //remove(fobjname); // delete corrupt output file
}

/**********************************
 * Terminate.
 */

void objfile_term()
{
static if (TERMCODE)
{
    mem_free(fobjname);
    fobjname = null;
}
}

/**********************************
  * Write to the object file
  */
/+void objfile_write(FILE *fd, void *buffer, uint len)
{
    fobjbuf.write(buffer, len);
}
+/

int elf_align(targ_size_t size,int foffset)
{
    if (size <= 1)
        return foffset;
    int offset = cast(int)((foffset + size - 1) & ~(size - 1));
    if (offset > foffset)
        fobjbuf.writezeros(offset - foffset);
    return offset;
}

/***************************************
 * Stuff pointer to ModuleInfo into its own section (minfo).
 */

version (MARS)
{

void Obj_moduleinfo(Symbol *scc)
{
    const int CFflags = I64 ? (CFoffset64 | CFoff) : CFoff;

    // needs to be writeable for PIC code, see Bugzilla 13117
    const int shf_flags = SHF_ALLOC | SHF_WRITE;
    const int seg = Obj_getsegment("minfo", null, SHT_PROGBITS, shf_flags, _tysize[TYnptr]);
    SegData[seg].SDoffset +=
        Obj_reftoident(seg, SegData[seg].SDoffset, scc, 0, CFflags);
}

/***************************************
 * Create startup/shutdown code to register an executable/shared
 * library (DSO) with druntime. Create one for each object file and
 * put the sections into a COMDAT group. This will ensure that each
 * DSO gets registered only once.
 */

private void obj_rtinit()
{
    // section start/stop symbols are defined by the linker (http://www.airs.com/blog/archives/56)
    // make the symbols hidden so that each DSO gets it's own brackets
    IDXSYM minfo_beg, minfo_end, dso_rec;
    IDXSTR namidx;
    int seg;

    {
    // needs to be writeable for PIC code, see Bugzilla 13117
    const int shf_flags = SHF_ALLOC | SHF_WRITE;

    namidx = Obj_addstr(symtab_strings,"__start_minfo");
    minfo_beg = elf_addsym(namidx, 0, 0, STT_NOTYPE, STB_GLOBAL, SHN_UNDEF, STV_HIDDEN);

    Obj_getsegment("minfo", null, SHT_PROGBITS, shf_flags, _tysize[TYnptr]);

    namidx = Obj_addstr(symtab_strings,"__stop_minfo");
    minfo_end = elf_addsym(namidx, 0, 0, STT_NOTYPE, STB_GLOBAL, SHN_UNDEF, STV_HIDDEN);
    }

    // Create a COMDAT section group
    const int groupseg = Obj_getsegment(".group.d_dso", null, SHT_GROUP, 0, 0);
    SegData[groupseg].SDbuf.write32(GRP_COMDAT);

    {
        /*
         * Create an instance of DSORec as global static data in the section .data.d_dso_rec
         * It is writeable and allows the runtime to store information.
         * Make it a COMDAT so there's only one per DSO.
         *
         * typedef union
         * {
         *     size_t        id;
         *     void       *data;
         * } DSORec;
         */
        seg = Obj_getsegment(".data.d_dso_rec", null, SHT_PROGBITS,
                         SHF_ALLOC|SHF_WRITE|SHF_GROUP, _tysize[TYnptr]);
        dso_rec = MAP_SEG2SYMIDX(seg);
        Obj_bytes(seg, 0, _tysize[TYnptr], null);
        // add to section group
        SegData[groupseg].SDbuf.write32(MAP_SEG2SECIDX(seg));

        /*
         * Create an instance of DSO on the stack:
         *
         * typedef struct
         * {
         *     size_t                version;
         *     DSORec               *dso_rec;
         *     void   *minfo_beg, *minfo_end;
         * } DSO;
         *
         * Generate the following function as a COMDAT so there's only one per DSO:
         *  .text.d_dso_init    segment
         *      push    EBP
         *      mov     EBP,ESP
         *      sub     ESP,align
         *      lea     RAX,minfo_end[RIP]
         *      push    RAX
         *      lea     RAX,minfo_beg[RIP]
         *      push    RAX
         *      lea     RAX,.data.d_dso_rec[RIP]
         *      push    RAX
         *      push    1       // version
         *      mov     RDI,RSP
         *      call      _d_dso_registry@PLT32
         *      leave
         *      ret
         * and then put a pointer to that function in .ctors and in .dtors so it'll
         * get executed once upon loading and once upon unloading the DSO.
         */
        int codseg;
        {
            codseg = Obj_getsegment(".text.d_dso_init", null, SHT_PROGBITS,
                                    SHF_ALLOC|SHF_EXECINSTR|SHF_GROUP, _tysize[TYnptr]);
            // add to section group
            SegData[groupseg].SDbuf.write32(MAP_SEG2SECIDX(codseg));

debug
{
            // adds a local symbol (name) to the code, useful to set a breakpoint
            namidx = Obj_addstr(symtab_strings, "__d_dso_init");
            elf_addsym(namidx, 0, 0, STT_FUNC, STB_LOCAL, MAP_SEG2SECIDX(codseg));
}
        }
        Outbuffer *buf = SegData[codseg].SDbuf;
        assert(!buf.size());
        size_t off = 0;

        // 16-byte align for call
        const size_t sizeof_dso = 6 * _tysize[TYnptr];
        const size_t align_ = I64 ?
            // return address, RBP, DSO
            (-(2 * _tysize[TYnptr] + sizeof_dso) & 0xF) :
            // return address, EBP, EBX, DSO, arg
            (-(3 * _tysize[TYnptr] + sizeof_dso + _tysize[TYnptr]) & 0xF);

        // push EBP
        buf.writeByte(0x50 + BP);
        off += 1;
        // mov EBP, ESP
        if (I64)
        {
            buf.writeByte(REX | REX_W);
            off += 1;
        }
        buf.writeByte(0x8B);
        buf.writeByte(modregrm(3,BP,SP));
        off += 2;
        // sub ESP, align_
        if (align_)
        {
            if (I64)
            {
                buf.writeByte(REX | REX_W);
                off += 1;
            }
            buf.writeByte(0x81);
            buf.writeByte(modregrm(3,5,SP));
            buf.writeByte(align_ & 0xFF);
            buf.writeByte(align_ >> 8 & 0xFF);
            buf.writeByte(0);
            buf.writeByte(0);
            off += 6;
        }

        if (config.flags3 & CFG3pic && I32)
        {   // see cod3_load_got() for reference
            // push EBX
            buf.writeByte(0x50 + BX);
            off += 1;
            // call L1
            buf.writeByte(0xE8);
            buf.write32(0);
            // L1: pop EBX (now contains EIP)
            buf.writeByte(0x58 + BX);
            off += 6;
            // add EBX,_GLOBAL_OFFSET_TABLE_+3
            buf.writeByte(0x81);
            buf.writeByte(modregrm(3,0,BX));
            off += 2;
            off += Obj_writerel(codseg, off, R_386_GOTPC, Obj_external(Obj_getGOTsym()), 3);
        }

        int reltype;
        if (config.flags3 & CFG3pic)
            reltype = I64 ? R_X86_64_PC32 : R_386_GOTOFF;
        else
            reltype = I64 ? R_X86_64_32 : R_386_32;

        const IDXSYM[3] syms = [dso_rec, minfo_beg, minfo_end];

        for (size_t i = (syms).sizeof / (syms[0]).sizeof; i--; )
        {
            const IDXSYM sym = syms[i];

            if (config.flags3 & CFG3pic)
            {
                if (I64)
                {
                    // lea RAX, sym[RIP]
                    buf.writeByte(REX | REX_W);
                    buf.writeByte(0x8D);
                    buf.writeByte(modregrm(0,AX,5));
                    off += 3;
                    off += Obj_writerel(codseg, off, reltype, syms[i], -4);
                }
                else
                {
                    // lea EAX, sym[EBX]
                    buf.writeByte(0x8D);
                    buf.writeByte(modregrm(2,AX,BX));
                    off += 2;
                    off += Obj_writerel(codseg, off, reltype, syms[i], 0);
                }
            }
            else
            {
                // mov EAX, sym
                buf.writeByte(0xB8 + AX);
                off += 1;
                off += Obj_writerel(codseg, off, reltype, syms[i], 0);
            }
            // push RAX
            buf.writeByte(0x50 + AX);
            off += 1;
        }
        // Pass a version flag to simplify future extensions.
        static immutable size_t ver = 1;
        // push imm8
        assert(!(ver & ~0xFF));
        buf.writeByte(0x6A);
        buf.writeByte(ver);
        off += 2;

        if (I64)
        {   // mov RDI, DSO*
            buf.writeByte(REX | REX_W);
            buf.writeByte(0x8B);
            buf.writeByte(modregrm(3,DI,SP));
            off += 3;
        }
        else
        {   // push DSO*
            buf.writeByte(0x50 + SP);
            off += 1;
        }

static if (REQUIRE_DSO_REGISTRY)
{

        const IDXSYM symidx = Obj_external_def("_d_dso_registry");

        // call _d_dso_registry@PLT
        buf.writeByte(0xE8);
        off += 1;
        off += Obj_writerel(codseg, off, I64 ? R_X86_64_PLT32 : R_386_PLT32, symidx, -4);

}
else
{

        // use a weak reference for _d_dso_registry
        namidx = Obj_addstr(symtab_strings, "_d_dso_registry");
        const IDXSYM symidx = elf_addsym(namidx, 0, 0, STT_NOTYPE, STB_WEAK, SHN_UNDEF);

        if (config.flags3 & CFG3pic)
        {
            if (I64)
            {
                // cmp foo@GOT[RIP], 0
                buf.writeByte(REX | REX_W);
                buf.writeByte(0x83);
                buf.writeByte(modregrm(0,7,5));
                off += 3;
                off += Obj_writerel(codseg, off, R_X86_64_GOTPCREL, symidx, -5);
                buf.writeByte(0);
                off += 1;
            }
            else
            {
                // cmp foo[GOT], 0
                buf.writeByte(0x81);
                buf.writeByte(modregrm(2,7,BX));
                off += 2;
                off += Obj_writerel(codseg, off, R_386_GOT32, symidx, 0);
                buf.write32(0);
                off += 4;
            }
            // jz +5
            buf.writeByte(0x74);
            buf.writeByte(0x05);
            off += 2;

            // call foo@PLT[RIP]
            buf.writeByte(0xE8);
            off += 1;
            off += Obj_writerel(codseg, off, I64 ? R_X86_64_PLT32 : R_386_PLT32, symidx, -4);
        }
        else
        {
            // mov ECX, offset foo
            buf.writeByte(0xB8 + CX);
            off += 1;
            reltype = I64 ? R_X86_64_32 : R_386_32;
            off += Obj_writerel(codseg, off, reltype, symidx, 0);

            // test ECX, ECX
            buf.writeByte(0x85);
            buf.writeByte(modregrm(3,CX,CX));

            // jz +5 (skip call)
            buf.writeByte(0x74);
            buf.writeByte(0x05);
            off += 4;

            // call _d_dso_registry[RIP]
            buf.writeByte(0xE8);
            off += 1;
            off += Obj_writerel(codseg, off, I64 ? R_X86_64_PC32 : R_386_PC32, symidx, -4);
        }

}

        if (config.flags3 & CFG3pic && I32)
        {   // mov EBX,[EBP-4-align_]
            buf.writeByte(0x8B);
            buf.writeByte(modregrm(1,BX,BP));
            buf.writeByte(cast(int)(-4-align_));
            off += 3;
        }
        // leave
        buf.writeByte(0xC9);
        // ret
        buf.writeByte(0xC3);
        off += 2;
        Offset(codseg) = off;

        // put a reference into .ctors/.dtors each
        const(char)*[2] p = [".dtors.d_dso_dtor", ".ctors.d_dso_ctor"];
        // needs to be writeable for PIC code, see Bugzilla 13117
        const int flags = SHF_ALLOC | SHF_WRITE | SHF_GROUP;
        for (size_t i = 0; i < 2; ++i)
        {
            seg = Obj_getsegment(p[i], null, SHT_PROGBITS, flags, _tysize[TYnptr]);
            assert(!SegData[seg].SDbuf.size());

            // add to section group
            SegData[groupseg].SDbuf.write32(MAP_SEG2SECIDX(seg));

            // relocation
            if (I64)
                reltype = R_X86_64_64;
            else
                reltype = R_386_32;

            SegData[seg].SDoffset += Obj_writerel(seg, 0, reltype, MAP_SEG2SYMIDX(codseg), 0);
        }
    }
    // set group section infos
    Offset(groupseg) = SegData[groupseg].SDbuf.size();
    Elf32_Shdr *p = MAP_SEG2SEC(groupseg);
    p.sh_link    = SHN_SYMTAB;
    p.sh_info    = dso_rec; // set the dso_rec as group symbol
    p.sh_entsize = IDXSYM.sizeof;
    p.sh_size    = cast(uint)Offset(groupseg);
}

}

/*************************************
 */

void Obj_gotref(Symbol *s)
{
    //printf("Obj_gotref(%x '%s', %d)\n",s,s.Sident.ptr, s.Sclass);
    switch(s.Sclass)
    {
        case SCstatic:
        case SClocstat:
            s.Sfl = FLgotoff;
            break;

        case SCextern:
        case SCglobal:
        case SCcomdat:
        case SCcomdef:
            s.Sfl = FLgot;
            break;

        default:
            break;
    }
}

Symbol *Obj_tlv_bootstrap()
{
    // specific for Mach-O
    assert(0);
}

void Obj_write_pointerRef(Symbol* s, uint off)
{
}

/******************************************
 * Generate fixup specific to .eh_frame and .gcc_except_table sections.
 * Params:
 *      seg = segment of where to write fixup
 *      offset = offset of where to write fixup
 *      s = fixup is a reference to this Symbol
 *      val = displacement from s
 * Returns:
 *      number of bytes written at seg:offset
 */
int dwarf_reftoident(int seg, targ_size_t offset, Symbol *s, targ_size_t val)
{
    if (config.flags3 & CFG3pic)
    {
        /* fixup: R_X86_64_PC32 sym="DW.ref.name"
         * symtab: .weak DW.ref.name,@OBJECT,VALUE=.data.DW.ref.name+0x00,SIZE=8
         * Section 13  .data.DW.ref.name  PROGBITS,ALLOC,WRITE,SIZE=0x0008(8),OFFSET=0x0138,ALIGN=8
         *  0138:   0  0  0  0  0  0  0  0                           ........
         * Section 14  .rela.data.DW.ref.name  RELA,ENTRIES=1,OFFSET=0x0E18,ALIGN=8,LINK=22,INFO=13
         *   0 offset=00000000 addend=0000000000000000 type=R_X86_64_64 sym="name"
         */
        if (!s.Sdw_ref_idx)
        {
            int dataDWref_seg = Obj_getsegment(".data.DW.ref.", s.Sident.ptr, SHT_PROGBITS, SHF_ALLOC|SHF_WRITE, I64 ? 8 : 4);
            Outbuffer *buf = SegData[dataDWref_seg].SDbuf;
            assert(buf.size() == 0);
            Obj_reftoident(dataDWref_seg, 0, s, 0, I64 ? CFoffset64 : CFoff);

            // Add "DW.ref." ~ name to the symtab_strings table
            IDXSTR namidx = cast(IDXSTR)symtab_strings.size();
            symtab_strings.writeString("DW.ref.");
            symtab_strings.setsize(cast(uint)(symtab_strings.size() - 1));  // back up over terminating 0
            symtab_strings.writeString(s.Sident.ptr);

            s.Sdw_ref_idx = elf_addsym(namidx, val, 8, STT_OBJECT, STB_WEAK, MAP_SEG2SECIDX(dataDWref_seg), STV_HIDDEN);
        }
        Obj_writerel(seg, cast(uint)offset, I64 ? R_X86_64_PC32 : R_386_PC32, s.Sdw_ref_idx, 0);
    }
    else
    {
        Obj_reftoident(seg, offset, s, val, CFoff);
        //dwarf_addrel(seg, offset, s.Sseg, s.Soffset);
        //et.write32(s.Soffset);
    }
    return 4;
}

}

}
