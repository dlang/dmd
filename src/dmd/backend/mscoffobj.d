/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2009-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/mscoffobj.d, backend/mscoffobj.d)
 */

module dmd.backend.mscoffobj;

version (MARS)
    version = COMPILE;
version (SCPP)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdint;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.cv8;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.md5;
import dmd.backend.mem;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.outbuf;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.mscoff;

extern (C++):

nothrow:
@safe:

alias _compare_fp_t = extern(C) nothrow int function(const void*, const void*);
extern(C) void qsort(void* base, size_t nmemb, size_t size, _compare_fp_t compar);

extern (C) char* strupr(char*);

private extern (D) __gshared Outbuffer *fobjbuf;

enum DEST_LEN = (IDMAX + IDOHD + 1);


/******************************************
 */

// The object file is built ib several separate pieces

__gshared private
{

// String Table  - String table for all other names
    Outbuffer *string_table;

// Section Headers
    public Outbuffer  *ScnhdrBuf;             // Buffer to build section table in

// The -1 is because it is 1 based indexing
    @trusted
IMAGE_SECTION_HEADER* ScnhdrTab() { return cast(IMAGE_SECTION_HEADER *)ScnhdrBuf.buf - 1; }

    int scnhdr_cnt;          // Number of sections in table
    enum SCNHDR_TAB_INITSIZE = 16;  // Initial number of sections in buffer
    enum SCNHDR_TAB_INC = 4;        // Number of sections to increment buffer by

    enum SYM_TAB_INIT = 100;        // Initial number of symbol entries in buffer
    enum SYM_TAB_INC  = 50;         // Number of symbols to increment buffer by

// The symbol table
    Outbuffer *symbuf;

    Outbuffer *syment_buf;   // array of struct syment

    segidx_t segidx_drectve = UNKNOWN;         // contents of ".drectve" section
    segidx_t segidx_debugS = UNKNOWN;
    segidx_t segidx_xdata = UNKNOWN;
    segidx_t segidx_pdata = UNKNOWN;

    extern (D) int jumpTableSeg;     // segment index for __jump_table

    extern (D) Outbuffer *indirectsymbuf2;      // indirect symbol table of Symbol*'s
    extern (D) int pointersSeg;      // segment index for __pointers

    Outbuffer *ptrref_buf;           // buffer for pointer references

    int floatused;

/* If an MsCoffObj_external_def() happens, set this to the string index,
 * to be added last to the symbol table.
 * Obviously, there can be only one.
 */
    extern (D) IDXSTR extdef;

// Each compiler segment is a section
// Predefined compiler segments CODE,DATA,CDATA,UDATA map to indexes
//      into SegData[]
//      New compiler segments are added to end.

/******************************
 * Returns !=0 if this segment is a code segment.
 */

@trusted
int mscoff_seg_data_isCode(const ref seg_data sd)
{
    return (ScnhdrTab[sd.SDshtidx].Characteristics & IMAGE_SCN_CNT_CODE) != 0;
}

public:

// already in cgobj.c (should be part of objmod?):
// seg_data **SegData;
extern Rarray!(seg_data*) SegData;

private extern (D) segidx_t seg_tlsseg = UNKNOWN;
private extern (D) segidx_t seg_tlsseg_bss = UNKNOWN;

}

/*******************************************************
 * Because the mscoff relocations cannot be computed until after
 * all the segments are written out, and we need more information
 * than the mscoff relocations provide, make our own relocation
 * type. Later, translate to mscoff relocation structure.
 */

enum
{
    RELaddr   = 0,     // straight address
    RELrel    = 1,     // relative to location to be fixed up
    RELseg    = 2,     // 2 byte section
    RELaddr32 = 3,     // 4 byte offset
}

struct Relocation
{   // Relocations are attached to the struct seg_data they refer to
    targ_size_t offset; // location in segment to be fixed up
    Symbol *funcsym;    // function in which offset lies, if any
    Symbol *targsym;    // if !=null, then location is to be fixed up
                        // to address of this symbol
    uint targseg;   // if !=0, then location is to be fixed up
                        // to address of start of this segment
    ubyte rtype;   // RELxxxx
    short val;          // 0, -1, -2, -3, -4, -5
}


/*******************************
 * Output a string into a string table
 * Input:
 *      strtab  =       string table for entry
 *      str     =       string to add
 *
 * Returns offset into the specified string table.
 */

IDXSTR MsCoffObj_addstr(Outbuffer *strtab, const(char)* str)
{
    //printf("MsCoffObj_addstr(strtab = %p str = '%s')\n",strtab,str);
    IDXSTR idx = cast(IDXSTR)strtab.length();        // remember starting offset
    strtab.writeString(str);
    //printf("\tidx %d, new size %d\n",idx,strtab.length());
    return idx;
}

/**************************
 * Output read only data and generate a symbol for it.
 *
 */

Symbol * MsCoffObj_sym_cdata(tym_t ty,char *p,int len)
{
    //printf("MsCoffObj_sym_cdata(ty = %x, p = %x, len = %d, Offset(CDATA) = %x)\n", ty, p, len, Offset(CDATA));
    alignOffset(CDATA, tysize(ty));
    Symbol *s = symboldata(Offset(CDATA), ty);
    s.Sseg = CDATA;
    MsCoffObj_pubdef(CDATA, s, Offset(CDATA));
    MsCoffObj_bytes(CDATA, Offset(CDATA), len, p);

    s.Sfl = FLdata; //FLextern;
    return s;
}

/**************************
 * Ouput read only data for data
 *
 */

@trusted
int MsCoffObj_data_readonly(char *p, int len, segidx_t *pseg)
{
    int oldoff;
version (SCPP)
{
    oldoff = Offset(DATA);
    SegData[DATA].SDbuf.reserve(len);
    SegData[DATA].SDbuf.writen(p,len);
    Offset(DATA) += len;
    *pseg = DATA;
}
else
{
    oldoff = cast(int)Offset(CDATA);
    SegData[CDATA].SDbuf.reserve(len);
    SegData[CDATA].SDbuf.writen(p,len);
    Offset(CDATA) += len;
    *pseg = CDATA;
}
    return oldoff;
}

@trusted
int MsCoffObj_data_readonly(char *p, int len)
{
    segidx_t pseg;

    return MsCoffObj_data_readonly(p, len, &pseg);
}

/*****************************
 * Get segment for readonly string literals.
 * The linker will pool strings in this section.
 * Params:
 *    sz = number of bytes per character (1, 2, or 4)
 * Returns:
 *    segment index
 */
int MsCoffObj_string_literal_segment(uint sz)
{
    assert(0);
}

/******************************
 * Start a .obj file.
 * Called before any other obj_xxx routines.
 * One source file can generate multiple .obj files.
 */

@trusted
Obj MsCoffObj_init(Outbuffer *objbuf, const(char)* filename, const(char)* csegname)
{
    //printf("MsCoffObj_init()\n");
    Obj obj = cast(Obj)mem_calloc(__traits(classInstanceSize, Obj));

    cseg = CODE;
    fobjbuf = objbuf;
    assert(objbuf.length() == 0);

    floatused = 0;

    segidx_drectve = UNKNOWN;
    seg_tlsseg = UNKNOWN;
    seg_tlsseg_bss = UNKNOWN;

    segidx_pdata = UNKNOWN;
    segidx_xdata = UNKNOWN;
    segidx_debugS = UNKNOWN;

    // Initialize buffers

    if (!string_table)
    {
        string_table = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(string_table);
        string_table.reserve(2048);
    }
    string_table.reset();
    string_table.write32(4);           // first 4 bytes are length of string table

    if (symbuf)
    {
        Symbol **p = cast(Symbol **)symbuf.buf;
        const size_t n = symbuf.length() / (Symbol *).sizeof;
        for (size_t i = 0; i < n; ++i)
            symbol_reset(p[i]);
        symbuf.reset();
    }
    else
    {
        symbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(symbuf);
        symbuf.reserve((Symbol *).sizeof * SYM_TAB_INIT);
    }

    if (!syment_buf)
    {
        syment_buf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(syment_buf);
        syment_buf.reserve(SymbolTable32.sizeof * SYM_TAB_INIT);
    }
    syment_buf.reset();

    extdef = 0;
    pointersSeg = 0;

    // Initialize segments for CODE, DATA, UDATA and CDATA
    if (!ScnhdrBuf)
    {
        ScnhdrBuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(ScnhdrBuf);
        ScnhdrBuf.reserve(SCNHDR_TAB_INITSIZE * (IMAGE_SECTION_HEADER).sizeof);
    }
    ScnhdrBuf.reset();
    scnhdr_cnt = 0;

    /* Define sections. Although the order should not matter, we duplicate
     * the same order VC puts out just to avoid trouble.
     */

    int alignText = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_8BYTES;
    int alignData = IMAGE_SCN_ALIGN_16BYTES;
    MsCoffObj_addScnhdr(".data$B",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ |
                          IMAGE_SCN_MEM_WRITE);             // DATA
    MsCoffObj_addScnhdr(".text",    IMAGE_SCN_CNT_CODE |
                          alignText |
                          IMAGE_SCN_MEM_EXECUTE |
                          IMAGE_SCN_MEM_READ);              // CODE
    MsCoffObj_addScnhdr(".bss$B",   IMAGE_SCN_CNT_UNINITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ |
                          IMAGE_SCN_MEM_WRITE);             // UDATA
    MsCoffObj_addScnhdr(".rdata",   IMAGE_SCN_CNT_INITIALIZED_DATA |
                          alignData |
                          IMAGE_SCN_MEM_READ);              // CONST

    SegData.reset();
    SegData.push();

    enum
    {
        SHI_DATA       = 1,
        SHI_TEXT       = 2,
        SHI_UDATA      = 3,
        SHI_CDATA      = 4,
    }

    MsCoffObj_getsegment2(SHI_TEXT);
    assert(SegData[CODE].SDseg == CODE);

    MsCoffObj_getsegment2(SHI_DATA);
    assert(SegData[DATA].SDseg == DATA);

    MsCoffObj_getsegment2(SHI_CDATA);
    assert(SegData[CDATA].SDseg == CDATA);

    MsCoffObj_getsegment2(SHI_UDATA);
    assert(SegData[UDATA].SDseg == UDATA);

    if (config.fulltypes)
        cv8_initfile(filename);
    assert(objbuf.length() == 0);
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

@trusted
void MsCoffObj_initfile(const(char)* filename, const(char)* csegname, const(char)* modname)
{
    //dbg_printf("MsCoffObj_initfile(filename = %s, modname = %s)\n",filename,modname);
version (SCPP)
{
    static if (TARGET_LINUX)
    {
    if (csegname && *csegname && strcmp(csegname,".text"))
    {   // Define new section and make it the default for cseg segment
        // NOTE: cseg is initialized to CODE
        IDXSEC newsecidx;
        Elf32_Shdr *newtextsec;
        IDXSYM newsymidx;
        assert(!I64);      // fix later
        SegData[cseg].SDshtidx = newsecidx =
            elf_newsection(csegname,0,SHT_PROGDEF,SHF_ALLOC|SHF_EXECINSTR);
        newtextsec = &ScnhdrTab[newsecidx];
        newtextsec.sh_addralign = 4;
        SegData[cseg].SDsymidx =
            elf_addsym(0, 0, 0, STT_SECTION, STB_LOCAL, newsecidx);
    }
    }
}
    if (config.fulltypes)
        cv8_initmodule(filename, modname);
}

/************************************
 * Patch pseg/offset by adding in the vmaddr difference from
 * pseg/offset to start of seg.
 */

@trusted
private extern (D)
int32_t *MsCoffObj_patchAddr(int seg, targ_size_t offset)
{
    return cast(int32_t *)(fobjbuf.buf + ScnhdrTab[SegData[seg].SDshtidx].PointerToRawData + offset);
}

@trusted
private extern (D)
int32_t *MsCoffObj_patchAddr64(int seg, targ_size_t offset)
{
    return cast(int32_t *)(fobjbuf.buf + ScnhdrTab[SegData[seg].SDshtidx].PointerToRawData + offset);
}

private extern (D)
static if (0)
{
@trusted
void patch(seg_data *pseg, targ_size_t offset, int seg, targ_size_t value)
{
    //printf("patch(offset = x%04x, seg = %d, value = x%llx)\n", cast(uint)offset, seg, value);
    if (I64)
    {
        int32_t *p = cast(int32_t *)(fobjbuf.buf + ScnhdrTab[pseg.SDshtidx].PointerToRawData  + offset);

static if (0)
        printf("\taddr1 = x%llx\n\taddr2 = x%llx\n\t*p = x%llx\n\tdelta = x%llx\n",
            ScnhdrTab[pseg.SDshtidx].VirtualAddress,
            ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress,
            *p,
            ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress -
            (ScnhdrTab[pseg.SDshtidx].VirtualAddress + offset));

        *p += ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress -
              (ScnhdrTab[pseg.SDshtidx].VirtualAddress - value);
    }
    else
    {
        int32_t *p = cast(int32_t *)(fobjbuf.buf + ScnhdrTab[pseg.SDshtidx].PointerToRawData + offset);

static if (0)
        printf("\taddr1 = x%x\n\taddr2 = x%x\n\t*p = x%x\n\tdelta = x%x\n",
            ScnhdrTab[pseg.SDshtidx].VirtualAddress,
            ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress,
            *p,
            ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress -
            (ScnhdrTab[pseg.SDshtidx].VirtualAddress + offset));

        *p += ScnhdrTab[SegData[seg].SDshtidx].VirtualAddress -
              (ScnhdrTab[pseg.SDshtidx].VirtualAddress - value);
    }
}
}

/*********************************
 * Build syment[], the array of symbols.
 * Store them in syment_buf.
 */

@trusted
private void syment_set_name(SymbolTable32 *sym, const(char)* name)
{
    size_t len = strlen(name);
    if (len > 8)
    {   // Use offset into string table
        IDXSTR idx = MsCoffObj_addstr(string_table, name);
        sym.Zeros = 0;
        sym.Offset = idx;
    }
    else
    {   memcpy(sym.Name.ptr, name, len);
        if (len < 8)
            memset(sym.Name.ptr + len, 0, 8 - len);
    }
}

@trusted
void write_sym(SymbolTable32* sym, bool bigobj)
{
    assert((*sym).sizeof == 20);
    if (bigobj)
    {
        syment_buf.write(sym[0 .. 1]);
    }
    else
    {
        // the only difference between SymbolTable32 and SymbolTable
        // is that field SectionNumber is long instead of short
        uint scoff = cast(uint)(cast(char*)&sym.SectionNumber - cast(char*)sym);
        syment_buf.write(sym, scoff + 2);
        syment_buf.write(cast(char*)sym + scoff + 4, cast(uint)((*sym).sizeof - scoff - 4));
    }
}
@trusted

void build_syment_table(bool bigobj)
{
    /* The @comp.id symbol appears to be the version of VC that generated the .obj file.
     * Anything we put in there would have no relevance, so we'll not put out this symbol.
     */

    uint symsize = bigobj ? SymbolTable32.sizeof : SymbolTable.sizeof;
    /* Now goes one symbol per section.
     */
    for (segidx_t seg = 1; seg < SegData.length; seg++)
    {
        seg_data *pseg = SegData[seg];
        IMAGE_SECTION_HEADER *psechdr = &ScnhdrTab[pseg.SDshtidx];   // corresponding section

        SymbolTable32 sym;
        memcpy(sym.Name.ptr, psechdr.Name.ptr, 8);
        sym.Value = 0;
        sym.SectionNumber = pseg.SDshtidx;
        sym.Type = 0;
        sym.StorageClass = IMAGE_SYM_CLASS_STATIC;
        sym.NumberOfAuxSymbols = 1;

        write_sym(&sym, bigobj);

        auxent aux = void;
        memset(&aux, 0, (aux).sizeof);

        // s_size is not set yet
        //aux.x_section.length = psechdr.s_size;
        if (pseg.SDbuf && pseg.SDbuf.length())
            aux.x_section.length = cast(uint)pseg.SDbuf.length();
        else
            aux.x_section.length = cast(uint)pseg.SDoffset;

        if (pseg.SDrel)
            aux.x_section.NumberOfRelocations = cast(ushort)(pseg.SDrel.length() / (Relocation).sizeof);

        if (psechdr.Characteristics & IMAGE_SCN_LNK_COMDAT)
        {
            aux.x_section.Selection = cast(ubyte)IMAGE_COMDAT_SELECT_ANY;
            if (pseg.SDassocseg)
            {   aux.x_section.Selection = cast(ubyte)IMAGE_COMDAT_SELECT_ASSOCIATIVE;
                aux.x_section.NumberHighPart = cast(ushort)(pseg.SDassocseg >> 16);
                aux.x_section.NumberLowPart = cast(ushort)(pseg.SDassocseg & 0x0000FFFF);
            }
        }

        memset(&aux.x_section.Zeros, 0, 2);

        syment_buf.write(&aux, symsize);

        assert((aux).sizeof == 20);
    }

    /* Add symbols from symbuf[]
     */

    int n = cast(int)SegData.length;
    size_t dim = symbuf.length() / (Symbol *).sizeof;
    for (size_t i = 0; i < dim; i++)
    {   Symbol *s = (cast(Symbol **)symbuf.buf)[i];
        s.Sxtrnnum = cast(uint)(syment_buf.length() / symsize);
        n++;

        SymbolTable32 sym;

        char[DEST_LEN+1] dest = void;
        char *destr = obj_mangle2(s, dest.ptr);
        syment_set_name(&sym, destr);

        sym.Value = 0;
        switch (s.Sclass)
        {
            case SCextern:
                sym.SectionNumber = IMAGE_SYM_UNDEFINED;
                break;

            default:
                sym.SectionNumber = SegData[s.Sseg].SDshtidx;
                break;
        }
        sym.Type = tyfunc(s.Stype.Tty) ? 0x20 : 0;
        switch (s.Sclass)
        {
            case SCstatic:
                if (s.Sflags & SFLhidden)
                    goto default;
                goto case;
            case SClocstat:
                sym.StorageClass = IMAGE_SYM_CLASS_STATIC;
                sym.Value = cast(uint)s.Soffset;
                break;

            default:
                sym.StorageClass = IMAGE_SYM_CLASS_EXTERNAL;
                if (sym.SectionNumber != IMAGE_SYM_UNDEFINED)
                    sym.Value = cast(uint)s.Soffset;
                break;
        }
        sym.NumberOfAuxSymbols = 0;

        write_sym(&sym, bigobj);
    }
}


/***************************
 * Fixup and terminate object file.
 */

@trusted
void MsCoffObj_termfile()
{
    //dbg_printf("MsCoffObj_termfile\n");
    if (configv.addlinenumbers)
    {
        cv8_termmodule();
    }
}

/*********************************
 * Terminate package.
 */

@trusted
void MsCoffObj_term(const(char)* objfilename)
{
    //printf("MsCoffObj_term()\n");
    assert(fobjbuf.length() == 0);
version (SCPP)
{
    if (!errcnt)
    {
        objflush_pointerRefs();
        outfixlist();           // backpatches
    }
}
else
{
    objflush_pointerRefs();
    outfixlist();           // backpatches
}

    if (configv.addlinenumbers)
    {
        cv8_termfile(objfilename);
    }

version (SCPP)
{
    if (errcnt)
        return;
}

    // To allow tooling support for most output files
    // switch to new object file format (similar to C++ with /bigobj)
    // only when exceeding the limit for 16-bit section count according to
    // https://msdn.microsoft.com/en-us/library/8578y171%28v=vs.71%29.aspx
    bool bigobj = scnhdr_cnt > 65_279;
    build_syment_table(bigobj);

    /* Write out the object file in the following order:
     *  Header
     *  Section Headers
     *  Symbol table
     *  String table
     *  Section data
     */

    uint foffset;

    // Write out the bytes for the header

    BIGOBJ_HEADER header = void;
    IMAGE_FILE_HEADER header_old = void;

    time_t f_timedat = 0;
    time(&f_timedat);
    uint symtable_offset;

    if (bigobj)
    {
        header.Sig1 = IMAGE_FILE_MACHINE_UNKNOWN;
        header.Sig2 = 0xFFFF;
        header.Version = 2;
        header.Machine = I64 ? IMAGE_FILE_MACHINE_AMD64 : IMAGE_FILE_MACHINE_I386;
        header.NumberOfSections = scnhdr_cnt;
        header.TimeDateStamp = cast(uint)f_timedat;
        static immutable ubyte[16] uuid =
                                  [ '\xc7', '\xa1', '\xba', '\xd1', '\xee', '\xba', '\xa9', '\x4b',
                                    '\xaf', '\x20', '\xfa', '\xf6', '\x6a', '\xa4', '\xdc', '\xb8' ];
        memcpy(header.UUID.ptr, uuid.ptr, 16);
        memset(header.unused.ptr, 0, (header.unused).sizeof);
        foffset = (header).sizeof;       // start after header
        foffset += ScnhdrBuf.length();   // section headers
        header.PointerToSymbolTable = foffset;      // offset to symbol table
        symtable_offset = foffset;
        header.NumberOfSymbols = cast(uint)(syment_buf.length() / (SymbolTable32).sizeof);
        foffset += header.NumberOfSymbols * (SymbolTable32).sizeof;  // symbol table
    }
    else
    {
        header_old.Machine = I64 ? IMAGE_FILE_MACHINE_AMD64 : IMAGE_FILE_MACHINE_I386;
        header_old.NumberOfSections = cast(ushort)scnhdr_cnt;
        header_old.TimeDateStamp = cast(uint)f_timedat;
        header_old.SizeOfOptionalHeader = 0;
        header_old.Characteristics = 0;
        foffset = (header_old).sizeof;   // start after header
        foffset += ScnhdrBuf.length();   // section headers
        header_old.PointerToSymbolTable = foffset;  // offset to symbol table
        symtable_offset = foffset;
        header_old.NumberOfSymbols = cast(uint)(syment_buf.length() / (SymbolTable).sizeof);
        foffset += header_old.NumberOfSymbols * (SymbolTable).sizeof;  // symbol table
    }

    uint string_table_offset = foffset;
    foffset += string_table.length();            // string table

    // Compute file offsets of all the section data

    for (segidx_t seg = 1; seg < SegData.length; seg++)
    {
        seg_data *pseg = SegData[seg];
        IMAGE_SECTION_HEADER *psechdr = &ScnhdrTab[pseg.SDshtidx];   // corresponding section

        int align_ = pseg.SDalignment;
        if (align_ > 1)
            foffset = (foffset + align_ - 1) & ~(align_ - 1);

        if (pseg.SDbuf && pseg.SDbuf.length())
        {
            psechdr.PointerToRawData = foffset;
            //printf("seg = %2d SDshtidx = %2d psechdr = %p s_scnptr = x%x\n", seg, pseg.SDshtidx, psechdr, cast(uint)psechdr.s_scnptr);
            psechdr.SizeOfRawData = cast(uint)pseg.SDbuf.length();
            foffset += psechdr.SizeOfRawData;
        }
        else
            psechdr.SizeOfRawData = cast(uint)pseg.SDoffset;
    }

    // Compute file offsets of the relocation data
    for (segidx_t seg = 1; seg < SegData.length; seg++)
    {
        seg_data *pseg = SegData[seg];
        IMAGE_SECTION_HEADER *psechdr = &ScnhdrTab[pseg.SDshtidx];   // corresponding section
        if (pseg.SDrel)
        {
            foffset = (foffset + 3) & ~3;
            assert(psechdr.PointerToRelocations == 0);
            auto nreloc = pseg.SDrel.length() / Relocation.sizeof;
            if (nreloc > 0xffff)
            {
                // https://docs.microsoft.com/en-us/windows/win32/debug/pe-format#coff-relocations-object-only
                psechdr.Characteristics |= IMAGE_SCN_LNK_NRELOC_OVFL;
                psechdr.PointerToRelocations = foffset;
                psechdr.NumberOfRelocations = 0xffff;
                foffset += reloc.sizeof;
            }
            else if (nreloc)
            {
                psechdr.PointerToRelocations = foffset;
                //printf("seg = %d SDshtidx = %d psechdr = %p s_relptr = x%x\n", seg, pseg.SDshtidx, psechdr, cast(uint)psechdr.s_relptr);
                psechdr.NumberOfRelocations = cast(ushort)nreloc;
            }
            foffset += nreloc * reloc.sizeof;
        }
    }

    assert(fobjbuf.length() == 0);

    // Write the header
    if (bigobj)
    {
        fobjbuf.write((&header)[0 .. 1]);
        foffset = (header).sizeof;
    }
    else
    {
        fobjbuf.write((&header_old)[0 .. 1]);
        foffset = (header_old).sizeof;
    }

    // Write the section headers
    fobjbuf.write((*ScnhdrBuf)[]);
    foffset += ScnhdrBuf.length();

    // Write the symbol table
    assert(foffset == symtable_offset);
    fobjbuf.write((*syment_buf)[]);
    foffset += syment_buf.length();

    // Write the string table
    assert(foffset == string_table_offset);
    *cast(uint *)(string_table.buf) = cast(uint)string_table.length();
    fobjbuf.write((*string_table)[]);
    foffset += string_table.length();

    // Write the section data
    for (segidx_t seg = 1; seg < SegData.length; seg++)
    {
        seg_data *pseg = SegData[seg];
        IMAGE_SECTION_HEADER *psechdr = &ScnhdrTab[pseg.SDshtidx];   // corresponding section
        foffset = elf_align(pseg.SDalignment, foffset);
        if (pseg.SDbuf && pseg.SDbuf.length())
        {
            //printf("seg = %2d SDshtidx = %2d psechdr = %p s_scnptr = x%x, foffset = x%x\n", seg, pseg.SDshtidx, psechdr, cast(uint)psechdr.s_scnptr, cast(uint)foffset);
            assert(pseg.SDbuf.length() == psechdr.SizeOfRawData);
            assert(foffset == psechdr.PointerToRawData);
            fobjbuf.write((*pseg.SDbuf)[]);
            foffset += pseg.SDbuf.length();
        }
    }

    // Compute the relocations, write them out
    assert((reloc).sizeof == 10);
    for (segidx_t seg = 1; seg < SegData.length; seg++)
    {
        seg_data *pseg = SegData[seg];
        IMAGE_SECTION_HEADER *psechdr = &ScnhdrTab[pseg.SDshtidx];   // corresponding section
        if (pseg.SDrel)
        {
            Relocation *r = cast(Relocation *)pseg.SDrel.buf;
            size_t sz = pseg.SDrel.length();
            bool pdata = (strcmp(cast(const(char)* )psechdr.Name, ".pdata") == 0);
            Relocation *rend = cast(Relocation *)(pseg.SDrel.buf + sz);
            foffset = elf_align(4, foffset);

            debug
            if (sz && foffset != psechdr.PointerToRelocations)
                printf("seg = %d SDshtidx = %d psechdr = %p s_relptr = x%x, foffset = x%x\n", seg, pseg.SDshtidx, psechdr, cast(uint)psechdr.PointerToRelocations, cast(uint)foffset);
            assert(sz == 0 || foffset == psechdr.PointerToRelocations);

            if (psechdr.Characteristics & IMAGE_SCN_LNK_NRELOC_OVFL)
            {
                auto rel = reloc(cast(uint)(sz / Relocation.sizeof) + 1);
                fobjbuf.write((&rel)[0 .. 1]);
                foffset += rel.sizeof;
            }
            for (; r != rend; r++)
            {   reloc rel;
                rel.r_vaddr = 0;
                rel.r_symndx = 0;
                rel.r_type = 0;

                Symbol *s = r.targsym;
                const(char)* rs = r.rtype == RELaddr ? "addr" : "rel";
                //printf("%d:x%04lx : tseg %d tsym %s REL%s\n", seg, cast(int)r.offset, r.targseg, s ? s.Sident.ptr : "0", rs);
                if (s)
                {
                    //printf("Relocation\n");
                    //symbol_print(s);
                    if (pseg.isCode())
                    {
                        if (I64)
                        {
                            rel.r_type = (r.rtype == RELrel)
                                    ? IMAGE_REL_AMD64_REL32
                                    : IMAGE_REL_AMD64_REL32;

                            if (s.Stype.Tty & mTYthread)
                                rel.r_type = IMAGE_REL_AMD64_SECREL;

                            if (r.val == -1)
                                rel.r_type = IMAGE_REL_AMD64_REL32_1;
                            else if (r.val == -2)
                                rel.r_type = IMAGE_REL_AMD64_REL32_2;
                            else if (r.val == -3)
                                rel.r_type = IMAGE_REL_AMD64_REL32_3;
                            else if (r.val == -4)
                                rel.r_type = IMAGE_REL_AMD64_REL32_4;
                            else if (r.val == -5)
                                rel.r_type = IMAGE_REL_AMD64_REL32_5;

                            /+if (s.Sclass == SCextern ||
                                s.Sclass == SCcomdef ||
                                s.Sclass == SCcomdat ||
                                s.Sclass == SCglobal)
                            {
                                rel.r_vaddr = cast(uint)r.offset;
                                rel.r_symndx = s.Sxtrnnum;
                            }
                            else+/
                            {
                                rel.r_vaddr = cast(uint)r.offset;
                                rel.r_symndx = s.Sxtrnnum;
                            }
                        }
                        else if (I32)
                        {
                            rel.r_type = (r.rtype == RELrel)
                                    ? IMAGE_REL_I386_REL32
                                    : IMAGE_REL_I386_DIR32;

                            if (s.Stype.Tty & mTYthread)
                                rel.r_type = IMAGE_REL_I386_SECREL;

                            /+if (s.Sclass == SCextern ||
                                s.Sclass == SCcomdef ||
                                s.Sclass == SCcomdat ||
                                s.Sclass == SCglobal)
                            {
                                rel.r_vaddr = cast(uint)r.offset;
                                rel.r_symndx = s.Sxtrnnum;
                            }
                            else+/
                            {
                                rel.r_vaddr = cast(uint)r.offset;
                                rel.r_symndx = s.Sxtrnnum;
                            }
                        }
                        else
                            assert(false); // not implemented for I16
                    }
                    else
                    {
                        if (I64)
                        {
                            if (pdata)
                                rel.r_type = IMAGE_REL_AMD64_ADDR32NB;
                            else
                                rel.r_type = IMAGE_REL_AMD64_ADDR64;

                            if (r.rtype == RELseg)
                                rel.r_type = IMAGE_REL_AMD64_SECTION;
                            else if (r.rtype == RELaddr32)
                                rel.r_type = IMAGE_REL_AMD64_SECREL;
                        }
                        else if (I32)
                        {
                            if (pdata)
                                rel.r_type = IMAGE_REL_I386_DIR32NB;
                            else
                                rel.r_type = IMAGE_REL_I386_DIR32;

                            if (r.rtype == RELseg)
                                rel.r_type = IMAGE_REL_I386_SECTION;
                            else if (r.rtype == RELaddr32)
                                rel.r_type = IMAGE_REL_I386_SECREL;
                        }
                        else
                            assert(false); // not implemented for I16

                        rel.r_vaddr = cast(uint)r.offset;
                        rel.r_symndx = s.Sxtrnnum;
                    }
                }
                else if (r.rtype == RELaddr && pseg.isCode())
                {
                    int32_t *p = null;
                    p = MsCoffObj_patchAddr(seg, r.offset);

                    rel.r_vaddr = cast(uint)r.offset;
                    rel.r_symndx = s ? s.Sxtrnnum : 0;

                    if (I64)
                    {
                        rel.r_type = IMAGE_REL_AMD64_REL32;
                        //srel.r_value = ScnhdrTab[SegData[r.targseg].SDshtidx].s_vaddr + *p;
                        //printf("SECTDIFF: x%llx + x%llx = x%x\n", ScnhdrTab[SegData[r.targseg].SDshtidx].s_vaddr, *p, srel.r_value);
                    }
                    else
                    {
                        rel.r_type = IMAGE_REL_I386_SECREL;
                        //srel.r_value = ScnhdrTab[SegData[r.targseg].SDshtidx].s_vaddr + *p;
                        //printf("SECTDIFF: x%x + x%x = x%x\n", ScnhdrTab[SegData[r.targseg].SDshtidx].s_vaddr, *p, srel.r_value);
                    }
                }
                else
                {
                    assert(0);
                }

                /* Some programs do generate a lot of symbols.
                 * Note that MS-Link can get pretty slow with large numbers of symbols.
                 */
                //assert(rel.r_symndx <= 20000);

                assert(rel.r_type <= 0x14);
                fobjbuf.write((&rel)[0 .. 1]);
                foffset += (rel).sizeof;
            }
        }
    }
}

/*****************************
 * Line number support.
 */

/***************************
 * Record file and line number at segment and offset.
 * Params:
 *      srcpos = source file position
 *      seg = segment it corresponds to
 *      offset = offset within seg
 */

@trusted
void MsCoffObj_linnum(Srcpos srcpos, int seg, targ_size_t offset)
{
    version (MARS)
    {
        if (srcpos.Slinnum == 0 || !srcpos.Sfilename)
            return;
    }
    else
    {
        if (srcpos.Slinnum == 0 || !srcpos.srcpos_name())
            return;
    }

    cv8_linnum(srcpos, cast(uint)offset);
}


/*******************************
 * Set start address
 */

void MsCoffObj_startaddress(Symbol *s)
{
    //dbg_printf("MsCoffObj_startaddress(Symbol *%s)\n",s.Sident.ptr);
    //obj.startaddress = s;
}

/*******************************
 * Output library name.
 */

@trusted
bool MsCoffObj_includelib(const(char)* name)
{
    int seg = MsCoffObj_seg_drectve();
    //dbg_printf("MsCoffObj_includelib(name *%s)\n",name);
    SegData[seg].SDbuf.write(" /DEFAULTLIB:\"".ptr, 14);
    SegData[seg].SDbuf.write(name, cast(uint)strlen(name));
    SegData[seg].SDbuf.writeByte('"');
    return true;
}

/*******************************
* Output linker directive name.
*/

@trusted
bool MsCoffObj_linkerdirective(const(char)* directive)
{
    int seg = MsCoffObj_seg_drectve();
    //dbg_printf("MsCoffObj::linkerdirective(directive *%s)\n",directive);
    SegData[seg].SDbuf.writeByte(' ');
    SegData[seg].SDbuf.write(directive, cast(uint)strlen(directive));
    return true;
}

/**********************************
 * Do we allow zero sized objects?
 */

bool MsCoffObj_allowZeroSize()
{
    return true;
}

/**************************
 * Embed string in executable.
 */

void MsCoffObj_exestr(const(char)* p)
{
    //dbg_printf("MsCoffObj_exestr(char *%s)\n",p);
}

/**************************
 * Embed string in obj.
 */

void MsCoffObj_user(const(char)* p)
{
    //dbg_printf("MsCoffObj_user(char *%s)\n",p);
}

/*******************************
 * Output a weak extern record.
 */

void MsCoffObj_wkext(Symbol *s1,Symbol *s2)
{
    //dbg_printf("MsCoffObj_wkext(Symbol *%s,Symbol *s2)\n",s1.Sident.ptr,s2.Sident.ptr);
}

/*******************************
 * Output file name record.
 *
 * Currently assumes that obj_filename will not be called
 *      twice for the same file.
 */

void MsCoffObj_filename(const(char)* modname)
{
    //dbg_printf("MsCoffObj_filename(char *%s)\n",modname);
    // Not supported by mscoff
}

/*******************************
 * Embed compiler version in .obj file.
 */

void MsCoffObj_compiler()
{
    //dbg_printf("MsCoffObj_compiler\n");
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

void MsCoffObj_staticctor(Symbol *s,int dtor,int none)
{
    MsCoffObj_setModuleCtorDtor(s, true);
}

/**************************************
 * Symbol is the function that calls the static destructors.
 * Put a pointer to it into a special segment that the exit code
 * looks at.
 * Input:
 *      s       static destructor function
 */

void MsCoffObj_staticdtor(Symbol *s)
{
    MsCoffObj_setModuleCtorDtor(s, false);
}


/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

@trusted
void MsCoffObj_setModuleCtorDtor(Symbol *sfunc, bool isCtor)
{
    // Also see https://blogs.msdn.microsoft.com/vcblog/2006/10/20/crt-initialization/
    // and http://www.codeguru.com/cpp/misc/misc/applicationcontrol/article.php/c6945/Running-Code-Before-and-After-Main.htm
    const int align_ = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;
    const int attr = IMAGE_SCN_CNT_INITIALIZED_DATA | align_ | IMAGE_SCN_MEM_READ;
    const int seg = MsCoffObj_getsegment(isCtor ? ".CRT$XCU" : ".CRT$XPU", attr);

    const int relflags = I64 ? CFoff | CFoffset64 : CFoff;
    const int sz = MsCoffObj_reftoident(seg, SegData[seg].SDoffset, sfunc, 0, relflags);
    SegData[seg].SDoffset += sz;
}


/***************************************
 * Stuff the following data (instance of struct FuncTable) in a separate segment:
 *      pointer to function
 *      pointer to ehsym
 *      length of function
 */

@trusted
void MsCoffObj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
{
    //printf("MsCoffObj_ehtables(func = %s, handler table = %s) \n",sfunc.Sident.ptr, ehsym.Sident.ptr);

    /* BUG: this should go into a COMDAT if sfunc is in a COMDAT
     * otherwise the duplicates aren't removed.
     */

    int align_ = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;  // align to _tysize[TYnptr]

    // The size is (FuncTable).sizeof in deh2.d
    const int seg =
    MsCoffObj_getsegment("._deh$B", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align_ |
                                      IMAGE_SCN_MEM_READ);

    Outbuffer *buf = SegData[seg].SDbuf;
    if (I64)
    {   MsCoffObj_reftoident(seg, buf.length(), sfunc, 0, CFoff | CFoffset64);
        MsCoffObj_reftoident(seg, buf.length(), ehsym, 0, CFoff | CFoffset64);
        buf.write64(sfunc.Ssize);
    }
    else
    {   MsCoffObj_reftoident(seg, buf.length(), sfunc, 0, CFoff);
        MsCoffObj_reftoident(seg, buf.length(), ehsym, 0, CFoff);
        buf.write32(cast(uint)sfunc.Ssize);
    }
}

/*********************************************
 * Put out symbols that define the beginning/end of the .deh_eh section.
 * This gets called if this is the module with "extern (D) main()" in it.
 */

@trusted
private void emitSectionBrace(const(char)* segname, const(char)* symname, int attr, bool coffZeroBytes)
{
    char[16] name = void;
    strcat(strcpy(name.ptr, segname), "$A");
    const int seg_bg = MsCoffObj_getsegment(name.ptr, attr);

    strcat(strcpy(name.ptr, segname), "$C");
    const int seg_en = MsCoffObj_getsegment(name.ptr, attr);

    /* Create symbol sym_beg that sits just before the .seg$B section
     */
    strcat(strcpy(name.ptr, symname), "_beg");
    Symbol *beg = symbol_name(name.ptr, SCglobal, tspvoid);
    beg.Sseg = seg_bg;
    beg.Soffset = 0;
    symbuf.write((&beg)[0 .. 1]);
    if (coffZeroBytes) // unnecessary, but required by current runtime
        MsCoffObj_bytes(seg_bg, 0, I64 ? 8 : 4, null);

    /* Create symbol sym_end that sits just after the .seg$B section
     */
    strcat(strcpy(name.ptr, symname), "_end");
    Symbol *end = symbol_name(name.ptr, SCglobal, tspvoid);
    end.Sseg = seg_en;
    end.Soffset = 0;
    symbuf.write((&end)[0 .. 1]);
    if (coffZeroBytes) // unnecessary, but required by current runtime
        MsCoffObj_bytes(seg_en, 0, I64 ? 8 : 4, null);
}

void MsCoffObj_ehsections()
{
    //printf("MsCoffObj_ehsections()\n");

    int align_ = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;
    int attr = IMAGE_SCN_CNT_INITIALIZED_DATA | align_ | IMAGE_SCN_MEM_READ;
    emitSectionBrace("._deh", "_deh", attr, true);
    emitSectionBrace(".minfo", "_minfo", attr, true);

    attr = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_ALIGN_4BYTES | IMAGE_SCN_MEM_READ;
    emitSectionBrace(".dp", "_DP", attr, false); // references to pointers in .data and .bss
    emitSectionBrace(".tp", "_TP", attr, false); // references to pointers in .tls

    attr = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_ALIGN_16BYTES | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE;
    emitSectionBrace(".data", "_data", attr, false);

    attr = IMAGE_SCN_CNT_UNINITIALIZED_DATA | IMAGE_SCN_ALIGN_16BYTES | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE;
    emitSectionBrace(".bss", "_bss", attr, false);

    /*************************************************************************/
static if (0)
{
  {
    /* TLS sections
     */
    int align_ = I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_4BYTES;

    int segbg =
    MsCoffObj_getsegment(".tls$AAA", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align_ |
                                      IMAGE_SCN_MEM_READ |
                                      IMAGE_SCN_MEM_WRITE);
    int segen =
    MsCoffObj_getsegment(".tls$AAC", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align_ |
                                      IMAGE_SCN_MEM_READ |
                                      IMAGE_SCN_MEM_WRITE);

    /* Create symbol _minfo_beg that sits just before the .tls$AAB section
     */
    Symbol *minfo_beg = symbol_name("_tlsstart", SCglobal, tspvoid);
    minfo_beg.Sseg = segbg;
    minfo_beg.Soffset = 0;
    symbuf.write((&minfo_beg)[0 .. 1]);
    MsCoffObj_bytes(segbg, 0, I64 ? 8 : 4, null);

    /* Create symbol _minfo_end that sits just after the .tls$AAB section
     */
    Symbol *minfo_end = symbol_name("_tlsend", SCglobal, tspvoid);
    minfo_end.Sseg = segen;
    minfo_end.Soffset = 0;
    symbuf.write((&minfo_end)[0 .. 1]);
    MsCoffObj_bytes(segen, 0, I64 ? 8 : 4, null);
  }
}
}

/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *      cseg            segment index of new current code segment
 *      Offset(cseg)         starting offset in cseg
 * Returns:
 *      "segment index" of COMDAT
 */

int MsCoffObj_comdatsize(Symbol *s, targ_size_t symsize)
{
    return MsCoffObj_comdat(s);
}

@trusted
int MsCoffObj_comdat(Symbol *s)
{
    uint align_;

    //printf("MsCoffObj_comdat(Symbol* %s)\n",s.Sident.ptr);
    //symbol_print(s);
    //symbol_debug(s);

    if (tyfunc(s.ty()))
    {
        align_ = I64 ? 16 : 4;
        s.Sseg = MsCoffObj_getsegment(".text", IMAGE_SCN_CNT_CODE |
                                           IMAGE_SCN_LNK_COMDAT |
                                           (I64 ? IMAGE_SCN_ALIGN_16BYTES : IMAGE_SCN_ALIGN_4BYTES) |
                                           IMAGE_SCN_MEM_EXECUTE |
                                           IMAGE_SCN_MEM_READ);
    }
    else if ((s.ty() & mTYLINK) == mTYthread)
    {
        s.Sfl = FLtlsdata;
        align_ = 16;
        s.Sseg = MsCoffObj_getsegment(".tls$AAB", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                            IMAGE_SCN_LNK_COMDAT |
                                            IMAGE_SCN_ALIGN_16BYTES |
                                            IMAGE_SCN_MEM_READ |
                                            IMAGE_SCN_MEM_WRITE);
        MsCoffObj_data_start(s, align_, s.Sseg);
    }
    else
    {
        s.Sfl = FLdata;
        align_ = 16;
        s.Sseg = MsCoffObj_getsegment(".data$B",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                                            IMAGE_SCN_LNK_COMDAT |
                                            IMAGE_SCN_ALIGN_16BYTES |
                                            IMAGE_SCN_MEM_READ |
                                            IMAGE_SCN_MEM_WRITE);
    }
                                // find or create new segment
    if (s.Salignment > align_)
    {   SegData[s.Sseg].SDalignment = s.Salignment;
        assert(s.Salignment >= -1);
    }
    s.Soffset = SegData[s.Sseg].SDoffset;
    if (s.Sfl == FLdata || s.Sfl == FLtlsdata)
    {   // Code symbols are 'published' by MsCoffObj_func_start()

        MsCoffObj_pubdef(s.Sseg,s,s.Soffset);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    return s.Sseg;
}

@trusted
int MsCoffObj_readonly_comdat(Symbol *s)
{
    //printf("MsCoffObj_readonly_comdat(Symbol* %s)\n",s.Sident.ptr);
    //symbol_print(s);
    symbol_debug(s);

    s.Sfl = FLdata;
    s.Sseg = MsCoffObj_getsegment(".rdata",  IMAGE_SCN_CNT_INITIALIZED_DATA |
                                        IMAGE_SCN_LNK_COMDAT |
                                        IMAGE_SCN_ALIGN_16BYTES |
                                        IMAGE_SCN_MEM_READ);

    SegData[s.Sseg].SDalignment = s.Salignment;
    assert(s.Salignment >= -1);
    s.Soffset = SegData[s.Sseg].SDoffset;
    if (s.Sfl == FLdata || s.Sfl == FLtlsdata)
    {   // Code symbols are 'published' by MsCoffObj_func_start()

        MsCoffObj_pubdef(s.Sseg,s,s.Soffset);
        searchfixlist(s);               // backpatch any refs to this symbol
    }
    return s.Sseg;
}


/***********************************
 * Returns:
 *      jump table segment for function s
 */
@trusted
int MsCoffObj_jmpTableSegment(Symbol *s)
{
    return (config.flags & CFGromable) ? cseg : DATA;
}


/**********************************
 * Get segment, which may already exist.
 * Input:
 *      flags2  put out some data for this, so the linker will keep things in order
 * Returns:
 *      segment index of found or newly created segment
 */

@trusted
segidx_t MsCoffObj_getsegment(const(char)* sectname, uint flags)
{
    //printf("getsegment(%s)\n", sectname);
    assert(strlen(sectname) <= 8);      // so it won't go into string_table
    if (!(flags & IMAGE_SCN_LNK_COMDAT))
    {
        for (segidx_t seg = 1; seg < SegData.length; seg++)
        {   seg_data *pseg = SegData[seg];
            if (!(ScnhdrTab[pseg.SDshtidx].Characteristics & IMAGE_SCN_LNK_COMDAT) &&
                strncmp(cast(const(char)* )ScnhdrTab[pseg.SDshtidx].Name, sectname, 8) == 0)
            {
                //printf("\t%s\n", sectname);
                return seg;         // return existing segment
            }
        }
    }

    segidx_t seg = MsCoffObj_getsegment2(MsCoffObj_addScnhdr(sectname, flags));

    //printf("\tSegData.length = %d\n", SegData.length);
    //printf("\tseg = %d, %d, %s\n", seg, SegData[seg].SDshtidx, ScnhdrTab[SegData[seg].SDshtidx].s_name);
    return seg;
}

/******************************************
 * Create a new segment corresponding to an existing scnhdr index shtidx
 */

@trusted
segidx_t MsCoffObj_getsegment2(IDXSEC shtidx)
{
    const segidx_t seg = cast(segidx_t)SegData.length;
    seg_data** ppseg = SegData.push();

    seg_data* pseg = *ppseg;
    if (pseg)
    {
        Outbuffer *b1 = pseg.SDbuf;
        Outbuffer *b2 = pseg.SDrel;
        memset(pseg, 0, (seg_data).sizeof);
        if (b1)
            b1.reset();
        else
        {
            b1 = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(b1);
            b1.reserve(4096);
        }
        if (b2)
            b2.reset();
        pseg.SDbuf = b1;
        pseg.SDrel = b2;
    }
    else
    {
        pseg = cast(seg_data *)mem_calloc((seg_data).sizeof);
        SegData[seg] = pseg;
        if (!(ScnhdrTab[shtidx].Characteristics & IMAGE_SCN_CNT_UNINITIALIZED_DATA))

        {
            pseg.SDbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
            assert(pseg.SDbuf);
            pseg.SDbuf.reserve(4096);
        }
    }

    //dbg_printf("\tNew segment - %d size %d\n", seg,SegData[seg].SDbuf);

    pseg.SDseg = seg;
    pseg.SDoffset = 0;

    pseg.SDshtidx = shtidx;
    pseg.SDaranges_offset = 0;
    pseg.SDlinnum_data.reset();

    //printf("SegData.length = %d\n", SegData.length);
    return seg;
}

/********************************************
 * Add new scnhdr.
 * Returns:
 *      scnhdr number for added scnhdr
 */

@trusted
IDXSEC MsCoffObj_addScnhdr(const(char)* scnhdr_name, uint flags)
{
    IMAGE_SECTION_HEADER sec;
    memset(&sec, 0, (sec).sizeof);
    size_t len = strlen(scnhdr_name);
    if (len > 8)
    {   // Use /nnnn form
        IDXSTR idx = MsCoffObj_addstr(string_table, scnhdr_name);
        sprintf(cast(char *)sec.Name, "/%d", idx);
    }
    else
        memcpy(sec.Name.ptr, scnhdr_name, len);
    sec.Characteristics = flags;
    ScnhdrBuf.write(cast(void *)&sec, (sec).sizeof);
    return ++scnhdr_cnt;
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

int MsCoffObj_codeseg(const char *name,int suffix)
{
    //dbg_printf("MsCoffObj_codeseg(%s,%x)\n",name,suffix);
    return 0;
}

/*********************************
 * Define segments for Thread Local Storage.
 * Output:
 *      seg_tlsseg      set to segment number for TLS segment.
 * Returns:
 *      segment for TLS segment
 */

@trusted
seg_data *MsCoffObj_tlsseg()
{
    //printf("MsCoffObj_tlsseg\n");

    if (seg_tlsseg == UNKNOWN)
    {
        seg_tlsseg = MsCoffObj_getsegment(".tls$AAB", IMAGE_SCN_CNT_INITIALIZED_DATA |
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

seg_data *MsCoffObj_tlsseg_bss()
{
    /* No thread local bss for MS-COFF
     */
    return MsCoffObj_tlsseg();
}

seg_data *MsCoffObj_tlsseg_data()
{
    // specific for Mach-O
    assert(0);
}

/*************************************
 * Return segment indices for .pdata and .xdata sections
 */

@trusted
segidx_t MsCoffObj_seg_pdata()
{
    if (segidx_pdata == UNKNOWN)
    {
        segidx_pdata = MsCoffObj_getsegment(".pdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ);
    }
    return segidx_pdata;
}

@trusted
segidx_t MsCoffObj_seg_xdata()
{
    if (segidx_xdata == UNKNOWN)
    {
        segidx_xdata = MsCoffObj_getsegment(".xdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ);
    }
    return segidx_xdata;
}

@trusted
segidx_t MsCoffObj_seg_pdata_comdat(Symbol *sfunc)
{
    segidx_t seg = MsCoffObj_getsegment(".pdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT);
    SegData[seg].SDassocseg = sfunc.Sseg;
    return seg;
}

@trusted
segidx_t MsCoffObj_seg_xdata_comdat(Symbol *sfunc)
{
    segidx_t seg = MsCoffObj_getsegment(".xdata", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_4BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT);
    SegData[seg].SDassocseg = sfunc.Sseg;
    return seg;
}

@trusted
segidx_t MsCoffObj_seg_debugS()
{
    if (segidx_debugS == UNKNOWN)
    {
        segidx_debugS = MsCoffObj_getsegment(".debug$S", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_MEM_DISCARDABLE);
    }
    return segidx_debugS;
}


@trusted
segidx_t MsCoffObj_seg_debugS_comdat(Symbol *sfunc)
{
    //printf("associated with seg %d\n", sfunc.Sseg);
    segidx_t seg = MsCoffObj_getsegment(".debug$S", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_LNK_COMDAT |
                                          IMAGE_SCN_MEM_DISCARDABLE);
    SegData[seg].SDassocseg = sfunc.Sseg;
    return seg;
}

segidx_t MsCoffObj_seg_debugT()
{
    segidx_t seg = MsCoffObj_getsegment(".debug$T", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_MEM_READ |
                                          IMAGE_SCN_MEM_DISCARDABLE);
    return seg;
}

@trusted
segidx_t MsCoffObj_seg_drectve()
{
    if (segidx_drectve == UNKNOWN)
    {
        segidx_drectve = MsCoffObj_getsegment(".drectve", IMAGE_SCN_LNK_INFO |
                                          IMAGE_SCN_ALIGN_1BYTES |
                                          IMAGE_SCN_LNK_REMOVE);        // linker commands
    }
    return segidx_drectve;
}


/*******************************
 * Output an alias definition record.
 */

void MsCoffObj_alias(const(char)* n1,const(char)* n2)
{
    //printf("MsCoffObj_alias(%s,%s)\n",n1,n2);
    assert(0);
static if (0) // NOT_DONE
{
    uint len;
    char *buffer;

    buffer = cast(char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
}
}

@trusted
private extern (D) char* unsstr(uint value)
{
    __gshared char[64] buffer;

    sprintf (buffer.ptr, "%d", value);
    return buffer.ptr;
}

/*******************************
 * Mangle a name.
 * Returns:
 *      mangled name
 */

@trusted
private extern (D)
char *obj_mangle2(Symbol *s,char *dest)
{
    size_t len;
    const(char)* name;

    //printf("MsCoffObj_mangle(s = %p, '%s'), mangle = x%x\n",s,s.Sident.ptr,type_mangle(s.Stype));
    symbol_debug(s);
    assert(dest);

version (SCPP)
    name = CPP ? cpp_mangle(s) : &s.Sident[0];
else version (MARS)
    // C++ name mangling is handled by front end
    name = &s.Sident[0];
else
    name = &s.Sident[0];

    len = strlen(name);                 // # of bytes in name
    //dbg_printf("len %d\n",len);
    switch (type_mangle(s.Stype))
    {
        case mTYman_pas:                // if upper case
        case mTYman_for:
            if (len >= DEST_LEN)
                dest = cast(char *)mem_malloc(len + 1);
            memcpy(dest,name,len + 1);  // copy in name and ending 0
            strupr(dest);               // to upper case
            break;
        case mTYman_std:
            if (!(config.flags4 & CFG4oldstdmangle) &&
                config.exe == EX_WIN32 && tyfunc(s.ty()) &&
                !variadic(s.Stype))
            {
                char *pstr = unsstr(type_paramsize(s.Stype));
                size_t pstrlen = strlen(pstr);
                size_t prelen = I32 ? 1 : 0;
                size_t destlen = prelen + len + 1 + pstrlen + 1;

                if (destlen > DEST_LEN)
                    dest = cast(char *)mem_malloc(destlen);
                dest[0] = '_';
                memcpy(dest + prelen,name,len);
                dest[prelen + len] = '@';
                memcpy(dest + prelen + 1 + len, pstr, pstrlen + 1);
                break;
            }
            goto case;

        case mTYman_cpp:
        case mTYman_sys:
        case_mTYman_c64:
        case 0:
            if (len >= DEST_LEN)
                dest = cast(char *)mem_malloc(len + 1);
            memcpy(dest,name,len+1);// copy in name and trailing 0
            break;

        case mTYman_c:
        case mTYman_d:
            if(I64)
                goto case_mTYman_c64;
            // Prepend _ to identifier
            if (len >= DEST_LEN - 1)
                dest = cast(char *)mem_malloc(1 + len + 1);
            dest[0] = '_';
            memcpy(dest + 1,name,len+1);// copy in name and trailing 0
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
    return dest;
}

/*******************************
 * Export a function name.
 */

@trusted
void MsCoffObj_export_symbol(Symbol *s,uint argsize)
{
    char[DEST_LEN+1] dest = void;
    char *destr = obj_mangle2(s, dest.ptr);

    int seg = MsCoffObj_seg_drectve();
    //printf("MsCoffObj_export_symbol(%s,%d)\n",s.Sident.ptr,argsize);
    SegData[seg].SDbuf.write(" /EXPORT:".ptr, 9);
    SegData[seg].SDbuf.write(dest.ptr, cast(uint)strlen(dest.ptr));
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

@trusted
segidx_t MsCoffObj_data_start(Symbol *sdata, targ_size_t datasize, segidx_t seg)
{
    targ_size_t alignbytes;

    //printf("MsCoffObj_data_start(%s,size %d,seg %d)\n",sdata.Sident.ptr,(int)datasize,seg);
    //symbol_print(sdata);

    assert(sdata.Sseg);
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
        MsCoffObj_lidata(seg, offset, alignbytes);
    sdata.Soffset = offset + alignbytes;
    return seg;
}

/*******************************
 * Update function info before codgen
 *
 * If code for this function is in a different segment
 * than the current default in cseg, switch cseg to new segment.
 */

@trusted
void MsCoffObj_func_start(Symbol *sfunc)
{
    //printf("MsCoffObj_func_start(%s)\n",sfunc.Sident.ptr);
    symbol_debug(sfunc);

    assert(sfunc.Sseg);
    if (sfunc.Sseg == UNKNOWN)
        sfunc.Sseg = CODE;
    //printf("sfunc.Sseg %d CODE %d cseg %d Coffset x%x\n",sfunc.Sseg,CODE,cseg,Offset(cseg));
    cseg = sfunc.Sseg;
    assert(cseg == CODE || cseg > UDATA);
    MsCoffObj_pubdef(cseg, sfunc, Offset(cseg));
    sfunc.Soffset = Offset(cseg);

    if (config.fulltypes)
        cv8_func_start(sfunc);
}

/*******************************
 * Update function info after codgen
 */

@trusted
void MsCoffObj_func_term(Symbol *sfunc)
{
    //dbg_printf("MsCoffObj_func_term(%s) offset %x, Coffset %x symidx %d\n",
//          sfunc.Sident.ptr, sfunc.Soffset,Offset(cseg),sfunc.Sxtrnnum);

    if (config.fulltypes)
        cv8_func_term(sfunc);
}

/********************************
 * Output a public definition.
 * Params:
 *      seg =           segment index that symbol is defined in
 *      s =             symbol
 *      offset =        offset of name within segment
 */

@trusted
void MsCoffObj_pubdef(segidx_t seg, Symbol *s, targ_size_t offset)
{
    //printf("MsCoffObj_pubdef(%d:x%x s=%p, %s)\n", seg, cast(int)offset, s, s.Sident.ptr);
    //symbol_print(s);

    symbol_debug(s);

    s.Soffset = offset;
    s.Sseg = seg;
    switch (s.Sclass)
    {
        case SCglobal:
        case SCinline:
            symbuf.write((&s)[0 .. 1]);
            break;
        case SCcomdat:
        case SCcomdef:
            symbuf.write((&s)[0 .. 1]);
            break;
        default:
            symbuf.write((&s)[0 .. 1]);
            break;
    }
    //printf("%p\n", *(void**)symbuf.buf);
    s.Sxtrnnum = 1;
}

void MsCoffObj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
{
    MsCoffObj_pubdef(seg, s, offset);
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

@trusted
int MsCoffObj_external_def(const(char)* name)
{
    //printf("MsCoffObj_external_def('%s')\n",name);
    assert(name);
    Symbol *s = symbol_name(name, SCextern, tspvoid);
    symbuf.write((&s)[0 .. 1]);
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

@trusted
int MsCoffObj_external(Symbol *s)
{
    //printf("MsCoffObj_external('%s') %x\n",s.Sident.ptr,s.Svalue);
    symbol_debug(s);
    symbuf.write((&s)[0 .. 1]);
    s.Sxtrnnum = 1;
    return 1;
}

/*******************************
 * Output a common block definition.
 * Params:
 *      s =     Symbol for common block
 *      size =  size in bytes of each elem
 *      count = number of elems
 * Returns:
 *      Symbol table index for symbol
 */

@trusted
int MsCoffObj_common_block(Symbol *s,targ_size_t size,targ_size_t count)
{
    //printf("MsCoffObj_common_block('%s', size=%d, count=%d)\n",s.Sident.ptr,size,count);
    symbol_debug(s);

    // can't have code or thread local comdef's
    assert(!(s.ty() & mTYthread));

    s.Sfl = FLudata;
    uint align_ = 16;
    s.Sseg = MsCoffObj_getsegment(".bss$B",  IMAGE_SCN_CNT_UNINITIALIZED_DATA |
                                        IMAGE_SCN_LNK_COMDAT |
                                        IMAGE_SCN_ALIGN_16BYTES |
                                        IMAGE_SCN_MEM_READ |
                                        IMAGE_SCN_MEM_WRITE);
    if (s.Salignment > align_)
    {
        SegData[s.Sseg].SDalignment = s.Salignment;
        assert(s.Salignment >= -1);
    }
    s.Soffset = SegData[s.Sseg].SDoffset;
    SegData[s.Sseg].SDsym = s;
    SegData[s.Sseg].SDoffset += count * size;

    MsCoffObj_pubdef(s.Sseg, s, s.Soffset);
    searchfixlist(s);               // backpatch any refs to this symbol

    return 1;           // should return void
}

int MsCoffObj_common_block(Symbol *s, int flag, targ_size_t size, targ_size_t count)
{
    return MsCoffObj_common_block(s, size, count);
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void MsCoffObj_write_zeros(seg_data *pseg, targ_size_t count)
{
    MsCoffObj_lidata(pseg.SDseg, pseg.SDoffset, count);
}

/***************************************
 * Output an iterated data block of 0s.
 *
 *      For boundary alignment and initialization
 */

@trusted
void MsCoffObj_lidata(segidx_t seg,targ_size_t offset,targ_size_t count)
{
    //printf("MsCoffObj_lidata(%d,%x,%d)\n",seg,offset,count);
    size_t idx = SegData[seg].SDshtidx;
    if ((ScnhdrTab[idx].Characteristics) & IMAGE_SCN_CNT_UNINITIALIZED_DATA)
    {   // Use SDoffset to record size of bss section
        SegData[seg].SDoffset += count;
    }
    else
    {
        MsCoffObj_bytes(seg, offset, cast(uint)count, null);
    }
}

/***********************************
 * Append byte to segment.
 */

void MsCoffObj_write_byte(seg_data *pseg, uint byte_)
{
    MsCoffObj_byte(pseg.SDseg, pseg.SDoffset, byte_);
}

/************************************
 * Output byte_ to object file.
 */

@trusted
void MsCoffObj_byte(segidx_t seg,targ_size_t offset,uint byte_)
{
    Outbuffer *buf = SegData[seg].SDbuf;
    int save = cast(int)buf.length();
    //dbg_printf("MsCoffObj_byte(seg=%d, offset=x%lx, byte=x%x)\n",seg,offset,byte_);
    buf.setsize(cast(uint)offset);
    buf.writeByte(byte_);
    if (save > offset+1)
        buf.setsize(save);
    else
        SegData[seg].SDoffset = offset+1;
    //dbg_printf("\tsize now %d\n",buf.length());
}

/***********************************
 * Append bytes to segment.
 */

void MsCoffObj_write_bytes(seg_data *pseg, uint nbytes, void *p)
{
    MsCoffObj_bytes(pseg.SDseg, pseg.SDoffset, nbytes, p);
}

/************************************
 * Output bytes to object file.
 * Returns:
 *      nbytes
 */

@trusted
uint MsCoffObj_bytes(segidx_t seg, targ_size_t offset, uint nbytes, void *p)
{
static if (0)
{
    if (!(seg >= 0 && seg < SegData.length))
    {   printf("MsCoffObj_bytes: seg = %d, SegData.length = %d\n", seg, SegData.length);
        *cast(char*)0=0;
    }
}
    assert(seg >= 0 && seg < SegData.length);
    Outbuffer *buf = SegData[seg].SDbuf;
    if (buf == null)
    {
        //printf("MsCoffObj_bytes(seg=%d, offset=x%llx, nbytes=%d, p=x%x)\n", seg, offset, nbytes, p);
        //raise(SIGSEGV);
        assert(buf != null);
    }
    int save = cast(int)buf.length();
    //dbg_printf("MsCoffObj_bytes(seg=%d, offset=x%lx, nbytes=%d, p=x%x)\n",
            //seg,offset,nbytes,p);
    buf.position(cast(size_t)offset, nbytes);
    if (p)
        buf.write(p, nbytes);
    else // Zero out the bytes
        buf.writezeros(nbytes);

    if (save > offset+nbytes)
        buf.setsize(save);
    else
        SegData[seg].SDoffset = offset+nbytes;
    return nbytes;
}

/*********************************************
 * Add a relocation entry for seg/offset.
 */

@trusted
void MsCoffObj_addrel(segidx_t seg, targ_size_t offset, Symbol *targsym,
        uint targseg, int rtype, int val)
{
    //printf("addrel()\n");
    if (!targsym)
    {   // Generate one
        targsym = symbol_generate(SCstatic, tstypes[TYint]);
        targsym.Sseg = targseg;
        targsym.Soffset = val;
        symbuf.write((&targsym)[0 .. 1]);
    }

    Relocation rel = void;
    rel.offset = offset;
    rel.targsym = targsym;
    rel.targseg = targseg;
    rel.rtype = cast(ubyte)rtype;
    rel.funcsym = funcsym_p;
    rel.val = cast(short)val;
    seg_data *pseg = SegData[seg];
    if (!pseg.SDrel)
    {
        pseg.SDrel = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(pseg.SDrel);
    }
    pseg.SDrel.write((&rel)[0 .. 1]);
}

/****************************************
 * Sort the relocation entry buffer.
 */

extern (C) {
@trusted
private int mscoff_rel_fp(scope const(void*) e1, scope const(void*) e2)
{   Relocation *r1 = cast(Relocation *)e1;
    Relocation *r2 = cast(Relocation *)e2;

    return cast(int)(r1.offset - r2.offset);
}
}

void mscoff_relsort(Outbuffer *buf)
{
    qsort(buf.buf, buf.length() / (Relocation).sizeof, (Relocation).sizeof, &mscoff_rel_fp);
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
 *              MsCoffObj_reftodatseg(DATA,offset,3 * (int *).sizeof,UDATA);
 */

@trusted
void MsCoffObj_reftodatseg(segidx_t seg,targ_size_t offset,targ_size_t val,
        uint targetdatum,int flags)
{
    Outbuffer *buf = SegData[seg].SDbuf;
    int save = cast(int)buf.length();
    buf.setsize(cast(uint)offset);
static if (0)
{
    printf("MsCoffObj_reftodatseg(seg:offset=%d:x%llx, val=x%llx, targetdatum %x, flags %x )\n",
        seg,offset,val,targetdatum,flags);
}
    assert(seg != 0);
    if (SegData[seg].isCode() && SegData[targetdatum].isCode())
    {
        assert(0);
    }
    MsCoffObj_addrel(seg, offset, null, targetdatum, RELaddr, 0);
    if (I64)
    {
        if (flags & CFoffset64)
        {
            buf.write64(val);
            if (save > offset + 8)
                buf.setsize(save);
            return;
        }
    }
    buf.write32(cast(int)val);
    if (save > offset + 4)
        buf.setsize(save);
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

@trusted
void MsCoffObj_reftocodeseg(segidx_t seg,targ_size_t offset,targ_size_t val)
{
    //printf("MsCoffObj_reftocodeseg(seg=%d, offset=x%lx, val=x%lx )\n",seg,cast(uint)offset,cast(uint)val);
    assert(seg > 0);
    Outbuffer *buf = SegData[seg].SDbuf;
    int save = cast(int)buf.length();
    buf.setsize(cast(uint)offset);
    val -= funcsym_p.Soffset;
    if (I32)
        MsCoffObj_addrel(seg, offset, funcsym_p, 0, RELaddr, 0);
//    MsCoffObj_addrel(seg, offset, funcsym_p, 0, RELaddr);
//    if (I64)
//        buf.write64(val);
//    else
        buf.write32(cast(int)val);
    if (save > offset + 4)
        buf.setsize(save);
}

/*******************************
 * Refer to an identifier.
 * Params:
 *      seg =   where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      s =             Symbol table entry for identifier
 *      val =           displacement from identifier
 *      flags =         CFselfrel: self-relative
 *                      CFseg: get segment
 *                      CFoff: get offset
 *                      CFpc32: [RIP] addressing, val is 0, -1, -2 or -4
 *                      CFoffset64: 8 byte offset for 64 bit builds
 * Returns:
 *      number of bytes in reference (4 or 8)
 */

@trusted
int MsCoffObj_reftoident(segidx_t seg, targ_size_t offset, Symbol *s, targ_size_t val,
        int flags)
{
    int refsize = (flags & CFoffset64) ? 8 : 4;
    if (flags & CFseg)
        refsize += 2;
static if (0)
{
    printf("\nMsCoffObj_reftoident('%s' seg %d, offset x%llx, val x%llx, flags x%x)\n",
        s.Sident.ptr,seg,cast(ulong)offset,cast(ulong)val,flags);
    //printf("refsize = %d\n", refsize);
    //dbg_printf("Sseg = %d, Sxtrnnum = %d\n",s.Sseg,s.Sxtrnnum);
    //symbol_print(s);
}
    assert(seg > 0);
    if (s.Sclass != SClocstat && !s.Sxtrnnum)
    {   // It may get defined later as public or local, so defer
        size_t numbyteswritten = addtofixlist(s, offset, seg, val, flags);
        assert(numbyteswritten == refsize);
    }
    else
    {
        if (I64 || I32)
        {
            //if (s.Sclass != SCcomdat)
                //val += s.Soffset;
            int v = 0;
            if (flags & CFpc32)
            {
                v = -((flags & CFREL) >> 24);
                assert(v >= -5 && v <= 0);
            }
            if (flags & CFselfrel)
            {
                MsCoffObj_addrel(seg, offset, s, 0, RELrel, v);
            }
            else if ((flags & (CFseg | CFoff)) == (CFseg | CFoff))
            {
                MsCoffObj_addrel(seg, offset,     s, 0, RELaddr32, v);
                MsCoffObj_addrel(seg, offset + 4, s, 0, RELseg, v);
                refsize = 6;    // 4 bytes for offset, 2 for section
            }
            else
            {
                MsCoffObj_addrel(seg, offset, s, 0, RELaddr, v);
            }
        }
        else
        {
            if (SegData[seg].isCode() && flags & CFselfrel)
            {
                seg_data *pseg = SegData[jumpTableSeg];
                val -= offset + 4;
                MsCoffObj_addrel(seg, offset, null, jumpTableSeg, RELrel, 0);
            }
            else if (SegData[seg].isCode() &&
                    ((s.Sclass != SCextern && SegData[s.Sseg].isCode()) || s.Sclass == SClocstat || s.Sclass == SCstatic))
            {
                val += s.Soffset;
                MsCoffObj_addrel(seg, offset, null, s.Sseg, RELaddr, 0);
            }
            else if (SegData[seg].isCode() && !tyfunc(s.ty()))
            {
                seg_data *pseg = SegData[pointersSeg];

                if (!indirectsymbuf2)
                {
                    indirectsymbuf2 = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
                    assert(indirectsymbuf2);
                }
                else
                {   // Look through indirectsym to see if it is already there
                    int n = cast(int)(indirectsymbuf2.length() / (Symbol *).sizeof);
                    Symbol **psym = cast(Symbol **)indirectsymbuf2.buf;
                    for (int i = 0; i < n; i++)
                    {   // Linear search, pretty pathetic
                        if (s == psym[i])
                        {   val = i * 4;
                            goto L2;
                        }
                    }
                }

                val = pseg.SDbuf.length();
                pseg.SDbuf.writezeros(_tysize[TYnptr]);

                // Add symbol s to indirectsymbuf2
                indirectsymbuf2.write((&s)[0 .. 1]);

             L2:
                //printf("MsCoffObj_reftoident: seg = %d, offset = x%x, s = %s, val = x%x, pointersSeg = %d\n", seg, offset, s.Sident.ptr, val, pointersSeg);
                MsCoffObj_addrel(seg, offset, null, pointersSeg, RELaddr, 0);
            }
            else
            {   //val -= s.Soffset;
//                MsCoffObj_addrel(seg, offset, s, 0, RELaddr, 0);
            }
        }

        Outbuffer *buf = SegData[seg].SDbuf;
        int save = cast(int)buf.length();
        buf.setsize(cast(uint)offset);
        //printf("offset = x%llx, val = x%llx\n", offset, val);
        if (refsize == 8)
            buf.write64(val);
        else if (refsize == 4)
            buf.write32(cast(int)val);
        else if (refsize == 6)
        {
            buf.write32(cast(int)val);
            buf.write16(0);
        }
        else
            assert(0);
        if (save > offset + refsize)
            buf.setsize(save);
    }
    return refsize;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *      s       Symbol to generate a thunk for
 */

void MsCoffObj_far16thunk(Symbol *s)
{
    //dbg_printf("MsCoffObj_far16thunk('%s')\n", s.Sident.ptr);
    assert(0);
}

/**************************************
 * Mark object file as using floating point.
 */

@trusted
void MsCoffObj_fltused()
{
    //dbg_printf("MsCoffObj_fltused()\n");
    /* Otherwise, we'll get the dreaded
     *    "runtime error R6002 - floating point support not loaded"
     */
    if (!floatused)
    {
        MsCoffObj_external_def("_fltused");
        floatused = 1;
    }
}


@trusted
int elf_align(int size, int foffset)
{
    if (size <= 1)
        return foffset;
    int offset = (foffset + size - 1) & ~(size - 1);
    //printf("offset = x%lx, foffset = x%lx, size = x%lx\n", offset, foffset, (int)size);
    if (offset > foffset)
        fobjbuf.writezeros(offset - foffset);
    return offset;
}

/***************************************
 * Stuff pointer to ModuleInfo in its own segment.
 * Input:
 *      scc     symbol for ModuleInfo
 */

version (MARS)
{

@trusted
void MsCoffObj_moduleinfo(Symbol *scc)
{
    int align_ = I64 ? IMAGE_SCN_ALIGN_8BYTES : IMAGE_SCN_ALIGN_4BYTES;

    /* Module info sections
     */
    const int seg =
    MsCoffObj_getsegment(".minfo$B", IMAGE_SCN_CNT_INITIALIZED_DATA |
                                      align_ |
                                      IMAGE_SCN_MEM_READ);
    //printf("MsCoffObj_moduleinfo(%s) seg = %d:x%x\n", scc.Sident.ptr, seg, Offset(seg));

    int flags = CFoff;
    if (I64)
        flags |= CFoffset64;
    SegData[seg].SDoffset += MsCoffObj_reftoident(seg, Offset(seg), scc, 0, flags);
}

}

/**********************************
 * Reset code seg to existing seg.
 * Used after a COMDAT for a function is done.
 */

@trusted
void MsCoffObj_setcodeseg(int seg)
{
    assert(0 < seg && seg < SegData.length);
    cseg = seg;
}

Symbol *MsCoffObj_tlv_bootstrap()
{
    // specific for Mach-O
    assert(0);
}

/*****************************************
 * write a reference to a mutable pointer into the object file
 * Params:
 *      s    = symbol that contains the pointer
 *      soff = offset of the pointer inside the Symbol's memory
 */
@trusted
void MsCoffObj_write_pointerRef(Symbol* s, uint soff)
{
    if (!ptrref_buf)
    {
        ptrref_buf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(ptrref_buf);
    }

    // defer writing pointer references until the symbols are written out
    ptrref_buf.write((&s)[0 .. 1]);
    ptrref_buf.write32(soff);
}

/*****************************************
 * flush a single pointer reference saved by write_pointerRef
 * to the object file
 * Params:
 *      s    = symbol that contains the pointer
 *      soff = offset of the pointer inside the Symbol's memory
 */
@trusted
extern (D) private void objflush_pointerRef(Symbol* s, uint soff)
{
    bool isTls = (s.Sfl == FLtlsdata);
    const(char)* segname = isTls ? ".tp$B" : ".dp$B";
    int attr = IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_ALIGN_4BYTES | IMAGE_SCN_MEM_READ;
    int seg = MsCoffObj_getsegment(segname, attr);

    targ_size_t offset = SegData[seg].SDoffset;
    MsCoffObj_addrel(seg, offset, s, cast(uint)offset, RELaddr32, 0);
    Outbuffer* buf = SegData[seg].SDbuf;
    buf.setsize(cast(uint)offset);
    buf.write32(soff);
    SegData[seg].SDoffset = buf.length();
}

/*****************************************
 * flush all pointer references saved by write_pointerRef
 * to the object file
 */
@trusted
extern (D) private void objflush_pointerRefs()
{
    if (!ptrref_buf)
        return;

    ubyte *p = ptrref_buf.buf;
    ubyte *end = ptrref_buf.buf + ptrref_buf.length();
    while (p < end)
    {
        Symbol* s = *cast(Symbol**)p;
        p += s.sizeof;
        uint soff = *cast(uint*)p;
        p += soff.sizeof;
        objflush_pointerRef(s, soff);
    }
    ptrref_buf.reset();
}

}
