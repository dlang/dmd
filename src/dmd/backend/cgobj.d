/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgobj.d, backend/cgobj.d)
 */

module dmd.backend.cgobj;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.md5;
import dmd.backend.mem;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.outbuf;
import dmd.backend.rtlsym;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):

nothrow:
@safe:

version (SCPP)
{
    import filespec;
    import msgs2;
    import scopeh;

    extern(C) char* getcwd(char*,size_t);
}

version (MARS)
{
    import dmd.backend.dvarstats;

    //import dmd.backend.filespec;
    char *filespecdotext(const(char)* filespec);
    char *filespecgetroot(const(char)* name);
    char *filespecname(const(char)* filespec);

    version (Windows)
    {
        extern (C) int stricmp(const(char)*, const(char)*) pure nothrow @nogc;
        alias filespeccmp = stricmp;
    }
    else
        alias filespeccmp = strcmp;

    extern(C) char* getcwd(char*,size_t);

struct Loc
{
    char *filename;
    uint linnum;
    uint charnum;

    this(int y, int x)
    {
        linnum = y;
        charnum = x;
        filename = null;
    }
}

static if (__VERSION__ < 2092)
    void error(Loc loc, const(char)* format, ...);
else
    pragma(printf) void error(Loc loc, const(char)* format, ...);
}

version (Windows)
{
    extern(C) char* strupr(char*);
}
version (Posix)
{
    @trusted
    extern(C) char* strupr(char* s)
    {
        for (char* p = s; *p; ++p)
        {
            char c = *p;
            if ('a' <= c && c <= 'z')
                *p = cast(char)(c - 'a' + 'A');
        }
        return s;
    }
}

int obj_namestring(char *p,const(char)* name);

enum MULTISCOPE = 1;            /* account for bug in MultiScope debugger
                                   where it cannot handle a line number
                                   with multiple offsets. We use a bit vector
                                   to filter out the extra offsets.
                                 */

extern (C) void TOOFFSET(void* p, targ_size_t value);

@trusted
void TOWORD(void* a, uint b)
{
    *cast(ushort*)a = cast(ushort)b;
}

@trusted
void TOLONG(void* a, uint b)
{
    *cast(uint*)a = b;
}


/**************************
 * Record types:
 */

enum
{
    RHEADR  = 0x6E,
    REGINT  = 0x70,
    REDATA  = 0x72,
    RIDATA  = 0x74,
    OVLDEF  = 0x76,
    ENDREC  = 0x78,
    BLKDEF  = 0x7A,
    BLKEND  = 0x7C,
//  DEBSYM  = 0x7E,
    THEADR  = 0x80,
    LHEADR  = 0x82,
    PEDATA  = 0x84,
    PIDATA  = 0x86,
    COMENT  = 0x88,
    MODEND  = 0x8A,
    EXTDEF  = 0x8C,
    TYPDEF  = 0x8E,
    PUBDEF  = 0x90,
    PUB386  = 0x91,
    LOCSYM  = 0x92,
    LINNUM  = 0x94,
    LNAMES  = 0x96,
    SEGDEF  = 0x98,
    SEG386  = 0x99,
    GRPDEF  = 0x9A,
    FIXUPP  = 0x9C,
    FIX386  = 0x9D,
    LEDATA  = 0xA0,
    LED386  = 0xA1,
    LIDATA  = 0xA2,
    LID386  = 0xA3,
    LIBHED  = 0xA4,
    LIBNAM  = 0xA6,
    LIBLOC  = 0xA8,
    LIBDIC  = 0xAA,
    COMDEF  = 0xB0,
    LEXTDEF = 0xB4,
    LPUBDEF = 0xB6,
    LCOMDEF = 0xB8,
    CEXTDEF = 0xBC,
    COMDAT  = 0xC2,
    LINSYM  = 0xC4,
    ALIAS   = 0xC6,
    LLNAMES = 0xCA,
}

// Some definitions for .OBJ files. Trial and error to determine which
// one to use when. Page #s refer to Intel spec on .OBJ files.

// Values for LOCAT byte: (pg. 71)
enum
{
    LOCATselfrel            = 0x8000,
    LOCATsegrel             = 0xC000,

// OR'd with one of the following:
    LOClobyte               = 0x0000,
    LOCbase                 = 0x0800,
    LOChibyte               = 0x1000,
    LOCloader_resolved      = 0x1400,

// Unfortunately, the fixup stuff is different for EASY OMF and Microsoft
    EASY_LOCoffset          = 0x1400,          // 32 bit offset
    EASY_LOCpointer         = 0x1800,          // 48 bit seg/offset

    LOC32offset             = 0x2400,
    LOC32tlsoffset          = 0x2800,
    LOC32pointer            = 0x2C00,

    LOC16offset             = 0x0400,
    LOC16pointer            = 0x0C00,

    LOCxx                   = 0x3C00
}

// FDxxxx are constants for the FIXDAT byte in fixup records (pg. 72)

enum
{
    FD_F0 = 0x00,            // segment index
    FD_F1 = 0x10,            // group index
    FD_F2 = 0x20,            // external index
    FD_F4 = 0x40,            // canonic frame of LSEG that contains Location
    FD_F5 = 0x50,            // Target determines the frame

    FD_T0 = 0,               // segment index
    FD_T1 = 1,               // group index
    FD_T2 = 2,               // external index
    FD_T4 = 4,               // segment index, 0 displacement
    FD_T5 = 5,               // group index, 0 displacement
    FD_T6 = 6,               // external index, 0 displacement
}

/***************
 * Fixup list.
 */

struct FIXUP
{
    FIXUP              *FUnext;
    targ_size_t         FUoffset;       // offset from start of ledata
    ushort              FUlcfd;         // LCxxxx | FDxxxx
    ushort              FUframedatum;
    ushort              FUtargetdatum;
}

@trusted
FIXUP* list_fixup(list_t fl) { return cast(FIXUP *)list_ptr(fl); }

int seg_is_comdat(int seg) { return seg < 0; }

/*****************************
 * Ledata records
 */

enum LEDATAMAX = 1024-14;

struct Ledatarec
{
    ubyte[14] header;           // big enough to handle COMDAT header
    ubyte[LEDATAMAX] data;
    int lseg;                   // segment value
    uint i;                     // number of bytes in data
    targ_size_t offset;         // segment offset of start of data
    FIXUP *fixuplist;           // fixups for this ledata

    // For COMDATs
    ubyte flags;                // flags byte of COMDAT
    ubyte alloctyp;             // allocation type of COMDAT
    ubyte _align;               // align type
    int typidx;
    int pubbase;
    int pubnamidx;
}

/*****************************
 * For defining segments.
 */

uint SEG_ATTR(uint A, uint C, uint B, uint P)
{
    return (A << 5) | (C << 2) | (B << 1) | P;
}

enum
{
// Segment alignment A
    SEG_ALIGN0    = 0,       // absolute segment
    SEG_ALIGN1    = 1,       // byte align
    SEG_ALIGN2    = 2,       // word align
    SEG_ALIGN16   = 3,       // paragraph align
    SEG_ALIGN4K   = 4,       // 4Kb page align
    SEG_ALIGN4    = 5,       // dword align

// Segment combine types C
    SEG_C_ABS     = 0,
    SEG_C_PUBLIC  = 2,
    SEG_C_STACK   = 5,
    SEG_C_COMMON  = 6,

// Segment type P
    USE16 = 0,
    USE32 = 1,

    USE32_CODE    = (4+2),          // use32 + execute/read
    USE32_DATA    = (4+3),          // use32 + read/write
}

/*****************************
 * Line number support.
 */

struct Linnum
{
version (MARS)
        const(char)* filename;  // source file name
else
        Sfile *filptr;          // file pointer

        int cseg;               // our internal segment number
        int seg;                // segment/public index
        Outbuffer data;         // linnum/offset data

        void reset() nothrow
        {
            data.reset();
        }
}

/*****************************
 */
struct PtrRef
{
  align(4):
    Symbol* sym;
    uint offset;
}

enum LINRECMAX = 2 + 255 * 2;   // room for 255 line numbers

/************************************
 * State of object file.
 */

struct Objstate
{
    const(char)* modname;
    char *csegname;
    Outbuffer *buf;     // output buffer

    int fdsegattr;      // far data segment attribute
    int csegattr;       // code segment attribute

    int lastfardatasegi;        // SegData[] index of last far data seg

    int LOCoffset;
    int LOCpointer;

    int mlidata;
    int mpubdef;
    int mfixupp;
    int mmodend;

    int lnameidx;               // index of next LNAMES record
    int segidx;                 // index of next SEGDEF record
    int extidx;                 // index of next EXTDEF record
    int pubnamidx;              // index of COMDAT public name index

    Symbol *startaddress;       // if !null, then Symbol is start address

    debug
    int fixup_count;

    // Line numbers
    char *linrec;               // line number record
    uint linreci;               // index of next avail in linrec[]
    uint linrecheader;          // size of line record header
    uint linrecnum;             // number of line record entries
    int mlinnum;
    int recseg;
    int term;
static if (MULTISCOPE)
{
    vec_t linvec;               // bit vector of line numbers used
    vec_t offvec;               // and offsets used
}

    int fisegi;                 // SegData[] index of FI segment

version (MARS)
{
    int fmsegi;                 // SegData[] of FM segment
    int datrefsegi;             // SegData[] of DATA pointer ref segment
    int tlsrefsegi;             // SegData[] of TLS pointer ref segment
}

    int tlssegi;                // SegData[] of tls segment
    int fardataidx;

    char[1024] pubdata;
    int pubdatai;

    char[1024] extdata;
    int extdatai;

    // For OmfObj_far16thunk
    int code16segi;             // SegData[] index
    targ_size_t CODE16offset;

    int fltused;
    int nullext;

    // The rest don't get re-zeroed for each object file, they get reset

    Rarray!(Ledatarec*) ledatas;
    Barray!(Symbol*) resetSymbols;  // reset symbols
    Rarray!(Linnum) linnum_list;
    Barray!(char*) linreclist;  // array of line records

version (MARS)
{
    Barray!PtrRef ptrrefs;      // buffer for pointer references
}
}

__gshared
{
    Rarray!(seg_data*) SegData;
    Objstate obj;
}


/*******************************
 * Output an object file data record.
 * Input:
 *      rectyp  =       record type
 *      record  .      the data
 *      reclen  =       # of bytes in record
 */

@trusted
void objrecord(uint rectyp, const(char)* record, uint reclen)
{
    Outbuffer *o = obj.buf;

    //printf("rectyp = x%x, record[0] = x%x, reclen = x%x\n",rectyp,record[0],reclen);
    o.reserve(reclen + 4);
    o.writeByten(cast(ubyte)rectyp);
    o.write16n(reclen + 1);  // record length includes checksum
    o.writen(record,reclen);
    o.writeByten(0);           // use 0 for checksum
}


/**************************
 * Insert an index number.
 * Input:
 *      p . where to put the 1 or 2 byte index
 *      index = the 15 bit index
 * Returns:
 *      # of bytes stored
 */

void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...);
void fatal();

void too_many_symbols()
{
version (SCPP)
    err_fatal(EM_too_many_symbols, 0x7FFF);
else // MARS
{
    error(null, 0, 0, "more than %d symbols in object file", 0x7FFF);
    fatal();
}
}

version (X86) version (DigitalMars)
    version = X86ASM;

version (X86ASM)
{
@trusted
int insidx(char *p,uint index)
{
    asm nothrow
    {
        naked                           ;
        mov     EAX,[ESP+8]             ; // index
        mov     ECX,[ESP+4]             ; // p

        cmp     EAX,0x7F                ;
        jae     L1                      ;
        mov     [ECX],AL                ;
        mov     EAX,1                   ;
        ret                             ;


    L1:                                 ;
        cmp     EAX,0x7FFF              ;
        ja      L2                      ;

        mov     [ECX+1],AL              ;
        or      EAX,0x8000              ;
        mov     [ECX],AH                ;
        mov     EAX,2                   ;
        ret                             ;
    }
    L2:
        too_many_symbols();
}
}
else
{
@trusted
int insidx(char *p,uint index)
{
    //if (index > 0x7FFF) printf("index = x%x\n",index);
    /* OFM spec says it could be <=0x7F, but that seems to cause
     * "library is corrupted" messages. Unverified. See Bugzilla 3601
     */
    if (index < 0x7F)
    {
        *p = cast(char)index;
        return 1;
    }
    else if (index <= 0x7FFF)
    {
        *(p + 1) = cast(char)index;
        *p = cast(char)((index >> 8) | 0x80);
        return 2;
    }
    else
    {
        too_many_symbols();
        return 0;
    }
}
}

/**************************
 * Insert a type index number.
 * Input:
 *      p . where to put the 1 or 2 byte index
 *      index = the 15 bit index
 * Returns:
 *      # of bytes stored
 */
@trusted
int instypidx(char *p,uint index)
{
    if (index <= 127)
    {   *p = cast(char)index;
        return 1;
    }
    else if (index <= 0x7FFF)
    {   *(p + 1) = cast(char)index;
        *p = cast(char)((index >> 8) | 0x80);
        return 2;
    }
    else                        // overflow
    {   *p = 0;                 // the linker ignores this field anyway
        return 1;
    }
}

/****************************
 * Read index.
 */
@trusted
int getindex(ubyte* p)
{
    return ((*p & 0x80)
    ? ((*p & 0x7F) << 8) | *(p + 1)
    : *p);
}

enum ONS_OHD = 4;               // max # of extra bytes added by obj_namestring()

/******************************
 * Allocate a new segment.
 * Return index for the new segment.
 */
@trusted
seg_data *getsegment()
{
    const int seg = cast(int)SegData.length;
    seg_data** ppseg = SegData.push();

    seg_data* pseg = *ppseg;
    if (!pseg)
    {
        pseg = cast(seg_data *)mem_calloc(seg_data.sizeof);
        //printf("test2: SegData[%d] = %p\n", seg, SegData[seg]);
        SegData[seg] = pseg;
    }
    else
        memset(pseg, 0, seg_data.sizeof);

    pseg.SDseg = seg;
    pseg.segidx = 0;
    return pseg;
}

/**************************
 * Output read only data and generate a symbol for it.
 *
 */

Symbol * OmfObj_sym_cdata(tym_t ty,char *p,int len)
{
    Symbol *s;

    alignOffset(CDATA, tysize(ty));
    s = symboldata(Offset(CDATA), ty);
    s.Sseg = CDATA;
    OmfObj_bytes(CDATA, Offset(CDATA), len, p);
    Offset(CDATA) += len;

    s.Sfl = FLdata; //FLextern;
    return s;
}

/**************************
 * Ouput read only data for data.
 * Output:
 *      *pseg   segment of that data
 * Returns:
 *      offset of that data
 */

int OmfObj_data_readonly(char *p, int len, int *pseg)
{
version (MARS)
{
    targ_size_t oldoff = Offset(CDATA);
    OmfObj_bytes(CDATA,Offset(CDATA),len,p);
    Offset(CDATA) += len;
    *pseg = CDATA;
}
else
{
    targ_size_t oldoff = Offset(DATA);
    OmfObj_bytes(DATA,Offset(DATA),len,p);
    Offset(DATA) += len;
    *pseg = DATA;
}
    return cast(int)oldoff;
}

@trusted
int OmfObj_data_readonly(char *p, int len)
{
    int pseg;

    return OmfObj_data_readonly(p, len, &pseg);
}

/*****************************
 * Get segment for readonly string literals.
 * The linker will pool strings in this section.
 * Params:
 *    sz = number of bytes per character (1, 2, or 4)
 * Returns:
 *    segment index
 */
int OmfObj_string_literal_segment(uint sz)
{
    assert(0);
}

segidx_t OmfObj_seg_debugT()
{
    return DEBTYP;
}

/******************************
 * Perform initialization that applies to all .obj output files.
 * Input:
 *      filename        source file name
 *      csegname        code segment name (can be null)
 */

@trusted
Obj OmfObj_init(Outbuffer *objbuf, const(char)* filename, const(char)* csegname)
{
        //printf("OmfObj_init()\n");
        Obj mobj = cast(Obj)mem_calloc(__traits(classInstanceSize, Obj));

        // Zero obj up to ledatas
        memset(&obj,0,obj.ledatas.offsetof);

        obj.ledatas.reset();    // recycle the memory used by ledatas

        foreach (s; obj.resetSymbols)
            symbol_reset(s);
        obj.resetSymbols.reset();

        obj.buf = objbuf;
        obj.buf.reserve(40_000);

        obj.lastfardatasegi = -1;

        obj.mlidata = LIDATA;
        obj.mpubdef = PUBDEF;
        obj.mfixupp = FIXUPP;
        obj.mmodend = MODEND;
        obj.mlinnum = LINNUM;


        // Reset for different OBJ file formats
        if (I32)
        {   if (config.flags & CFGeasyomf)
            {   obj.LOCoffset = EASY_LOCoffset;
                obj.LOCpointer = EASY_LOCpointer;
            }
            else
            {
                obj.mlidata = LID386;
                obj.mpubdef = PUB386;
                obj.mfixupp = FIX386;
                obj.mmodend = MODEND + 1;
                obj.LOCoffset = LOC32offset;
                obj.LOCpointer = LOC32pointer;
            }
            obj.fdsegattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE32);
            obj.csegattr  = SEG_ATTR(SEG_ALIGN4, SEG_C_PUBLIC,0,USE32);
        }
        else
        {
            obj.LOCoffset  = LOC16offset;
            obj.LOCpointer = LOC16pointer;
            obj.fdsegattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE16);
            obj.csegattr  = SEG_ATTR(SEG_ALIGN2, SEG_C_PUBLIC,0,USE16);
        }

        if (config.flags4 & CFG4speed && // if optimized for speed
            config.target_cpu == TARGET_80486)
            // 486 is only CPU that really benefits from alignment
            obj.csegattr  = I32 ? SEG_ATTR(SEG_ALIGN16, SEG_C_PUBLIC,0,USE32)
                                : SEG_ATTR(SEG_ALIGN16, SEG_C_PUBLIC,0,USE16);

        SegData.reset();       // recycle memory
        getsegment();           // element 0 is reserved

        getsegment();
        getsegment();
        getsegment();
        getsegment();

        SegData[CODE].SDseg = CODE;
        SegData[DATA].SDseg = DATA;
        SegData[CDATA].SDseg = CDATA;
        SegData[UDATA].SDseg = UDATA;

        SegData[CODE].segidx = CODE;
        SegData[DATA].segidx = DATA;
        SegData[CDATA].segidx = CDATA;
        SegData[UDATA].segidx = UDATA;

        if (config.fulltypes)
        {
            getsegment();
            getsegment();

            SegData[DEBSYM].SDseg = DEBSYM;
            SegData[DEBTYP].SDseg = DEBTYP;

            SegData[DEBSYM].segidx = DEBSYM;
            SegData[DEBTYP].segidx = DEBTYP;
        }

        OmfObj_theadr(filename);
        obj.modname = filename;
        if (!csegname || !*csegname)            // if no code seg name supplied
            obj.csegname = objmodtoseg(obj.modname);    // generate one
        else
            obj.csegname = mem_strdup(csegname);        // our own copy
        objheader(obj.csegname);
        OmfObj_segment_group(0,0,0,0);             // obj seg and grp info
        ledata_new(cseg,0);             // so ledata is never null
        if (config.fulltypes)           // if full typing information
        {   objmod = mobj;
            cv_init();                  // initialize debug output code
        }

        return mobj;
}

/**************************
 * Initialize the start of object output for this particular .obj file.
 */

void OmfObj_initfile(const(char)* filename,const(char)* csegname, const(char)* modname)
{
}

/***************************
 * Fixup and terminate object file.
 */

void OmfObj_termfile()
{
}

/*********************************
 * Terminate package.
 */

@trusted
void OmfObj_term(const(char)* objfilename)
{
        //printf("OmfObj_term()\n");
        list_t dl;
        uint size;

version (SCPP)
{
        if (!errcnt)
        {
            obj_defaultlib();
            objflush_pointerRefs();
            outfixlist();               // backpatches
        }
}
else
{
        obj_defaultlib();
        objflush_pointerRefs();
        outfixlist();               // backpatches
}
        if (config.fulltypes)
            cv_term();                  // write out final debug info
        outextdata();                   // finish writing EXTDEFs
        outpubdata();                   // finish writing PUBDEFs

        // Put out LEDATA records and associated fixups
        for (size_t i = 0; i < obj.ledatas.length; i++)
        {   Ledatarec *d = obj.ledatas[i];

            if (d.i)                   // if any data in this record
            {   // Fill in header
                int headersize;
                int rectyp;
                assert(d.lseg > 0 && d.lseg < SegData.length);
                int lseg = SegData[d.lseg].segidx;
                char[(d.header).sizeof] header = void;

                if (seg_is_comdat(lseg))   // if COMDAT
                {
                    header[0] = d.flags | (d.offset ? 1 : 0); // continuation flag
                    header[1] = d.alloctyp;
                    header[2] = d._align;
                    TOOFFSET(header.ptr + 3,d.offset);
                    headersize = 3 + _tysize[TYint];
                    headersize += instypidx(header.ptr + headersize,d.typidx);
                    if ((header[1] & 0x0F) == 0)
                    {   // Group index
                        header[headersize] = (d.pubbase == DATA) ? 1 : 0;
                        headersize++;

                        // Segment index
                        headersize += insidx(header.ptr + headersize,d.pubbase);
                    }
                    headersize += insidx(header.ptr + headersize,d.pubnamidx);

                    rectyp = I32 ? COMDAT + 1 : COMDAT;
                }
                else
                {
                    rectyp = LEDATA;
                    headersize = insidx(header.ptr,lseg);
                    if (_tysize[TYint] == LONGSIZE || d.offset & ~0xFFFFL)
                    {   if (!(config.flags & CFGeasyomf))
                            rectyp++;
                        TOLONG(header.ptr + headersize,cast(uint)d.offset);
                        headersize += 4;
                    }
                    else
                    {
                        TOWORD(header.ptr + headersize,cast(uint)d.offset);
                        headersize += 2;
                    }
                }
                assert(headersize <= (d.header).sizeof);

                // Right-justify data in d.header[]
                memcpy(d.header.ptr + (d.header).sizeof - headersize,header.ptr,headersize);
                //printf("objrecord(rectyp=x%02x, d=%p, p=%p, size = %d)\n",
                //rectyp,d,d.header.ptr + ((d.header).sizeof - headersize),d.i + headersize);

                objrecord(rectyp,cast(char*)d.header.ptr + ((d.header).sizeof - headersize),
                        d.i + headersize);
                objfixupp(d.fixuplist);
            }
        }

static if (TERMCODE)
{
        //list_free(&obj.ledata_list,mem_freefp);
}

        linnum_term();
        obj_modend();

        size = cast(uint)obj.buf.length();
        obj.buf.reset();            // rewind file
        OmfObj_theadr(obj.modname);
        objheader(obj.csegname);
        mem_free(obj.csegname);
        OmfObj_segment_group(SegData[CODE].SDoffset, SegData[DATA].SDoffset, SegData[CDATA].SDoffset, SegData[UDATA].SDoffset);  // do real sizes

        // Update any out-of-date far segment sizes
        for (size_t i = 0; i < SegData.length; i++)
        {
            seg_data* f = SegData[i];
            if (f.isfarseg && f.origsize != f.SDoffset)
            {   obj.buf.setsize(cast(int)f.seek);
                objsegdef(f.attr,f.SDoffset,f.lnameidx,f.classidx);
            }
        }
        //mem_free(obj.farseg);

        //printf("Ledata max = %d\n", obj.ledatas.length);
        //printf("Max # of fixups = %d\n",obj.fixup_count);

        obj.buf.setsize(size);
}

/*****************************
 * Line number support.
 */

/***************************
 * Record line number linnum at offset.
 * Params:
 *      srcpos = source file position
 *      seg = segment it corresponds to (negative for COMDAT segments)
 *      offset = offset within seg
 *      pubnamidx = public name index
 *      obj.mlinnum = LINNUM or LINSYM
 */
@trusted
void OmfObj_linnum(Srcpos srcpos,int seg,targ_size_t offset)
{
version (MARS)
    varStats_recordLineOffset(srcpos, offset);

    uint linnum = srcpos.Slinnum;

static if (0)
{
    printf("OmfObj_linnum(seg=%d, offset=0x%x) ", seg, cast(int)offset);
    srcpos.print("");
}

    char linos2 = config.exe == EX_OS2 && !seg_is_comdat(SegData[seg].segidx);

version (MARS)
{
    bool cond = (!obj.term &&
        (seg_is_comdat(SegData[seg].segidx) || (srcpos.Sfilename && srcpos.Sfilename != obj.modname)));
}
else
{
    if (!srcpos.Sfilptr)
        return;
    sfile_debug(*srcpos.Sfilptr);
    bool cond = !obj.term &&
                (!(srcpos_sfile(srcpos).SFflags & SFtop) || (seg_is_comdat(SegData[seg].segidx) && !obj.term));
}
    if (cond)
    {
        // Not original source file, or a COMDAT.
        // Save data away and deal with it at close of compile.
        // It is done this way because presumably 99% of the lines
        // will be in the original source file, so we wish to minimize
        // memory consumption and maximize speed.

        if (linos2)
            return;             // BUG: not supported under OS/2

        Linnum* ln;
        foreach (ref rln; obj.linnum_list)
        {
            version (MARS)
                bool cond2 = rln.filename == srcpos.Sfilename;
            else version (SCPP)
                bool cond2 = rln.filptr == *srcpos.Sfilptr;

            if (cond2 &&
                rln.cseg == seg)
            {
                ln = &rln;      // found existing entry with room
                goto L1;
            }
        }
        // Create new entry
        ln = obj.linnum_list.push();
        version (MARS)
            ln.filename = srcpos.Sfilename;
        else
            ln.filptr = *srcpos.Sfilptr;

        ln.cseg = seg;
        ln.seg = obj.pubnamidx;
        ln.reset();

    L1:
        //printf("offset = x%x, line = %d\n", (int)offset, linnum);
        ln.data.write16(linnum);
        if (_tysize[TYint] == 2)
            ln.data.write16(cast(int)offset);
        else
            ln.data.write32(cast(int)offset);
    }
    else
    {
        if (linos2 && obj.linreci > LINRECMAX - 8)
            obj.linrec = null;                  // allocate a new one
        else if (seg != obj.recseg)
            linnum_flush();

        if (!obj.linrec)                        // if not allocated
        {
            obj.linrec = cast(char* ) mem_calloc(LINRECMAX);
            obj.linrec[0] = 0;              // base group / flags
            obj.linrecheader = 1 + insidx(obj.linrec + 1,seg_is_comdat(SegData[seg].segidx) ? obj.pubnamidx : SegData[seg].segidx);
            obj.linreci = obj.linrecheader;
            obj.recseg = seg;
static if (MULTISCOPE)
{
            if (!obj.linvec)
            {
                obj.linvec = vec_calloc(1000);
                obj.offvec = vec_calloc(1000);
            }
}
            if (linos2)
            {
                if (obj.linreclist.length == 0)  // if first line number record
                    obj.linreci += 8;       // leave room for header
                obj.linreclist.push(obj.linrec);
            }

            // Select record type to use
            obj.mlinnum = seg_is_comdat(SegData[seg].segidx) ? LINSYM : LINNUM;
            if (I32 && !(config.flags & CFGeasyomf))
                obj.mlinnum++;
        }
        else if (obj.linreci > LINRECMAX - (2 + _tysize[TYint]))
        {
            objrecord(obj.mlinnum,obj.linrec,obj.linreci);  // output data
            obj.linreci = obj.linrecheader;
            if (seg_is_comdat(SegData[seg].segidx))        // if LINSYM record
                obj.linrec[0] |= 1;         // continuation bit
        }
static if (MULTISCOPE)
{
        if (linnum >= vec_numbits(obj.linvec))
            obj.linvec = vec_realloc(obj.linvec,linnum + 1000);
        if (offset >= vec_numbits(obj.offvec))
        {
            if (offset < 0xFF00)        // otherwise we overflow ph_malloc()
                obj.offvec = vec_realloc(obj.offvec,cast(uint)offset * 2);
        }
        bool cond3 =
            // disallow multiple offsets per line
            !vec_testbit(linnum,obj.linvec) &&  // if linnum not already used

            // disallow multiple lines per offset
            (offset >= 0xFF00 || !vec_testbit(cast(uint)offset,obj.offvec));      // and offset not already used
}
else
        enum cond3 = true;

        if (cond3)
        {
static if (MULTISCOPE)
{
            vec_setbit(linnum,obj.linvec);              // mark linnum as used
            if (offset < 0xFF00)
                vec_setbit(cast(uint)offset,obj.offvec);  // mark offset as used
}
            TOWORD(obj.linrec + obj.linreci,linnum);
            if (linos2)
            {
                obj.linrec[obj.linreci + 2] = 1;        // source file index
                TOLONG(obj.linrec + obj.linreci + 4,cast(uint)offset);
                obj.linrecnum++;
                obj.linreci += 8;
            }
            else
            {
                TOOFFSET(obj.linrec + obj.linreci + 2,offset);
                obj.linreci += 2 + _tysize[TYint];
            }
        }
    }
}

/***************************
 * Flush any pending line number records.
 */

@trusted
private void linnum_flush()
{
    if (obj.linreclist.length)
    {
        obj.linrec = obj.linreclist[0];
        TOWORD(obj.linrec + 6,obj.linrecnum);

        foreach (i; 0 .. obj.linreclist.length - 1)
        {
            obj.linrec = obj.linreclist[i];
            objrecord(obj.mlinnum, obj.linrec, LINRECMAX);
            mem_free(obj.linrec);
        }
        obj.linrec = obj.linreclist[obj.linreclist.length - 1];
        objrecord(obj.mlinnum,obj.linrec,obj.linreci);
        obj.linreclist.reset();

        // Put out File Names Table
        TOLONG(obj.linrec + 2,0);               // record no. of start of source (???)
        TOLONG(obj.linrec + 6,obj.linrecnum);   // number of primary source records
        TOLONG(obj.linrec + 10,1);              // number of source and listing files
        const len = obj_namestring(obj.linrec + 14,obj.modname);
        assert(14 + len <= LINRECMAX);
        objrecord(obj.mlinnum,obj.linrec,cast(uint)(14 + len));

        mem_free(obj.linrec);
        obj.linrec = null;
    }
    else if (obj.linrec)                        // if some line numbers to send
    {
        objrecord(obj.mlinnum,obj.linrec,obj.linreci);
        mem_free(obj.linrec);
        obj.linrec = null;
    }
static if (MULTISCOPE)
{
    vec_clear(obj.linvec);
    vec_clear(obj.offvec);
}
}

/*************************************
 * Terminate line numbers.
 */

@trusted
private void linnum_term()
{
version (SCPP)
    Sfile *lastfilptr = null;

version (MARS)
    const(char)* lastfilename = null;

    const csegsave = cseg;

    linnum_flush();
    obj.term = 1;

    foreach (ref ln; obj.linnum_list)
    {
        version (SCPP)
        {
            Sfile *filptr = ln.filptr;
            if (filptr != lastfilptr)
            {
                if (lastfilptr == null && strcmp(filptr.SFname,obj.modname))
                    OmfObj_theadr(filptr.SFname);
                lastfilptr = filptr;
            }
        }
        version (MARS)
        {
            const(char)* filename = ln.filename;
            if (filename != lastfilename)
            {
                if (filename)
                    objmod.theadr(filename);
                lastfilename = filename;
            }
        }
        cseg = ln.cseg;
        assert(cseg > 0);
        obj.pubnamidx = ln.seg;

        Srcpos srcpos;
        version (MARS)
            srcpos.Sfilename = ln.filename;
        else
            srcpos.Sfilptr = &ln.filptr;

        const slice = ln.data[];
        const pend = slice.ptr + slice.length;
        for (const(ubyte)* p = slice.ptr; p < pend; )
        {
            srcpos.Slinnum = *cast(ushort *)p;
            p += 2;
            targ_size_t offset;
            if (I32)
            {
                offset = *cast(uint *)p;
                p += 4;
            }
            else
            {
                offset = *cast(ushort *)p;
                p += 2;
            }
            OmfObj_linnum(srcpos,cseg,offset);
        }
        linnum_flush();
    }

    obj.linnum_list.reset();
    cseg = csegsave;
    assert(cseg > 0);
static if (MULTISCOPE)
{
    vec_free(obj.linvec);
    vec_free(obj.offvec);
}
}

/*******************************
 * Set start address
 */

@trusted
void OmfObj_startaddress(Symbol *s)
{
    obj.startaddress = s;
}

/*******************************
 * Output DOSSEG coment record.
 */
@trusted
void OmfObj_dosseg()
{
    static immutable char[2] dosseg = [ 0x80,0x9E ];

    objrecord(COMENT, dosseg.ptr, dosseg.sizeof);
}

/*******************************
 * Embed comment record.
 */

@trusted
private void obj_comment(ubyte x, const(char)* string, size_t len)
{
    char[128] buf = void;

    char *library = (2 + len <= buf.sizeof) ? buf.ptr : cast(char *) malloc(2 + len);
    assert(library);
    library[0] = 0;
    library[1] = x;
    memcpy(library + 2,string,len);
    objrecord(COMENT,library,cast(uint)(len + 2));
    if (library != buf.ptr)
        free(library);
}

/*******************************
 * Output library name.
 * Output:
 *      name is modified
 * Returns:
 *      true if operation is supported
 */

@trusted
bool OmfObj_includelib(const(char)* name)
{
    const(char)* p;
    size_t len = strlen(name);

    p = filespecdotext(name);
    if (!filespeccmp(p,".lib"))
        len -= strlen(p);               // lop off .LIB extension
    obj_comment(0x9F, name, len);
    return true;
}

/*******************************
* Output linker directive.
* Output:
*      directive is modified
* Returns:
*      true if operation is supported
*/

bool OmfObj_linkerdirective(const(char)* name)
{
    return false;
}

/**********************************
 * Do we allow zero sized objects?
 */

bool OmfObj_allowZeroSize()
{
    return false;
}

/**************************
 * Embed string in executable.
 */

@trusted
void OmfObj_exestr(const(char)* p)
{
    obj_comment(0xA4,p, strlen(p));
}

/**************************
 * Embed string in obj.
 */

@trusted
void OmfObj_user(const(char)* p)
{
    obj_comment(0xDF,p, strlen(p));
}

/*********************************
 * Put out default library name.
 */

@trusted
private void obj_defaultlib()
{
    char[4] library;            // default library
    static immutable char[5+1] model = "SMCLV";

version (MARS)
    memcpy(library.ptr,"SM?".ptr,4);
else
    memcpy(library.ptr,"SD?".ptr,4);

    switch (config.exe)
    {
        case EX_OS2:
            library[2] = 'F';
            goto case;

        case EX_OS1:
            library[1] = 'O';
            break;
        case EX_WIN32:
version (MARS)
            library[1] = 'M';
else
            library[1] = 'N';

            library[2] = (config.flags4 & CFG4dllrtl) ? 'D' : 'N';
            break;
        case EX_DOSX:
        case EX_PHARLAP:
            library[2] = 'X';
            break;
        default:
            library[2] = model[config.memmodel];
            if (config.wflags & WFwindows)
                library[1] = 'W';
            break;
    }

    if (!(config.flags2 & CFG2nodeflib))
    {
        objmod.includelib(configv.deflibname ? configv.deflibname : library.ptr);
    }
}

/*******************************
 * Output a weak extern record.
 * s1 is the weak extern, s2 is its default resolution.
 */

@trusted
void OmfObj_wkext(Symbol *s1,Symbol *s2)
{
    //printf("OmfObj_wkext(%s)\n", s1.Sident.ptr);
    if (I32)
    {
        // Optlink crashes with weak symbols at EIP 41AFE7, 402000
        return;
    }

    int x2;
    if (s2)
        x2 = s2.Sxtrnnum;
    else
    {
        if (!obj.nullext)
        {
            obj.nullext = OmfObj_external_def("__nullext");
        }
        x2 = obj.nullext;
    }
    outextdata();

    char[2+2+2] buffer = void;
    buffer[0] = 0x80;
    buffer[1] = 0xA8;
    int i = 2;
    i += insidx(&buffer[2],s1.Sxtrnnum);
    i += insidx(&buffer[i],x2);
    objrecord(COMENT,buffer.ptr,i);
}

/*******************************
 * Output a lazy extern record.
 * s1 is the lazy extern, s2 is its default resolution.
 */
@trusted
void OmfObj_lzext(Symbol *s1,Symbol *s2)
{
    char[2+2+2] buffer = void;
    int i;

    outextdata();
    buffer[0] = 0x80;
    buffer[1] = 0xA9;
    i = 2;
    i += insidx(&buffer[2],s1.Sxtrnnum);
    i += insidx(&buffer[i],s2.Sxtrnnum);
    objrecord(COMENT,buffer.ptr,i);
}

/*******************************
 * Output an alias definition record.
 */

@trusted
void OmfObj_alias(const(char)* n1,const(char)* n2)
{
    uint len;
    char* buffer;

    buffer = cast(char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
}

/*******************************
 * Output module name record.
 */

@trusted
void OmfObj_theadr(const(char)* modname)
{
    //printf("OmfObj_theadr(%s)\n", modname);

    // Convert to absolute file name, so debugger can find it anywhere
    char[260] absname = void;
    if (config.fulltypes &&
        modname[0] != '\\' && modname[0] != '/' && !(modname[0] && modname[1] == ':'))
    {
        if (getcwd(absname.ptr, absname.sizeof))
        {
            int len = cast(int)strlen(absname.ptr);
            if(absname[len - 1] != '\\' && absname[len - 1] != '/')
                absname[len++] = '\\';
            strcpy(absname.ptr + len, modname);
            modname = absname.ptr;
        }
    }

    char *theadr = cast(char *)alloca(ONS_OHD + strlen(modname));
    int i = obj_namestring(theadr,modname);
    objrecord(THEADR,theadr,i);                 // module name record
}

/*******************************
 * Embed compiler version in .obj file.
 */

@trusted
void OmfObj_compiler()
{
    const(char)* compiler = "\0\xDB" ~ "Digital Mars C/C++"
        ~ VERSION
        ;       // compiled by ...

    objrecord(COMENT,compiler,cast(uint)strlen(compiler));
}

/*******************************
 * Output header stuff for object files.
 * Input:
 *      csegname        Name to use for code segment (null if use default)
 */

enum CODECLASS  = 4;    // code class lname index
enum DATACLASS  = 6;    // data class lname index
enum CDATACLASS = 7;    // CONST class lname index
enum BSSCLASS   = 9;    // BSS class lname index

@trusted
private void objheader(char *csegname)
{
  char *nam;
    __gshared char[78] lnames =
        "\0\06DGROUP\05_TEXT\04CODE\05_DATA\04DATA\05CONST\04_BSS\03BSS" ~
        "\07$$TYPES\06DEBTYP\011$$SYMBOLS\06DEBSYM";
    assert(lnames[lnames.length - 2] == 'M');

    // Include debug segment names if inserting type information
    int lnamesize = config.fulltypes ? lnames.sizeof - 1 : lnames.sizeof - 1 - 32;
    int texti = 8;                                // index of _TEXT

    __gshared char[5] comment = [0,0x9D,'0','?','O']; // memory model
    __gshared char[5+1] model = "smclv";
    __gshared char[5] exten = [0,0xA1,1,'C','V'];     // extended format
    __gshared char[7] pmdeb = [0x80,0xA1,1,'H','L','L',0];    // IBM PM debug format

    if (I32)
    {
        if (config.flags & CFGeasyomf)
        {
            // Indicate we're in EASY OMF (hah!) format
            static immutable char[7] easy_omf = [ 0x80,0xAA,'8','0','3','8','6' ];
            objrecord(COMENT,easy_omf.ptr,easy_omf.sizeof);
        }
    }

    // Send out a comment record showing what memory model was used
    comment[2] = cast(char)(config.target_cpu + '0');
    comment[3] = model[config.memmodel];
    if (I32)
    {
        if (config.exe == EX_WIN32)
            comment[3] = 'n';
        else if (config.exe == EX_OS2)
            comment[3] = 'f';
        else
            comment[3] = 'x';
    }
    objrecord(COMENT,comment.ptr,comment.sizeof);

    // Send out comment indicating we're using extensions to .OBJ format
    if (config.exe == EX_OS2)
        objrecord(COMENT, pmdeb.ptr, pmdeb.sizeof);
    else
        objrecord(COMENT, exten.ptr, exten.sizeof);

    // Change DGROUP to FLAT if we are doing flat memory model
    // (Watch out, objheader() is called twice!)
    if (config.exe & EX_flat)
    {
        if (lnames[2] != 'F')                   // do not do this twice
        {
            memcpy(lnames.ptr + 1, "\04FLAT".ptr, 5);
            memmove(lnames.ptr + 6, lnames.ptr + 8, lnames.sizeof - 8);
        }
        lnamesize -= 2;
        texti -= 2;
    }

    // Put out segment and group names
    if (csegname)
    {
        // Replace the module name _TEXT with the new code segment name
        const size_t i = strlen(csegname);
        char *p = cast(char *)alloca(lnamesize + i - 5);
        memcpy(p,lnames.ptr,8);
        p[texti] = cast(char)i;
        texti++;
        memcpy(p + texti,csegname,i);
        memcpy(p + texti + i,lnames.ptr + texti + 5,lnamesize - (texti + 5));
        objrecord(LNAMES,p,cast(uint)(lnamesize + i - 5));
    }
    else
        objrecord(LNAMES,lnames.ptr,lnamesize);
}

/********************************
 * Convert module name to code segment name.
 * Output:
 *      mem_malloc'd code seg name
 */

@trusted
private char*  objmodtoseg(const(char)* modname)
{
    char* csegname = null;

    if (LARGECODE)              // if need to add in module name
    {
        int i;
        char* m;
        static immutable char[6] suffix = "_TEXT";

        // Prepend the module name to the beginning of the _TEXT
        m = filespecgetroot(filespecname(modname));
        strupr(m);
        i = cast(int)strlen(m);
        csegname = cast(char *)mem_malloc(i + suffix.sizeof);
        strcpy(csegname,m);
        strcat(csegname,suffix.ptr);
        mem_free(m);
    }
    return csegname;
}

/*********************************
 * Put out a segment definition.
 */

@trusted
private void objsegdef(int attr,targ_size_t size,int segnamidx,int classnamidx)
{
    uint reclen;
    char[1+4+2+2+2+1] sd = void;

    //printf("objsegdef(attr=x%x, size=x%x, segnamidx=x%x, classnamidx=x%x)\n",
      //attr,size,segnamidx,classnamidx);
    sd[0] = cast(char)attr;
    if (attr & 1 || config.flags & CFGeasyomf)
    {
        TOLONG(sd.ptr + 1, cast(uint)size);          // store segment size
        reclen = 5;
    }
    else
    {
        debug
        assert(size <= 0xFFFF);

        TOWORD(sd.ptr + 1,cast(uint)size);
        reclen = 3;
    }
    reclen += insidx(sd.ptr + reclen,segnamidx);    // segment name index
    reclen += insidx(sd.ptr + reclen,classnamidx);  // class name index
    sd[reclen] = 1;                             // overlay name index
    reclen++;
    if (attr & 1)                       // if USE32
    {
        if (config.flags & CFGeasyomf)
        {
            // Translate to Pharlap format
            sd[0] &= ~1;                // turn off P bit

            // Translate A: 4.6
            attr &= SEG_ATTR(7,0,0,0);
            if (attr == SEG_ATTR(4,0,0,0))
                sd[0] ^= SEG_ATTR(4 ^ 6,0,0,0);

            // 2 is execute/read
            // 3 is read/write
            // 4 is use32
            sd[reclen] = (classnamidx == 4) ? (4+2) : (4+3);
            reclen++;
        }
    }
    else                                // 16 bit segment
    {
version (MARS)
        assert(0);
else
{
        if (size & ~0xFFFFL)
        {
            if (size == 0x10000)        // if exactly 64Kb
                sd[0] |= 2;             // set "B" bit
            else
                synerr(EM_seg_gt_64k,size);     // segment exceeds 64Kb
        }
//printf("attr = %x\n", attr);
}
    }
    debug
    assert(reclen <= sd.sizeof);

    objrecord(SEGDEF + (sd[0] & 1),sd.ptr,reclen);
}

/*********************************
 * Output segment and group definitions.
 * Input:
 *      codesize        size of code segment
 *      datasize        size of initialized data segment
 *      cdatasize       size of initialized const data segment
 *      udatasize       size of uninitialized data segment
 */

@trusted
void OmfObj_segment_group(targ_size_t codesize,targ_size_t datasize,
                targ_size_t cdatasize,targ_size_t udatasize)
{
    int dsegattr;
    int dsymattr;

    // Group into DGROUP the segments CONST, _BSS and _DATA
    // For FLAT model, it's just GROUP FLAT
    static immutable char[7] grpdef = [2,0xFF,2,0xFF,3,0xFF,4];

    objsegdef(obj.csegattr,codesize,3,CODECLASS);  // seg _TEXT, class CODE

version (MARS)
{
    dsegattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE32);
    objsegdef(dsegattr,datasize,5,DATACLASS);   // [DATA]  seg _DATA, class DATA
    objsegdef(dsegattr,cdatasize,7,CDATACLASS); // [CDATA] seg CONST, class CONST
    objsegdef(dsegattr,udatasize,8,BSSCLASS);   // [UDATA] seg _BSS,  class BSS
}
else
{
    dsegattr = I32
          ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
          : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);
    objsegdef(dsegattr,datasize,5,DATACLASS);   // seg _DATA, class DATA
    objsegdef(dsegattr,cdatasize,7,CDATACLASS); // seg CONST, class CONST
    objsegdef(dsegattr,udatasize,8,BSSCLASS);   // seg _BSS, class BSS
}

    obj.lnameidx = 10;                          // next lname index
    obj.segidx = 5;                             // next segment index

    if (config.fulltypes)
    {
        dsymattr = I32
              ? SEG_ATTR(SEG_ALIGN1,SEG_C_ABS,0,USE32)
              : SEG_ATTR(SEG_ALIGN1,SEG_C_ABS,0,USE16);

        if (config.exe & EX_flat)
        {
            // IBM's version of CV uses dword aligned segments
            dsymattr = SEG_ATTR(SEG_ALIGN4,SEG_C_ABS,0,USE32);
        }
        else if (config.fulltypes == CV4)
        {
            // Always use 32 bit segments
            dsymattr |= USE32;
            assert(!(config.flags & CFGeasyomf));
        }
        objsegdef(dsymattr,SegData[DEBSYM].SDoffset,0x0C,0x0D);
        objsegdef(dsymattr,SegData[DEBTYP].SDoffset,0x0A,0x0B);
        obj.lnameidx += 4;                      // next lname index
        obj.segidx += 2;                        // next segment index
    }

    objrecord(GRPDEF,grpdef.ptr,(config.exe & EX_flat) ? 1 : grpdef.sizeof);
static if (0)
{
    // Define fixup threads, we don't use them
    {
        static immutable char[12] thread = [ 0,3,1,2,2,1,3,4,0x40,1,0x45,1 ];
        objrecord(obj.mfixupp,thread.ptr,thread.sizeof);
    }
    // This comment appears to indicate that no more PUBDEFs, EXTDEFs,
    // or COMDEFs are coming.
    {
        static immutable char[3] cv = [0,0xA2,1];
        objrecord(COMENT,cv.ptr,cv.sizeof);
    }
}
}


/**************************************
 * Symbol is the function that calls the static constructors.
 * Put a pointer to it into a special segment that the startup code
 * looks at.
 * Input:
 *      s       static constructor function
 *      dtor    number of static destructors
 *      seg     1:      user
 *              2:      lib
 *              3:      compiler
 */
@trusted
void OmfObj_staticctor(Symbol *s,int dtor,int seg)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static immutable char[28] lnamector = "\05XIFCB\04XIFU\04XIFL\04XIFM\05XIFCE";
    static immutable char[15] lnamedtor = "\04XOFB\03XOF\04XOFE";
    static immutable char[12] lnamedtorf = "\03XOB\02XO\03XOE";

    symbol_debug(s);

    // Determine if near or far function
    assert(I32 || tyfarfunc(s.ty()));

    // Put out LNAMES record
    objrecord(LNAMES,lnamector.ptr,lnamector.sizeof - 1);

    int dsegattr = I32
        ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
        : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

    for (int i = 0; i < 5; i++)
    {
        int sz;

        sz = (i == seg) ? 4 : 0;

        // Put out segment definition record
        objsegdef(dsegattr,sz,obj.lnameidx,DATACLASS);

        if (i == seg)
        {
            seg_data *pseg = getsegment();
            pseg.segidx = obj.segidx;
            OmfObj_reftoident(pseg.SDseg,0,s,0,0);     // put out function pointer
        }

        obj.segidx++;
        obj.lnameidx++;
    }

    if (dtor)
    {
        // Leave space in XOF segment so that __fatexit() can insert a
        // pointer to the static destructor in XOF.

        // Put out LNAMES record
        if (LARGEDATA)
            objrecord(LNAMES,lnamedtorf.ptr,lnamedtorf.sizeof - 1);
        else
            objrecord(LNAMES,lnamedtor.ptr,lnamedtor.sizeof - 1);

        // Put out beginning segment
        objsegdef(dsegattr,0,obj.lnameidx,BSSCLASS);

        // Put out segment definition record
        objsegdef(dsegattr,4 * dtor,obj.lnameidx + 1,BSSCLASS);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 2,BSSCLASS);

        obj.lnameidx += 3;                      // for next time
        obj.segidx += 3;
    }
}

void OmfObj_staticdtor(Symbol *s)
{
    assert(0);
}


/***************************************
 * Set up function to be called as static constructor on program
 * startup or static destructor on program shutdown.
 * Params:
 *      s = function symbol
 *      isCtor = true if constructor, false if destructor
 */

@trusted
void OmfObj_setModuleCtorDtor(Symbol *s, bool isCtor)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static immutable char[5+4+5+1][4] lnames =
    [   "\03XIB\02XI\03XIE",            // near constructor
        "\03XCB\02XC\03XCE",            // near destructor
        "\04XIFB\03XIF\04XIFE",         // far constructor
        "\04XCFB\03XCF\04XCFE",         // far destructor
    ];
    // Size of each of the above strings
    static immutable int[4] lnamesize = [ 4+3+4,4+3+4,5+4+5,5+4+5 ];

    int dsegattr;

    symbol_debug(s);

version (SCPP)
    debug assert(memcmp(s.Sident.ptr,"_ST".ptr,3) == 0);

    // Determine if constructor or destructor
    // _STI... is a constructor, _STD... is a destructor
    int i = !isCtor;
    // Determine if near or far function
    if (tyfarfunc(s.Stype.Tty))
        i += 2;

    // Put out LNAMES record
    objrecord(LNAMES,lnames[i].ptr,lnamesize[i]);

    dsegattr = I32
        ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
        : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

    // Put out beginning segment
    objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
    obj.segidx++;

    // Put out segment definition record
    // size is NPTRSIZE or FPTRSIZE
    objsegdef(dsegattr,(i & 2) + tysize(TYnptr),obj.lnameidx + 1,DATACLASS);
    seg_data *pseg = getsegment();
    pseg.segidx = obj.segidx;
    OmfObj_reftoident(pseg.SDseg,0,s,0,0);     // put out function pointer
    obj.segidx++;

    // Put out ending segment
    objsegdef(dsegattr,0,obj.lnameidx + 2,DATACLASS);
    obj.segidx++;

    obj.lnameidx += 3;                  // for next time
}


/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */
@trusted
void OmfObj_ehtables(Symbol *sfunc,uint size,Symbol *ehsym)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static immutable char[12] lnames =
       "\03FIB\02FI\03FIE";             // near constructor
    int i;
    int dsegattr;
    targ_size_t offset;

    symbol_debug(sfunc);

    if (obj.fisegi == 0)
    {
        // Put out LNAMES record
        objrecord(LNAMES,lnames.ptr,lnames.sizeof - 1);

        dsegattr = I32
            ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
            : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

        // Put out beginning segment
        objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
        obj.lnameidx++;
        obj.segidx++;

        // Put out segment definition record
        obj.fisegi = obj_newfarseg(0,DATACLASS);
        objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
        SegData[obj.fisegi].attr = dsegattr;
        assert(SegData[obj.fisegi].segidx == obj.segidx);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 1,DATACLASS);

        obj.lnameidx += 2;              // for next time
        obj.segidx += 2;
    }
    offset = SegData[obj.fisegi].SDoffset;
    offset += OmfObj_reftoident(obj.fisegi,offset,sfunc,0,LARGECODE ? CFoff | CFseg : CFoff);   // put out function pointer
    offset += OmfObj_reftoident(obj.fisegi,offset,ehsym,0,0);   // pointer to data
    OmfObj_bytes(obj.fisegi,offset,_tysize[TYint],&size);          // size of function
    SegData[obj.fisegi].SDoffset = offset + _tysize[TYint];
}

void OmfObj_ehsections()
{
    assert(0);
}

/***************************************
 * Append pointer to ModuleInfo to "FM" segment.
 * The FM segment is bracketed by the empty FMB and FME segments.
 */

version (MARS)
{

@trusted
void OmfObj_moduleinfo(Symbol *scc)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static immutable char[12] lnames =
        "\03FMB\02FM\03FME";

    symbol_debug(scc);

    if (obj.fmsegi == 0)
    {
        // Put out LNAMES record
        objrecord(LNAMES,lnames.ptr,lnames.sizeof - 1);

        int dsegattr = I32
            ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
            : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

        // Put out beginning segment
        objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
        obj.lnameidx++;
        obj.segidx++;

        // Put out segment definition record
        obj.fmsegi = obj_newfarseg(0,DATACLASS);
        objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
        SegData[obj.fmsegi].attr = dsegattr;
        assert(SegData[obj.fmsegi].segidx == obj.segidx);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 1,DATACLASS);

        obj.lnameidx += 2;              // for next time
        obj.segidx += 2;
    }

    targ_size_t offset = SegData[obj.fmsegi].SDoffset;
    offset += OmfObj_reftoident(obj.fmsegi,offset,scc,0,LARGECODE ? CFoff | CFseg : CFoff);     // put out function pointer
    SegData[obj.fmsegi].SDoffset = offset;
}

}


/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *      cseg            segment index of new current code segment
 *      Coffset         starting offset in cseg
 * Returns:
 *      "segment index" of COMDAT (which will be a negative value to
 *      distinguish it from regular segments).
 */

int OmfObj_comdatsize(Symbol *s, targ_size_t symsize)
{
    return generate_comdat(s, false);
}

int OmfObj_comdat(Symbol *s)
{
    return generate_comdat(s, false);
}

int OmfObj_readonly_comdat(Symbol *s)
{
    s.Sseg = generate_comdat(s, true);
    return s.Sseg;
}

@trusted
static int generate_comdat(Symbol *s, bool is_readonly_comdat)
{
    char[IDMAX+IDOHD+1] lnames = void; // +1 to allow room for strcpy() terminating 0
    char[2+2] cextdef = void;
    char *p;
    size_t lnamesize;
    uint ti;
    int isfunc;
    tym_t ty;

    symbol_debug(s);
    obj.resetSymbols.push(s);
    ty = s.ty();
    isfunc = tyfunc(ty) != 0 || is_readonly_comdat;

    // Put out LNAME for name of Symbol
    lnamesize = OmfObj_mangle(s,lnames.ptr);
    objrecord((s.Sclass == SCstatic ? LLNAMES : LNAMES),lnames.ptr,cast(uint)lnamesize);

    // Put out CEXTDEF for name of Symbol
    outextdata();
    p = cextdef.ptr;
    p += insidx(p,obj.lnameidx++);
    ti = (config.fulltypes == CVOLD) ? cv_typidx(s.Stype) : 0;
    p += instypidx(p,ti);
    objrecord(CEXTDEF,cextdef.ptr,cast(uint)(p - cextdef.ptr));
    s.Sxtrnnum = ++obj.extidx;

    seg_data *pseg = getsegment();
    pseg.segidx = -obj.extidx;
    assert(pseg.SDseg > 0);

    // Start new LEDATA record for this COMDAT
    Ledatarec *lr = ledata_new(pseg.SDseg,0);
    lr.typidx = ti;
    lr.pubnamidx = obj.lnameidx - 1;
    if (isfunc)
    {   lr.pubbase = SegData[cseg].segidx;
        if (s.Sclass == SCcomdat || s.Sclass == SCinline)
            lr.alloctyp = 0x10 | 0x00; // pick any instance | explicit allocation
        if (is_readonly_comdat)
        {
            assert(lr.lseg > 0 && lr.lseg < SegData.length);
            lr.flags |= 0x08;      // data in code seg
        }
        else
        {
            cseg = lr.lseg;
            assert(cseg > 0 && cseg < SegData.length);
            obj.pubnamidx = obj.lnameidx - 1;
            Offset(cseg) = 0;
            if (tyfarfunc(ty) && strcmp(s.Sident.ptr,"main") == 0)
                lr.alloctyp |= 1;  // because MS does for unknown reasons
        }
    }
    else
    {
        ubyte atyp;

        switch (ty & mTYLINK)
        {
            case 0:
            case mTYnear:       lr.pubbase = DATA;
static if (0)
                                atyp = 0;       // only one instance is allowed
else
                                atyp = 0x10;    // pick any (also means it is
                                                // not searched for in a library)

                                break;

            case mTYcs:         lr.flags |= 0x08;      // data in code seg
                                atyp = 0x11;    break;

            case mTYfar:        atyp = 0x12;    break;

            case mTYthread:     lr.pubbase = OmfObj_tlsseg().segidx;
                                atyp = 0x10;    // pick any (also means it is
                                                // not searched for in a library)
                                break;

            default:            assert(0);
        }
        lr.alloctyp = atyp;
    }
    if (s.Sclass == SCstatic)
        lr.flags |= 0x04;      // local bit (make it an "LCOMDAT")
    s.Soffset = 0;
    s.Sseg = pseg.SDseg;
    return pseg.SDseg;
}

/***********************************
 * Returns:
 *      jump table segment for function s
 */
@trusted
int OmfObj_jmpTableSegment(Symbol *s)
{
    return (config.flags & CFGromable) ? cseg : DATA;
}

/**********************************
 * Reset code seg to existing seg.
 * Used after a COMDAT for a function is done.
 */

@trusted
void OmfObj_setcodeseg(int seg)
{
    assert(0 < seg && seg < SegData.length);
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
 *      Coffset         starting offset in cseg
 * Returns:
 *      segment index of newly created code segment
 */

@trusted
int OmfObj_codeseg(const char *name,int suffix)
{
    if (!name)
    {
        if (cseg != CODE)
        {
            cseg = CODE;
        }
        return cseg;
    }

    // Put out LNAMES record
    size_t lnamesize = strlen(name) + suffix * 5;
    char *lnames = cast(char *) alloca(1 + lnamesize + 1);
    lnames[0] = cast(char)lnamesize;
    assert(lnamesize <= (255 - 2 - int.sizeof*3));
    strcpy(lnames + 1,name);
    if (suffix)
        strcat(lnames + 1,"_TEXT");
    objrecord(LNAMES,lnames,cast(uint)(lnamesize + 1));

    cseg = obj_newfarseg(0,4);
    SegData[cseg].attr = obj.csegattr;
    SegData[cseg].segidx = obj.segidx;
    assert(cseg > 0);
    obj.segidx++;
    Offset(cseg) = 0;

    objsegdef(obj.csegattr,0,obj.lnameidx++,4);

    return cseg;
}

/*********************************
 * Define segment for Thread Local Storage.
 * Output:
 *      tlsseg  set to segment number for TLS segment.
 * Returns:
 *      segment for TLS segment
 */

seg_data* OmfObj_tlsseg_bss() { return OmfObj_tlsseg(); }

@trusted
seg_data* OmfObj_tlsseg()
{
    //static char tlssegname[] = "\04$TLS\04$TLS";
    //static char tlssegname[] = "\05.tls$\03tls";
    static immutable char[25] tlssegname = "\05.tls$\03tls\04.tls\010.tls$ZZZ";

    assert(tlssegname[tlssegname.length - 5] == '$');

    if (obj.tlssegi == 0)
    {
        int segattr;

        objrecord(LNAMES,tlssegname.ptr,tlssegname.sizeof - 1);

version (MARS)
        segattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE32);
else
        segattr = I32
            ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
            : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);


        // Put out beginning segment (.tls)
        objsegdef(segattr,0,obj.lnameidx + 2,obj.lnameidx + 1);
        obj.segidx++;

        // Put out .tls$ segment definition record
        obj.tlssegi = obj_newfarseg(0,obj.lnameidx + 1);
        objsegdef(segattr,0,obj.lnameidx,obj.lnameidx + 1);
        SegData[obj.tlssegi].attr = segattr;
        SegData[obj.tlssegi].segidx = obj.segidx;

        // Put out ending segment (.tls$ZZZ)
        objsegdef(segattr,0,obj.lnameidx + 3,obj.lnameidx + 1);

        obj.lnameidx += 4;
        obj.segidx += 2;
    }
    return SegData[obj.tlssegi];
}

seg_data *OmfObj_tlsseg_data()
{
    // specific for Mach-O
    assert(0);
}

/********************************
 * Define a far data segment.
 * Input:
 *      name    Name of module
 *      size    Size of the segment to be created
 * Returns:
 *      segment index of far data segment created
 *      *poffset start of the data for the far data segment
 */

@trusted
int OmfObj_fardata(char *name,targ_size_t size,targ_size_t *poffset)
{
    static immutable char[10] fardataclass = "\010FAR_DATA";
    int len;
    int i;
    char *buffer;

    // See if we can use existing far segment, and just bump its size
    i = obj.lastfardatasegi;
    if (i != -1
        && (_tysize[TYint] != 2 || cast(uint) SegData[i].SDoffset + size < 0x8000)
        )
    {   *poffset = SegData[i].SDoffset;        // BUG: should align this
        SegData[i].SDoffset += size;
        return i;
    }

    // No. We need to build a new far segment

    if (obj.fardataidx == 0)            // if haven't put out far data lname
    {   // Put out class lname
        objrecord(LNAMES,fardataclass.ptr,fardataclass.sizeof - 1);
        obj.fardataidx = obj.lnameidx++;
    }

    // Generate name based on module name
    name = strupr(filespecgetroot(filespecname(obj.modname)));

    // Generate name for this far segment
    len = 1 + cast(int)strlen(name) + 3 + 5 + 1;
    buffer = cast(char *)alloca(len);
    sprintf(buffer + 1,"%s%d_DATA",name,obj.segidx);
    len = cast(int)strlen(buffer + 1);
    buffer[0] = cast(char)len;
    assert(len <= 255);
    objrecord(LNAMES,buffer,len + 1);

    mem_free(name);

    // Construct a new SegData[] entry
    obj.lastfardatasegi = obj_newfarseg(size,obj.fardataidx);

    // Generate segment definition
    objsegdef(obj.fdsegattr,size,obj.lnameidx++,obj.fardataidx);
    obj.segidx++;

    *poffset = 0;
    return SegData[obj.lastfardatasegi].SDseg;
}

/************************************
 * Remember where we put a far segment so we can adjust
 * its size later.
 * Input:
 *      obj.segidx
 *      lnameidx
 * Returns:
 *      index of SegData[]
 */

@trusted
private int obj_newfarseg(targ_size_t size,int classidx)
{
    seg_data *f = getsegment();
    f.isfarseg = true;
    f.seek = cast(int)obj.buf.length();
    f.attr = obj.fdsegattr;
    f.origsize = size;
    f.SDoffset = size;
    f.segidx = obj.segidx;
    f.lnameidx = obj.lnameidx;
    f.classidx = classidx;
    return f.SDseg;
}

/******************************
 * Convert reference to imported name.
 */

void OmfObj_import(elem *e)
{
version (MARS)
    assert(0);
else
{
    Symbol *s;
    Symbol *simp;

    elem_debug(e);
    if ((e.Eoper == OPvar || e.Eoper == OPrelconst) &&
        (s = e.EV.Vsym).ty() & mTYimport &&
        (s.Sclass == SCextern || s.Sclass == SCinline)
       )
    {
        char* name;
        char* p;
        size_t len;
        char[IDMAX + IDOHD + 1] buffer = void;

        // Create import name
        len = OmfObj_mangle(s,buffer.ptr);
        if (buffer[0] == cast(char)0xFF && buffer[1] == 0)
        {   name = buffer.ptr + 4;
            len -= 4;
        }
        else
        {   name = buffer.ptr + 1;
            len -= 1;
        }
        if (config.flags4 & CFG4underscore)
        {   p = cast(char *) alloca(5 + len + 1);
            memcpy(p,"_imp_".ptr,5);
            memcpy(p + 5,name,len);
            p[5 + len] = 0;
        }
        else
        {   p = cast(char *) alloca(6 + len + 1);
            memcpy(p,"__imp_".ptr,6);
            memcpy(p + 6,name,len);
            p[6 + len] = 0;
        }
        simp = scope_search(p,SCTglobal);
        if (!simp)
        {   type *t;

            simp = scope_define(p,SCTglobal,SCextern);
            simp.Ssequence = 0;
            simp.Sfl = FLextern;
            simp.Simport = s;
            t = newpointer(s.Stype);
            t.Tmangle = mTYman_c;
            t.Tcount++;
            simp.Stype = t;
        }
        assert(!e.EV.Voffset);
        if (e.Eoper == OPrelconst)
        {
            e.Eoper = OPvar;
            e.EV.Vsym = simp;
        }
        else // OPvar
        {
            e.Eoper = OPind;
            e.EV.E1 = el_var(simp);
            e.EV.E2 = null;
        }
    }
}
}

/*******************************
 * Mangle a name.
 * Returns:
 *      length of mangled name
 */

@trusted
size_t OmfObj_mangle(Symbol *s,char *dest)
{   size_t len;
    size_t ilen;
    const(char)* name;
    char *name2 = null;

    //printf("OmfObj_mangle('%s'), mangle = x%x\n",s.Sident.ptr,type_mangle(s.Stype));
version (SCPP)
    name = CPP ? cpp_mangle(s) : &s.Sident[0];
else version (MARS)
    name = &s.Sident[0];
else
    static assert(0);

    len = strlen(name);                 // # of bytes in name

    // Use as max length the max length lib.exe can handle
    // Use 5 as length of _ + @nnn
//    enum LIBIDMAX = ((512 - 0x25 - 3 - 4) - 5);
    enum LIBIDMAX = 128;
    if (len > LIBIDMAX)
    //if (len > IDMAX)
    {
        size_t len2;

        // Attempt to compress the name
        name2 = id_compress(name, cast(int)len, &len2);
version (MARS)
{
        if (len2 > LIBIDMAX)            // still too long
        {
            /* Form md5 digest of the name and store it in the
             * last 32 bytes of the name.
             */
            MD5_CTX mdContext;
            MD5Init(&mdContext);
            MD5Update(&mdContext, cast(ubyte *)name, cast(uint)len);
            MD5Final(&mdContext);
            memcpy(name2, name, LIBIDMAX - 32);
            for (int i = 0; i < 16; i++)
            {   ubyte c = mdContext.digest[i];
                ubyte c1 = (c >> 4) & 0x0F;
                ubyte c2 = c & 0x0F;
                c1 += (c1 < 10) ? '0' : 'A' - 10;
                name2[LIBIDMAX - 32 + i * 2] = c1;
                c2 += (c2 < 10) ? '0' : 'A' - 10;
                name2[LIBIDMAX - 32 + i * 2 + 1] = c2;
            }
            len = LIBIDMAX;
            name2[len] = 0;
            name = name2;
            //printf("name = '%s', len = %d, strlen = %d\n", name, len, strlen(name));
        }
        else
        {
            name = name2;
            len = len2;
        }
}
else
{
        if (len2 > IDMAX)               // still too long
        {
version (SCPP)
            synerr(EM_identifier_too_long, name, len - IDMAX, IDMAX);
else version (MARS)
{
//          error(Loc(), "identifier %s is too long by %d characters", name, len - IDMAX);
}
else
            assert(0);

            len = IDMAX;
        }
        else
        {
            name = name2;
            len = len2;
        }
}
    }
    ilen = len;
    if (ilen > (255-2-int.sizeof*3))
        dest += 3;
    switch (type_mangle(s.Stype))
    {
        case mTYman_pas:                // if upper case
        case mTYman_for:
            memcpy(dest + 1,name,len);  // copy in name
            dest[1 + len] = 0;
            strupr(dest + 1);           // to upper case
            break;

        case mTYman_cpp:
            memcpy(dest + 1,name,len);
            break;

        case mTYman_std:
            if (!(config.flags4 & CFG4oldstdmangle) &&
                config.exe == EX_WIN32 && tyfunc(s.ty()) &&
                !variadic(s.Stype))
            {
                dest[1] = '_';
                memcpy(dest + 2,name,len);
                dest[1 + 1 + len] = '@';
                sprintf(dest + 3 + len, "%d", type_paramsize(s.Stype));
                len = strlen(dest + 1);
                assert(isdigit(dest[len]));
                break;
            }
            goto case;

        case mTYman_c:
        case mTYman_d:
            if (config.flags4 & CFG4underscore)
            {
                dest[1] = '_';          // leading _ in name
                memcpy(&dest[2],name,len);      // copy in name
                len++;
                break;
            }
            goto case;

        case mTYman_sys:
            memcpy(dest + 1, name, len);        // no mangling
            dest[1 + len] = 0;
            break;
        default:
            symbol_print(s);
            assert(0);
    }
    if (ilen > (255-2-int.sizeof*3))
    {
        dest -= 3;
        dest[0] = 0xFF;
        dest[1] = 0;
        debug
        assert(len <= 0xFFFF);

        TOWORD(dest + 2,cast(uint)len);
        len += 4;
    }
    else
    {
        *dest = cast(char)len;
        len++;
    }
    if (name2)
        free(name2);
    assert(len <= IDMAX + IDOHD);
    return len;
}

/*******************************
 * Export a function name.
 */

@trusted
void OmfObj_export_symbol(Symbol* s, uint argsize)
{
    char* coment;
    size_t len;

    coment = cast(char *) alloca(4 + 1 + (IDMAX + IDOHD) + 1); // allow extra byte for mangling
    len = OmfObj_mangle(s,&coment[4]);
    assert(len <= IDMAX + IDOHD);
    coment[1] = 0xA0;                           // comment class
    coment[2] = 2;                              // why??? who knows
    if (argsize >= 64)                          // we only have a 5 bit field
        argsize = 0;                            // hope we don't need callgate
    coment[3] = cast(char)((argsize + 1) >> 1); // # words on stack
    coment[4 + len] = 0;                        // no internal name
    objrecord(COMENT,coment,cast(uint)(4 + len + 1));       // module name record
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
int OmfObj_data_start(Symbol *sdata, targ_size_t datasize, int seg)
{
    targ_size_t alignbytes;
    //printf("OmfObj_data_start(%s,size %llx,seg %d)\n",sdata.Sident.ptr,datasize,seg);
    //symbol_print(sdata);

    if (sdata.Sseg == UNKNOWN) // if we don't know then there
        sdata.Sseg = seg;      // wasn't any segment override
    else
        seg = sdata.Sseg;
    targ_size_t offset = SegData[seg].SDoffset;
    if (sdata.Salignment > 0)
    {
        if (SegData[seg].SDalignment < sdata.Salignment)
            SegData[seg].SDalignment = sdata.Salignment;
        alignbytes = ((offset + sdata.Salignment - 1) & ~(sdata.Salignment - 1)) - offset;
    }
    else
        alignbytes = _align(datasize, offset) - offset;
    sdata.Soffset = offset + alignbytes;
    SegData[seg].SDoffset = sdata.Soffset;
    return seg;
}

@trusted
void OmfObj_func_start(Symbol *sfunc)
{
    //printf("OmfObj_func_start(%s)\n",sfunc.Sident.ptr);
    symbol_debug(sfunc);
    sfunc.Sseg = cseg;             // current code seg
    sfunc.Soffset = Offset(cseg);       // offset of start of function

version (MARS)
    varStats_startFunction();
}

/*******************************
 * Update function info after codgen
 */

void OmfObj_func_term(Symbol *sfunc)
{
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s .            symbol
 *      offset =        offset of name
 */

@trusted
private void outpubdata()
{
    if (obj.pubdatai)
    {
        objrecord(obj.mpubdef,obj.pubdata.ptr,obj.pubdatai);
        obj.pubdatai = 0;
    }
}

@trusted
void OmfObj_pubdef(int seg,Symbol *s,targ_size_t offset)
{
    uint reclen, len;
    char* p;
    uint ti;

    assert(offset < 100_000_000);
    obj.resetSymbols.push(s);

    int idx = SegData[seg].segidx;
    if (obj.pubdatai + 1 + (IDMAX + IDOHD) + 4 + 2 > obj.pubdata.sizeof ||
        idx != getindex(cast(ubyte*)obj.pubdata.ptr + 1))
        outpubdata();
    if (obj.pubdatai == 0)
    {
        obj.pubdata[0] = (seg == DATA || seg == CDATA || seg == UDATA) ? 1 : 0; // group index
        obj.pubdatai += 1 + insidx(obj.pubdata.ptr + 1,idx);        // segment index
    }
    p = &obj.pubdata[obj.pubdatai];
    len = cast(uint)OmfObj_mangle(s,p);              // mangle in name
    reclen = len + _tysize[TYint];
    p += len;
    TOOFFSET(p,offset);
    p += _tysize[TYint];
    ti = (config.fulltypes == CVOLD) ? cv_typidx(s.Stype) : 0;
    reclen += instypidx(p,ti);
    obj.pubdatai += reclen;
}

void OmfObj_pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
{
    OmfObj_pubdef(seg, s, offset);
}

/*******************************
 * Output an external definition.
 * Input:
 *      name . external identifier
 * Returns:
 *      External index of the definition (1,2,...)
 */

@trusted
private void outextdata()
{
    if (obj.extdatai)
    {
        objrecord(EXTDEF, obj.extdata.ptr, obj.extdatai);
        obj.extdatai = 0;
    }
}

@trusted
int OmfObj_external_def(const(char)* name)
{
    uint len;
    char *e;

    //printf("OmfObj_external_def('%s', %d)\n",name,obj.extidx + 1);
    assert(name);
    len = cast(uint)strlen(name);                 // length of identifier
    if (obj.extdatai + len + ONS_OHD + 1 > obj.extdata.sizeof)
        outextdata();

    e = &obj.extdata[obj.extdatai];
    len = obj_namestring(e,name);
    e[len] = 0;                         // typidx = 0
    obj.extdatai += len + 1;
    assert(obj.extdatai <= obj.extdata.sizeof);
    return ++obj.extidx;
}

/*******************************
 * Output an external definition.
 * Input:
 *      s       Symbol to do EXTDEF on
 * Returns:
 *      External index of the definition (1,2,...)
 */

@trusted
int OmfObj_external(Symbol *s)
{
    //printf("OmfObj_external('%s', %d)\n",s.Sident.ptr, obj.extidx + 1);
    symbol_debug(s);
    obj.resetSymbols.push(s);
    if (obj.extdatai + (IDMAX + IDOHD) + 3 > obj.extdata.sizeof)
        outextdata();

    char *e = &obj.extdata[obj.extdatai];
    uint len = cast(uint)OmfObj_mangle(s,e);
    e[len] = 0;                 // typidx = 0
    obj.extdatai += len + 1;
    s.Sxtrnnum = ++obj.extidx;
    return obj.extidx;
}

/*******************************
 * Output a common block definition.
 * Input:
 *      p .    external identifier
 *      flag    TRUE:   in default data segment
 *              FALSE:  not in default data segment
 *      size    size in bytes of each elem
 *      count   number of elems
 * Returns:
 *      External index of the definition (1,2,...)
 */

// Helper for OmfObj_common_block()

@trusted
static uint storelength(uint length,uint i)
{
    obj.extdata[i] = cast(char)length;
    if (length >= 128)  // Microsoft docs say 129, but their linker
                        // won't take >=128, so accommodate it
    {   obj.extdata[i] = 129;

        TOWORD(obj.extdata.ptr + i + 1,length);
        if (length >= 0x10000)
        {   obj.extdata[i] = 132;
            obj.extdata[i + 3] = cast(char)(length >> 16);

            // Only 386 can generate lengths this big
            if (I32 && length >= 0x1000000)
            {   obj.extdata[i] = 136;
                obj.extdata[i + 4] = length >> 24;
                i += 4;
            }
            else
                i += 3;
        }
        else
            i += 2;
    }
    return i + 1;               // index past where we stuffed length
}

int OmfObj_common_block(Symbol *s,targ_size_t size,targ_size_t count)
{
    return OmfObj_common_block(s, 0, size, count);
}

@trusted
int OmfObj_common_block(Symbol *s,int flag,targ_size_t size,targ_size_t count)
{
  uint i;
  uint length;
  uint ti;

    //printf("OmfObj_common_block('%s',%d,%d,%d, %d)\n",s.Sident.ptr,flag,size,count, obj.extidx + 1);
    obj.resetSymbols.push(s);
    outextdata();               // borrow the extdata[] storage
    i = cast(uint)OmfObj_mangle(s,obj.extdata.ptr);

    ti = (config.fulltypes == CVOLD) ? cv_typidx(s.Stype) : 0;
    i += instypidx(obj.extdata.ptr + i,ti);

  if (flag)                             // if in default data segment
  {
        //printf("NEAR comdef\n");
        obj.extdata[i] = 0x62;
        length = cast(uint) size * cast(uint) count;
        assert(I32 || length <= 0x10000);
        i = storelength(length,i + 1);
  }
  else
  {
        //printf("FAR comdef\n");
        obj.extdata[i] = 0x61;
        i = storelength(cast(uint) size,i + 1);
        i = storelength(cast(uint) count,i);
  }
  assert(i <= obj.extdata.length);
  objrecord(COMDEF,obj.extdata.ptr,i);
  return ++obj.extidx;
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void OmfObj_write_zeros(seg_data *pseg, targ_size_t count)
{
    OmfObj_lidata(pseg.SDseg, pseg.SDoffset, count);
    //pseg.SDoffset += count;
}

/***************************************
 * Output an iterated data block of 0s.
 * (uninitialized data only)
 */

@trusted
void OmfObj_lidata(int seg,targ_size_t offset,targ_size_t count)
{   int i;
    uint reclen;
    static immutable char[20] zero = 0;
    char[20] data = void;
    char *di;

    //printf("OmfObj_lidata(seg = %d, offset = x%x, count = %d)\n", seg, offset, count);

    SegData[seg].SDoffset += count;

    if (seg == UDATA)
        return;
    int idx = SegData[seg].segidx;

Lagain:
    if (count <= zero.sizeof)          // if shorter to use ledata
    {
        OmfObj_bytes(seg,offset,cast(uint)count,cast(char*)zero.ptr);
        return;
    }

    if (seg_is_comdat(idx))
    {
        while (count > zero.sizeof)
        {
            OmfObj_bytes(seg,offset,zero.sizeof,cast(char*)zero.ptr);
            offset += zero.sizeof;
            count -= zero.sizeof;
        }
        OmfObj_bytes(seg,offset,cast(uint)count,cast(char*)zero.ptr);
        return;
    }

    i = insidx(data.ptr,idx);
    di = data.ptr + i;
    TOOFFSET(di,offset);

    if (config.flags & CFGeasyomf)
    {
        if (count >= 0x8000)            // repeat count can only go to 32k
        {
            TOWORD(di + 4,cast(ushort)(count / 0x8000));
            TOWORD(di + 4 + 2,1);               // 1 data block follows
            TOWORD(di + 4 + 2 + 2,0x8000);      // repeat count
            TOWORD(di + 4 + 2 + 2 + 2,0);       // block count
            TOWORD(di + 4 + 2 + 2 + 2 + 2,1);   // 1 byte of 0
            reclen = i + 4 + 5 * 2;
            objrecord(obj.mlidata,data.ptr,reclen);

            offset += (count & ~cast(targ_size_t)0x7FFF);
            count &= 0x7FFF;
            goto Lagain;
        }
        else
        {
            TOWORD(di + 4,cast(ushort)count);       // repeat count
            TOWORD(di + 4 + 2,0);                       // block count
            TOWORD(di + 4 + 2 + 2,1);                   // 1 byte of 0
            reclen = i + 4 + 2 + 2 + 2;
            objrecord(obj.mlidata,data.ptr,reclen);
        }
    }
    else
    {
        TOOFFSET(di + _tysize[TYint],count);
        TOWORD(di + _tysize[TYint] * 2,0);     // block count
        TOWORD(di + _tysize[TYint] * 2 + 2,1); // repeat 1 byte of 0s
        reclen = i + (I32 ? 12 : 8);
        objrecord(obj.mlidata,data.ptr,reclen);
    }
    assert(reclen <= data.sizeof);
}

/****************************
 * Output a MODEND record.
 */

@trusted
private void obj_modend()
{
    if (obj.startaddress)
    {   char[10] mdata = void;
        int i;
        uint framedatum,targetdatum;
        ubyte fd;
        targ_size_t offset;
        int external;           // !=0 if identifier is defined externally
        tym_t ty;
        Symbol *s = obj.startaddress;

        // Turn startaddress into a fixup.
        // Borrow heavilly from OmfObj_reftoident()

        obj.resetSymbols.push(s);
        symbol_debug(s);
        offset = 0;
        ty = s.ty();

        switch (s.Sclass)
        {
            case SCcomdat:
            case_SCcomdat:
            case SCextern:
            case SCcomdef:
                if (s.Sxtrnnum)                // identifier is defined somewhere else
                    external = s.Sxtrnnum;
                else
                {
                 Ladd:
                    s.Sclass = SCextern;
                    external = objmod.external(s);
                    outextdata();
                }
                break;
            case SCinline:
                if (config.flags2 & CFG2comdat)
                    goto case_SCcomdat; // treat as initialized common block
                goto case;

            case SCsinline:
            case SCstatic:
            case SCglobal:
                if (s.Sseg == UNKNOWN)
                    goto Ladd;
                if (seg_is_comdat(SegData[s.Sseg].segidx))   // if in comdat
                    goto case_SCcomdat;
                goto case;

            case SClocstat:
                external = 0;           // identifier is static or global
                                            // and we know its offset
                offset += s.Soffset;
                break;
            default:
                //symbol_print(s);
                assert(0);
        }

        if (external)
        {   fd = FD_T2;
            targetdatum = external;
            switch (s.Sfl)
            {
                case FLextern:
                    if (!(ty & (mTYcs | mTYthread)))
                        goto L1;
                    goto case;

                case FLfunc:
                case FLfardata:
                case FLcsdata:
                case FLtlsdata:
                    if (config.exe & EX_flat)
                    {   fd |= FD_F1;
                        framedatum = 1;
                    }
                    else
                    {
                //case FLtlsdata:
                        fd |= FD_F2;
                        framedatum = targetdatum;
                    }
                    break;
                default:
                    goto L1;
            }
        }
        else
        {
            fd = FD_T0;                 // target is always a segment
            targetdatum = SegData[s.Sseg].segidx;
            assert(targetdatum != -1);
            switch (s.Sfl)
            {
                case FLextern:
                    if (!(ty & (mTYcs | mTYthread)))
                        goto L1;
                    goto case;

                case FLfunc:
                case FLfardata:
                case FLcsdata:
                case FLtlsdata:
                    if (config.exe & EX_flat)
                    {   fd |= FD_F1;
                        framedatum = 1;
                    }
                    else
                    {
                //case FLtlsdata:
                        fd |= FD_F0;
                        framedatum = targetdatum;
                    }
                    break;
                default:
                L1:
                    fd |= FD_F1;
                    framedatum = DGROUPIDX;
                    //if (flags == CFseg)
                    {   fd = FD_F1 | FD_T1;     // target is DGROUP
                        targetdatum = DGROUPIDX;
                    }
                    break;
            }
        }

        // Write the fixup into mdata[]
        mdata[0] = 0xC1;
        mdata[1] = fd;
        i = 2 + insidx(&mdata[2],framedatum);
        i += insidx(&mdata[i],targetdatum);
        TOOFFSET(mdata.ptr + i,offset);

        objrecord(obj.mmodend,mdata.ptr,i + _tysize[TYint]);       // write mdata[] to .OBJ file
    }
    else
    {   static immutable char[1] modend = [0];

        objrecord(obj.mmodend,modend.ptr,modend.sizeof);
    }
}

/****************************
 * Output the fixups in list fl.
 */

@trusted
private void objfixupp(FIXUP *f)
{
  uint i,j,k;
  targ_size_t locat;
  FIXUP *fn;

static if (1)   // store in one record
{
  char[1024] data = void;

  i = 0;
  for (; f; f = fn)
  {     ubyte fd;

        if (i >= data.sizeof - (3 + 2 + 2))    // if not enough room
        {   objrecord(obj.mfixupp,data.ptr,i);
            i = 0;
        }

        //printf("f = %p, offset = x%x\n",f,f.FUoffset);
        assert(f.FUoffset < 1024);
        locat = (f.FUlcfd & 0xFF00) | f.FUoffset;
        data[i+0] = cast(char)(locat >> 8);
        data[i+1] = cast(char)locat;
        data[i+2] = fd = cast(ubyte)f.FUlcfd;
        k = i;
        i += 3 + insidx(&data[i+3],f.FUframedatum);
        //printf("FUframedatum = x%x\n", f.FUframedatum);
        if ((fd >> 4) == (fd & 3) && f.FUframedatum == f.FUtargetdatum)
        {
            data[k + 2] = (fd & 15) | FD_F5;
        }
        else
        {   i += insidx(&data[i],f.FUtargetdatum);
            //printf("FUtargetdatum = x%x\n", f.FUtargetdatum);
        }
        //printf("[%d]: %02x %02x %02x\n", k, data[k + 0] & 0xFF, data[k + 1] & 0xFF, data[k + 2] & 0xFF);
        fn = f.FUnext;
        free(f);
  }
  assert(i <= data.sizeof);
  if (i)
      objrecord(obj.mfixupp,data.ptr,i);
}
else   // store in multiple records
{
  for (; fl; fl = list_next(fl))
  {
        char[7] data = void;

        assert(f.FUoffset < 1024);
        locat = (f.FUlcfd & 0xFF00) | f.FUoffset;
        data[0] = locat >> 8;
        data[1] = locat;
        data[2] = f.FUlcfd;
        i = 3 + insidx(&data[3],f.FUframedatum);
        i += insidx(&data[i],f.FUtargetdatum);
        objrecord(obj.mfixupp,data,i);
  }
}
}


/***************************
 * Add a new fixup to the fixup list.
 * Write things out if we overflow the list.
 */

@trusted
private void addfixup(Ledatarec *lr, targ_size_t offset,uint lcfd,
        uint framedatum,uint targetdatum)
{   FIXUP *f;

    assert(offset < 0x1024);
debug
{
    assert(targetdatum <= 0x7FFF);
    assert(framedatum <= 0x7FFF);
}
    f = cast(FIXUP *) malloc(FIXUP.sizeof);
    //printf("f = %p, offset = x%x\n",f,offset);
    f.FUoffset = offset;
    f.FUlcfd = cast(ushort)lcfd;
    f.FUframedatum = cast(ushort)framedatum;
    f.FUtargetdatum = cast(ushort)targetdatum;
    f.FUnext = lr.fixuplist;  // link f into list
    lr.fixuplist = f;
    debug
    obj.fixup_count++;                  // gather statistics
}


/*********************************
 * Open up a new ledata record.
 * Input:
 *      seg     segment number data is in
 *      offset  starting offset of start of data for this record
 */

@trusted
private Ledatarec *ledata_new(int seg,targ_size_t offset)
{

    //printf("ledata_new(seg = %d, offset = x%lx)\n",seg,offset);
    assert(seg > 0 && seg < SegData.length);

    Ledatarec** p = obj.ledatas.push();
    Ledatarec* lr = *p;
    if (!lr)
    {
        lr = cast(Ledatarec *) mem_malloc(Ledatarec.sizeof);
        *p = lr;
    }
    memset(lr, 0, Ledatarec.sizeof);

    lr.lseg = seg;
    lr.offset = offset;

    if (seg_is_comdat(SegData[seg].segidx) && offset)      // if continuation of an existing COMDAT
    {
        Ledatarec *d = cast(Ledatarec*)SegData[seg].ledata;
        if (d)
        {
            if (d.lseg == seg)                 // found existing COMDAT
            {   lr.flags = d.flags;
                lr.alloctyp = d.alloctyp;
                lr._align = d._align;
                lr.typidx = d.typidx;
                lr.pubbase = d.pubbase;
                lr.pubnamidx = d.pubnamidx;
            }
        }
    }
    SegData[seg].ledata = lr;
    return lr;
}

/***********************************
 * Append byte to segment.
 */

void OmfObj_write_byte(seg_data *pseg, uint _byte)
{
    OmfObj_byte(pseg.SDseg, pseg.SDoffset, _byte);
    pseg.SDoffset++;
}

/************************************
 * Output byte to object file.
 */

@trusted
void OmfObj_byte(int seg,targ_size_t offset,uint _byte)
{
    Ledatarec *lr = cast(Ledatarec*)SegData[seg].ledata;
    if (!lr)
        goto L2;

    if (
         lr.i > LEDATAMAX - 1 ||       // if it'll overflow
         offset < lr.offset || // underflow
         offset > lr.offset + lr.i
     )
    {
        // Try to find an existing ledata
        for (size_t i = obj.ledatas.length; i; )
        {   Ledatarec *d = obj.ledatas[--i];
            if (seg == d.lseg &&       // segments match
                offset >= d.offset &&
                offset + 1 <= d.offset + LEDATAMAX &&
                offset <= d.offset + d.i
               )
            {
                lr = d;
                SegData[seg].ledata = cast(void*)d;
                goto L1;
            }
        }
L2:
        lr = ledata_new(seg,offset);
L1:     { }
    }

    uint i = cast(uint)(offset - lr.offset);
    if (lr.i <= i)
        lr.i = i + 1;
    lr.data[i] = cast(ubyte)_byte;           // 1st byte of data
}

/***********************************
 * Append bytes to segment.
 */

void OmfObj_write_bytes(seg_data *pseg, uint nbytes, void *p)
{
    OmfObj_bytes(pseg.SDseg, pseg.SDoffset, nbytes, p);
    pseg.SDoffset += nbytes;
}

/************************************
 * Output bytes to object file.
 * Returns:
 *      nbytes
 */

@trusted
uint OmfObj_bytes(int seg, targ_size_t offset, uint nbytes, void* p)
{
    uint n = nbytes;

    //dbg_printf("OmfObj_bytes(seg=%d, offset=x%lx, nbytes=x%x, p=%p)\n",seg,offset,nbytes,p);
    Ledatarec *lr = cast(Ledatarec*)SegData[seg].ledata;
    if (!lr)
        lr = ledata_new(seg, offset);
 L1:
    if (
         lr.i + nbytes > LEDATAMAX ||  // or it'll overflow
         offset < lr.offset ||         // underflow
         offset > lr.offset + lr.i
     )
    {
        while (nbytes)
        {
            OmfObj_byte(seg, offset, *cast(char*)p);
            offset++;
            p = (cast(char *)p) + 1;
            nbytes--;
            lr = cast(Ledatarec*)SegData[seg].ledata;
            if (lr.i + nbytes <= LEDATAMAX)
                goto L1;
            if (lr.i == LEDATAMAX)
            {
                while (nbytes > LEDATAMAX)  // start writing full ledatas
                {
                    lr = ledata_new(seg, offset);
                    memcpy(lr.data.ptr, p, LEDATAMAX);
                    p = (cast(char *)p) + LEDATAMAX;
                    nbytes -= LEDATAMAX;
                    offset += LEDATAMAX;
                    lr.i = LEDATAMAX;
                }
                goto L1;
            }
        }
    }
    else
    {
        uint i = cast(uint)(offset - lr.offset);
        if (lr.i < i + nbytes)
            lr.i = i + nbytes;
        memcpy(lr.data.ptr + i,p,nbytes);
    }
    return n;
}

/************************************
 * Output word of data. (Two words if segment:offset pair.)
 * Input:
 *      seg     CODE, DATA, CDATA, UDATA
 *      offset  offset of start of data
 *      data    word of data
 *      lcfd    LCxxxx | FDxxxx
 *      if (FD_F2 | FD_T6)
 *              idx1 = external Symbol #
 *      else
 *              idx1 = frame datum
 *              idx2 = target datum
 */

@trusted
void OmfObj_ledata(int seg,targ_size_t offset,targ_size_t data,
        uint lcfd,uint idx1,uint idx2)
{
    uint size;                      // number of bytes to output

    uint ptrsize = tysize(TYfptr);

    if ((lcfd & LOCxx) == obj.LOCpointer)
        size = ptrsize;
    else if ((lcfd & LOCxx) == LOCbase)
        size = 2;
    else
        size = tysize(TYnptr);

    Ledatarec *lr = cast(Ledatarec*)SegData[seg].ledata;
    if (!lr)
         lr = ledata_new(seg, offset);
    assert(seg == lr.lseg);
    if (
         lr.i + size > LEDATAMAX ||    // if it'll overflow
         offset < lr.offset || // underflow
         offset > lr.offset + lr.i
     )
    {
        // Try to find an existing ledata
//dbg_printf("seg = %d, offset = x%lx, size = %d\n",seg,offset,size);
        for (size_t i = obj.ledatas.length; i; )
        {   Ledatarec *d = obj.ledatas[--i];

//dbg_printf("d: seg = %d, offset = x%lx, i = x%x\n",d.lseg,d.offset,d.i);
            if (seg == d.lseg &&       // segments match
                offset >= d.offset &&
                offset + size <= d.offset + LEDATAMAX &&
                offset <= d.offset + d.i
               )
            {
//dbg_printf("match\n");
                lr = d;
                SegData[seg].ledata = cast(void*)d;
                goto L1;
            }
        }
        lr = ledata_new(seg,offset);
L1:     { }
    }

    uint i = cast(uint)(offset - lr.offset);
    if (lr.i < i + size)
        lr.i = i + size;
    if (size == 2 || !I32)
        TOWORD(lr.data.ptr + i,cast(uint)data);
    else
        TOLONG(lr.data.ptr + i,cast(uint)data);
    if (size == ptrsize)         // if doing a seg:offset pair
        TOWORD(lr.data.ptr + i + tysize(TYnptr),0);        // segment portion
    addfixup(lr, offset - lr.offset,lcfd,idx1,idx2);
}

/************************************
 * Output long word of data.
 * Input:
 *      seg     CODE, DATA, CDATA, UDATA
 *      offset  offset of start of data
 *      data    long word of data
 *   Present only if size == 2:
 *      lcfd    LCxxxx | FDxxxx
 *      if (FD_F2 | FD_T6)
 *              idx1 = external Symbol #
 *      else
 *              idx1 = frame datum
 *              idx2 = target datum
 */

@trusted
void OmfObj_write_long(int seg,targ_size_t offset,uint data,
        uint lcfd,uint idx1,uint idx2)
{
    uint sz = tysize(TYfptr);
    Ledatarec *lr = cast(Ledatarec*)SegData[seg].ledata;
    if (!lr)
         lr = ledata_new(seg, offset);
    if (
         lr.i + sz > LEDATAMAX || // if it'll overflow
         offset < lr.offset || // underflow
         offset > lr.offset + lr.i
       )
        lr = ledata_new(seg,offset);
    uint i = cast(uint)(offset - lr.offset);
    if (lr.i < i + sz)
        lr.i = i + sz;
    TOLONG(lr.data.ptr + i,data);
    if (I32)                              // if 6 byte far pointers
        TOWORD(lr.data.ptr + i + LONGSIZE,0);              // fill out seg
    addfixup(lr, offset - lr.offset,lcfd,idx1,idx2);
}

/*******************************
 * Refer to address that is in the data segment.
 * Input:
 *      seg =           where the address is going
 *      offset =        offset within seg
 *      val =           displacement from address
 *      targetdatum =   DATA, CDATA or UDATA, depending where the address is
 *      flags =         CFoff, CFseg
 * Example:
 *      int *abc = &def[3];
 *      to allocate storage:
 *              OmfObj_reftodatseg(DATA,offset,3 * (int *).sizeof,UDATA);
 */

@trusted
void OmfObj_reftodatseg(int seg,targ_size_t offset,targ_size_t val,
        uint targetdatum,int flags)
{
    assert(flags);

    if (flags == 0 || flags & CFoff)
    {
        // The frame datum is always 1, which is DGROUP
        OmfObj_ledata(seg,offset,val,
            LOCATsegrel | obj.LOCoffset | FD_F1 | FD_T4,DGROUPIDX,SegData[targetdatum].segidx);
        offset += _tysize[TYint];
    }

    if (flags & CFseg)
    {
static if (0)
{
        if (config.wflags & WFdsnedgroup)
            warerr(WM_ds_ne_dgroup);
}
        OmfObj_ledata(seg,offset,0,
            LOCATsegrel | LOCbase | FD_F1 | FD_T5,DGROUPIDX,DGROUPIDX);
    }
}

/*******************************
 * Refer to address that is in a far segment.
 * Input:
 *      seg =           where the address is going
 *      offset =        offset within seg
 *      val =           displacement from address
 *      farseg =        far segment index
 *      flags =         CFoff, CFseg
 */

@trusted
void OmfObj_reftofarseg(int seg,targ_size_t offset,targ_size_t val,
        int farseg,int flags)
{
    assert(flags);

    int idx = SegData[farseg].segidx;
    if (flags == 0 || flags & CFoff)
    {
        OmfObj_ledata(seg,offset,val,
            LOCATsegrel | obj.LOCoffset | FD_F0 | FD_T4,idx,idx);
        offset += _tysize[TYint];
    }

    if (flags & CFseg)
    {
        OmfObj_ledata(seg,offset,0,
            LOCATsegrel | LOCbase | FD_F0 | FD_T4,idx,idx);
    }
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

@trusted
void OmfObj_reftocodeseg(int seg,targ_size_t offset,targ_size_t val)
{
    uint framedatum;
    uint lcfd;

    int idx = SegData[cseg].segidx;
    if (seg_is_comdat(idx))             // if comdat
    {   idx = -idx;
        framedatum = idx;
        lcfd = (LOCATsegrel | obj.LOCoffset) | (FD_F2 | FD_T6);
    }
    else if (config.exe & EX_flat)
    {   framedatum = 1;
        lcfd = (LOCATsegrel | obj.LOCoffset) | (FD_F1 | FD_T4);
    }
    else
    {   framedatum = idx;
        lcfd = (LOCATsegrel | obj.LOCoffset) | (FD_F0 | FD_T4);
    }

    OmfObj_ledata(seg,offset,val,lcfd,framedatum,idx);
}

/*******************************
 * Refer to an identifier.
 * Input:
 *      seg =           where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      s .            Symbol table entry for identifier
 *      val =           displacement from identifier
 *      flags =         CFselfrel: self-relative
 *                      CFseg: get segment
 *                      CFoff: get offset
 * Returns:
 *      number of bytes in reference (2 or 4)
 * Example:
 *      extern int def[];
 *      int *abc = &def[3];
 *      to allocate storage:
 *              OmfObj_reftodatseg(DATA,offset,3 * (int *).sizeof,UDATA);
 */

@trusted
int OmfObj_reftoident(int seg,targ_size_t offset,Symbol *s,targ_size_t val,
        int flags)
{
    uint targetdatum;       // which datum the symbol is in
    uint framedatum;
    int     lc;
    int     external;           // !=0 if identifier is defined externally
    int numbytes;
    tym_t ty;

static if (0)
{
    printf("OmfObj_reftoident('%s' seg %d, offset x%lx, val x%lx, flags x%x)\n",
        s.Sident.ptr,seg,offset,val,flags);
    printf("Sseg = %d, Sxtrnnum = %d\n",s.Sseg,s.Sxtrnnum);
    symbol_print(s);
}
    assert(seg > 0);

    ty = s.ty();
    while (1)
    {
        switch (flags & (CFseg | CFoff))
        {
            case 0:
                // Select default
                flags |= CFoff;
                if (tyfunc(ty))
                {
                    if (tyfarfunc(ty))
                        flags |= CFseg;
                }
                else // DATA
                {
                    if (LARGEDATA)
                        flags |= CFseg;
                }
                continue;
            case CFoff:
                if (I32)
                {
                    if (ty & mTYthread)
                    {   lc = LOC32tlsoffset;
                    }
                    else
                        lc = obj.LOCoffset;
                }
                else
                {
                    // The 'loader_resolved' offset is required for VCM
                    // and Windows support. A fixup of this type is
                    // relocated by the linker to point to a 'thunk'.
                    lc = (tyfarfunc(ty)
                          && !(flags & CFselfrel))
                            ? LOCloader_resolved : obj.LOCoffset;
                }
                numbytes = tysize(TYnptr);
                break;
            case CFseg:
                lc = LOCbase;
                numbytes = 2;
                break;
            case CFoff | CFseg:
                lc = obj.LOCpointer;
                numbytes = tysize(TYfptr);
                break;

            default:
                assert(0);
        }
        break;
    }

    switch (s.Sclass)
    {
        case SCcomdat:
        case_SCcomdat:
        case SCextern:
        case SCcomdef:
            if (s.Sxtrnnum)            // identifier is defined somewhere else
            {
                external = s.Sxtrnnum;

                debug
                if (external > obj.extidx)
                {
                    printf("obj.extidx = %d\n", obj.extidx);
                    symbol_print(s);
                }

                assert(external <= obj.extidx);
            }
            else
            {
                // Don't know yet, worry about it later
             Ladd:
                size_t byteswritten = addtofixlist(s,offset,seg,val,flags);
                assert(byteswritten == numbytes);
                return numbytes;
            }
            break;
        case SCinline:
            if (config.flags2 & CFG2comdat)
                goto case_SCcomdat;     // treat as initialized common block
            goto case;

        case SCsinline:
        case SCstatic:
        case SCglobal:
            if (s.Sseg == UNKNOWN)
                goto Ladd;
            if (seg_is_comdat(SegData[s.Sseg].segidx))
                goto case_SCcomdat;
            goto case;

        case SClocstat:
            external = 0;               // identifier is static or global
                                        // and we know its offset
            if (flags & CFoff)
                val += s.Soffset;
            break;
        default:
            symbol_print(s);
            assert(0);
    }

    lc |= (flags & CFselfrel) ? LOCATselfrel : LOCATsegrel;
    if (external)
    {   lc |= FD_T6;
        targetdatum = external;
        switch (s.Sfl)
        {
            case FLextern:
                if (!(ty & (mTYcs | mTYthread)))
                    goto L1;
                goto case;

            case FLfunc:
            case FLfardata:
            case FLcsdata:
            case FLtlsdata:
                if (config.exe & EX_flat)
                {   lc |= FD_F1;
                    framedatum = 1;
                }
                else
                {
            //case FLtlsdata:
                    lc |= FD_F2;
                    framedatum = targetdatum;
                }
                break;
            default:
                goto L1;
        }
    }
    else
    {
        lc |= FD_T4;                    // target is always a segment
        targetdatum = SegData[s.Sseg].segidx;
        assert(s.Sseg != UNKNOWN);
        switch (s.Sfl)
        {
            case FLextern:
                if (!(ty & (mTYcs | mTYthread)))
                    goto L1;
                goto case;

            case FLfunc:
            case FLfardata:
            case FLcsdata:
            case FLtlsdata:
                if (config.exe & EX_flat)
                {   lc |= FD_F1;
                    framedatum = 1;
                }
                else
                {
            //case FLtlsdata:
                    lc |= FD_F0;
                    framedatum = targetdatum;
                }
                break;
            default:
            L1:
                lc |= FD_F1;
                framedatum = DGROUPIDX;
                if (flags == CFseg)
                {   lc = LOCATsegrel | LOCbase | FD_F1 | FD_T5;
                    targetdatum = DGROUPIDX;
                }
static if (0)
{
                if (flags & CFseg && config.wflags & WFdsnedgroup)
                    warerr(WM_ds_ne_dgroup);
}
                break;
        }
    }

    OmfObj_ledata(seg,offset,val,lc,framedatum,targetdatum);
    return numbytes;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *      s       Symbol to generate a thunk for
 */

@trusted
void OmfObj_far16thunk(Symbol *s)
{
    static ubyte[25] cod32_1 =
    [
        0x55,                           //      PUSH    EBP
        0x8B,0xEC,                      //      MOV     EBP,ESP
        0x83,0xEC,0x04,                 //      SUB     ESP,4
        0x53,                           //      PUSH    EBX
        0x57,                           //      PUSH    EDI
        0x56,                           //      PUSH    ESI
        0x06,                           //      PUSH    ES
        0x8C,0xD2,                      //      MOV     DX,SS
        0x80,0xE2,0x03,                 //      AND     DL,3
        0x80,0xCA,0x07,                 //      OR      DL,7
        0x89,0x65,0xFC,                 //      MOV     -4[EBP],ESP
        0x8C,0xD0,                      //      MOV     AX,SS
        0x66,0x3D, // 0x00,0x00 */      /*      CMP     AX,seg FLAT:_DATA
    ];
    assert(cod32_1[cod32_1.length - 1] == 0x3D);

    static ubyte[22 + 46] cod32_2 =
    [
        0x0F,0x85,0x10,0x00,0x00,0x00,  //      JNE     L1
        0x8B,0xC4,                      //      MOV     EAX,ESP
        0x66,0x3D,0x00,0x08,            //      CMP     AX,2048
        0x0F,0x83,0x04,0x00,0x00,0x00,  //      JAE     L1
        0x66,0x33,0xC0,                 //      XOR     AX,AX
        0x94,                           //      XCHG    ESP,EAX
                                        // L1:
        0x55,                           //      PUSH    EBP
        0x8B,0xC4,                      //      MOV     EAX,ESP
        0x16,                           //      PUSH    SS
        0x50,                           //      PUSH    EAX
        LEA,0x75,0x08,                  //      LEA     ESI,8[EBP]
        0x81,0xEC,0x00,0x00,0x00,0x00,  //      SUB     ESP,numparam
        0x8B,0xFC,                      //      MOV     EDI,ESP
        0xB9,0x00,0x00,0x00,0x00,       //      MOV     ECX,numparam
        0x66,0xF3,0xA4,                 //      REP     MOVSB
        0x8B,0xC4,                      //      MOV     EAX,ESP
        0xC1,0xC8,0x10,                 //      ROR     EAX,16
        0x66,0xC1,0xE0,0x03,            //      SHL     AX,3
        0x0A,0xC2,                      //      OR      AL,DL
        0xC1,0xC0,0x10,                 //      ROL     EAX,16
        0x50,                           //      PUSH    EAX
        0x66,0x0F,0xB2,0x24,0x24,       //      LSS     SP,[ESP]
        0x66,0xEA, // 0,0,0,0, */       /*      JMPF    L3
    ];
    assert(cod32_2[cod32_2.length - 1] == 0xEA);

    static ubyte[26] cod32_3 =
    [                                   // L2:
        0xC1,0xE0,0x10,                 //      SHL     EAX,16
        0x0F,0xAC,0xD0,0x10,            //      SHRD    EAX,EDX,16
        0x0F,0xB7,0xE4,                 //      MOVZX   ESP,SP
        0x0F,0xB2,0x24,0x24,            //      LSS     ESP,[ESP]
        0x5D,                           //      POP     EBP
        0x8B,0x65,0xFC,                 //      MOV     ESP,-4[EBP]
        0x07,                           //      POP     ES
        0x5E,                           //      POP     ESI
        0x5F,                           //      POP     EDI
        0x5B,                           //      POP     EBX
        0xC9,                           //      LEAVE
        0xC2,0x00,0x00                  //      RET     numparam
    ];
    assert(cod32_3[cod32_3.length - 3] == 0xC2);

    uint numparam = 24;
    targ_size_t L2offset;
    int idx;

    s.Sclass = SCstatic;
    s.Sseg = cseg;             // identifier is defined in code segment
    s.Soffset = Offset(cseg);

    // Store numparam into right places
    assert((numparam & 0xFFFF) == numparam);    // 2 byte value
    TOWORD(&cod32_2[32],numparam);
    TOWORD(&cod32_2[32 + 7],numparam);
    TOWORD(&cod32_3[cod32_3.sizeof - 2],numparam);

    //------------------------------------------
    // Generate CODE16 segment if it isn't there already
    if (obj.code16segi == 0)
    {
        // Define CODE16 segment for far16 thunks

        static immutable char[8] lname = "\06CODE16";

        // Put out LNAMES record
        objrecord(LNAMES,lname.ptr,lname.sizeof - 1);

        obj.code16segi = obj_newfarseg(0,4);
        obj.CODE16offset = 0;

        // class CODE
        uint attr = SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);
        SegData[obj.code16segi].attr = attr;
        objsegdef(attr,0,obj.lnameidx++,4);
        obj.segidx++;
    }

    //------------------------------------------
    // Output the 32 bit thunk

    OmfObj_bytes(cseg,Offset(cseg),cod32_1.sizeof,cod32_1.ptr);
    Offset(cseg) += cod32_1.sizeof;

    // Put out fixup for SEG FLAT:_DATA
    OmfObj_ledata(cseg,Offset(cseg),0,LOCATsegrel|LOCbase|FD_F1|FD_T4,
        DGROUPIDX,DATA);
    Offset(cseg) += 2;

    OmfObj_bytes(cseg,Offset(cseg),cod32_2.sizeof,cod32_2.ptr);
    Offset(cseg) += cod32_2.sizeof;

    // Put out fixup to CODE16 part of thunk
    OmfObj_ledata(cseg,Offset(cseg),obj.CODE16offset,LOCATsegrel|LOC16pointer|FD_F0|FD_T4,
        SegData[obj.code16segi].segidx,
        SegData[obj.code16segi].segidx);
    Offset(cseg) += 4;

    L2offset = Offset(cseg);
    OmfObj_bytes(cseg,Offset(cseg),cod32_3.sizeof,cod32_3.ptr);
    Offset(cseg) += cod32_3.sizeof;

    s.Ssize = Offset(cseg) - s.Soffset;            // size of thunk

    //------------------------------------------
    // Output the 16 bit thunk

    OmfObj_byte(obj.code16segi,obj.CODE16offset++,0x9A);       //      CALLF   function

    // Make function external
    idx = OmfObj_external(s);                         // use Pascal name mangling

    // Output fixup for function
    OmfObj_ledata(obj.code16segi,obj.CODE16offset,0,LOCATsegrel|LOC16pointer|FD_F2|FD_T6,
        idx,idx);
    obj.CODE16offset += 4;

    OmfObj_bytes(obj.code16segi,obj.CODE16offset,3,cast(void*)"\x66\x67\xEA".ptr);    // JMPF L2
    obj.CODE16offset += 3;

    OmfObj_ledata(obj.code16segi,obj.CODE16offset,L2offset,
        LOCATsegrel | LOC32pointer | FD_F1 | FD_T4,
        DGROUPIDX,
        SegData[cseg].segidx);
    obj.CODE16offset += 6;

    SegData[obj.code16segi].SDoffset = obj.CODE16offset;
}

/**************************************
 * Mark object file as using floating point.
 */

@trusted
void OmfObj_fltused()
{
    if (!obj.fltused)
    {
        obj.fltused = 1;
        if (!(config.flags3 & CFG3wkfloat))
            OmfObj_external_def("__fltused");
    }
}

Symbol *OmfObj_tlv_bootstrap()
{
    // specific for Mach-O
    assert(0);
}

void OmfObj_gotref(Symbol *s)
{
}

/*****************************************
 * write a reference to a mutable pointer into the object file
 * Params:
 *      s    = symbol that contains the pointer
 *      soff = offset of the pointer inside the Symbol's memory
 */

@trusted
void OmfObj_write_pointerRef(Symbol* s, uint soff)
{
version (MARS)
{
    // defer writing pointer references until the symbols are written out
    obj.ptrrefs.push(PtrRef(s, soff));
}
}

/*****************************************
 * flush a single pointer reference saved by write_pointerRef
 * to the object file
 * Params:
 *      s    = symbol that contains the pointer
 *      soff = offset of the pointer inside the Symbol's memory
 */
@trusted
private void objflush_pointerRef(Symbol* s, uint soff)
{
version (MARS)
{
    bool isTls = (s.Sfl == FLtlsdata);
    int* segi = isTls ? &obj.tlsrefsegi : &obj.datrefsegi;
    symbol_debug(s);

    if (*segi == 0)
    {
        // We need to always put out the segments in triples, so that the
        // linker will put them in the correct order.
        static immutable char[12] lnames_dat = "\03DPB\02DP\03DPE";
        static immutable char[12] lnames_tls = "\03TPB\02TP\03TPE";
        const lnames = isTls ? lnames_tls.ptr : lnames_dat.ptr;
        // Put out LNAMES record
        objrecord(LNAMES,lnames,lnames_dat.sizeof - 1);

        int dsegattr = obj.csegattr;

        // Put out beginning segment
        objsegdef(dsegattr,0,obj.lnameidx,CODECLASS);
        obj.lnameidx++;
        obj.segidx++;

        // Put out segment definition record
        *segi = obj_newfarseg(0,CODECLASS);
        objsegdef(dsegattr,0,obj.lnameidx,CODECLASS);
        SegData[*segi].attr = dsegattr;
        assert(SegData[*segi].segidx == obj.segidx);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 1,CODECLASS);

        obj.lnameidx += 2;              // for next time
        obj.segidx += 2;
    }

    targ_size_t offset = SegData[*segi].SDoffset;
    offset += objmod.reftoident(*segi, offset, s, soff, CFoff);
    SegData[*segi].SDoffset = offset;
}
}

/*****************************************
 * flush all pointer references saved by write_pointerRef
 * to the object file
 */
@trusted
private void objflush_pointerRefs()
{
version (MARS)
{
    foreach (ref pr; obj.ptrrefs)
        objflush_pointerRef(pr.sym, pr.offset);
    obj.ptrrefs.reset();
}
}

}
