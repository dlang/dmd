// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if !HTOD && (SCPP || MARS)

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <malloc.h>
#include        <ctype.h>
#include        <direct.h>

#include        "filespec.h"

#include        "cc.h"
#include        "global.h"
#include        "cgcv.h"
#include        "code.h"
#include        "type.h"
#include        "outbuf.h"

#include        "md5.h"

#if MARS
struct Loc
{
    char *filename;
    unsigned linnum;
    unsigned charnum;

    Loc(int y, int x)
    {
        linnum = y;
        charnum = x;
        filename = NULL;
    }
};

void error(Loc loc, const char *format, ...);
#endif

#if OMFOBJ

static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"

#define MULTISCOPE      1       /* account for bug in MultiScope debugger
                                   where it cannot handle a line number
                                   with multiple offsets. We use a bit vector
                                   to filter out the extra offsets.
                                 */

#define TOOFFSET(a,b)   (I32 ? TOLONG(a,b) : TOWORD(a,b))

/**************************
 * Record types:
 */

#define RHEADR  0x6E
#define REGINT  0x70
#define REDATA  0x72
#define RIDATA  0x74
#define OVLDEF  0x76
#define ENDREC  0x78
#define BLKDEF  0x7A
#define BLKEND  0x7C
//#define DEBSYM        0x7E
#define THEADR  0x80
#define LHEADR  0x82
#define PEDATA  0x84
#define PIDATA  0x86
#define COMENT  0x88
#define MODEND  0x8A
#define EXTDEF  0x8C
#define TYPDEF  0x8E
#define PUBDEF  0x90
#define PUB386  0x91
#define LOCSYM  0x92
#define LINNUM  0x94
#define LNAMES  0x96
#define SEGDEF  0x98
#define SEG386  0x99
#define GRPDEF  0x9A
#define FIXUPP  0x9C
#define FIX386  0x9D
#define LEDATA  0xA0
#define LED386  0xA1
#define LIDATA  0xA2
#define LID386  0xA3
#define LIBHED  0xA4
#define LIBNAM  0xA6
#define LIBLOC  0xA8
#define LIBDIC  0xAA
#define COMDEF  0xB0
#define LEXTDEF 0xB4
#define LPUBDEF 0xB6
#define LCOMDEF 0xB8
#define CEXTDEF 0xBC
#define COMDAT  0xC2
#define LINSYM  0xC4
#define ALIAS   0xC6
#define LLNAMES 0xCA

// Some definitions for .OBJ files. Trial and error to determine which
// one to use when. Page #s refer to Intel spec on .OBJ files.

// Values for LOCAT byte: (pg. 71)
#define LOCATselfrel    0x8000
#define LOCATsegrel     0xC000
// OR'd with one of the following:
#define LOClobyte               0x0000
#define LOCbase                 0x0800
#define LOChibyte               0x1000
#define LOCloader_resolved      0x1400

// Unfortunately, the fixup stuff is different for EASY OMF and Microsoft
#define EASY_LOCoffset          0x1400          // 32 bit offset
#define EASY_LOCpointer         0x1800          // 48 bit seg/offset

#define LOC32offset             0x2400
#define LOC32tlsoffset          0x2800
#define LOC32pointer            0x2C00

#define LOC16offset             0x0400
#define LOC16pointer            0x0C00

#define LOCxx                   0x3C00

// FDxxxx are constants for the FIXDAT byte in fixup records (pg. 72)

#define FD_F0   0x00            // segment index
#define FD_F1   0x10            // group index
#define FD_F2   0x20            // external index
#define FD_F4   0x40            // canonic frame of LSEG that contains Location
#define FD_F5   0x50            // Target determines the frame

#define FD_T0   0               // segment index
#define FD_T1   1               // group index
#define FD_T2   2               // external index
#define FD_T4   4               // segment index, 0 displacement
#define FD_T5   5               // group index, 0 displacement
#define FD_T6   6               // external index, 0 displacement

/***************
 * Fixup list.
 */

struct FIXUP
{
    struct FIXUP        *FUnext;
    targ_size_t         FUoffset;       // offset from start of ledata
    unsigned short      FUlcfd;         // LCxxxx | FDxxxx
    unsigned short      FUframedatum;
    unsigned short      FUtargetdatum;
};

#define list_fixup(fl)  ((struct FIXUP *)list_ptr(fl))

#define seg_is_comdat(seg) ((seg) < 0)

/*****************************
 * Ledata records
 */

#define LEDATAMAX (1024-14)

struct Ledatarec
{
    char header[14];                    // big enough to handle COMDAT header
    char data[LEDATAMAX];
    int lseg;                           // segment value
    unsigned i;                         // number of bytes in data
    targ_size_t offset;                 // segment offset of start of data
    struct FIXUP *fixuplist;            // fixups for this ledata

    // For COMDATs
    unsigned char flags;                // flags byte of COMDAT
    unsigned char alloctyp;             // allocation type of COMDAT
    unsigned char align;                // align type
    int typidx;
    int pubbase;
    int pubnamidx;
};

/*****************************
 * For defining segments.
 */

#define SEG_ATTR(A,C,B,P)       (((A) << 5) | ((C) << 2) | ((B) << 1) | (P))

// Segment alignment A
#define SEG_ALIGN0      0       // absolute segment
#define SEG_ALIGN1      1       // byte align
#define SEG_ALIGN2      2       // word align
#define SEG_ALIGN16     3       // paragraph align
#define SEG_ALIGN4K     4       // 4Kb page align
#define SEG_ALIGN4      5       // dword align

// Segment combine types C
#define SEG_C_ABS       0
#define SEG_C_PUBLIC    2
#define SEG_C_STACK     5
#define SEG_C_COMMON    6

// Segment type P
#define USE16   0
#define USE32   1

#define USE32_CODE      (4+2)           // use32 + execute/read
#define USE32_DATA      (4+3)           // use32 + read/write

/*****************************
 * Line number support.
 */

#define LINNUMMAX       512

struct Linnum
{
#if MARS
        const char *filename;   // source file name
#else
        Sfile *filptr;          // file pointer
#endif
        int cseg;               // our internal segment number
        int seg;                // segment/public index
        int i;                  // used in data[]
        char data[LINNUMMAX];   // linnum/offset data
};

#define LINRECMAX       (2 + 255 * 2)   // room for 255 line numbers

/************************************
 * State of object file.
 */

struct Objstate
{
    const char *modname;
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

    Symbol *startaddress;       // if !NULL, then Symbol is start address

#ifdef DEBUG
    int fixup_count;
#endif

    size_t ledatai;             // max index used in ledatas[]

    // Line numbers
    list_t linnum_list;
    char *linrec;               // line number record
    unsigned linreci;           // index of next avail in linrec[]
    unsigned linrecheader;      // size of line record header
    unsigned linrecnum;         // number of line record entries
    list_t linreclist;          // list of line records
    int mlinnum;
    int recseg;
    int term;
#if MULTISCOPE
    vec_t linvec;               // bit vector of line numbers used
    vec_t offvec;               // and offsets used
#endif

    int fisegi;                 // SegData[] index of FI segment

#if MARS
    int fmsegi;                 // SegData[] of FM segment
#endif

    int tlssegi;                // SegData[] of tls segment
    int fardataidx;

    char pubdata[1024];
    int pubdatai;

    char extdata[1024];
    int extdatai;

    // For Obj::far16thunk
    int code16segi;             // SegData[] index
    targ_size_t CODE16offset;

    int fltused;
    int nullext;
};

Ledatarec **ledatas;
size_t ledatamax;

seg_data **SegData;
static int seg_count;
static int seg_max;

static Objstate obj;

STATIC void obj_defaultlib();
STATIC void objheader (char *csegname);
STATIC char * objmodtoseg (const char *modname);
STATIC void obj_browse_flush();
STATIC int obj_newfarseg (targ_size_t size,int);
STATIC void linnum_flush(void);
STATIC void linnum_term(void);
STATIC void objsegdef (int attr,targ_size_t size,int segnamidx,int classnamidx);
STATIC void obj_modend();
STATIC void objfixupp (struct FIXUP *);
STATIC void outextdata();
STATIC void outpubdata();
STATIC Ledatarec *ledata_new(int seg,targ_size_t offset);

char *id_compress(char *id, int idlen);

/*******************************
 * Output an object file data record.
 * Input:
 *      rectyp  =       record type
 *      record  ->      the data
 *      reclen  =       # of bytes in record
 */

void objrecord(unsigned rectyp,const char *record,unsigned reclen)
{   Outbuffer *o = obj.buf;

    //printf("rectyp = x%x, record[0] = x%x, reclen = x%x\n",rectyp,record[0],reclen);
    o->reserve(reclen + 4);
    o->writeByten(rectyp);
    o->writeWordn(reclen + 1);  // record length includes checksum
    o->writen(record,reclen);
    o->writeByten(0);           // use 0 for checksum
}


/**************************
 * Insert an index number.
 * Input:
 *      p -> where to put the 1 or 2 byte index
 *      index = the 15 bit index
 * Returns:
 *      # of bytes stored
 */

extern void error(const char *filename, unsigned linnum, unsigned charnum, const char *format, ...);
extern void fatal();

void too_many_symbols()
{
#if SCPP
    err_fatal(EM_too_many_symbols, 0x7FFF);
#elif TARGET_WINDOS // COFF
    error(NULL, 0, 0, "more than %d sections in object file", 65279);
    fatal();    
#else // MARS
    error(NULL, 0, 0, "more than %d symbols in object file", 0x7FFF);
    fatal();
#endif
}

#if !DEBUG && TX86 && __INTSIZE == 4 && !defined(_MSC_VER)
__declspec(naked) int __pascal insidx(char *p,unsigned index)
{
#undef AL
#undef AH
#undef DL
#undef DH
    _asm
    {
        mov     EAX,index - 4[ESP]
        mov     ECX,p - 4[ESP]
        cmp     EAX,0x7F
        jae     L1
        mov     [ECX],AL
        mov     EAX,1
        ret     8


    L1:
        cmp     EAX,0x7FFF
        ja      L2

        mov     1[ECX],AL
        or      EAX,0x8000
        mov     [ECX],AH
        mov     EAX,2
        ret     8
    }
    L2:
        too_many_symbols();
}
#else
__inline int insidx(char *p,unsigned index)
{
    //if (index > 0x7FFF) printf("index = x%x\n",index);
    /* OFM spec says it could be <=0x7F, but that seems to cause
     * "library is corrupted" messages. Unverified. See Bugzilla 3601
     */
    if (index < 0x7F)
    {   *p = index;
        return 1;
    }
    else if (index <= 0x7FFF)
    {
        *(p + 1) = index;
        *p = (index >> 8) | 0x80;
        return 2;
    }
    else
    {   too_many_symbols();
        return 0;
    }
}
#endif

/**************************
 * Insert a type index number.
 * Input:
 *      p -> where to put the 1 or 2 byte index
 *      index = the 15 bit index
 * Returns:
 *      # of bytes stored
 */

__inline int instypidx(char *p,unsigned index)
{
    if (index <= 127)
    {   *p = index;
        return 1;
    }
    else if (index <= 0x7FFF)
    {   *(p + 1) = index;
        *p = (index >> 8) | 0x80;
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

#define getindex(p) ((*(p) & 0x80) \
    ? ((*(unsigned char *)(p) & 0x7F) << 8) | *((unsigned char *)(p) + 1) \
    : *(unsigned char *)(p))

/*****************************
 * Returns:
 *      # of bytes stored
 */

#define ONS_OHD 4               // max # of extra bytes added by obj_namestring()

STATIC int obj_namestring(char *p,const char *name)
{   unsigned len;

    len = strlen(name);
    if (len > 255)
    {   p[0] = 0xFF;
        p[1] = 0;
#ifdef DEBUG
        assert(len <= 0xFFFF);
#endif
        TOWORD(p + 2,len);
        memcpy(p + 4,name,len);
        len += ONS_OHD;
    }
    else
    {   p[0] = len;
        memcpy(p + 1,name,len);
        len++;
    }
    return len;
}

/******************************
 * Allocate a new segment.
 * Return index for the new segment.
 */

seg_data *getsegment()
{
    int seg = ++seg_count;
    if (seg_count == seg_max)
    {
        seg_max += 10;
        SegData = (seg_data **)mem_realloc(SegData, seg_max * sizeof(seg_data *));
        memset(&SegData[seg_count], 0, 10 * sizeof(seg_data *));
    }
    assert(seg_count < seg_max);
    if (SegData[seg])
        memset(SegData[seg], 0, sizeof(seg_data));
    else
        SegData[seg] = (seg_data *)mem_calloc(sizeof(seg_data));

    seg_data *pseg = SegData[seg];
    pseg->SDseg = seg;
    pseg->segidx = 0;
    return pseg;
}

/**************************
 * Output read only data and generate a symbol for it.
 *
 */

symbol * Obj::sym_cdata(tym_t ty,char *p,int len)
{
    symbol *s;

    alignOffset(CDATA, tysize(ty));
    s = symboldata(CDoffset, ty);
    s->Sseg = CDATA;
    Obj::bytes(CDATA, CDoffset, len, p);
    CDoffset += len;

    s->Sfl = FLdata; //FLextern;
    return s;
}

/**************************
 * Ouput read only data for data.
 * Output:
 *      *pseg   segment of that data
 * Returns:
 *      offset of that data
 */

int Obj::data_readonly(char *p, int len, int *pseg)
{
#if MARS
    targ_size_t oldoff = CDoffset;
    Obj::bytes(CDATA,CDoffset,len,p);
    CDoffset += len;
    *pseg = CDATA;
#else
    targ_size_t oldoff = Doffset;
    Obj::bytes(DATA,Doffset,len,p);
    Doffset += len;
    *pseg = DATA;
#endif
    return oldoff;
}

int Obj::data_readonly(char *p, int len)
{
    int pseg;

    return Obj::data_readonly(p, len, &pseg);
}

segidx_t Obj::seg_debugT()
{
    return DEBTYP;
}

/******************************
 * Perform initialization that applies to all .obj output files.
 * Input:
 *      filename        source file name
 *      csegname        code segment name (can be NULL)
 */

Obj *Obj::init(Outbuffer *objbuf, const char *filename, const char *csegname)
{
        //printf("Obj::init()\n");
        Obj *mobj = new Obj();

        memset(&obj,0,sizeof(obj));

        obj.buf = objbuf;
        obj.buf->reserve(40000);

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

        if (!SegData)
        {   seg_max = UDATA + 10;
            SegData = (seg_data **)mem_calloc(seg_max * sizeof(seg_data *));
        }

        for (int i = 0; i < seg_max; i++)
        {
            if (SegData[i])
                memset(SegData[i], 0, sizeof(seg_data));
            else
                SegData[i] = (seg_data *)mem_calloc(sizeof(seg_data));
        }

        SegData[CODE]->SDseg = CODE;
        SegData[DATA]->SDseg = DATA;
        SegData[CDATA]->SDseg = CDATA;
        SegData[UDATA]->SDseg = UDATA;

        SegData[CODE]->segidx = CODE;
        SegData[DATA]->segidx = DATA;
        SegData[CDATA]->segidx = CDATA;
        SegData[UDATA]->segidx = UDATA;

        seg_count = UDATA;

        if (config.fulltypes)
        {
            SegData[DEBSYM]->SDseg = DEBSYM;
            SegData[DEBTYP]->SDseg = DEBTYP;

            SegData[DEBSYM]->segidx = DEBSYM;
            SegData[DEBTYP]->segidx = DEBTYP;

            seg_count = DEBTYP;
        }

        mobj->theadr(filename);
        obj.modname = filename;
        if (!csegname || !*csegname)            // if no code seg name supplied
            obj.csegname = objmodtoseg(obj.modname);    // generate one
        else
            obj.csegname = mem_strdup(csegname);        // our own copy
        objheader(obj.csegname);
        mobj->segment_group(0,0,0,0);             // obj seg and grp info
        ledata_new(cseg,0);             // so ledata is never NULL
        if (config.fulltypes)           // if full typing information
        {   objmod = mobj;
            cv_init();                  // initialize debug output code
        }

        return mobj;
}

/**************************
 * Initialize the start of object output for this particular .obj file.
 */

void Obj::initfile(const char *filename,const char *csegname, const char *modname)
{
}

/***************************
 * Fixup and terminate object file.
 */

void Obj::termfile()
{
}

/*********************************
 * Terminate package.
 */

void Obj::term(const char *objfilename)
{
        //printf("Obj::term()\n");
        list_t dl;
        unsigned long size;

#if SCPP
        if (!errcnt)
#endif
        {   obj_defaultlib();
            outfixlist();               // backpatches
        }

        if (config.fulltypes)
            cv_term();                  // write out final debug info
        outextdata();                   // finish writing EXTDEFs
        outpubdata();                   // finish writing PUBDEFs

        // Put out LEDATA records and associated fixups
        for (size_t i = 0; i < obj.ledatai; i++)
        {   Ledatarec *d = ledatas[i];

            if (d->i)                   // if any data in this record
            {   // Fill in header
                int headersize;
                int rectyp;
                assert(d->lseg > 0 && d->lseg <= seg_count);
                int lseg = SegData[d->lseg]->segidx;
                char header[sizeof(d->header)];

                if (seg_is_comdat(lseg))   // if COMDAT
                {
                    header[0] = d->flags | (d->offset ? 1 : 0); // continuation flag
                    header[1] = d->alloctyp;
                    header[2] = d->align;
                    TOOFFSET(header + 3,d->offset);
                    headersize = 3 + intsize;
                    headersize += instypidx(header + headersize,d->typidx);
                    if ((header[1] & 0x0F) == 0)
                    {   // Group index
                        header[headersize] = (d->pubbase == DATA) ? 1 : 0;
                        headersize++;

                        // Segment index
                        headersize += insidx(header + headersize,d->pubbase);
                    }
                    headersize += insidx(header + headersize,d->pubnamidx);

                    rectyp = I32 ? COMDAT + 1 : COMDAT;
                }
                else
                {
                    rectyp = LEDATA;
                    headersize = insidx(header,lseg);
                    if (intsize == LONGSIZE || d->offset & ~0xFFFFL)
                    {   if (!(config.flags & CFGeasyomf))
                            rectyp++;
                        TOLONG(header + headersize,d->offset);
                        headersize += 4;
                    }
                    else
                    {
                        TOWORD(header + headersize,d->offset);
                        headersize += 2;
                    }
                }
                assert(headersize <= sizeof(d->header));

                // Right-justify data in d->header[]
                memcpy(d->header + sizeof(d->header) - headersize,header,headersize);
                //printf("objrecord(rectyp=x%02x, d=%p, p=%p, size = %d)\n",
                //rectyp,d,d->header + (sizeof(d->header) - headersize),d->i + headersize);

                objrecord(rectyp,d->header + (sizeof(d->header) - headersize),
                        d->i + headersize);
                objfixupp(d->fixuplist);
            }
        }
#if TERMCODE
        //list_free(&obj.ledata_list,mem_freefp);
#endif

        linnum_term();
        obj_modend();

        size = obj.buf->size();
        obj.buf->setsize(0);            // rewind file
        Obj::theadr(obj.modname);
        objheader(obj.csegname);
        mem_free(obj.csegname);
        Obj::segment_group(SegData[CODE]->SDoffset, SegData[DATA]->SDoffset, SegData[CDATA]->SDoffset, SegData[UDATA]->SDoffset);  // do real sizes

        // Update any out-of-date far segment sizes
        for (size_t i = 0; i <= seg_count; i++)
        {   seg_data *f = SegData[i];
            if (f->isfarseg && f->origsize != f->SDoffset)
            {   obj.buf->setsize(f->seek);
                objsegdef(f->attr,f->SDoffset,f->lnameidx,f->classidx);
            }
        }
        //mem_free(obj.farseg);

        //printf("Ledata max = %d\n", obj.ledatai);
#if 0
        printf("Max # of fixups = %d\n",obj.fixup_count);
#endif

        obj.buf->setsize(size);
}

/*****************************
 * Line number support.
 */

/***************************
 * Record line number linnum at offset.
 * Input:
 *      cseg    current code segment (negative for COMDAT segments)
 *      pubnamidx
 *      obj.mlinnum             LINNUM or LINSYM
 */

void Obj::linnum(Srcpos srcpos,targ_size_t offset)
{
    unsigned linnum = srcpos.Slinnum;

#if 0
#if MARS || SCPP
    printf("Obj::linnum(cseg=%d, offset=0x%lx) ", cseg, offset);
#endif
    srcpos.print("");
#endif

    char linos2 = config.exe == EX_OS2 && !seg_is_comdat(SegData[cseg]->segidx);

#if MARS
    if (!obj.term &&
        (seg_is_comdat(SegData[cseg]->segidx) || (srcpos.Sfilename && srcpos.Sfilename != obj.modname)))
#else
    if (!srcpos.Sfilptr)
        return;
    sfile_debug(&srcpos_sfile(srcpos));
    if (!obj.term && (!(srcpos_sfile(srcpos).SFflags & SFtop) || (seg_is_comdat(SegData[cseg]->segidx) && !obj.term)))
#endif
    {   // Not original source file, or a COMDAT.
        // Save data away and deal with it at close of compile.
        // It is done this way because presumably 99% of the lines
        // will be in the original source file, so we wish to minimize
        // memory consumption and maximize speed.
        list_t ll;
        struct Linnum *ln;

        if (linos2)
            return;             // BUG: not supported under OS/2
        for (ll = obj.linnum_list; 1; ll = list_next(ll))
        {
            if (!ll)
            {
                ln = (struct Linnum *) mem_calloc(sizeof(struct Linnum));
#if MARS
                ln->filename = srcpos.Sfilename;
#else
                ln->filptr = *srcpos.Sfilptr;
#endif
                ln->cseg = cseg;
                ln->seg = obj.pubnamidx;
                list_prepend(&obj.linnum_list,ln);
                break;
            }
            ln = (Linnum *)list_ptr(ll);
            if (
#if MARS
                (ln->filename == srcpos.Sfilename) &&
#endif
#if SCPP
                (ln->filptr == *srcpos.Sfilptr) &&
#endif
                ln->cseg == cseg &&
                ln->i < LINNUMMAX - 6)
                break;
        }
        TOWORD(&ln->data[ln->i],linnum);
        TOOFFSET(&ln->data[ln->i + 2],offset);
        ln->i += 2 + intsize;
    }
    else
    {
        if (linos2 && obj.linreci > LINRECMAX - 8)
            obj.linrec = NULL;                  // allocate a new one
        else if (cseg != obj.recseg)
            linnum_flush();

        if (!obj.linrec)                        // if not allocated
        {       obj.linrec = (char *) mem_calloc(LINRECMAX);
                obj.linrec[0] = 0;              // base group / flags
                obj.linrecheader = 1 + insidx(obj.linrec + 1,seg_is_comdat(SegData[cseg]->segidx) ? obj.pubnamidx : SegData[cseg]->segidx);
                obj.linreci = obj.linrecheader;
                obj.recseg = cseg;
#if MULTISCOPE
                if (!obj.linvec)
                {   obj.linvec = vec_calloc(1000);
                    obj.offvec = vec_calloc(1000);
                }
#endif
                if (linos2)
                {
                    if (!obj.linreclist)        // if first line number record
                        obj.linreci += 8;       // leave room for header
                    list_append(&obj.linreclist,obj.linrec);
                }

                // Select record type to use
                obj.mlinnum = seg_is_comdat(SegData[cseg]->segidx) ? LINSYM : LINNUM;
                if (I32 && !(config.flags & CFGeasyomf))
                    obj.mlinnum++;
        }
        else if (obj.linreci > LINRECMAX - (2 + intsize))
        {       objrecord(obj.mlinnum,obj.linrec,obj.linreci);  // output data
                obj.linreci = obj.linrecheader;
                if (seg_is_comdat(SegData[cseg]->segidx))        // if LINSYM record
                    obj.linrec[0] |= 1;         // continuation bit
        }
#if MULTISCOPE
        if (linnum >= vec_numbits(obj.linvec))
            obj.linvec = vec_realloc(obj.linvec,linnum + 1000);
        if (offset >= vec_numbits(obj.offvec))
        {
#if __INTSIZE == 2
            unsigned newsize = (unsigned)offset * 2;

            if (offset >= 0x8000)
            {   newsize = 0xFF00;
                assert(offset < newsize);
            }
            if (newsize != vec_numbits(obj.offvec))
                obj.offvec = vec_realloc(obj.offvec,newsize);
#else
            if (offset < 0xFF00)        // otherwise we overflow ph_malloc()
                obj.offvec = vec_realloc(obj.offvec,offset * 2);
#endif
        }
        if (
#if 1 // disallow multiple offsets per line
            !vec_testbit(linnum,obj.linvec) &&  // if linnum not already used
#endif
            // disallow multiple lines per offset
            (offset >= 0xFF00 || !vec_testbit(offset,obj.offvec)))      // and offset not already used
#endif
        {
#if MULTISCOPE
            vec_setbit(linnum,obj.linvec);              // mark linnum as used
            if (offset < 0xFF00)
                vec_setbit(offset,obj.offvec);  // mark offset as used
#endif
            TOWORD(obj.linrec + obj.linreci,linnum);
            if (linos2)
            {   obj.linrec[obj.linreci + 2] = 1;        // source file index
                TOLONG(obj.linrec + obj.linreci + 4,offset);
                obj.linrecnum++;
                obj.linreci += 8;
            }
            else
            {
                TOOFFSET(obj.linrec + obj.linreci + 2,offset);
                obj.linreci += 2 + intsize;
            }
        }
    }
}

/***************************
 * Flush any pending line number records.
 */

STATIC void linnum_flush()
{
    if (obj.linreclist)
    {   list_t list;
        size_t len;

        obj.linrec = (char *) list_ptr(obj.linreclist);
        TOWORD(obj.linrec + 6,obj.linrecnum);
        list = obj.linreclist;
        while (1)
        {   obj.linrec = (char *) list_ptr(list);

            list = list_next(list);
            if (list)
            {   objrecord(obj.mlinnum,obj.linrec,LINRECMAX);
                mem_free(obj.linrec);
            }
            else
            {   objrecord(obj.mlinnum,obj.linrec,obj.linreci);
                break;
            }
        }
        list_free(&obj.linreclist,FPNULL);

        // Put out File Names Table
        TOLONG(obj.linrec + 2,0);               // record no. of start of source (???)
        TOLONG(obj.linrec + 6,obj.linrecnum);   // number of primary source records
        TOLONG(obj.linrec + 10,1);              // number of source and listing files
        len = obj_namestring(obj.linrec + 14,obj.modname);
        assert(14 + len <= LINRECMAX);
        objrecord(obj.mlinnum,obj.linrec,14 + len);

        mem_free(obj.linrec);
        obj.linrec = NULL;
    }
    else if (obj.linrec)                        // if some line numbers to send
    {   objrecord(obj.mlinnum,obj.linrec,obj.linreci);
        mem_free(obj.linrec);
        obj.linrec = NULL;
    }
#if MULTISCOPE
    vec_clear(obj.linvec);
    vec_clear(obj.offvec);
#endif
}

/*************************************
 * Terminate line numbers.
 */

STATIC void linnum_term()
{   list_t ll;
#if SCPP
    Sfile *lastfilptr = NULL;
#endif
#if MARS
    const char *lastfilename = NULL;
#endif
    int csegsave = cseg;

    linnum_flush();
    obj.term = 1;
    while (obj.linnum_list)
    {   struct Linnum *ln;
        unsigned u;
        Srcpos srcpos;
        targ_size_t offset;

        ll = obj.linnum_list;
        ln = (struct Linnum *) list_ptr(ll);
#if SCPP
        Sfile *filptr = ln->filptr;
        if (filptr != lastfilptr)
        {   Obj::theadr(filptr->SFname);
            lastfilptr = filptr;
        }
#endif
#if MARS
        const char *filename = ln->filename;
        if (filename != lastfilename)
        {
            if (filename)
                objmod->theadr(filename);
            lastfilename = filename;
        }
#endif
        while (1)
        {
            cseg = ln->cseg;
            assert(cseg > 0);
            obj.pubnamidx = ln->seg;
#if MARS
            srcpos.Sfilename = ln->filename;
#else
            srcpos.Sfilptr = &ln->filptr;
#endif
            for (u = 0; u < ln->i; )
            {
                srcpos.Slinnum = *(unsigned short *)&ln->data[u];
                u += 2;
                if (I32)
                    offset = *(unsigned long *)&ln->data[u];
                else
                    offset = *(unsigned short *)&ln->data[u];
                objmod->linnum(srcpos,offset);
                u += intsize;
            }
            linnum_flush();
            ll = list_next(ll);
            list_subtract(&obj.linnum_list,ln);
            mem_free(ln);
        L1:
            if (!ll)
                break;
            ln = (struct Linnum *) list_ptr(ll);
#if SCPP
            if (filptr != ln->filptr)
#else
            if (filename != ln->filename)
#endif
            {   ll = list_next(ll);
                goto L1;
            }
        }
    }
    cseg = csegsave;
    assert(cseg > 0);
#if MULTISCOPE
    vec_free(obj.linvec);
    vec_free(obj.offvec);
#endif
}

/*******************************
 * Set start address
 */

void Obj::startaddress(Symbol *s)
{
    obj.startaddress = s;
}

/*******************************
 * Output DOSSEG coment record.
 */

void Obj::dosseg()
{   static const char dosseg[] = { 0x80,0x9E };

    objrecord(COMENT,dosseg,sizeof(dosseg));
}

/*******************************
 * Embed comment record.
 */

STATIC void obj_comment(unsigned char x, const char *string, size_t len)
{
    char __ss *library;

    library = (char __ss *) alloca(2 + len);
    library[0] = 0;
    library[1] = x;
    memcpy(library + 2,string,len);
    objrecord(COMENT,library,len + 2);
}

/*******************************
 * Output library name.
 * Output:
 *      name is modified
 * Returns:
 *      true if operation is supported
 */

bool Obj::includelib(const char *name)
{   const char *p;
    size_t len = strlen(name);

    p = filespecdotext(name);
    if (!filespeccmp(p,".lib"))
        len -= strlen(p);               // lop off .LIB extension
    obj_comment(0x9F, name, len);
    return true;
}

/**********************************
 * Do we allow zero sized objects?
 */

bool Obj::allowZeroSize()
{
    return false;
}

/**************************
 * Embed string in executable.
 */

void Obj::exestr(const char *p)
{
    obj_comment(0xA4,p, strlen(p));
}

/**************************
 * Embed string in obj.
 */

void Obj::user(const char *p)
{
    obj_comment(0xDF,p, strlen(p));
}

/*********************************
 * Put out default library name.
 */

STATIC void obj_defaultlib()
{
    char library[4];            // default library
    static const char model[MEMMODELS+1] = "SMCLV";

#if MARS
    memcpy(library,"SM?",4);
#else
    memcpy(library,"SD?",4);
#endif
    switch (config.exe)
    {
        case EX_OS2:
            library[2] = 'F';
        case EX_OS1:
            library[1] = 'O';
            break;
        case EX_NT:
#if MARS
            library[1] = 'M';
#else
            library[1] = 'N';
#endif
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
        objmod->includelib(configv.deflibname ? configv.deflibname : library);
    }
}

/*******************************
 * Output a weak extern record.
 * s1 is the weak extern, s2 is its default resolution.
 */

void Obj::wkext(Symbol *s1,Symbol *s2)
{
    //printf("Obj::wkext(%s)\n", s1->Sident);
    if (I32)
    {
        // Optlink crashes with weak symbols at EIP 41AFE7, 402000
        return;
    }

    int x2;
    if (s2)
        x2 = s2->Sxtrnnum;
    else
    {
        if (!obj.nullext)
        {
            obj.nullext = Obj::external_def("__nullext");
        }
        x2 = obj.nullext;
    }
    outextdata();

    char buffer[2+2+2];
    buffer[0] = 0x80;
    buffer[1] = 0xA8;
    int i = 2;
    i += insidx(&buffer[2],s1->Sxtrnnum);
    i += insidx(&buffer[i],x2);
    objrecord(COMENT,buffer,i);
}

/*******************************
 * Output a lazy extern record.
 * s1 is the lazy extern, s2 is its default resolution.
 */

void Obj::lzext(Symbol *s1,Symbol *s2)
{   char buffer[2+2+2];
    int i;

    outextdata();
    buffer[0] = 0x80;
    buffer[1] = 0xA9;
    i = 2;
    i += insidx(&buffer[2],s1->Sxtrnnum);
    i += insidx(&buffer[i],s2->Sxtrnnum);
    objrecord(COMENT,buffer,i);
}

/*******************************
 * Output an alias definition record.
 */

void Obj::alias(const char *n1,const char *n2)
{   unsigned len;
    char *buffer;

    buffer = (char *) alloca(strlen(n1) + strlen(n2) + 2 * ONS_OHD);
    len = obj_namestring(buffer,n1);
    len += obj_namestring(buffer + len,n2);
    objrecord(ALIAS,buffer,len);
}

/*******************************
 * Output module name record.
 */

void Obj::theadr(const char *modname)
{
    //printf("Obj::theadr(%s)\n", modname);

    // Convert to absolute file name, so debugger can find it anywhere
    char absname[260];
    if (config.fulltypes &&
        modname[0] != '\\' && modname[0] != '/' && !(modname[0] && modname[1] == ':'))
    {
        if (getcwd(absname, sizeof(absname)))
        {
            int len = strlen(absname);
            if(absname[len - 1] != '\\' && absname[len - 1] != '/')
                absname[len++] = '\\';
            strcpy(absname + len, modname);
            modname = absname;
        }
    }

    char *theadr = (char *)alloca(ONS_OHD + strlen(modname));
    int i = obj_namestring(theadr,modname);
    objrecord(THEADR,theadr,i);                 // module name record
}

/*******************************
 * Embed compiler version in .obj file.
 */

void Obj::compiler()
{
    static const char compiler[] = "\0\xDB" "Digital Mars C/C++"
        VERSION
        ;       // compiled by ...

    objrecord(COMENT,compiler,sizeof(compiler) - 1);
}

/*******************************
 * Output header stuff for object files.
 * Input:
 *      csegname        Name to use for code segment (NULL if use default)
 */

STATIC void objheader(char *csegname)
{
  char *nam;
  static char lnames[] =
        "\0\06DGROUP\05_TEXT\04CODE\05_DATA\04DATA\05CONST\04_BSS\03BSS\
\07$$TYPES\06DEBTYP\011$$SYMBOLS\06DEBSYM";

#define CODECLASS       4                       // code class lname index
#define DATACLASS       6                       // data class lname index
#define CDATACLASS      7                       // CONST class lname index
#define BSSCLASS        9                       // BSS class lname index

  // Include debug segment names if inserting type information
  int lnamesize = config.fulltypes ? sizeof(lnames) - 1 : sizeof(lnames) - 1 - 32;
  int texti = 8;                                // index of _TEXT

  static char comment[] = {0,0x9D,'0','?','O'}; // memory model
  static char model[MEMMODELS+1] = "smclv";
  static char exten[] = {0,0xA1,1,'C','V'};     // extended format
  static char pmdeb[] = {0x80,0xA1,1,'H','L','L',0};    // IBM PM debug format

    if (I32)
    {   if (config.flags & CFGeasyomf)
        {
            // Indicate we're in EASY OMF (hah!) format
            static const char easy_omf[] = { 0x80,0xAA,'8','0','3','8','6' };
            objrecord(COMENT,easy_omf,sizeof(easy_omf));
        }
    }

  // Send out a comment record showing what memory model was used
  comment[2] = config.target_cpu + '0';
  comment[3] = model[config.memmodel];
  if (I32)
  {     if (config.exe == EX_NT)
            comment[3] = 'n';
        else if (config.exe == EX_OS2)
            comment[3] = 'f';
        else
            comment[3] = 'x';
  }
  objrecord(COMENT,comment,sizeof(comment));

    // Send out comment indicating we're using extensions to .OBJ format
    if (config.exe == EX_OS2)
        objrecord(COMENT,pmdeb,sizeof(pmdeb));
    else
        objrecord(COMENT,exten,sizeof(exten));

    // Change DGROUP to FLAT if we are doing flat memory model
    // (Watch out, objheader() is called twice!)
    if (config.exe & EX_flat)
    {
        if (lnames[2] != 'F')                   // do not do this twice
        {   memcpy(lnames + 1,"\04FLAT",5);
            memmove(lnames + 6,lnames + 8,sizeof(lnames) - 8);
        }
        lnamesize -= 2;
        texti -= 2;
    }

    // Put out segment and group names
    if (csegname)
    {   char *p;
        size_t i;

        // Replace the module name _TEXT with the new code segment name
        i = strlen(csegname);
        p = (char *)alloca(lnamesize + i - 5);
        memcpy(p,lnames,8);
        p[texti] = i;
        texti++;
        memcpy(p + texti,csegname,i);
        memcpy(p + texti + i,lnames + texti + 5,lnamesize - (texti + 5));
        objrecord(LNAMES,p,lnamesize + i - 5);
    }
    else
        objrecord(LNAMES,lnames,lnamesize);
}

/********************************
 * Convert module name to code segment name.
 * Output:
 *      mem_malloc'd code seg name
 */

STATIC char * objmodtoseg(const char *modname)
{   char *csegname = NULL;

    if (LARGECODE)              // if need to add in module name
    {   int i;
        char *m;
        static const char suffix[] = "_TEXT";

        // Prepend the module name to the beginning of the _TEXT
        m = filespecgetroot(filespecname(modname));
        strupr(m);
        i = strlen(m);
        csegname = (char *)mem_malloc(i + sizeof(suffix));
        strcpy(csegname,m);
        strcat(csegname,suffix);
        mem_free(m);
    }
    return csegname;
}

/*********************************
 * Put out a segment definition.
 */

STATIC void objsegdef(int attr,targ_size_t size,int segnamidx,int classnamidx)
{
    unsigned reclen;
    char sd[1+4+2+2+2+1];

    //printf("objsegdef(attr=x%x, size=x%x, segnamidx=x%x, classnamidx=x%x)\n",
      //attr,size,segnamidx,classnamidx);
    sd[0] = attr;
    if (attr & 1 || config.flags & CFGeasyomf)
    {   TOLONG(sd + 1,size);            // store segment size
        reclen = 5;
    }
    else
    {
#ifdef DEBUG
        assert(size <= 0xFFFF);
#endif
        TOWORD(sd + 1,size);
        reclen = 3;
    }
    reclen += insidx(sd + reclen,segnamidx);    // segment name index
    reclen += insidx(sd + reclen,classnamidx);  // class name index
    sd[reclen] = 1;                             // overlay name index
    reclen++;
    if (attr & 1)                       // if USE32
    {
        if (config.flags & CFGeasyomf)
        {   // Translate to Pharlap format
            sd[0] &= ~1;                // turn off P bit

            // Translate A: 4->6
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
#if MARS
        assert(0);
#else
        if (size & ~0xFFFFL)
        {   if (size == 0x10000)        // if exactly 64Kb
                sd[0] |= 2;             // set "B" bit
            else
                synerr(EM_seg_gt_64k,size);     // segment exceeds 64Kb
        }
//printf("attr = %x\n", attr);
#endif
    }
#ifdef DEBUG
    assert(reclen <= sizeof(sd));
#endif
    objrecord(SEGDEF + (sd[0] & 1),sd,reclen);
}

/*********************************
 * Output segment and group definitions.
 * Input:
 *      codesize        size of code segment
 *      datasize        size of initialized data segment
 *      cdatasize       size of initialized const data segment
 *      udatasize       size of uninitialized data segment
 */

void Obj::segment_group(targ_size_t codesize,targ_size_t datasize,
                targ_size_t cdatasize,targ_size_t udatasize)
{
    int dsegattr;
    int dsymattr;

    // Group into DGROUP the segments CONST, _BSS and _DATA
    // For FLAT model, it's just GROUP FLAT
    static const char grpdef[] = {2,0xFF,2,0xFF,3,0xFF,4};

    objsegdef(obj.csegattr,codesize,3,CODECLASS);  // seg _TEXT, class CODE

#if MARS
    dsegattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE32);
    objsegdef(dsegattr,datasize,5,DATACLASS);   // [DATA]  seg _DATA, class DATA
    objsegdef(dsegattr,cdatasize,7,CDATACLASS); // [CDATA] seg CONST, class CONST
    objsegdef(dsegattr,udatasize,8,BSSCLASS);   // [UDATA] seg _BSS,  class BSS
#else
    dsegattr = I32
          ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
          : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);
    objsegdef(dsegattr,datasize,5,DATACLASS);   // seg _DATA, class DATA
    objsegdef(dsegattr,cdatasize,7,CDATACLASS); // seg CONST, class CONST
    objsegdef(dsegattr,udatasize,8,BSSCLASS);   // seg _BSS, class BSS
#endif

    obj.lnameidx = 10;                          // next lname index
    obj.segidx = 5;                             // next segment index

    if (config.fulltypes)
    {
        dsymattr = I32
              ? SEG_ATTR(SEG_ALIGN1,SEG_C_ABS,0,USE32)
              : SEG_ATTR(SEG_ALIGN1,SEG_C_ABS,0,USE16);

        if (config.exe & EX_flat)
        {   // IBM's version of CV uses dword aligned segments
            dsymattr = SEG_ATTR(SEG_ALIGN4,SEG_C_ABS,0,USE32);
        }
        else if (config.fulltypes == CV4)
        {   // Always use 32 bit segments
            dsymattr |= USE32;
            assert(!(config.flags & CFGeasyomf));
        }
        objsegdef(dsymattr,SegData[DEBSYM]->SDoffset,0x0C,0x0D);
        objsegdef(dsymattr,SegData[DEBTYP]->SDoffset,0x0A,0x0B);
        obj.lnameidx += 4;                      // next lname index
        obj.segidx += 2;                        // next segment index
    }

    objrecord(GRPDEF,grpdef,(config.exe & EX_flat) ? 1 : sizeof(grpdef));
#if 0
    // Define fixup threads, we don't use them
    {   static const char thread[] = { 0,3,1,2,2,1,3,4,0x40,1,0x45,1 };
        objrecord(obj.mfixupp,thread,sizeof(thread));
    }
    // This comment appears to indicate that no more PUBDEFs, EXTDEFs,
    // or COMDEFs are coming.
    {   static const char cv[] = {0,0xA2,1};
        objrecord(COMENT,cv,sizeof(cv));
    }
#endif
}

//#if NEWSTATICDTOR

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

void Obj::staticctor(Symbol *s,int dtor,int seg)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static char lnamector[] = "\05XIFCB\04XIFU\04XIFL\04XIFM\05XIFCE";
    static char lnamedtor[] = "\04XOFB\03XOF\04XOFE";
    static char lnamedtorf[] = "\03XOB\02XO\03XOE";

    symbol_debug(s);

    // Determine if near or far function
    assert(I32 || tyfarfunc(s->ty()));

    // Put out LNAMES record
    objrecord(LNAMES,lnamector,sizeof(lnamector) - 1);

    int dsegattr = I32
        ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
        : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

    for (int i = 0; i < 5; i++)
    {   int sz;

        sz = (i == seg) ? 4 : 0;

        // Put out segment definition record
        objsegdef(dsegattr,sz,obj.lnameidx,DATACLASS);

        if (i == seg)
        {
            seg_data *pseg = getsegment();
            pseg->segidx = obj.segidx;
            Obj::reftoident(pseg->SDseg,0,s,0,0);     // put out function pointer
        }

        obj.segidx++;
        obj.lnameidx++;
    }

    if (dtor)
    {   // Leave space in XOF segment so that __fatexit() can insert a
        // pointer to the static destructor in XOF.

        // Put out LNAMES record
        if (LARGEDATA)
            objrecord(LNAMES,lnamedtorf,sizeof(lnamedtorf) - 1);
        else
            objrecord(LNAMES,lnamedtor,sizeof(lnamedtor) - 1);

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

void Obj::staticdtor(Symbol *s)
{
    assert(0);
}

//#else

/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

void Obj::funcptr(Symbol *s)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static char lnames[4][5+4+5+1] =
    {   "\03XIB\02XI\03XIE",            // near constructor
        "\03XCB\02XC\03XCE",            // near destructor
        "\04XIFB\03XIF\04XIFE",         // far constructor
        "\04XCFB\03XCF\04XCFE",         // far destructor
    };
    // Size of each of the above strings
    static int lnamesize[4] = { 4+3+4,4+3+4,5+4+5,5+4+5 };

    int dsegattr;
    int i;

    symbol_debug(s);
#ifdef DEBUG
    assert(memcmp(s->Sident,"_ST",3) == 0);
#endif

    // Determine if constructor or destructor
    // _STI... is a constructor, _STD... is a destructor
    i = s->Sident[3] == 'D';
    // Determine if near or far function
    if (tyfarfunc(s->Stype->Tty))
        i += 2;

    // Put out LNAMES record
    objrecord(LNAMES,lnames[i],lnamesize[i]);

    dsegattr = I32
        ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
        : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);

    // Put out beginning segment
    objsegdef(dsegattr,0,obj.lnameidx,DATACLASS);
    obj.segidx++;

    // Put out segment definition record
    // size is NPTRSIZE or FPTRSIZE
    objsegdef(dsegattr,(i & 2) + tysize[TYnptr],obj.lnameidx + 1,DATACLASS);
    seg_data *pseg = getsegment();
    pseg->segidx = obj.segidx;
    Obj::reftoident(pseg->SDseg,0,s,0,0);     // put out function pointer
    obj.segidx++;

    // Put out ending segment
    objsegdef(dsegattr,0,obj.lnameidx + 2,DATACLASS);
    obj.segidx++;

    obj.lnameidx += 3;                  // for next time
}

//#endif

/***************************************
 * Stuff pointer to function in its own segment.
 * Used for static ctor and dtor lists.
 */

void Obj::ehtables(Symbol *sfunc,targ_size_t size,Symbol *ehsym)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static char lnames[] =
    {   "\03FIB\02FI\03FIE"             // near constructor
    };
    int i;
    int dsegattr;
    targ_size_t offset;

    symbol_debug(sfunc);

    if (obj.fisegi == 0)
    {
        // Put out LNAMES record
        objrecord(LNAMES,lnames,sizeof(lnames) - 1);

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
        SegData[obj.fisegi]->attr = dsegattr;
        assert(SegData[obj.fisegi]->segidx == obj.segidx);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 1,DATACLASS);

        obj.lnameidx += 2;              // for next time
        obj.segidx += 2;
    }
    offset = SegData[obj.fisegi]->SDoffset;
    offset += Obj::reftoident(obj.fisegi,offset,sfunc,0,LARGECODE ? CFoff | CFseg : CFoff);   // put out function pointer
    offset += Obj::reftoident(obj.fisegi,offset,ehsym,0,0);   // pointer to data
    Obj::bytes(obj.fisegi,offset,intsize,&size);          // size of function
    SegData[obj.fisegi]->SDoffset = offset + intsize;
}

void Obj::ehsections()
{
    assert(0);
}

/***************************************
 * Append pointer to ModuleInfo to "FM" segment.
 * The FM segment is bracketed by the empty FMB and FME segments.
 */

#if MARS

void Obj::moduleinfo(Symbol *scc)
{
    // We need to always put out the segments in triples, so that the
    // linker will put them in the correct order.
    static char lnames[] =
    {   "\03FMB\02FM\03FME"
    };

    symbol_debug(scc);

    if (obj.fmsegi == 0)
    {
        // Put out LNAMES record
        objrecord(LNAMES,lnames,sizeof(lnames) - 1);

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
        SegData[obj.fmsegi]->attr = dsegattr;
        assert(SegData[obj.fmsegi]->segidx == obj.segidx);

        // Put out ending segment
        objsegdef(dsegattr,0,obj.lnameidx + 1,DATACLASS);

        obj.lnameidx += 2;              // for next time
        obj.segidx += 2;
    }

    targ_size_t offset = SegData[obj.fmsegi]->SDoffset;
    offset += Obj::reftoident(obj.fmsegi,offset,scc,0,LARGECODE ? CFoff | CFseg : CFoff);     // put out function pointer
    SegData[obj.fmsegi]->SDoffset = offset;
}

#endif


/*********************************
 * Setup for Symbol s to go into a COMDAT segment.
 * Output (if s is a function):
 *      cseg            segment index of new current code segment
 *      Coffset         starting offset in cseg
 * Returns:
 *      "segment index" of COMDAT (which will be a negative value to
 *      distinguish it from regular segments).
 */

int Obj::comdatsize(Symbol *s, targ_size_t symsize)
{
    return Obj::comdat(s);
}

int Obj::comdat(Symbol *s)
{   char lnames[IDMAX+IDOHD+1]; // +1 to allow room for strcpy() terminating 0
    char cextdef[2+2];
    char __ss *p;
    size_t lnamesize;
    unsigned ti;
    int isfunc;
    tym_t ty;

    symbol_debug(s);
    ty = s->ty();
    isfunc = tyfunc(ty) != 0;

    // Put out LNAME for name of Symbol
    lnamesize = Obj::mangle(s,lnames);
    objrecord((s->Sclass == SCstatic ? LLNAMES : LNAMES),lnames,lnamesize);

    // Put out CEXTDEF for name of Symbol
    outextdata();
    p = cextdef;
    p += insidx(p,obj.lnameidx++);
    ti = (config.fulltypes == CVOLD) ? cv_typidx(s->Stype) : 0;
    p += instypidx(p,ti);
    objrecord(CEXTDEF,cextdef,p - cextdef);
    s->Sxtrnnum = ++obj.extidx;

    seg_data *pseg = getsegment();
    pseg->segidx = -obj.extidx;
    assert(pseg->SDseg > 0);

    // Start new LEDATA record for this COMDAT
    Ledatarec *lr = ledata_new(pseg->SDseg,0);
    lr->typidx = ti;
    lr->pubnamidx = obj.lnameidx - 1;
    if (isfunc)
    {   lr->pubbase = SegData[cseg]->segidx;
        if (s->Sclass == SCcomdat || s->Sclass == SCinline)
            lr->alloctyp = 0x10 | 0x00; // pick any instance | explicit allocation
        cseg = lr->lseg;
        assert(cseg > 0 && cseg <= seg_count);
        obj.pubnamidx = obj.lnameidx - 1;
        Coffset = 0;
        if (tyfarfunc(ty) && strcmp(s->Sident,"main") == 0)
            lr->alloctyp |= 1;  // because MS does for unknown reasons
    }
    else
    {   unsigned char atyp;

        switch (ty & mTYLINK)
        {   case 0:
            case mTYnear:       lr->pubbase = DATA;
#if 0
                                atyp = 0;       // only one instance is allowed
#else
                                atyp = 0x10;    // pick any (also means it is
                                                // not searched for in a library)
#endif
                                break;

#if TARGET_SEGMENTED
            case mTYcs:         lr->flags |= 0x08;      // data in code seg
                                atyp = 0x11;    break;

            case mTYfar:        atyp = 0x12;    break;
#endif
            case mTYthread:     lr->pubbase = Obj::tlsseg()->segidx;
                                atyp = 0x10;    // pick any (also means it is
                                                // not searched for in a library)
                                break;

            default:            assert(0);
        }
        lr->alloctyp = atyp;
    }
    if (s->Sclass == SCstatic)
        lr->flags |= 0x04;      // local bit (make it an "LCOMDAT")
    s->Soffset = 0;
    return pseg->SDseg;
}

/**********************************
 * Reset code seg to existing seg.
 * Used after a COMDAT for a function is done.
 */

void Obj::setcodeseg(int seg)
{
    assert(0 < seg && seg <= seg_count);
    cseg = seg;
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

int Obj::codeseg(char *name,int suffix)
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
    char *lnames = (char *) alloca(1 + lnamesize + 1);
    lnames[0] = lnamesize;
    assert(lnamesize <= (255 - 2 - sizeof(int)*3));
    strcpy(lnames + 1,name);
    if (suffix)
        strcat(lnames + 1,"_TEXT");
    objrecord(LNAMES,lnames,lnamesize + 1);

    cseg = obj_newfarseg(0,4);
    SegData[cseg]->attr = obj.csegattr;
    SegData[cseg]->segidx = obj.segidx;
    assert(cseg > 0);
    obj.segidx++;
    Coffset = 0;

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

seg_data *Obj::tlsseg_bss() { return Obj::tlsseg(); }

seg_data *Obj::tlsseg()
{   //static char tlssegname[] = "\04$TLS\04$TLS";
    //static char tlssegname[] = "\05.tls$\03tls";
    static const char tlssegname[] = "\05.tls$\03tls\04.tls\010.tls$ZZZ";

    if (obj.tlssegi == 0)
    {   int segattr;

        objrecord(LNAMES,tlssegname,sizeof(tlssegname) - 1);

#if MARS
        segattr = SEG_ATTR(SEG_ALIGN16,SEG_C_PUBLIC,0,USE32);
#else
        segattr = I32
            ? SEG_ATTR(SEG_ALIGN4,SEG_C_PUBLIC,0,USE32)
            : SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);
#endif

        // Put out beginning segment (.tls)
        objsegdef(segattr,0,obj.lnameidx + 2,obj.lnameidx + 1);
        obj.segidx++;

        // Put out .tls$ segment definition record
        obj.tlssegi = obj_newfarseg(0,obj.lnameidx + 1);
        objsegdef(segattr,0,obj.lnameidx,obj.lnameidx + 1);
        SegData[obj.tlssegi]->attr = segattr;
        SegData[obj.tlssegi]->segidx = obj.segidx;

        // Put out ending segment (.tls$ZZZ)
        objsegdef(segattr,0,obj.lnameidx + 3,obj.lnameidx + 1);

        obj.lnameidx += 4;
        obj.segidx += 2;
    }
    return SegData[obj.tlssegi];
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

int Obj::fardata(char *name,targ_size_t size,targ_size_t *poffset)
{
    static char fardataclass[] = "\010FAR_DATA";
    int len;
    int i;
    char *buffer;

    // See if we can use existing far segment, and just bump its size
    i = obj.lastfardatasegi;
    if (i != -1
        && (intsize != 2 || (unsigned long) SegData[i]->SDoffset + size < 0x8000)
        )
    {   *poffset = SegData[i]->SDoffset;        // BUG: should align this
        SegData[i]->SDoffset += size;
        return i;
    }

    // No. We need to build a new far segment

    if (obj.fardataidx == 0)            // if haven't put out far data lname
    {   // Put out class lname
        objrecord(LNAMES,fardataclass,sizeof(fardataclass) - 1);
        obj.fardataidx = obj.lnameidx++;
    }

    // Generate name based on module name
    name = strupr(filespecgetroot(filespecname(obj.modname)));

    // Generate name for this far segment
    len = 1 + strlen(name) + 3 + 5 + 1;
    buffer = (char *)alloca(len);
    sprintf(buffer + 1,"%s%d_DATA",name,obj.segidx);
    len = strlen(buffer + 1);
    buffer[0] = len;
    assert(len <= 255);
    objrecord(LNAMES,buffer,len + 1);

    mem_free(name);

    // Construct a new SegData[] entry
    obj.lastfardatasegi = obj_newfarseg(size,obj.fardataidx);

    // Generate segment definition
    objsegdef(obj.fdsegattr,size,obj.lnameidx++,obj.fardataidx);
    obj.segidx++;

    *poffset = 0;
    return SegData[obj.lastfardatasegi]->SDseg;
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

STATIC int obj_newfarseg(targ_size_t size,int classidx)
{
    seg_data *f = getsegment();
    f->isfarseg = true;
    f->seek = obj.buf->size();
    f->attr = obj.fdsegattr;
    f->origsize = size;
    f->SDoffset = size;
    f->segidx = obj.segidx;
    f->lnameidx = obj.lnameidx;
    f->classidx = classidx;
    return f->SDseg;
}

/******************************
 * Convert reference to imported name.
 */

void Obj::import(elem *e)
{
#if MARS
    assert(0);
#else
    Symbol *s;
    Symbol *simp;

    elem_debug(e);
    if ((e->Eoper == OPvar || e->Eoper == OPrelconst) &&
        (s = e->EV.sp.Vsym)->ty() & mTYimport &&
        (s->Sclass == SCextern || s->Sclass == SCinline)
       )
    {   char *name;
        char *p;
        size_t len;
        char buffer[IDMAX + IDOHD + 1];

        // Create import name
        len = Obj::mangle(s,buffer);
        if (buffer[0] == (char)0xFF && buffer[1] == 0)
        {   name = buffer + 4;
            len -= 4;
        }
        else
        {   name = buffer + 1;
            len -= 1;
        }
        if (config.flags4 & CFG4underscore)
        {   p = (char *) alloca(5 + len + 1);
            memcpy(p,"_imp_",5);
            memcpy(p + 5,name,len);
            p[5 + len] = 0;
        }
        else
        {   p = (char *) alloca(6 + len + 1);
            memcpy(p,"__imp_",6);
            memcpy(p + 6,name,len);
            p[6 + len] = 0;
        }
        simp = scope_search(p,SCTglobal);
        if (!simp)
        {   type *t;

            simp = scope_define(p,SCTglobal,SCextern);
            simp->Ssequence = 0;
            simp->Sfl = FLextern;
            simp->Simport = s;
            t = newpointer(s->Stype);
            t->Tmangle = mTYman_c;
            t->Tcount++;
            simp->Stype = t;
        }
        assert(!e->EV.sp.Voffset);
        if (e->Eoper == OPrelconst)
        {
            e->Eoper = OPvar;
            e->EV.sp.Vsym = simp;
        }
        else // OPvar
        {
            e->Eoper = OPind;
            e->E1 = el_var(simp);
            e->E2 = NULL;
        }
    }
#endif
}

/*******************************
 * Mangle a name.
 * Returns:
 *      length of mangled name
 */

size_t Obj::mangle(Symbol *s,char *dest)
{   size_t len;
    size_t ilen;
    char *name;
    char *name2 = NULL;

    //printf("Obj::mangle('%s'), mangle = x%x\n",s->Sident,type_mangle(s->Stype));
#if SCPP
    name = CPP ? cpp_mangle(s) : s->Sident;
#elif MARS
    name = cpp_mangle(s);
#else
    name = s->Sident;
#endif
    len = strlen(name);                 // # of bytes in name

    // Use as max length the max length lib.exe can handle
    // Use 5 as length of _ + @nnn
//    #define LIBIDMAX ((512 - 0x25 - 3 - 4) - 5)
#define LIBIDMAX 128
    if (len > LIBIDMAX)
    //if (len > IDMAX)
    {
        size_t len2;

        // Attempt to compress the name
        name2 = id_compress(name, len);
        len2  = strlen(name2);
#if MARS
        if (len2 > LIBIDMAX)            // still too long
        {
            /* Form md5 digest of the name and store it in the
             * last 32 bytes of the name.
             */
            MD5_CTX mdContext;
            MD5Init(&mdContext);
            MD5Update(&mdContext, (unsigned char *)name, len);
            MD5Final(&mdContext);
            memcpy(name2, name, LIBIDMAX - 32);
            for (int i = 0; i < 16; i++)
            {   unsigned char c = mdContext.digest[i];
                unsigned char c1 = (c >> 4) & 0x0F;
                unsigned char c2 = c & 0x0F;
                c1 += (c1 < 10) ? '0' : 'A' - 10;
                name2[LIBIDMAX - 32 + i * 2] = c1;
                c2 += (c2 < 10) ? '0' : 'A' - 10;
                name2[LIBIDMAX - 32 + i * 2 + 1] = c2;
            }
            name = name2;
            len = LIBIDMAX;
            name[len] = 0;
            //printf("name = '%s', len = %d, strlen = %d\n", name, len, strlen(name));
        }
#else
        if (len2 > IDMAX)               // still too long
        {
#if SCPP
            synerr(EM_identifier_too_long, name, len - IDMAX, IDMAX);
#elif MARS
//          error(Loc(), "identifier %s is too long by %d characters", name, len - IDMAX);
#else
            assert(0);
#endif
            len = IDMAX;
        }
#endif
        else
        {
            name = name2;
            len = len2;
        }
    }
    ilen = len;
    if (ilen > (255-2-sizeof(int)*3))
        dest += 3;
    switch (type_mangle(s->Stype))
    {   case mTYman_pas:                // if upper case
        case mTYman_for:
            memcpy(dest + 1,name,len);  // copy in name
            dest[1 + len] = 0;
            strupr(dest + 1);           // to upper case
            break;
#if SCPP || MARS
        case mTYman_cpp:
#if NEWMANGLE
            memcpy(dest + 1,name,len);
            break;
#endif
#endif
        case mTYman_std:
            if (!(config.flags4 & CFG4oldstdmangle) &&
                config.exe == EX_NT && tyfunc(s->ty()) &&
                !variadic(s->Stype))
            {
                dest[1] = '_';
                memcpy(dest + 2,name,len);
                dest[1 + 1 + len] = '@';
                itoa(type_paramsize(s->Stype),dest + 3 + len,10);
                len = strlen(dest + 1);
                assert(isdigit(dest[len]));
                break;
            }
        case mTYman_c:
            if (config.flags4 & CFG4underscore)
            {
                dest[1] = '_';          // leading _ in name
                memcpy(&dest[2],name,len);      // copy in name
                len++;
                break;
            }
        case mTYman_d:
        case mTYman_sys:
            memcpy(dest + 1, name, len);        // no mangling
            dest[1 + len] = 0;
            break;
        default:
#ifdef DEBUG
            symbol_print(s);
#endif
            assert(0);
    }
    if (ilen > (255-2-sizeof(int)*3))
    {   dest -= 3;
        dest[0] = 0xFF;
        dest[1] = 0;
#ifdef DEBUG
        assert(len <= 0xFFFF);
#endif
        TOWORD(dest + 2,len);
        len += 4;
    }
    else
    {   *dest = len;
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

void Obj::export_symbol(Symbol *s,unsigned argsize)
{   char *coment;
    size_t len;

    coment = (char *) alloca(4 + 1 + (IDMAX + IDOHD) + 1); // allow extra byte for mangling
    len = Obj::mangle(s,&coment[4]);
    assert(len <= IDMAX + IDOHD);
    coment[1] = 0xA0;                           // comment class
    coment[2] = 2;                              // why??? who knows
    if (argsize >= 64)                          // we only have a 5 bit field
        argsize = 0;                            // hope we don't need callgate
    coment[3] = (argsize + 1) >> 1;             // # words on stack
    coment[4 + len] = 0;                        // no internal name
    objrecord(COMENT,coment,4 + len + 1);       // module name record
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

int Obj::data_start(Symbol *sdata, targ_size_t datasize, int seg)
{
    targ_size_t alignbytes;
    //printf("Obj::data_start(%s,size %llx,seg %d)\n",sdata->Sident,datasize,seg);
    //symbol_print(sdata);

    if (sdata->Sseg == UNKNOWN) // if we don't know then there
        sdata->Sseg = seg;      // wasn't any segment override
    else
        seg = sdata->Sseg;
    targ_size_t offset = SegData[seg]->SDoffset;
    if (sdata->Salignment > 0)
    {   if (SegData[seg]->SDalignment < sdata->Salignment)
            SegData[seg]->SDalignment = sdata->Salignment;
        alignbytes = ((offset + sdata->Salignment - 1) & ~(sdata->Salignment - 1)) - offset;
    }
    else
        alignbytes = align(datasize, offset) - offset;
    sdata->Soffset = offset + alignbytes;
    SegData[seg]->SDoffset = sdata->Soffset;
    return seg;
}

void Obj::func_start(Symbol *sfunc)
{
    //printf("Obj::func_start(%s)\n",sfunc->Sident);
    symbol_debug(sfunc);
    sfunc->Sseg = cseg;             // current code seg
    sfunc->Soffset = Coffset;       // offset of start of function
}

/*******************************
 * Update function info after codgen
 */

void Obj::func_term(Symbol *sfunc)
{
}

/********************************
 * Output a public definition.
 * Input:
 *      seg =           segment index that symbol is defined in
 *      s ->            symbol
 *      offset =        offset of name
 */

STATIC void outpubdata()
{
    if (obj.pubdatai)
    {   objrecord(obj.mpubdef,obj.pubdata,obj.pubdatai);
        obj.pubdatai = 0;
    }
}

void Obj::pubdef(int seg,Symbol *s,targ_size_t offset)
{   unsigned reclen,len;
    char *p;
    unsigned ti;

    assert(offset < 100000000);
    int idx = SegData[seg]->segidx;
    if (obj.pubdatai + 1 + (IDMAX + IDOHD) + 4 + 2 > sizeof(obj.pubdata) ||
        idx != getindex(obj.pubdata + 1))
        outpubdata();
    if (obj.pubdatai == 0)
    {
        obj.pubdata[0] = (seg == DATA || seg == CDATA || seg == UDATA) ? 1 : 0; // group index
        obj.pubdatai += 1 + insidx(obj.pubdata + 1,idx);        // segment index
    }
    p = &obj.pubdata[obj.pubdatai];
    len = Obj::mangle(s,p);              // mangle in name
    reclen = len + intsize;
    p += len;
    TOOFFSET(p,offset);
    p += intsize;
    ti = (config.fulltypes == CVOLD) ? cv_typidx(s->Stype) : 0;
    reclen += instypidx(p,ti);
    obj.pubdatai += reclen;
}

void Obj::pubdefsize(int seg, Symbol *s, targ_size_t offset, targ_size_t symsize)
{
    Obj::pubdef(seg, s, offset);
}

/*******************************
 * Output an external definition.
 * Input:
 *      name -> external identifier
 * Returns:
 *      External index of the definition (1,2,...)
 */

STATIC void outextdata()
{
    if (obj.extdatai)
    {   objrecord(EXTDEF,obj.extdata,obj.extdatai);
        obj.extdatai = 0;
    }
}

int Obj::external_def(const char *name)
{   unsigned len;
    char *e;

    //dbg_printf("Obj::external_def('%s')\n",name);
    assert(name);
    len = strlen(name);                 // length of identifier
    if (obj.extdatai + len + ONS_OHD + 1 > sizeof(obj.extdata))
        outextdata();

    e = &obj.extdata[obj.extdatai];
    len = obj_namestring(e,name);
    e[len] = 0;                         // typidx = 0
    obj.extdatai += len + 1;
    assert(obj.extdatai <= sizeof(obj.extdata));
    return ++obj.extidx;
}

/*******************************
 * Output an external definition.
 * Input:
 *      s       Symbol to do EXTDEF on
 * Returns:
 *      External index of the definition (1,2,...)
 */

int Obj::external(Symbol *s)
{
    //dbg_printf("Obj::external('%s')\n",s->Sident);
    symbol_debug(s);
    if (obj.extdatai + (IDMAX + IDOHD) + 3 > sizeof(obj.extdata))
        outextdata();

    char *e = &obj.extdata[obj.extdatai];
    unsigned len = Obj::mangle(s,e);
    e[len] = 0;                 // typidx = 0
    obj.extdatai += len + 1;
    s->Sxtrnnum = ++obj.extidx;
    return obj.extidx;
}

/*******************************
 * Output a common block definition.
 * Input:
 *      p ->    external identifier
 *      flag    TRUE:   in default data segment
 *              FALSE:  not in default data segment
 *      size    size in bytes of each elem
 *      count   number of elems
 * Returns:
 *      External index of the definition (1,2,...)
 */

// Helper for Obj::common_block()

static unsigned storelength(unsigned long length,unsigned i)
{
    obj.extdata[i] = length;
    if (length >= 128)  // Microsoft docs say 129, but their linker
                        // won't take >=128, so accommodate it
    {   obj.extdata[i] = 129;
#ifdef DEBUG
        assert(length <= 0xFFFF);
#endif
        TOWORD(obj.extdata + i + 1,length);
        if (length >= 0x10000)
        {   obj.extdata[i] = 132;
            obj.extdata[i + 3] = length >> 16;

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

int Obj::common_block(Symbol *s,targ_size_t size,targ_size_t count)
{
    return common_block(s, 0, size, count);
}

int Obj::common_block(Symbol *s,int flag,targ_size_t size,targ_size_t count)
{ register unsigned i;
  unsigned long length;
  unsigned ti;

    //dbg_printf("Obj::common_block('%s',%d,%d,%d)\n",s->Sident,flag,size,count);
    outextdata();               // borrow the extdata[] storage
    i = Obj::mangle(s,obj.extdata);

    ti = (config.fulltypes == CVOLD) ? cv_typidx(s->Stype) : 0;
    i += instypidx(obj.extdata + i,ti);

  if (flag)                             // if in default data segment
  {
        //printf("NEAR comdef\n");
        obj.extdata[i] = 0x62;
        length = (unsigned long) size * count;
        assert(I32 || length <= 0x10000);
        i = storelength(length,i + 1);
  }
  else
  {
        //printf("FAR comdef\n");
        obj.extdata[i] = 0x61;
        i = storelength((unsigned long) size,i + 1);
        i = storelength((unsigned long) count,i);
  }
  assert(i <= arraysize(obj.extdata));
  objrecord(COMDEF,obj.extdata,i);
  return ++obj.extidx;
}

/***************************************
 * Append an iterated data block of 0s.
 * (uninitialized data only)
 */

void Obj::write_zeros(seg_data *pseg, targ_size_t count)
{
    Obj::lidata(pseg->SDseg, pseg->SDoffset, count);
    //pseg->SDoffset += count;
}

/***************************************
 * Output an iterated data block of 0s.
 * (uninitialized data only)
 */

void Obj::lidata(int seg,targ_size_t offset,targ_size_t count)
{   int i;
    unsigned reclen;
    static char zero[20];
    char data[20];
    char __ss *di;

    //printf("Obj::lidata(seg = %d, offset = x%x, count = %d)\n", seg, offset, count);

    SegData[seg]->SDoffset += count;

    if (seg == UDATA)
        return;
    int idx = SegData[seg]->segidx;

Lagain:
    if (count <= sizeof(zero))          // if shorter to use ledata
    {
        Obj::bytes(seg,offset,count,zero);
        return;
    }

    if (seg_is_comdat(idx))
    {
        while (count > sizeof(zero))
        {
            Obj::bytes(seg,offset,sizeof(zero),zero);
            offset += sizeof(zero);
            count -= sizeof(zero);
        }
        Obj::bytes(seg,offset,count,zero);
        return;
    }

    i = insidx(data,idx);
    di = data + i;
    TOOFFSET(di,offset);

    if (config.flags & CFGeasyomf)
    {
        if (count >= 0x8000)            // repeat count can only go to 32k
        {
            TOWORD(di + 4,(unsigned short)(count / 0x8000));
            TOWORD(di + 4 + 2,1);               // 1 data block follows
            TOWORD(di + 4 + 2 + 2,0x8000);      // repeat count
            TOWORD(di + 4 + 2 + 2 + 2,0);       // block count
            TOWORD(di + 4 + 2 + 2 + 2 + 2,1);   // 1 byte of 0
            reclen = i + 4 + 5 * 2;
            objrecord(obj.mlidata,data,reclen);

            offset += (count & ~0x7FFFL);
            count &= 0x7FFF;
            goto Lagain;
        }
        else
        {
            TOWORD(di + 4,(unsigned short)count);       // repeat count
            TOWORD(di + 4 + 2,0);                       // block count
            TOWORD(di + 4 + 2 + 2,1);                   // 1 byte of 0
            reclen = i + 4 + 2 + 2 + 2;
            objrecord(obj.mlidata,data,reclen);
        }
    }
    else
    {
        TOOFFSET(di + intsize,count);
        TOWORD(di + intsize * 2,0);     // block count
        TOWORD(di + intsize * 2 + 2,1); // repeat 1 byte of 0s
        reclen = i + (I32 ? 12 : 8);
        objrecord(obj.mlidata,data,reclen);
    }
    assert(reclen <= sizeof(data));
}

/****************************
 * Output a MODEND record.
 */

STATIC void obj_modend()
{
    if (obj.startaddress)
    {   char mdata[10];
        int i;
        unsigned framedatum,targetdatum;
        unsigned char fd;
        targ_size_t offset;
        int external;           // !=0 if identifier is defined externally
        tym_t ty;
        Symbol *s = obj.startaddress;

        // Turn startaddress into a fixup.
        // Borrow heavilly from Obj::reftoident()

        symbol_debug(s);
        offset = 0;
        ty = s->ty();

        switch (s->Sclass)
        {
            case SCcomdat:
            case_SCcomdat:
            case SCextern:
            case SCcomdef:
                if (s->Sxtrnnum)                // identifier is defined somewhere else
                    external = s->Sxtrnnum;
                else
                {
                 Ladd:
                    s->Sclass = SCextern;
                    external = objmod->external(s);
                    outextdata();
                }
                break;
            case SCinline:
                if (config.flags2 & CFG2comdat)
                    goto case_SCcomdat; // treat as initialized common block
            case SCsinline:
            case SCstatic:
            case SCglobal:
                if (s->Sseg == UNKNOWN)
                    goto Ladd;
                if (seg_is_comdat(SegData[s->Sseg]->segidx))   // if in comdat
                    goto case_SCcomdat;
            case SClocstat:
                external = 0;           // identifier is static or global
                                            // and we know its offset
                offset += s->Soffset;
                break;
            default:
    #ifdef DEBUG
                //symbol_print(s);
    #endif
                assert(0);
        }

        if (external)
        {   fd = FD_T2;
            targetdatum = external;
            switch (s->Sfl)
            {
                case FLextern:
                    if (!(ty & (
#if TARGET_SEGMENTED
                                    mTYcs |
#endif
                                    mTYthread)))
                        goto L1;
                case FLfunc:
#if TARGET_SEGMENTED
                case FLfardata:
                case FLcsdata:
#endif
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
            targetdatum = SegData[s->Sseg]->segidx;
            assert(targetdatum != -1);
            switch (s->Sfl)
            {
                case FLextern:
                    if (!(ty & (
#if TARGET_SEGMENTED
                                    mTYcs |
#endif
                                    mTYthread)))
                        goto L1;
                case FLfunc:
#if TARGET_SEGMENTED
                case FLfardata:
                case FLcsdata:
#endif
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
        TOOFFSET(mdata + i,offset);

        objrecord(obj.mmodend,mdata,i + intsize);       // write mdata[] to .OBJ file
    }
    else
    {   static const char modend[] = {0};

        objrecord(obj.mmodend,modend,sizeof(modend));
    }
}

/****************************
 * Output the fixups in list fl.
 */

STATIC void objfixupp(struct FIXUP *f)
{
  unsigned i,j,k;
  targ_size_t locat;
  struct FIXUP *fn;

#if 1   // store in one record
  char data[1024];

  i = 0;
  for (; f; f = fn)
  {     unsigned char fd;

        if (i >= sizeof(data) - (3 + 2 + 2))    // if not enough room
        {   objrecord(obj.mfixupp,data,i);
            i = 0;
        }

        //printf("f = %p, offset = x%x\n",f,f->FUoffset);
        assert(f->FUoffset < 1024);
        locat = (f->FUlcfd & 0xFF00) | f->FUoffset;
        data[i+0] = locat >> 8;
        data[i+1] = locat;
        data[i+2] = fd = f->FUlcfd;
        k = i;
        i += 3 + insidx(&data[i+3],f->FUframedatum);
        //printf("FUframedatum = x%x\n", f->FUframedatum);
        if ((fd >> 4) == (fd & 3) && f->FUframedatum == f->FUtargetdatum)
        {
            data[k + 2] = (fd & 15) | FD_F5;
        }
        else
        {   i += insidx(&data[i],f->FUtargetdatum);
            //printf("FUtargetdatum = x%x\n", f->FUtargetdatum);
        }
        //printf("[%d]: %02x %02x %02x\n", k, data[k + 0] & 0xFF, data[k + 1] & 0xFF, data[k + 2] & 0xFF);
        fn = f->FUnext;
        mem_ffree(f);
  }
  assert(i <= sizeof(data));
  if (i)
      objrecord(obj.mfixupp,data,i);
#else   // store in multiple records
  for (; fl; fl = list_next(fl))
  {
        char data[7];

        assert(f->FUoffset < 1024);
        locat = (f->FUlcfd & 0xFF00) | f->FUoffset;
        data[0] = locat >> 8;
        data[1] = locat;
        data[2] = f->FUlcfd;
        i = 3 + insidx(&data[3],f->FUframedatum);
        i += insidx(&data[i],f->FUtargetdatum);
        objrecord(obj.mfixupp,data,i);
  }
#endif
}


/***************************
 * Add a new fixup to the fixup list.
 * Write things out if we overflow the list.
 */

STATIC void addfixup(Ledatarec *lr, targ_size_t offset,unsigned lcfd,
        unsigned framedatum,unsigned targetdatum)
{   struct FIXUP *f;

    assert(offset < 0x1024);
#ifdef DEBUG
    assert(targetdatum <= 0x7FFF);
    assert(framedatum <= 0x7FFF);
#endif
    f = (struct FIXUP *) mem_fmalloc(sizeof(struct FIXUP));
    //printf("f = %p, offset = x%x\n",f,offset);
    f->FUoffset = offset;
    f->FUlcfd = lcfd;
    f->FUframedatum = framedatum;
    f->FUtargetdatum = targetdatum;
    f->FUnext = lr->fixuplist;  // link f into list
    lr->fixuplist = f;
#ifdef DEBUG
    obj.fixup_count++;                  // gather statistics
#endif
}


/*********************************
 * Open up a new ledata record.
 * Input:
 *      seg     segment number data is in
 *      offset  starting offset of start of data for this record
 */

STATIC Ledatarec *ledata_new(int seg,targ_size_t offset)
{

    //printf("ledata_new(seg = %d, offset = x%lx)\n",seg,offset);
    assert(seg > 0 && seg <= seg_count);

    if (obj.ledatai == ledatamax)
    {
        size_t o = ledatamax;
        ledatamax = o * 2 + 100;
        ledatas = (Ledatarec **)mem_realloc(ledatas, ledatamax * sizeof(Ledatarec *));
        memset(ledatas + o, 0, (ledatamax - o) * sizeof(Ledatarec *));
    }
    Ledatarec *lr = ledatas[obj.ledatai];
    if (!lr)
    {   lr = (Ledatarec *) mem_malloc(sizeof(Ledatarec));
        ledatas[obj.ledatai] = lr;
    }
    memset(lr, 0, sizeof(Ledatarec));
    ledatas[obj.ledatai] = lr;
    obj.ledatai++;

    lr->lseg = seg;
    lr->offset = offset;

    if (seg_is_comdat(SegData[seg]->segidx) && offset)      // if continuation of an existing COMDAT
    {
        Ledatarec *d = SegData[seg]->ledata;
        if (d)
        {
            if (d->lseg == seg)                 // found existing COMDAT
            {   lr->flags = d->flags;
                lr->alloctyp = d->alloctyp;
                lr->align = d->align;
                lr->typidx = d->typidx;
                lr->pubbase = d->pubbase;
                lr->pubnamidx = d->pubnamidx;
            }
        }
    }
    SegData[seg]->ledata = lr;
    return lr;
}

/***********************************
 * Append byte to segment.
 */

void Obj::write_byte(seg_data *pseg, unsigned byte)
{
    Obj::byte(pseg->SDseg, pseg->SDoffset, byte);
    pseg->SDoffset++;
}

/************************************
 * Output byte to object file.
 */

void Obj::byte(int seg,targ_size_t offset,unsigned byte)
{   unsigned i;

    Ledatarec *lr = SegData[seg]->ledata;
    if (!lr)
        goto L2;

    if (
         lr->i > LEDATAMAX - 1 ||       // if it'll overflow
         offset < lr->offset || // underflow
         offset > lr->offset + lr->i
     )
    {
        // Try to find an existing ledata
        for (size_t i = obj.ledatai; i; )
        {   Ledatarec *d = ledatas[--i];
            if (seg == d->lseg &&       // segments match
                offset >= d->offset &&
                offset + 1 <= d->offset + LEDATAMAX &&
                offset <= d->offset + d->i
               )
            {
                lr = SegData[seg]->ledata = d;
                goto L1;
            }
        }
L2:
        lr = ledata_new(seg,offset);
L1:     ;
    }

  i = offset - lr->offset;
  if (lr->i <= i)
        lr->i = i + 1;
  lr->data[i] = byte;           // 1st byte of data
}

/***********************************
 * Append bytes to segment.
 */

void Obj::write_bytes(seg_data *pseg, unsigned nbytes, void *p)
{
    Obj::bytes(pseg->SDseg, pseg->SDoffset, nbytes, p);
    pseg->SDoffset += nbytes;
}

/************************************
 * Output bytes to object file.
 * Returns:
 *      nbytes
 */

unsigned Obj::bytes(int seg,targ_size_t offset,unsigned nbytes, void *p)
{   unsigned n = nbytes;

    //dbg_printf("Obj::bytes(seg=%d, offset=x%lx, nbytes=x%x, p=%p)\n",seg,offset,nbytes,p);
    Ledatarec *lr = SegData[seg]->ledata;
    if (!lr)
        lr = ledata_new(seg, offset);
 L1:
    if (
         lr->i + nbytes > LEDATAMAX ||  // or it'll overflow
         offset < lr->offset ||         // underflow
         offset > lr->offset + lr->i
     )
    {
        while (nbytes)
        {   Obj::byte(seg,offset,*(char *)p);
            offset++;
            p = ((char *)p) + 1;
            nbytes--;
            lr = SegData[seg]->ledata;
            if (lr->i + nbytes <= LEDATAMAX)
                goto L1;
        }
    }
    else
    {
        unsigned i = offset - lr->offset;
        if (lr->i < i + nbytes)
            lr->i = i + nbytes;
        memcpy(lr->data + i,p,nbytes);
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

void Obj::ledata(int seg,targ_size_t offset,targ_size_t data,
        unsigned lcfd,unsigned idx1,unsigned idx2)
{   unsigned i;
    unsigned size;                      // number of bytes to output

#if TARGET_SEGMENTED
    unsigned ptrsize = tysize[TYfptr];
#else
    unsigned ptrsize = I64 ? 10 : 6;
#endif

    if ((lcfd & LOCxx) == obj.LOCpointer)
        size = ptrsize;
    else if ((lcfd & LOCxx) == LOCbase)
        size = 2;
    else
        size = tysize[TYnptr];

    Ledatarec *lr = SegData[seg]->ledata;
    if (!lr)
         lr = ledata_new(seg, offset);
    assert(seg == lr->lseg);
    if (
         lr->i + size > LEDATAMAX ||    // if it'll overflow
         offset < lr->offset || // underflow
         offset > lr->offset + lr->i
     )
    {
        // Try to find an existing ledata
//dbg_printf("seg = %d, offset = x%lx, size = %d\n",seg,offset,size);
        for (size_t i = obj.ledatai; i; )
        {   Ledatarec *d = ledatas[--i];

//dbg_printf("d: seg = %d, offset = x%lx, i = x%x\n",d->lseg,d->offset,d->i);
            if (seg == d->lseg &&       // segments match
                offset >= d->offset &&
                offset + size <= d->offset + LEDATAMAX &&
                offset <= d->offset + d->i
               )
            {
//dbg_printf("match\n");
                lr = SegData[seg]->ledata = d;
                goto L1;
            }
        }
        lr = ledata_new(seg,offset);
L1:     ;
    }

    i = offset - lr->offset;
    if (lr->i < i + size)
        lr->i = i + size;
    if (size == 2 || !I32)
        TOWORD(lr->data + i,data);
    else
        TOLONG(lr->data + i,data);
    if (size == ptrsize)         // if doing a seg:offset pair
        TOWORD(lr->data + i + tysize[TYnptr],0);        // segment portion
    addfixup(lr, offset - lr->offset,lcfd,idx1,idx2);
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

void Obj::write_long(int seg,targ_size_t offset,unsigned long data,
        unsigned lcfd,unsigned idx1,unsigned idx2)
{
#if TARGET_SEGMENTED
    unsigned sz = tysize[TYfptr];
#else
    unsigned sz = I64 ? 10 : 6;
#endif
    Ledatarec *lr = SegData[seg]->ledata;
    if (!lr)
         lr = ledata_new(seg, offset);
    if (
         lr->i + sz > LEDATAMAX || // if it'll overflow
         offset < lr->offset || // underflow
         offset > lr->offset + lr->i
       )
        lr = ledata_new(seg,offset);
    unsigned i = offset - lr->offset;
    if (lr->i < i + sz)
        lr->i = i + sz;
    TOLONG(lr->data + i,data);
    if (I32)                              // if 6 byte far pointers
        TOWORD(lr->data + i + LONGSIZE,0);              // fill out seg
    addfixup(lr, offset - lr->offset,lcfd,idx1,idx2);
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
 *              Obj::reftodatseg(DATA,offset,3 * sizeof(int *),UDATA);
 */

void Obj::reftodatseg(int seg,targ_size_t offset,targ_size_t val,
        unsigned targetdatum,int flags)
{
    assert(flags);

    if (flags == 0 || flags & CFoff)
    {
        // The frame datum is always 1, which is DGROUP
        Obj::ledata(seg,offset,val,
            LOCATsegrel | obj.LOCoffset | FD_F1 | FD_T4,DGROUPIDX,SegData[targetdatum]->segidx);
        offset += intsize;
    }

    if (flags & CFseg)
    {
#if 0
        if (config.wflags & WFdsnedgroup)
            warerr(WM_ds_ne_dgroup);
#endif
        Obj::ledata(seg,offset,0,
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

void Obj::reftofarseg(int seg,targ_size_t offset,targ_size_t val,
        int farseg,int flags)
{
    assert(flags);

    int idx = SegData[farseg]->segidx;
    if (flags == 0 || flags & CFoff)
    {
        Obj::ledata(seg,offset,val,
            LOCATsegrel | obj.LOCoffset | FD_F0 | FD_T4,idx,idx);
        offset += intsize;
    }

    if (flags & CFseg)
    {
        Obj::ledata(seg,offset,0,
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

void Obj::reftocodeseg(int seg,targ_size_t offset,targ_size_t val)
{   unsigned framedatum;
    unsigned lcfd;

    int idx = SegData[cseg]->segidx;
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

    Obj::ledata(seg,offset,val,lcfd,framedatum,idx);
}

/*******************************
 * Refer to an identifier.
 * Input:
 *      seg =           where the address is going (CODE or DATA)
 *      offset =        offset within seg
 *      s ->            Symbol table entry for identifier
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
 *              Obj::reftodatseg(DATA,offset,3 * sizeof(int *),UDATA);
 */

int Obj::reftoident(int seg,targ_size_t offset,Symbol *s,targ_size_t val,
        int flags)
{
    unsigned targetdatum;       // which datum the symbol is in
    unsigned framedatum;
    int     lc;
    int     external;           // !=0 if identifier is defined externally
    int numbytes;
    tym_t ty;

#if 0
    printf("Obj::reftoident('%s' seg %d, offset x%lx, val x%lx, flags x%x)\n",
        s->Sident,seg,offset,val,flags);
    printf("Sseg = %d, Sxtrnnum = %d\n",s->Sseg,s->Sxtrnnum);
    symbol_print(s);
#endif
    assert(seg > 0);

    ty = s->ty();
    while (1)
    {
        switch (flags & (CFseg | CFoff))
        {   case 0:
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
#if 1
                    if (ty & mTYthread)
                    {   lc = LOC32tlsoffset;
                    }
                    else
#endif
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
                numbytes = tysize[TYnptr];
                break;
            case CFseg:
                lc = LOCbase;
                numbytes = 2;
                break;
            case CFoff | CFseg:
                lc = obj.LOCpointer;
#if TARGET_SEGMENTED
                numbytes = tysize[TYfptr];
#else
                numbytes = I64 ? 10 : 6;
#endif
                break;
        }
        break;
    }

    switch (s->Sclass)
    {
        case SCcomdat:
        case_SCcomdat:
        case SCextern:
        case SCcomdef:
            if (s->Sxtrnnum)            // identifier is defined somewhere else
            {   external = s->Sxtrnnum;
#ifdef DEBUG
                if (external > obj.extidx)
                    symbol_print(s);
#endif
                assert(external <= obj.extidx);
            }
            else
            {   // Don't know yet, worry about it later
             Ladd:
                size_t byteswritten = addtofixlist(s,offset,seg,val,flags);
                assert(byteswritten == numbytes);
                return numbytes;
            }
            break;
        case SCinline:
            if (config.flags2 & CFG2comdat)
                goto case_SCcomdat;     // treat as initialized common block
        case SCsinline:
        case SCstatic:
        case SCglobal:
            if (s->Sseg == UNKNOWN)
                goto Ladd;
            if (seg_is_comdat(SegData[s->Sseg]->segidx))
                goto case_SCcomdat;
        case SClocstat:
            external = 0;               // identifier is static or global
                                        // and we know its offset
            if (flags & CFoff)
                val += s->Soffset;
            break;
        default:
#ifdef DEBUG
            symbol_print(s);
#endif
            assert(0);
    }

    lc |= (flags & CFselfrel) ? LOCATselfrel : LOCATsegrel;
    if (external)
    {   lc |= FD_T6;
        targetdatum = external;
        switch (s->Sfl)
        {
            case FLextern:
                if (!(ty & (
#if TARGET_SEGMENTED
                                mTYcs |
#endif
                                mTYthread)))
                    goto L1;
            case FLfunc:
#if TARGET_SEGMENTED
            case FLfardata:
            case FLcsdata:
#endif
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
        targetdatum = SegData[s->Sseg]->segidx;
        assert(s->Sseg != UNKNOWN);
        switch (s->Sfl)
        {
            case FLextern:
                if (!(ty & (
#if TARGET_SEGMENTED
                                mTYcs |
#endif
                                mTYthread)))
                    goto L1;
            case FLfunc:
#if TARGET_SEGMENTED
            case FLfardata:
            case FLcsdata:
#endif
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
#if 0
                if (flags & CFseg && config.wflags & WFdsnedgroup)
                    warerr(WM_ds_ne_dgroup);
#endif
                break;
        }
    }

    Obj::ledata(seg,offset,val,lc,framedatum,targetdatum);
    return numbytes;
}

/*****************************************
 * Generate far16 thunk.
 * Input:
 *      s       Symbol to generate a thunk for
 */

void Obj::far16thunk(Symbol *s)
{
    static unsigned char cod32_1[] =
    {
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
    };
    static unsigned char cod32_2[] =
    {   0x0F,0x85,0x10,0x00,0x00,0x00,  //      JNE     L1
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
        0x8D,0x75,0x08,                 //      LEA     ESI,8[EBP]
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
    };
    static unsigned char cod32_3[] =
    {                                   // L2:
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
    };

    unsigned numparam = 24;
    targ_size_t L2offset;
    int idx;

    s->Sclass = SCstatic;
    s->Sseg = cseg;             // identifier is defined in code segment
    s->Soffset = Coffset;

    // Store numparam into right places
    assert((numparam & 0xFFFF) == numparam);    // 2 byte value
    TOWORD(&cod32_2[32],numparam);
    TOWORD(&cod32_2[32 + 7],numparam);
    TOWORD(&cod32_3[sizeof(cod32_3) - 2],numparam);

    //------------------------------------------
    // Generate CODE16 segment if it isn't there already
    if (obj.code16segi == 0)
    {
        // Define CODE16 segment for far16 thunks

        static char lname[] = { "\06CODE16" };

        // Put out LNAMES record
        objrecord(LNAMES,lname,sizeof(lname) - 1);

        obj.code16segi = obj_newfarseg(0,4);
        obj.CODE16offset = 0;

        // class CODE
        unsigned attr = SEG_ATTR(SEG_ALIGN2,SEG_C_PUBLIC,0,USE16);
        SegData[obj.code16segi]->attr = attr;
        objsegdef(attr,0,obj.lnameidx++,4);
        obj.segidx++;
    }

    //------------------------------------------
    // Output the 32 bit thunk

    Obj::bytes(cseg,Coffset,sizeof(cod32_1),cod32_1);
    Coffset += sizeof(cod32_1);

    // Put out fixup for SEG FLAT:_DATA
    Obj::ledata(cseg,Coffset,0,LOCATsegrel|LOCbase|FD_F1|FD_T4,
        DGROUPIDX,DATA);
    Coffset += 2;

    Obj::bytes(cseg,Coffset,sizeof(cod32_2),cod32_2);
    Coffset += sizeof(cod32_2);

    // Put out fixup to CODE16 part of thunk
    Obj::ledata(cseg,Coffset,obj.CODE16offset,LOCATsegrel|LOC16pointer|FD_F0|FD_T4,
        SegData[obj.code16segi]->segidx,
        SegData[obj.code16segi]->segidx);
    Coffset += 4;

    L2offset = Coffset;
    Obj::bytes(cseg,Coffset,sizeof(cod32_3),cod32_3);
    Coffset += sizeof(cod32_3);

    s->Ssize = Coffset - s->Soffset;            // size of thunk

    //------------------------------------------
    // Output the 16 bit thunk

    Obj::byte(obj.code16segi,obj.CODE16offset++,0x9A);       //      CALLF   function

    // Make function external
    idx = Obj::external(s);                         // use Pascal name mangling

    // Output fixup for function
    Obj::ledata(obj.code16segi,obj.CODE16offset,0,LOCATsegrel|LOC16pointer|FD_F2|FD_T6,
        idx,idx);
    obj.CODE16offset += 4;

    Obj::bytes(obj.code16segi,obj.CODE16offset,3,"\x66\x67\xEA");    // JMPF L2
    obj.CODE16offset += 3;

    Obj::ledata(obj.code16segi,obj.CODE16offset,L2offset,
        LOCATsegrel | LOC32pointer | FD_F1 | FD_T4,
        DGROUPIDX,
        SegData[cseg]->segidx);
    obj.CODE16offset += 6;

    SegData[obj.code16segi]->SDoffset = obj.CODE16offset;
}

/**************************************
 * Mark object file as using floating point.
 */

void Obj::fltused()
{
    if (!obj.fltused)
    {
        obj.fltused = 1;
        if (!(config.flags3 & CFG3wkfloat))
            Obj::external_def("__fltused");
    }
}


/****************************************
 * Find longest match of pattern[] in dict[].
 */

static int longest_match(char *dict, int dlen, char *pattern, int plen,
        int *pmatchoff, int *pmatchlen)
{
    int matchlen = 0;
    int matchoff;

    int i;
    int j;

    for (i = 0; i < dlen; i++)
    {
        if (dict[i] == pattern[0])
        {
            for (j = 1; 1; j++)
            {
                if (i + j == dlen || j == plen)
                    break;
                if (dict[i + j] != pattern[j])
                    break;
            }
            if (j >= matchlen)
            {
                matchlen = j;
                matchoff = i;
            }
        }
    }

    if (matchlen > 1)
    {
        *pmatchlen = matchlen;
        *pmatchoff = matchoff;
        return 1;                       // found a match
    }
    return 0;                           // no match
}

/******************************************
 * Compress an identifier.
 * Format: if ASCII, then it's just the char
 *      if high bit set, then it's a length/offset pair
 * Returns:
 *      malloc'd compressed identifier
 */

char *id_compress(char *id, int idlen)
{
    int i;
    int count = 0;
    char *p;

    p = (char *)malloc(idlen + 1);
    for (i = 0; i < idlen; i++)
    {
        int matchoff;
        int matchlen;

        int j = 0;
        if (i > 1023)
            j = i - 1023;

        if (longest_match(id + j, i - j, id + i, idlen - i, &matchoff, &matchlen))
        {   int off;

            matchoff += j;
            off = i - matchoff;
            //printf("matchoff = %3d, matchlen = %2d, off = %d\n", matchoff, matchlen, off);
            assert(off >= matchlen);

            if (off <= 8 && matchlen <= 8)
            {
                p[count] = 0xC0 | ((off - 1) << 3) | (matchlen - 1);
                count++;
                i += matchlen - 1;
                continue;
            }
            else if (matchlen > 2 && off < 1024)
            {
                if (matchlen >= 1024)
                    matchlen = 1023;    // longest representable match
                p[count + 0] = 0x80 | ((matchlen >> 4) & 0x38) | ((off >> 7) & 7);
                p[count + 1] = 0x80 | matchlen;
                p[count + 2] = 0x80 | off;
                count += 3;
                i += matchlen - 1;
                continue;
            }
        }
        p[count] = id[i];
        count++;
    }
    p[count] = 0;
    //printf("old size = %d, new size = %d\n", idlen, count);
    return p;
}

#endif
#endif
