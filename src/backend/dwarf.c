
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gpl.txt.
// See the included readme.txt for details.

// Emit Dwarf symbolic debug info

#if !SPP
#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <sys/types.h>
#include        <sys/stat.h>
#include        <fcntl.h>
#include        <ctype.h>

#if __DMC__ || linux
#include        <malloc.h>
#endif

#if linux || __APPLE__ || __FreeBSD__ || __sun&&__SVR4
#include        <signal.h>
#include        <unistd.h>
#include        <errno.h>
#endif

#include        "cc.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"
#include        "outbuf.h"
#include        "filespec.h"
#include        "cv4.h"
#include        "cgcv.h"
#include        "dt.h"

#include        "aa.h"
#include        "tinfo.h"

#if ELFOBJ
#include        "melf.h"
#endif
#if MACHOBJ
#include        "mach.h"
#endif

#if ELFOBJ || MACHOBJ

#if MARS
#include        "mars.h"
#endif

#include        "dwarf.h"
#include        "dwarf2.h"

extern int seg_count;

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"

#if ELFOBJ
#define MAP_SEG2SYMIDX(seg) (SegData[seg]->SDsymidx)
#else
#define MAP_SEG2SYMIDX(seg) (assert(0))
#endif

int dwarf_getsegment(const char *name, int align)
{
#if ELFOBJ
    return elf_getsegment(name, NULL, SHT_PROGDEF, 0, align * 4);
#elif MACHOBJ
    return mach_getsegment(name, "__DWARF", align * 2, S_REGULAR);
#else
    assert(0);
    return 0;
#endif
}

void dwarf_addrel(int seg, targ_size_t offset, int targseg)
{
#if ELFOBJ
    elf_addrel(seg, offset, RI_TYPE_SYM32, MAP_SEG2SYMIDX(targseg),0);
#elif MACHOBJ
    mach_addrel(seg, offset, NULL, targseg, 0);
#else
    assert(0);
#endif
}

/************************  DWARF DEBUG OUTPUT ********************************/

// Dwarf Symbolic Debugging Information

struct CFA_reg
{
    int offset;                 // offset from CFA
};

// Current CFA state for .debug_frame
struct CFA_state
{
    size_t location;
    int reg;                    // CFA register number
    int offset;                 // CFA register offset
    CFA_reg regstates[9];       // register states
};

static CFA_state CFA_state_init =       // initial CFA state as defined by CIE
{   0,          // location
    SP,         // register
    4,          // offset
    {   { 0 },  // 0: EAX
        { 0 },  // 1: ECX
        { 0 },  // 2: EDX
        { 0 },  // 3: EBX
        { 0 },  // 4: ESP
        { 0 },  // 5: EBP
        { 0 },  // 6: ESI
        { 0 },  // 7: EDI
        { -4 }, // 8: EIP
    }
};
static CFA_state CFA_state_current;     // current CFA state
static Outbuffer cfa_buf;               // CFA instructions

void dwarf_CFA_set_loc(size_t location)
{
    assert(location >= CFA_state_current.location);
    size_t inc = location - CFA_state_current.location;
    if (inc <= 63)
        cfa_buf.writeByte(DW_CFA_advance_loc + inc);
    else if (inc <= 255)
    {   cfa_buf.writeByte(DW_CFA_advance_loc1);
        cfa_buf.writeByte(inc);
    }
    else if (inc <= 0xFFFF)
    {   cfa_buf.writeByte(DW_CFA_advance_loc2);
        cfa_buf.writeWord(inc);
    }
    else
    {   cfa_buf.writeByte(DW_CFA_advance_loc4);
        cfa_buf.write32(inc);
    }
    CFA_state_current.location = location;
}

void dwarf_CFA_set_reg_offset(int reg, int offset)
{
    if (reg != CFA_state_current.reg)
    {
        if (offset == CFA_state_current.offset)
        {
            cfa_buf.writeByte(DW_CFA_def_cfa_register);
            cfa_buf.writeuLEB128(reg);
        }
        else if (offset < 0)
        {
            cfa_buf.writeByte(DW_CFA_def_cfa_sf);
            cfa_buf.writeuLEB128(reg);
            cfa_buf.writesLEB128(offset / -4);
        }
        else
        {
            cfa_buf.writeByte(DW_CFA_def_cfa);
            cfa_buf.writeuLEB128(reg);
            cfa_buf.writeuLEB128(offset);
        }
    }
    else if (offset < 0)
    {
        cfa_buf.writeByte(DW_CFA_def_cfa_offset_sf);
        cfa_buf.writesLEB128(offset / -4);
    }
    else
    {
        cfa_buf.writeByte(DW_CFA_def_cfa_offset);
        cfa_buf.writeuLEB128(offset);
    }
    CFA_state_current.reg = reg;
    CFA_state_current.offset = offset;
}

void dwarf_CFA_offset(int reg, int offset)
{
    if (CFA_state_current.regstates[reg].offset != offset)
    {
        if (offset <= 0)
        {
            cfa_buf.writeByte(DW_CFA_offset + reg);
            cfa_buf.writeuLEB128(offset / -4);
        }
        else
        {
            cfa_buf.writeByte(DW_CFA_offset_extended_sf);
            cfa_buf.writeuLEB128(reg);
            cfa_buf.writesLEB128(offset / -4);
        }
    }
    CFA_state_current.regstates[reg].offset = offset;
}

void dwarf_CFA_args_size(size_t sz)
{
    cfa_buf.writeByte(DW_CFA_GNU_args_size);
    cfa_buf.writeuLEB128(sz);
}

// .debug_frame
static IDXSEC debug_frame_secidx;

// .debug_str
static IDXSEC debug_str_secidx;
static Outbuffer *debug_str_buf;

// .debug_pubnames
static IDXSEC debug_pubnames_secidx;
static Outbuffer *debug_pubnames_buf;

// .debug_aranges
static IDXSEC debug_aranges_seg;
static IDXSEC debug_aranges_secidx;
static Outbuffer *debug_aranges_buf;

// .debug_ranges
static IDXSEC debug_ranges_seg;
static IDXSEC debug_ranges_secidx;
static Outbuffer *debug_ranges_buf;

// .debug_loc
static IDXSEC debug_loc_seg;
static IDXSEC debug_loc_secidx;
static Outbuffer *debug_loc_buf;

// .debug_abbrev
static IDXSEC abbrevseg;
static Outbuffer *abbrevbuf;

/* DWARF 7.5.3: "Each declaration begins with an unsigned LEB128 number
 * representing the abbreviation code itself."
 */
static unsigned abbrevcode = 1;
static AArray *abbrev_table;
static int hasModname;    // 1 if has DW_TAG_module

// .debug_info
static IDXSEC infoseg;
static Outbuffer *infobuf;

static AArray *type_table;

#pragma pack(1)
struct DebugInfoHeader
{   unsigned total_length;
    unsigned short version;
    unsigned abbrev_offset;
    unsigned char address_size;
};
#pragma pack()

static DebugInfoHeader debuginfo_init =
{       0,      // total_length
        2,      // version
        0,      // abbrev_offset
        4       // address_size
};

static DebugInfoHeader debuginfo;

// .debug_line
static IDXSEC lineseg;
static Outbuffer *linebuf;

#pragma pack(1)
struct DebugLineHeader
{   unsigned total_length;
    unsigned short version;
    unsigned prologue_length;
    unsigned char minimum_instruction_length;
    unsigned char default_is_stmt;
    signed char line_base;
    unsigned char line_range;
    unsigned char opcode_base;
    unsigned char standard_opcode_lengths[9];
};
#pragma pack()

static DebugLineHeader debugline_init =
{       0,      // total_length
        2,      // version
        0,      // prologue_length
        1,      // minimum_instruction_length
        TRUE,   // default_is_stmt
        -5,     // line_base
        14,     // line_range
        10,     // opcode_base
        { 0,1,1,1,1,0,0,0,1 }
};

static DebugLineHeader debugline;

unsigned typidx_tab[TYMAX];


void dwarf_initfile(const char *filename)
{
    // Set debug_frame_secidx
    Outbuffer *debug_frame_buf;
    int seg;

    #pragma pack(1)
    struct DebugFrameHeader
    {
        unsigned length;
        unsigned CIE_id;
        unsigned char version;
        unsigned char augmentation;
        unsigned char code_alignment_factor;
        unsigned char data_alignment_factor;
        unsigned char return_address_register;
        unsigned char opcodes[7];
    };
    #pragma pack()
    static DebugFrameHeader debugFrameHeader =
    {   16,             // length
        0xFFFFFFFF,     // CIE_id
        1,              // version
        0,              // augmentation
        1,              // code alignment factor
        0x7C,           // data alignment factor (-4)
        8,              // return address register
      {
        DW_CFA_def_cfa, 4,4,    // r4,4
        DW_CFA_offset   +8,1,   // r8,1
        DW_CFA_nop,
        DW_CFA_nop,
      }
    };

    seg = dwarf_getsegment(".debug_frame", 1);
    debug_frame_secidx = SegData[seg]->SDshtidx;
    debug_frame_buf = SegData[seg]->SDbuf;
    debug_frame_buf->reserve(1000);
    debug_frame_buf->writen(&debugFrameHeader,sizeof(debugFrameHeader));

    /* ======================================== */

    seg = dwarf_getsegment(".debug_str", 0);
    debug_str_secidx = SegData[seg]->SDshtidx;
    debug_str_buf = SegData[seg]->SDbuf;
    debug_str_buf->reserve(1000);

    /* ======================================== */

    debug_ranges_seg = dwarf_getsegment(".debug_ranges", 0);
    debug_ranges_secidx = SegData[debug_ranges_seg]->SDshtidx;
    debug_ranges_buf = SegData[debug_ranges_seg]->SDbuf;
    debug_ranges_buf->reserve(1000);

    /* ======================================== */

    debug_loc_seg = dwarf_getsegment(".debug_loc", 0);
    debug_loc_secidx = SegData[debug_loc_seg]->SDshtidx;
    debug_loc_buf = SegData[debug_loc_seg]->SDbuf;
    debug_loc_buf->reserve(1000);

    /* ======================================== */

    lineseg = dwarf_getsegment(".debug_line", 0);
    linebuf = SegData[lineseg]->SDbuf;

    debugline = debugline_init;

    linebuf->write(&debugline, sizeof(debugline));

    // include_directories
#if SCPP
    list_t pl;
    for (pl = pathlist; pl; pl = list_next(pl))
    {
        linebuf->writeString((char *)list_ptr(pl));
        linebuf->writeByte(0);
    }
#if linux || __APPLE__ || __FreeBSD__ || __sun&&__SVR4
    for (pl = pathsyslist; pl; pl = list_next(pl))
    {
        linebuf->writeString((char *)list_ptr(pl));
        linebuf->writeByte(0);
    }
#endif
#endif
#if 0 && MARS
    for (int i = 0; i < global.params.imppath->dim; i++)
    {
        linebuf->writeString((char *)global.params.imppath->data[i]);
        linebuf->writeByte(0);
    }
#endif
    linebuf->writeByte(0);              // terminated with 0 byte

    /* ======================================== */

    abbrevseg = dwarf_getsegment(".debug_abbrev", 0);
    abbrevbuf = SegData[abbrevseg]->SDbuf;
    abbrevcode = 1;

    // Free only if starting another file. Waste of time otherwise.
    if (abbrev_table)
    {   delete abbrev_table;
        abbrev_table = NULL;
    }

    static unsigned char abbrevHeader[] =
    {
        1,                      // abbreviation code
        DW_TAG_compile_unit,
        1,
        DW_AT_producer,  DW_FORM_string,
        DW_AT_language,  DW_FORM_data1,
        DW_AT_name,      DW_FORM_string,
        DW_AT_comp_dir,  DW_FORM_string,
        DW_AT_low_pc,    DW_FORM_addr,
        DW_AT_entry_pc,  DW_FORM_addr,
        DW_AT_ranges,    DW_FORM_data4,
        DW_AT_stmt_list, DW_FORM_data4,
        0,               0,
    };

    abbrevbuf->write(abbrevHeader,sizeof(abbrevHeader));

    /* ======================================== */

    infoseg = dwarf_getsegment(".debug_info", 0);
    infobuf = SegData[infoseg]->SDbuf;

    debuginfo = debuginfo_init;

    infobuf->write(&debuginfo, sizeof(debuginfo));
    dwarf_addrel(infoseg,6,abbrevseg);

    infobuf->writeuLEB128(1);                   // abbreviation code
#if MARS
    infobuf->write("Digital Mars D ");
    infobuf->writeString(global.version);       // DW_AT_producer
    // DW_AT_language
    infobuf->writeByte((config.fulltypes == CVDWARF_D) ? DW_LANG_D : DW_LANG_C89);
#elif SCPP
    infobuf->write("Digital Mars C ");
    infobuf->writeString(global.version);       // DW_AT_producer
    infobuf->writeByte(DW_LANG_C89);            // DW_AT_language
#else
    assert(0);
#endif
    infobuf->writeString(filename);             // DW_AT_name
#if 0
    // This relies on an extension to POSIX.1 not always implemented
    char *cwd = getcwd(NULL, 0);
#else
    char *cwd;
    size_t sz = 80;
    while (1)
    {
        errno = 0;
        cwd = (char *)malloc(sz + 1);
        if (!cwd)
            err_nomem();
        char *buf = getcwd(cwd, sz);
        if (buf)
        {   cwd[sz] = 0;        // man page doesn't say if always 0 terminated
            break;
        }
        if (errno == ERANGE)
        {
            sz += 80;
            free(cwd);
            continue;
        }
        cwd[0] = 0;
        break;
    }
#endif
    //infobuf->write32(elf_addstr(debug_str_buf, cwd)); // DW_AT_comp_dir as DW_FORM_strp, doesn't work on some systems
    infobuf->writeString(cwd);                  // DW_AT_comp_dir as DW_FORM_string
    free(cwd);

    infobuf->write32(0);                        // DW_AT_low_pc
    infobuf->write32(0);                        // DW_AT_entry_pc

    dwarf_addrel(infoseg,infobuf->size(),debug_ranges_seg);
    infobuf->write32(0);                        // DW_AT_ranges

    dwarf_addrel(infoseg,infobuf->size(),lineseg);
    infobuf->write32(0);                        // DW_AT_stmt_list

    memset(typidx_tab, 0, sizeof(typidx_tab));

    /* ======================================== */

    seg = dwarf_getsegment(".debug_pubnames", 0);
    debug_pubnames_secidx = SegData[seg]->SDshtidx;
    debug_pubnames_buf = SegData[seg]->SDbuf;
    debug_pubnames_buf->reserve(1000);

    debug_pubnames_buf->write32(0);             // unit_length
    debug_pubnames_buf->writeWord(2);           // version
    dwarf_addrel(seg,debug_pubnames_buf->size(),lineseg);
    debug_pubnames_buf->write32(0);             // debug_info_offset
    debug_pubnames_buf->write32(0);             // debug_info_length

    /* ======================================== */

    debug_aranges_seg = dwarf_getsegment(".debug_aranges", 0);
    debug_aranges_secidx = SegData[debug_aranges_seg]->SDshtidx;
    debug_aranges_buf = SegData[debug_aranges_seg]->SDbuf;
    debug_aranges_buf->reserve(1000);

    debug_aranges_buf->write32(0);              // unit_length
    debug_aranges_buf->writeWord(2);            // version
    dwarf_addrel(debug_aranges_seg,debug_aranges_buf->size(),infoseg);
    debug_aranges_buf->write32(0);              // debug_info_offset
    debug_aranges_buf->writeByte(4);            // address_size
    debug_aranges_buf->writeByte(0);            // segment_size
    debug_aranges_buf->write32(0);              // pad to 16
}

void dwarf_initmodule(const char *filename, const char *modname)
{
    if (modname)
    {
        static unsigned char abbrevModule[] =
        {
            DW_TAG_module,
            //1,                // one children
            0,                  // no children
            DW_AT_name,         DW_FORM_string, // module name
            0,                  0,
        };
        abbrevcode++;
        abbrevbuf->writeuLEB128(abbrevcode);
        abbrevbuf->write(abbrevModule,sizeof(abbrevModule));
        infobuf->writeuLEB128(abbrevcode);      // abbreviation code
        infobuf->writeString(modname);          // DW_AT_name
        //hasModname = 1;
    }
    else
        hasModname = 0;
}

void dwarf_termmodule()
{
    if (hasModname)
        infobuf->writeByte(0);  // end of DW_TAG_module's children
}

/*************************************
 * Finish writing Dwarf debug info to object file.
 */

void dwarf_termfile()
{
    //printf("dwarf_termfile()\n");

    /* ======================================== */

    // Put out line number info

    // file_names
    unsigned filenumber = 0;
    for (unsigned seg = 1; seg <= seg_count; seg++)
    {
        for (unsigned i = 0; i < SegData[seg]->SDlinnum_count; i++)
        {
            linnum_data *ld = &SegData[seg]->SDlinnum_data[i];
            char *filename;
#if MARS
            filename = ld->filename;
#else
            Sfile *sf = ld->filptr;
            if (sf)
                filename = sf->SFname;
            else
                filename = ::filename;
#endif
            /* Look to see if filename has already been output
             */
            for (unsigned s = 1; s < seg; s++)
            {
                for (unsigned j = 0; j < SegData[s]->SDlinnum_count; j++)
                {
                    char *f2;
                    linnum_data *ld2 = &SegData[s]->SDlinnum_data[j];

#if MARS
                    f2 = ld2->filename;
#else
                    Sfile *sf = ld2->filptr;
                    if (sf)
                        f2 = sf->SFname;
                    else
                        f2 = ::filename;
#endif
                    if (filename == f2)
                    {   ld->filenumber = ld2->filenumber;
                        goto L1;
                    }
                }
            }

            linebuf->writeString(filename);
            ld->filenumber = ++filenumber;

            linebuf->writeByte(0);      // index
            linebuf->writeByte(0);      // mtime
            linebuf->writeByte(0);      // length
        L1:
            ;
        }
    }
    linebuf->writeByte(0);              // end of file_names

    debugline.prologue_length = linebuf->size() - 10;

    for (unsigned seg = 1; seg <= seg_count; seg++)
    {
        seg_data *sd = SegData[seg];
        unsigned addressmax = 0;
        unsigned linestart = ~0;

        if (!sd->SDlinnum_count)
            continue;
#if ELFOBJ
        if (!sd->SDsym) // gdb ignores line number data without a DW_AT_name
            continue;
#endif

        //printf("sd = %x, SDlinnum_count = %d\n", sd, sd->SDlinnum_count);
        for (int i = 0; i < sd->SDlinnum_count; i++)
        {   linnum_data *ld = &sd->SDlinnum_data[i];

            // Set address to start of segment with DW_LNE_set_address
            linebuf->writeByte(0);
            linebuf->writeByte(5);
            linebuf->writeByte(2);
            dwarf_addrel(lineseg,linebuf->size(),seg);
            linebuf->write32(0);

            // Dwarf2 6.2.2 State machine registers
            unsigned address = 0;       // instruction address
            unsigned file = ld->filenumber;
            unsigned line = 1;          // line numbers beginning with 1
            unsigned column = 0;        // column number, leftmost column is 1
            int is_stmt = debugline.default_is_stmt;    // TRUE if beginning of a statement
            int basic_block = FALSE;  // TRUE if start of basic block
            int end_sequence = FALSE; // TRUE if address is after end of sequence

            linebuf->writeByte(DW_LNS_set_file);
            linebuf->writeuLEB128(file);

            for (int j = 0; j < ld->linoff_count; j++)
            {   int lininc = ld->linoff[j][0] - line;
                int addinc = ld->linoff[j][1] - address;

                //printf("\tld[%d] line = %d offset = x%x lininc = %d addinc = %d\n", j, ld->linoff[j][0], ld->linoff[j][1], lininc, addinc);

                //assert(addinc >= 0);
                if (addinc < 0)
                    continue;
                if (j && lininc == 0 && !(addinc && j + 1 == ld->linoff_count))
                    continue;
                line += lininc;
                if (line < linestart)
                    linestart = line;
                address += addinc;
                if (address >= addressmax)
                    addressmax = address + 1;
                if (lininc >= debugline.line_base && lininc < debugline.line_base + debugline.line_range)
                {   unsigned opcode = lininc - debugline.line_base +
                                    debugline.line_range * addinc +
                                    debugline.opcode_base;

                    if (opcode <= 255)
                    {   linebuf->writeByte(opcode);
                        continue;
                    }
                }
                if (lininc)
                {
                    linebuf->writeByte(DW_LNS_advance_line);
                    linebuf->writesLEB128((long)lininc);
                }
                if (addinc)
                {
                    linebuf->writeByte(DW_LNS_advance_pc);
                    linebuf->writeuLEB128((unsigned long)addinc);
                }
                if (lininc || addinc)
                    linebuf->writeByte(DW_LNS_copy);
            }

            // Write DW_LNE_end_sequence
            linebuf->writeByte(0);
            linebuf->writeByte(1);
            linebuf->writeByte(1);
        }
    }

    debugline.total_length = linebuf->size() - 4;
    memcpy(linebuf->buf, &debugline, sizeof(debugline));

    /* ================================================= */

    abbrevbuf->writeByte(0);

    /* ================================================= */

    infobuf->writeByte(0);      // ending abbreviation code

    debuginfo.total_length = infobuf->size() - 4;
    memcpy(infobuf->buf, &debuginfo, sizeof(debuginfo));

    /* ================================================= */

    // Terminate by offset field containing 0
    debug_pubnames_buf->write32(0);

    // Plug final sizes into header
    *(unsigned *)debug_pubnames_buf->buf = debug_pubnames_buf->size() - 4;
    *(unsigned *)(debug_pubnames_buf->buf + 10) = infobuf->size();

    /* ================================================= */

    // Terminate by address/length fields containing 0
    debug_aranges_buf->write32(0);
    debug_aranges_buf->write32(0);

    // Plug final sizes into header
    *(unsigned *)debug_aranges_buf->buf = debug_aranges_buf->size() - 4;

    /* ================================================= */

    // Terminate by beg address/end address fields containing 0
    debug_ranges_buf->write32(0);
    debug_ranges_buf->write32(0);

    /* ================================================= */

    // Free only if starting another file. Waste of time otherwise.
    if (type_table)
    {   delete type_table;
        type_table = NULL;
    }
}

/*****************************************
 * Start of code gen for function.
 */
void dwarf_func_start(Symbol *sfunc)
{
    CFA_state_current = CFA_state_init;
    cfa_buf.reset();
}

/*****************************************
 * End of code gen for function.
 */
void dwarf_func_term(Symbol *sfunc)
{
   //printf("dwarf_func_term(sfunc = '%s')\n", sfunc->Sident);
   unsigned funcabbrevcode;

    /* Put out the start of the debug_frame entry for this function
     */
    Outbuffer *debug_frame_buf;
    unsigned debug_frame_buf_offset;

    #pragma pack(1)
    struct DebugFrameFDE
    {
        unsigned length;
        unsigned CIE_pointer;
        unsigned initial_location;
        unsigned address_range;
    };
    #pragma pack()
    static DebugFrameFDE debugFrameFDE =
    {   12,             // length
        0,              // CIE_pointer
        0,              // initial_location
        0,              // address_range
    };

    // Pad to 4 byte boundary
    int n;
    for (n = (-cfa_buf.size() & 3); n; n--)
        cfa_buf.writeByte(DW_CFA_nop);

    debugFrameFDE.length = 12 + cfa_buf.size();
    debugFrameFDE.address_range = sfunc->Ssize;
    // Do we need this?
    //debugFrameFDE.initial_location = sfunc->Soffset;

    IDXSEC dfseg;
    dfseg = dwarf_getsegment(".debug_frame", 1);
    debug_frame_secidx = SegData[dfseg]->SDshtidx;
    debug_frame_buf = SegData[dfseg]->SDbuf;
    debug_frame_buf_offset = debug_frame_buf->p - debug_frame_buf->buf;
    debug_frame_buf->reserve(1000);
    debug_frame_buf->writen(&debugFrameFDE,sizeof(debugFrameFDE));
    debug_frame_buf->write(&cfa_buf);

    dwarf_addrel(dfseg,debug_frame_buf_offset + 4,dfseg);
    dwarf_addrel(dfseg,debug_frame_buf_offset + 8,sfunc->Sseg);

    IDXSEC seg = sfunc->Sseg;
    seg_data *sd = SegData[seg];

        unsigned ret_type = dwarf_typidx(sfunc->Stype->Tnext);
        if (tybasic(sfunc->Stype->Tnext->Tty) == TYvoid)
            ret_type = 0;

        // See if there are any parameters
        int haveparameters = 0;
        unsigned formalcode = 0;
        unsigned autocode = 0;
        SYMIDX si;
        for (si = 0; si < globsym.top; si++)
        {   symbol *sa = globsym.tab[si];

            static unsigned char formal[] =
            {
                DW_TAG_formal_parameter,
                0,
                DW_AT_name,     DW_FORM_string,
                DW_AT_type,     DW_FORM_ref4,
                DW_AT_location, DW_FORM_block1,
                0,              0,
            };

            switch (sa->Sclass)
            {   case SCparameter:
                case SCregpar:
                case SCfastpar:
                    dwarf_typidx(sa->Stype);
                    formal[0] = DW_TAG_formal_parameter;
                    if (!formalcode)
                        formalcode = dwarf_abbrev_code(formal,sizeof(formal));
                    haveparameters = 1;
                    break;

                case SCauto:
                case SCbprel:
                case SCregister:
                case SCpseudo:
                    dwarf_typidx(sa->Stype);
                    formal[0] = DW_TAG_variable;
                    if (!autocode)
                        autocode = dwarf_abbrev_code(formal,sizeof(formal));
                    haveparameters = 1;
                    break;
            }
        }

        Outbuffer abuf;
        abuf.writeByte(DW_TAG_subprogram);
        abuf.writeByte(haveparameters);          // have children?
        if (haveparameters)
        {
            abuf.writeByte(DW_AT_sibling);  abuf.writeByte(DW_FORM_ref4);
        }
        abuf.writeByte(DW_AT_name);      abuf.writeByte(DW_FORM_string);
        abuf.writeuLEB128(DW_AT_MIPS_linkage_name);      abuf.writeByte(DW_FORM_string);
        abuf.writeByte(DW_AT_decl_file); abuf.writeByte(DW_FORM_data1);
        abuf.writeByte(DW_AT_decl_line); abuf.writeByte(DW_FORM_data2);
        if (ret_type)
        {
            abuf.writeByte(DW_AT_type);  abuf.writeByte(DW_FORM_ref4);
        }
        if (sfunc->Sclass == SCglobal)
        {
            abuf.writeByte(DW_AT_external);       abuf.writeByte(DW_FORM_flag);
        }
        abuf.writeByte(DW_AT_low_pc);     abuf.writeByte(DW_FORM_addr);
        abuf.writeByte(DW_AT_high_pc);    abuf.writeByte(DW_FORM_addr);
        abuf.writeByte(DW_AT_frame_base); abuf.writeByte(DW_FORM_data4);
        abuf.writeByte(0);                abuf.writeByte(0);

        funcabbrevcode = dwarf_abbrev_code(abuf.buf, abuf.size());

        unsigned idxsibling = 0;
        unsigned siblingoffset;

        unsigned infobuf_offset = infobuf->size();
        infobuf->writeuLEB128(funcabbrevcode);  // abbreviation code
        if (haveparameters)
        {
            siblingoffset = infobuf->size();
            infobuf->write32(idxsibling);       // DW_AT_sibling
        }

        const char *name;
#if MARS
        name = sfunc->prettyIdent ? sfunc->prettyIdent : sfunc->Sident;
#else
        name = sfunc->Sident;
#endif
        infobuf->writeString(name);             // DW_AT_name
        infobuf->writeString(sfunc->Sident);    // DW_AT_MIPS_linkage_name
        infobuf->writeByte(1);                  // DW_AT_decl_file
        infobuf->writeWord(sfunc->Sfunc->Fstartline.Slinnum);   // DW_AT_decl_line
        if (ret_type)
            infobuf->write32(ret_type);         // DW_AT_type

        if (sfunc->Sclass == SCglobal)
            infobuf->writeByte(1);              // DW_AT_external

        dwarf_addrel(infoseg,infobuf->size(),seg);
        infobuf->write32(funcoffset);           // DW_AT_low_pc

        dwarf_addrel(infoseg,infobuf->size(),seg);
        infobuf->write32(funcoffset + sfunc->Ssize);            // DW_AT_high_pc

        dwarf_addrel(infoseg,infobuf->size(),debug_loc_seg);
        infobuf->write32(debug_loc_buf->size());                // DW_AT_frame_base

        if (haveparameters)
        {
            for (si = 0; si < globsym.top; si++)
            {   symbol *sa = globsym.tab[si];
                unsigned vcode;

                switch (sa->Sclass)
                {
                    case SCparameter:
                    case SCregpar:
                    case SCfastpar:
                        vcode = formalcode;
                        goto L1;
                    case SCauto:
                    case SCregister:
                    case SCpseudo:
                    case SCbprel:
                        vcode = autocode;
                    L1:
                    {   unsigned soffset;
                        unsigned tidx = dwarf_typidx(sa->Stype);

                        infobuf->writeuLEB128(vcode);           // abbreviation code
                        infobuf->writeString(sa->Sident);       // DW_AT_name
                        infobuf->write32(tidx);                 // DW_AT_type
                        soffset = infobuf->size();
                        infobuf->writeByte(2);                  // DW_FORM_block1
                        if (sa->Sfl == FLreg || sa->Sclass == SCpseudo)
                        {   // BUG: register pairs not supported in Dwarf?
                            infobuf->writeByte(DW_OP_reg0 + sa->Sreglsw);
                        }
                        else
                        {
                            infobuf->writeByte(DW_OP_fbreg);
                            if (sa->Sclass == SCregpar ||
                                sa->Sclass == SCparameter)
                                infobuf->writesLEB128(Poff + sa->Soffset);
                            else if (sa->Sclass == SCfastpar)
                                infobuf->writesLEB128(Aoff + BPoff + sa->Soffset);
                            else if (sa->Sclass == SCbprel)
                                infobuf->writesLEB128(sa->Soffset);
                            else
                                infobuf->writesLEB128(Aoff + BPoff + sa->Soffset);
                        }
                        infobuf->buf[soffset] = infobuf->size() - soffset - 1;
                        break;
                    }
                }
            }
            infobuf->writeByte(0);              // end of parameter children

            idxsibling = infobuf->size();
            *(unsigned *)(infobuf->buf + siblingoffset) = idxsibling;
        }

        /* ============= debug_pubnames =========================== */

        debug_pubnames_buf->write32(infobuf_offset);
        // Should be the fully qualified name, not the simple DW_AT_name
        debug_pubnames_buf->writeString(sfunc->Sident);

        /* ============= debug_aranges =========================== */

        if (sd->SDaranges_offset)
            // Extend existing entry size
            *(unsigned *)(debug_aranges_buf->buf + sd->SDaranges_offset + 4) = funcoffset + sfunc->Ssize;
        else
        {   // Add entry
            sd->SDaranges_offset = debug_aranges_buf->size();
            dwarf_addrel(debug_aranges_seg,sd->SDaranges_offset,seg);
            debug_aranges_buf->write32(0);      // address of start of .text segment
            debug_aranges_buf->write32(funcoffset + sfunc->Ssize);      // size of .text segment
        }

        /* ============= debug_ranges =========================== */

        /* Each function gets written into its own segment,
         * indicate this by adding to the debug_ranges
         */
        targ_size_t offset = debug_ranges_buf->size();
        debug_ranges_buf->write32(funcoffset);                  // start of function
        dwarf_addrel(debug_ranges_seg, offset, seg);
        debug_ranges_buf->write32(funcoffset + sfunc->Ssize);   // end of function
        dwarf_addrel(debug_ranges_seg, offset + 4, seg);

        /* ============= debug_loc =========================== */
#if 1
        // set the entry for this function in .debug_loc segment
        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + 0);
        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + 1);
        debug_loc_buf->write32(0x04740002);

        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + 1);
        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + 3);
        debug_loc_buf->write32(0x08740002);

        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + 3);
        dwarf_addrel(debug_loc_seg, debug_loc_buf->size(), seg);
        debug_loc_buf->write32(funcoffset + sfunc->Ssize);
        //debug_loc_buf->write32(0x08750002);
        debug_loc_buf->write32(0x00750002);

        debug_loc_buf->write32(0);              // 2 words of 0 end it
        debug_loc_buf->write32(0);
#endif
}


/******************************************
 * Write out symbol table for current function.
 */

void cv_outsym(symbol *s)
{
    //printf("cv_outsym('%s')\n",s->Sident);
    //symbol_print(s);

    symbol_debug(s);
#if MARS
    if (s->Sflags & SFLnodebug)
        return;
#endif
    type *t = s->Stype;
    type_debug(t);
    tym_t tym = tybasic(t->Tty);
    if (tyfunc(tym) && s->Sclass != SCtypedef)
        return;

    Outbuffer abuf;
    unsigned code;
    unsigned typidx;
    unsigned soffset;
    switch (s->Sclass)
    {
        case SCglobal:
            typidx = dwarf_typidx(t);

            abuf.writeByte(DW_TAG_variable);
            abuf.writeByte(0);                  // no children
            abuf.writeByte(DW_AT_name);         abuf.writeByte(DW_FORM_string);
            abuf.writeByte(DW_AT_type);         abuf.writeByte(DW_FORM_ref4);
            abuf.writeByte(DW_AT_external);     abuf.writeByte(DW_FORM_flag);
            abuf.writeByte(DW_AT_location);     abuf.writeByte(DW_FORM_block1);
            abuf.writeByte(0);                  abuf.writeByte(0);
            code = dwarf_abbrev_code(abuf.buf, abuf.size());

            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeString(s->Sident);    // DW_AT_name
            infobuf->write32(typidx);           // DW_AT_type
            infobuf->writeByte(1);              // DW_AT_external

            soffset = infobuf->size();
            infobuf->writeByte(2);                      // DW_FORM_block1

            infobuf->writeByte(DW_OP_addr);
            dwarf_addrel(infoseg,infobuf->size(),s->Sseg);
            infobuf->write32(0);        // address of global

            infobuf->buf[soffset] = infobuf->size() - soffset - 1;
            break;
    }
}


/******************************************
 * Write out any deferred symbols.
 */

void cv_outlist()
{
}


/******************************************
 * Write out symbol table for current function.
 */

void cv_func(Funcsym *s)
{
}

/* =================== Cached Types in debug_info ================= */

struct Atype
{
    size_t start;
    size_t end;
};

struct TypeInfo_Atype : TypeInfo
{
    const char* toString();
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
};

TypeInfo_Atype ti_atype;

const char* TypeInfo_Atype::toString()
{
    return "Atype";
}

hash_t TypeInfo_Atype::getHash(void *p)
{   Atype a;
    hash_t hash = 0;
    size_t i;

    a = *(Atype *)p;
    for (i = a.start; i < a.end; i++)
    {
        hash = hash * 11 + infobuf->buf[i];
    }
    return hash;
}

int TypeInfo_Atype::equals(void *p1, void *p2)
{
    Atype a1 = *(Atype*)p1;
    Atype a2 = *(Atype*)p2;
    size_t len = a1.end - a1.start;

    return len == a2.end - a2.start &&
        memcmp(infobuf->buf + a1.start, infobuf->buf + a2.start, len) == 0;
}

int TypeInfo_Atype::compare(void *p1, void *p2)
{
    Atype a1 = *(Atype*)p1;
    Atype a2 = *(Atype*)p2;
    size_t len = a1.end - a1.start;
    if (len == a2.end - a2.start)
        return memcmp(infobuf->buf + a1.start, infobuf->buf + a2.start, len);
    else if (len < a2.end - a2.start)
        return -1;
    else
        return 1;
}

size_t TypeInfo_Atype::tsize()
{
    return sizeof(Atype);
}

void TypeInfo_Atype::swap(void *p1, void *p2)
{
    assert(0);
}

/* ======================= Type Index ============================== */

unsigned dwarf_typidx(type *t)
{   unsigned idx = 0;
    unsigned nextidx;
    unsigned keyidx;
    unsigned pvoididx;
    unsigned code;
    type *tnext;
    const char *p;

    static unsigned char abbrevTypeBasic[] =
    {
        DW_TAG_base_type,
        0,                      // no children
        DW_AT_name,             DW_FORM_string,
        DW_AT_byte_size,        DW_FORM_data1,
        DW_AT_encoding,         DW_FORM_data1,
        0,                      0,
    };
    static unsigned char abbrevTypePointer[] =
    {
        DW_TAG_pointer_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        DW_AT_type,             DW_FORM_ref4,
        0,                      0,
    };
    static unsigned char abbrevTypePointerVoid[] =
    {
        DW_TAG_pointer_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        0,                      0,
    };
    static unsigned char abbrevTypeDArray[] =
    {
        DW_TAG_darray_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        DW_AT_type,             DW_FORM_ref4,
        0,                      0,
    };
    static unsigned char abbrevTypeDArrayVoid[] =
    {
        DW_TAG_darray_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        0,                      0,
    };
    static unsigned char abbrevTypeAArray[] =
    {
        DW_TAG_aarray_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        DW_AT_type,             DW_FORM_ref4,   // element type
        DW_AT_containing_type,  DW_FORM_ref4,   // key type
        0,                      0,
    };
    static unsigned char abbrevTypeDelegate[] =
    {
        DW_TAG_delegate_type,
        0,                      // no children
        DW_AT_byte_size,        DW_FORM_data1,
        DW_AT_containing_type,  DW_FORM_ref4,   // this type
        DW_AT_type,             DW_FORM_ref4,   // function type
        0,                      0,
    };
    static unsigned char abbrevTypeConst[] =
    {
        DW_TAG_const_type,
        0,                      // no children
        DW_AT_type,             DW_FORM_ref4,
        0,                      0,
    };
    static unsigned char abbrevTypeConstVoid[] =
    {
        DW_TAG_const_type,
        0,                      // no children
        0,                      0,
    };
    static unsigned char abbrevTypeVolatile[] =
    {
        DW_TAG_volatile_type,
        0,                      // no children
        DW_AT_type,             DW_FORM_ref4,
        0,                      0,
    };
    static unsigned char abbrevTypeVolatileVoid[] =
    {
        DW_TAG_volatile_type,
        0,                      // no children
        0,                      0,
    };

    if (!t)
        return 0;

    if (t->Tty & mTYconst)
    {   tnext = type_copy(t);
        tnext->Tcount++;
        tnext->Tty &= ~mTYconst;
        nextidx = dwarf_typidx(tnext);
        code = nextidx
            ? dwarf_abbrev_code(abbrevTypeConst, sizeof(abbrevTypeConst))
            : dwarf_abbrev_code(abbrevTypeConstVoid, sizeof(abbrevTypeConstVoid));
        goto Lcv;
    }

    if (t->Tty & mTYvolatile)
    {   tnext = type_copy(t);
        tnext->Tcount++;
        tnext->Tty &= ~mTYvolatile;
        nextidx = dwarf_typidx(tnext);
        code = nextidx
            ? dwarf_abbrev_code(abbrevTypeVolatile, sizeof(abbrevTypeVolatile))
            : dwarf_abbrev_code(abbrevTypeVolatileVoid, sizeof(abbrevTypeVolatileVoid));
    Lcv:
        idx = infobuf->size();
        infobuf->writeuLEB128(code);    // abbreviation code
        if (nextidx)
            infobuf->write32(nextidx);  // DW_AT_type
        goto Lret;
    }

    tym_t ty;
    ty = tybasic(t->Tty);
    idx = typidx_tab[ty];
    if (idx)
        return idx;
    const char *name;
    unsigned char ate;
    ate = tyuns(t->Tty) ? DW_ATE_unsigned : DW_ATE_signed;
    switch (tybasic(t->Tty))
    {
        Lnptr:
            nextidx = dwarf_typidx(t->Tnext);
            code = nextidx
                ? dwarf_abbrev_code(abbrevTypePointer, sizeof(abbrevTypePointer))
                : dwarf_abbrev_code(abbrevTypePointerVoid, sizeof(abbrevTypePointerVoid));
            idx = infobuf->size();
            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeByte(tysize(t->Tty)); // DW_AT_byte_size
            if (nextidx)
                infobuf->write32(nextidx);      // DW_AT_type
            break;

        case TYullong:
            if (!t->Tnext)
            {   p = "unsigned long long";
                goto Lsigned;
            }
            /* It's really TYdarray, and Tnext is the
             * element type
             */
            nextidx = dwarf_typidx(t->Tnext);
            code = nextidx
                ? dwarf_abbrev_code(abbrevTypeDArray, sizeof(abbrevTypeDArray))
                : dwarf_abbrev_code(abbrevTypeDArrayVoid, sizeof(abbrevTypeDArrayVoid));
            idx = infobuf->size();
            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeByte(tysize(t->Tty)); // DW_AT_byte_size
            if (nextidx)
                infobuf->write32(nextidx);      // DW_AT_type
            break;

        case TYllong:
            if (!t->Tnext)
            {   p = "long long";
                goto Lsigned;
            }
            /* It's really TYdelegate, and Tnext is the
             * function type
             */
            {   type *tv = type_fake(TYnptr);
                tv->Tcount++;
                pvoididx = dwarf_typidx(tv);    // void* is the 'this' type
                type_free(tv);
            }
            nextidx = dwarf_typidx(t->Tnext);
            code = dwarf_abbrev_code(abbrevTypeDelegate, sizeof(abbrevTypeDelegate));
            idx = infobuf->size();
            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeByte(tysize(t->Tty)); // DW_AT_byte_size
            infobuf->write32(pvoididx);         // DW_AT_containing_type
            infobuf->write32(nextidx);          // DW_AT_type
            break;

        case TYnptr:
            if (!t->Tkey)
                goto Lnptr;

            /* It's really TYaarray, and Tnext is the
             * element type, Tkey is the key type
             */
            keyidx = dwarf_typidx(t->Tkey);
            nextidx = dwarf_typidx(t->Tnext);
            code = dwarf_abbrev_code(abbrevTypeAArray, sizeof(abbrevTypeAArray));
            idx = infobuf->size();
            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeByte(tysize(t->Tty)); // DW_AT_byte_size
            infobuf->write32(nextidx);          // DW_AT_type
            infobuf->write32(keyidx);           // DW_AT_containing_type
            break;

        case TYvoid:        return 0;
        case TYbool:        p = "_Bool";         ate = DW_ATE_boolean;       goto Lsigned;
        case TYchar:        p = "char";          ate = (config.flags & CFGuchar) ? DW_ATE_unsigned_char : DW_ATE_signed_char;   goto Lsigned;
        case TYschar:       p = "signed char";   ate = DW_ATE_signed_char;   goto Lsigned;
        case TYuchar:       p = "unsigned char"; ate = DW_ATE_unsigned_char; goto Lsigned;
        case TYshort:       p = "short";                goto Lsigned;
        case TYushort:      p = "unsigned short";       goto Lsigned;
        case TYint:         p = "int";                  goto Lsigned;
        case TYuint:        p = "unsigned";             goto Lsigned;
        case TYlong:        p = "long";                 goto Lsigned;
        case TYulong:       p = "unsigned long";        goto Lsigned;
        case TYdchar:       p = "dchar";                goto Lsigned;
        case TYfloat:       p = "float";        ate = DW_ATE_float;     goto Lsigned;
        case TYdouble_alias:
        case TYdouble:      p = "double";       ate = DW_ATE_float;     goto Lsigned;
        case TYldouble:     p = "long double";  ate = DW_ATE_float;     goto Lsigned;
        case TYifloat:      p = "imaginary float";       ate = DW_ATE_imaginary_float;  goto Lsigned;
        case TYidouble:     p = "imaginary double";      ate = DW_ATE_imaginary_float;  goto Lsigned;
        case TYildouble:    p = "imaginary long double"; ate = DW_ATE_imaginary_float;  goto Lsigned;
        case TYcfloat:      p = "complex float";         ate = DW_ATE_complex_float;    goto Lsigned;
        case TYcdouble:     p = "complex double";        ate = DW_ATE_complex_float;    goto Lsigned;
        case TYcldouble:    p = "complex long double";   ate = DW_ATE_complex_float;    goto Lsigned;
        Lsigned:
            code = dwarf_abbrev_code(abbrevTypeBasic, sizeof(abbrevTypeBasic));
            idx = infobuf->size();
            infobuf->writeuLEB128(code);        // abbreviation code
            infobuf->writeString(p);            // DW_AT_name
            infobuf->writeByte(tysize(t->Tty)); // DW_AT_byte_size
            infobuf->writeByte(ate);            // DW_AT_encoding
            typidx_tab[ty] = idx;
            return idx;

        case TYnsfunc:
        case TYnpfunc:
        case TYjfunc:

        case TYnfunc:
        {   unsigned paramcode;
            unsigned params;

            nextidx = dwarf_typidx(t->Tnext);
            params = 0;
            for (param_t *p = t->Tparamtypes; p; p = p->Pnext)
            {   params = 1;
                dwarf_typidx(p->Ptype);
            }

            Outbuffer abuf;             // for abbrev
            abuf.writeByte(DW_TAG_subroutine_type);
            if (params)
            {
                abuf.writeByte(1);      // children
                abuf.writeByte(DW_AT_sibling);  abuf.writeByte(DW_FORM_ref4);
            }
            else
                abuf.writeByte(0);      // no children
            abuf.writeByte(DW_AT_prototyped);   abuf.writeByte(DW_FORM_flag);
            abuf.writeByte(DW_AT_type);         abuf.writeByte(DW_FORM_ref4);
            abuf.writeByte(0);                  abuf.writeByte(0);
            code = dwarf_abbrev_code(abuf.buf, abuf.size());

            if (params)
            {   abuf.reset();
                abuf.writeByte(DW_TAG_formal_parameter);
                abuf.writeByte(0);
                abuf.writeByte(DW_AT_type);     abuf.writeByte(DW_FORM_ref4);
                abuf.writeByte(0);              abuf.writeByte(0);
                paramcode = dwarf_abbrev_code(abuf.buf, abuf.size());
            }

            unsigned idxsibling = 0;
            unsigned siblingoffset;

            idx = infobuf->size();
            infobuf->writeuLEB128(code);
            siblingoffset = infobuf->size();
            if (params)
                infobuf->write32(idxsibling);   // DW_AT_sibling
            infobuf->writeByte(1);              // DW_AT_prototyped
            infobuf->write32(nextidx);          // DW_AT_type

            if (params)
            {
                for (param_t *p = t->Tparamtypes; p; p = p->Pnext)
                {   infobuf->writeuLEB128(paramcode);
                    unsigned x = dwarf_typidx(p->Ptype);
                    infobuf->write32(x);        // DW_AT_type
                }
                infobuf->writeByte(0);          // end parameter list

                idxsibling = infobuf->size();
                *(unsigned *)(infobuf->buf + siblingoffset) = idxsibling;
            }
            break;
        }

        case TYarray:
        {   static unsigned char abbrevTypeArray[] =
            {
                DW_TAG_array_type,
                1,                      // child (the subrange type)
                DW_AT_sibling,          DW_FORM_ref4,
                DW_AT_type,             DW_FORM_ref4,
                0,                      0,
            };
            static unsigned char abbrevTypeSubrange[] =
            {
                DW_TAG_subrange_type,
                0,                      // no children
                DW_AT_type,             DW_FORM_ref4,
                DW_AT_upper_bound,      DW_FORM_data4,
                0,                      0,
            };
            static unsigned char abbrevTypeSubrange2[] =
            {
                DW_TAG_subrange_type,
                0,                      // no children
                DW_AT_type,             DW_FORM_ref4,
                0,                      0,
            };
            unsigned code1 = dwarf_abbrev_code(abbrevTypeArray, sizeof(abbrevTypeArray));
            unsigned code2 = (t->Tflags & TFsizeunknown)
                ? dwarf_abbrev_code(abbrevTypeSubrange2, sizeof(abbrevTypeSubrange2))
                : dwarf_abbrev_code(abbrevTypeSubrange, sizeof(abbrevTypeSubrange));
            unsigned idxbase = dwarf_typidx(tsuns);     // should be tssize_t
            unsigned idxsibling = 0;
            unsigned siblingoffset;
            nextidx = dwarf_typidx(t->Tnext);
            idx = infobuf->size();

            infobuf->writeuLEB128(code1);       // DW_TAG_array_type
            siblingoffset = infobuf->size();
            infobuf->write32(idxsibling);       // DW_AT_sibling
            infobuf->write32(nextidx);          // DW_AT_type

            infobuf->writeuLEB128(code2);       // DW_TAG_subrange_type
            infobuf->write32(idxbase);          // DW_AT_type
            if (!(t->Tflags & TFsizeunknown))
                infobuf->write32(t->Tdim ? t->Tdim - 1 : 0);    // DW_AT_upper_bound

            infobuf->writeByte(0);              // no more siblings
            idxsibling = infobuf->size();
            *(unsigned *)(infobuf->buf + siblingoffset) = idxsibling;
            break;
        }

#if 0
        case TYwchar_t:
            DW_TAG_typedef
            children = 0
            DW_AT_name                  DW_FORM_strp    00000170 'wchar_t'
            DW_AT_decl_file             DW_FORM_data1   03
            DW_AT_decl_line             DW_FORM_data2   0145
            DW_AT_type                  DW_FORM_ref4    00000076 (long int)
            DW_AT_0x00                  DW_FORM_0x00
#endif

        case TYstruct:
        {
            Classsym *s = t->Ttag;
            struct_t *st = s->Sstruct;

            if (s->Stypidx)
                return s->Stypidx;

            static unsigned char abbrevTypeStruct0[] =
            {
                DW_TAG_structure_type,
                0,                      // no children
                DW_AT_name,             DW_FORM_string,
                DW_AT_byte_size,        DW_FORM_data1,
                0,                      0,
            };
            static unsigned char abbrevTypeStruct1[] =
            {
                DW_TAG_structure_type,
                0,                      // no children
                DW_AT_name,             DW_FORM_string,
                DW_AT_declaration,      DW_FORM_flag,
                0,                      0,
            };

            if (t->Tflags & (TFsizeunknown | TFforward))
            {
                abbrevTypeStruct1[0] = (st->Sflags & STRunion)
                        ? DW_TAG_union_type : DW_TAG_structure_type;
                code = dwarf_abbrev_code(abbrevTypeStruct1, sizeof(abbrevTypeStruct1));
                idx = infobuf->size();
                infobuf->writeuLEB128(code);
                infobuf->writeString(s->Sident);        // DW_AT_name
                infobuf->writeByte(1);                  // DW_AT_declaration
                break;                  // don't set Stypidx
            }

            Outbuffer fieldidx;

            // Count number of fields
            unsigned nfields = 0;
            symlist_t sl;
            t->Tflags |= TFforward;
            for (sl = st->Sfldlst; sl; sl = list_next(sl))
            {   symbol *sf = list_symbol(sl);

                switch (sf->Sclass)
                {
                    case SCmember:
                        fieldidx.write32(dwarf_typidx(sf->Stype));
                        nfields++;
                        break;
                }
            }
            t->Tflags &= ~TFforward;
            if (nfields == 0)
            {
                abbrevTypeStruct0[0] = (st->Sflags & STRunion)
                        ? DW_TAG_union_type : DW_TAG_structure_type;
                abbrevTypeStruct0[1] = 0;               // no children
                abbrevTypeStruct0[5] = DW_FORM_data1;   // DW_AT_byte_size
                code = dwarf_abbrev_code(abbrevTypeStruct0, sizeof(abbrevTypeStruct0));
                idx = infobuf->size();
                infobuf->writeuLEB128(code);
                infobuf->writeString(s->Sident);        // DW_AT_name
                infobuf->writeByte(0);                  // DW_AT_byte_size
            }
            else
            {
                Outbuffer abuf;         // for abbrev
                abuf.writeByte((st->Sflags & STRunion)
                        ? DW_TAG_union_type : DW_TAG_structure_type);
                abuf.writeByte(1);              // children
                abuf.writeByte(DW_AT_sibling);  abuf.writeByte(DW_FORM_ref4);
                abuf.writeByte(DW_AT_name);     abuf.writeByte(DW_FORM_string);
                abuf.writeByte(DW_AT_byte_size);

                size_t sz = st->Sstructsize;
                if (sz <= 0xFF)
                    abuf.writeByte(DW_FORM_data1);      // DW_AT_byte_size
                else if (sz <= 0xFFFF)
                    abuf.writeByte(DW_FORM_data2);      // DW_AT_byte_size
                else
                    abuf.writeByte(DW_FORM_data4);      // DW_AT_byte_size
                abuf.writeByte(0);              abuf.writeByte(0);

                code = dwarf_abbrev_code(abuf.buf, abuf.size());

                unsigned membercode;
                abuf.reset();
                abuf.writeByte(DW_TAG_member);
                abuf.writeByte(0);              // no children
                abuf.writeByte(DW_AT_name);
                abuf.writeByte(DW_FORM_string);
                abuf.writeByte(DW_AT_type);
                abuf.writeByte(DW_FORM_ref4);
                abuf.writeByte(DW_AT_data_member_location);
                abuf.writeByte(DW_FORM_block1);
                abuf.writeByte(0);
                abuf.writeByte(0);
                membercode = dwarf_abbrev_code(abuf.buf, abuf.size());

                unsigned idxsibling = 0;
                unsigned siblingoffset;

                idx = infobuf->size();
                infobuf->writeuLEB128(code);
                siblingoffset = infobuf->size();
                infobuf->write32(idxsibling);   // DW_AT_sibling
                infobuf->writeString(s->Sident);        // DW_AT_name
                if (sz <= 0xFF)
                    infobuf->writeByte(sz);     // DW_AT_byte_size
                else if (sz <= 0xFFFF)
                    infobuf->writeWord(sz);     // DW_AT_byte_size
                else
                    infobuf->write32(sz);       // DW_AT_byte_size

                s->Stypidx = idx;
                unsigned n = 0;
                for (sl = st->Sfldlst; sl; sl = list_next(sl))
                {   symbol *sf = list_symbol(sl);
                    size_t soffset;

                    switch (sf->Sclass)
                    {
                        case SCmember:
                            infobuf->writeuLEB128(membercode);
                            infobuf->writeString(sf->Sident);
                            //infobuf->write32(dwarf_typidx(sf->Stype));
                            unsigned fi = ((unsigned *)fieldidx.buf)[n];
                            infobuf->write32(fi);
                            n++;
                            soffset = infobuf->size();
                            infobuf->writeByte(2);
                            infobuf->writeByte(DW_OP_plus_uconst);
                            infobuf->writeuLEB128(sf->Smemoff);
                            infobuf->buf[soffset] = infobuf->size() - soffset - 1;
                            break;
                    }
                }

                infobuf->writeByte(0);          // no more siblings
                idxsibling = infobuf->size();
                *(unsigned *)(infobuf->buf + siblingoffset) = idxsibling;
            }
            s->Stypidx = idx;
            return idx;                 // no need to cache it
        }

        case TYenum:
        {   static unsigned char abbrevTypeEnum[] =
            {
                DW_TAG_enumeration_type,
                1,                      // child (the subrange type)
                DW_AT_sibling,          DW_FORM_ref4,
                DW_AT_name,             DW_FORM_string,
                DW_AT_byte_size,        DW_FORM_data1,
                0,                      0,
            };
            static unsigned char abbrevTypeEnumMember[] =
            {
                DW_TAG_enumerator,
                0,                      // no children
                DW_AT_name,             DW_FORM_string,
                DW_AT_const_value,      DW_FORM_data1,
                0,                      0,
            };

            symbol *s = t->Ttag;
            enum_t *se = s->Senum;
            type *tbase = s->Stype->Tnext;
            unsigned sz = type_size(tbase);
            symlist_t sl;

            if (s->Stypidx)
                return s->Stypidx;

            if (se->SEflags & SENforward)
            {
                static unsigned char abbrevTypeEnumForward[] =
                {
                    DW_TAG_enumeration_type,
                    0,                  // no children
                    DW_AT_name,         DW_FORM_string,
                    DW_AT_declaration,  DW_FORM_flag,
                    0,                  0,
                };
                code = dwarf_abbrev_code(abbrevTypeEnumForward, sizeof(abbrevTypeEnumForward));
                idx = infobuf->size();
                infobuf->writeuLEB128(code);
                infobuf->writeString(s->Sident);        // DW_AT_name
                infobuf->writeByte(1);                  // DW_AT_declaration
                break;                  // don't set Stypidx
            }

            Outbuffer abuf;             // for abbrev
            abuf.write(abbrevTypeEnum, sizeof(abbrevTypeEnum));
            code = dwarf_abbrev_code(abuf.buf, abuf.size());

            unsigned membercode;
            abuf.reset();
            abuf.writeByte(DW_TAG_enumerator);
            abuf.writeByte(0);
            abuf.writeByte(DW_AT_name);
            abuf.writeByte(DW_FORM_string);
            abuf.writeByte(DW_AT_const_value);
            if (tyuns(tbase->Tty))
                abuf.writeByte(DW_FORM_udata);
            else
                abuf.writeByte(DW_FORM_sdata);
            abuf.writeByte(0);
            abuf.writeByte(0);
            membercode = dwarf_abbrev_code(abuf.buf, abuf.size());

            unsigned idxsibling = 0;
            unsigned siblingoffset;

            idx = infobuf->size();
            infobuf->writeuLEB128(code);
            siblingoffset = infobuf->size();
            infobuf->write32(idxsibling);       // DW_AT_sibling
            infobuf->writeString(s->Sident);    // DW_AT_name
            infobuf->writeByte(sz);             // DW_AT_byte_size

            for (sl = s->Senumlist; sl; sl = list_next(sl))
            {   symbol *sf = (symbol *)list_ptr(sl);
                unsigned long value = el_tolongt(sf->Svalue);

                infobuf->writeuLEB128(membercode);
                infobuf->writeString(sf->Sident);
                if (tyuns(tbase->Tty))
                    infobuf->writeuLEB128(value);
                else
                    infobuf->writesLEB128(value);
            }

            infobuf->writeByte(0);              // no more siblings
            idxsibling = infobuf->size();
            *(unsigned *)(infobuf->buf + siblingoffset) = idxsibling;

            s->Stypidx = idx;
            return idx;                 // no need to cache it
        }

        default:
            return 0;
    }
Lret:
    /* If infobuf->buf[idx .. size()] is already in infobuf,
     * discard this one and use the previous one.
     */
    Atype atype;
    atype.start = idx;
    atype.end = infobuf->size();

    if (!type_table)
        /* unsigned[Adata] type_table;
         * where the table values are the type indices
         */
        type_table = new AArray(&ti_atype, sizeof(unsigned));

    unsigned *pidx;
    pidx = (unsigned *)type_table->get(&atype);
    if (!*pidx)                 // if no idx assigned yet
    {
        *pidx = idx;            // assign newly computed idx
    }
    else
    {   // Reuse existing code
        infobuf->setsize(idx);  // discard current
        idx = *pidx;
    }
    return idx;
}

/* ======================= Abbreviation Codes ====================== */

struct Adata
{
    size_t start;
    size_t end;
};

struct TypeInfo_Adata : TypeInfo
{
    const char* toString();
    hash_t getHash(void *p);
    int equals(void *p1, void *p2);
    int compare(void *p1, void *p2);
    size_t tsize();
    void swap(void *p1, void *p2);
};

TypeInfo_Adata ti_adata;

const char* TypeInfo_Adata::toString()
{
    return "Adata";
}

hash_t TypeInfo_Adata::getHash(void *p)
{   Adata a;
    hash_t hash = 0;
    size_t i;

    a = *(Adata *)p;
    for (i = a.start; i < a.end; i++)
    {
        //printf("%02x ", abbrevbuf->buf[i]);
        hash = hash * 11 + abbrevbuf->buf[i];
    }
    //printf("\nhash = %x, length = %d\n", hash, a.end - a.start);
    return hash;
}

int TypeInfo_Adata::equals(void *p1, void *p2)
{
    Adata a1 = *(Adata*)p1;
    Adata a2 = *(Adata*)p2;
    size_t len = a1.end - a1.start;

    return len == a2.end - a2.start &&
        memcmp(abbrevbuf->buf + a1.start, abbrevbuf->buf + a2.start, len) == 0;
}

int TypeInfo_Adata::compare(void *p1, void *p2)
{
    Adata a1 = *(Adata*)p1;
    Adata a2 = *(Adata*)p2;
    size_t len = a1.end - a1.start;
    if (len == a2.end - a2.start)
        return memcmp(abbrevbuf->buf + a1.start, abbrevbuf->buf + a2.start, len);
    else if (len < a2.end - a2.start)
        return -1;
    else
        return 1;
}

size_t TypeInfo_Adata::tsize()
{
    return sizeof(Adata);
}

void TypeInfo_Adata::swap(void *p1, void *p2)
{
    assert(0);
}


unsigned dwarf_abbrev_code(unsigned char *data, size_t nbytes)
{
    if (!abbrev_table)
        /* unsigned[Adata] abbrev_table;
         * where the table values are the abbreviation codes.
         */
        abbrev_table = new AArray(&ti_adata, sizeof(unsigned));

    /* Write new entry into abbrevbuf
     */
    Adata adata;

    unsigned idx = abbrevbuf->size();
    abbrevcode++;
    abbrevbuf->writeuLEB128(abbrevcode);
    adata.start = abbrevbuf->size();
    abbrevbuf->write(data, nbytes);
    adata.end = abbrevbuf->size();

    /* If abbrevbuf->buf[idx .. size()] is already in abbrevbuf,
     * discard this one and use the previous one.
     */

    unsigned *pcode;
    pcode = (unsigned *)abbrev_table->get(&adata);
    if (!*pcode)                // if no code assigned yet
    {
        *pcode = abbrevcode;    // assign newly computed code
    }
    else
    {   // Reuse existing code
        abbrevbuf->setsize(idx);        // discard current
        abbrevcode--;
    }
    return *pcode;
}

#endif
#endif
