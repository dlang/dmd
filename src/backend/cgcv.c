// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


#if (SCPP || MARS) && !HTOD

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        <stdlib.h>

#include        "cc.h"
#include        "type.h"
#include        "code.h"
#include        "cgcv.h"
#include        "cv4.h"
#include        "global.h"
#if SCPP
#include        "parser.h"
#include        "cpp.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

// Convert from SFL protections to CV4 protections
#define SFLtoATTR(sfl)  (4 - (((sfl) & SFLpmask) >> 5))

/* Dynamic array of debtyp_t's  */
static debtyp_t **debtyp;
static unsigned debtyptop;      // # of used entries in debtyp[]
static unsigned debtypmax;      // current size of debtyp[]
static vec_t debtypvec;         // vector of used entries
#define DEBTYPVECDIM    16001 //8009 //3001     // dimension of debtypvec (should be prime)

#define DEBTYPHASHDIM   1009
static unsigned debtyphash[DEBTYPHASHDIM];

#define DEB_NULL cgcv.deb_offset        // index of null debug type record

/* This limitation is because of 4K page sizes
 * in optlink/cv/cvhashes.asm
 */
#define CVIDMAX (0xFF0-20)   // the -20 is picked by trial and error

#define LOCATsegrel     0xC000

/* Unfortunately, the fixup stuff is different for EASY OMF and Microsoft */
#define EASY_LCFDoffset         (LOCATsegrel | 0x1404)
#define EASY_LCFDpointer        (LOCATsegrel | 0x1800)

#define LCFD32offset            (LOCATsegrel | 0x2404)
#define LCFD32pointer           (LOCATsegrel | 0x2C00)
#define LCFD16pointer           (LOCATsegrel | 0x0C00)

Cgcv cgcv;

STATIC void cv3_symdes ( unsigned char *p , unsigned next );
STATIC unsigned cv3_paramlist ( type *t , unsigned nparam );
STATIC unsigned cv3_struct ( symbol *s );
STATIC char * cv4_prettyident(symbol *s);
STATIC unsigned cv4_symtypidx ( symbol *s );
STATIC void cv4_outsym(symbol *s);
STATIC void cv4_func(Funcsym *s);

/******************************************
 * Return number of bytes consumed in OBJ file by a name.
 */

#if SCPP
inline
#endif
int cv_stringbytes(const char *name)
{
    size_t len = strlen(name);
    if (config.fulltypes == CV8)
        return len + 1;
    if (len > CVIDMAX)
        len = CVIDMAX;
    return len + ((len > 255) ? 4 : 1);
}

/******************************************
 * Stuff a namestring into p.
 * Returns:
 *      number of bytes consumed
 */

int cv_namestring(unsigned char *p, const char *name, int length)
{
    size_t len = (length >= 0) ? length : strlen(name);
    if (config.fulltypes == CV8)
    {
        size_t numBytesWritten = len + ((length < 0) ? 1 : 0);
        memcpy(p, name, numBytesWritten);
        if(config.flags2 & CFG2gms)
        {
            for(int i = 0; i < len; i++)
            {
                if(p[i] == '.')
                    p[i] = '@';
            }
        }
        return numBytesWritten;
    }
    if (len > 255)
    {   p[0] = 0xFF;
        p[1] = 0;
        if (len > CVIDMAX)
            len = CVIDMAX;
        TOWORD(p + 2,len);
        memcpy(p + 4,name,len);
        len += 4;
    }
    else
    {   p[0] = len;
        memcpy(p + 1,name,len);
        len++;
    }
    return len;
}

/***********************************
 * Compute debug register number for symbol s.
 * Returns:
 *      0..7    byte registers
 *      8..15   word registers
 *      16..23  dword registers
 */

STATIC int cv_regnum(symbol *s)
{   unsigned reg;

    reg = s->Sreglsw;
#if SCPP
    if (s->Sclass == SCpseudo)
    {
        reg = pseudoreg[reg];
    }
    else
#endif
    {
        assert(reg < 8);
        assert(s->Sfl == FLreg);
        switch (type_size(s->Stype))
        {
            case LONGSIZE:
            case 3:             reg += 8;
            case SHORTSIZE:     reg += 8;
            case CHARSIZE:      break;

            case LLONGSIZE:
                reg += (s->Sregmsw << 8) + (16 << 8) + 16;
                if (config.fulltypes == CV4)
                    reg += (1 << 8);
                break;

            default:
#if 0
                symbol_print(s);
                type_print(s->Stype);
                printf("size = %d\n",type_size(s->Stype));
#endif
                assert(0);
        }
    }
    if (config.fulltypes == CV4)
        reg++;
    return reg;
}

/***********************************
 * Allocate a debtyp_t.
 */

debtyp_t * debtyp_alloc(unsigned length)
{
    debtyp_t *d;
    unsigned pad = 0;

    //printf("len = %u, x%x\n", length, length);
    if (config.fulltypes == CV8)
    {   // length+2 must lie on 4 byte boundary
        pad = ((length + 2 + 3) & ~3) - (length + 2);
        length += pad;
    }

#ifdef DEBUG
    unsigned len = sizeof(debtyp_t) - sizeof(d->data) + length;
    assert(len < 4 * 4096 - 100);
    d = (debtyp_t *) mem_malloc(len /*+ 1*/);
    memset(d, 0xAA, len);
//    ((char*)d)[len] = 0x2E;
#else
    assert(length < 0x10000);
    d = (debtyp_t *) malloc(sizeof(debtyp_t) - sizeof(d->data) + length);
#endif
    d->length = length;
    if (pad)
    {
        static const unsigned char padx[3] = {0xF3, 0xF2, 0xF1};
        memcpy(d->data + length - pad, padx + 3 - pad, pad);
    }
    //printf("debtyp_alloc(%d) = %p\n", length, d);
    return d;
}

/***********************************
 * Free a debtyp_t.
 */

STATIC void debtyp_free(debtyp_t *d)
{
    //printf("debtyp_free(length = %d, %p)\n", d->length, d);
    //fflush(stdout);
#ifdef DEBUG
    unsigned len = sizeof(debtyp_t) - sizeof(d->data) + d->length;
    assert(len < 4 * 4096 - 100);
//    assert(((char*)d)[len] == 0x2E);
    memset(d, 0x55, len);
    mem_free(d);
#else
    free(d);
#endif
}

#if 0
void debtyp_check(debtyp_t *d,int linnum)
{   int i;
    static volatile char c;

    //printf("linnum = %d\n",linnum);
    //printf(" length = %d\n",d->length);
    for (i = 0; i < d->length; i++)
        c = d->data[i];
}

#define debtyp_check(d) debtyp_check(d,__LINE__);
#else
#define debtyp_check(d)
#endif

/***********************************
 * Search for debtyp_t in debtyp[]. If it is there, return the index
 * of it, and free d. Otherwise, add it.
 * Returns:
 *      index in debtyp[]
 */

idx_t cv_debtyp(debtyp_t *d)
{   unsigned u;
    unsigned short length;
    unsigned hashi;

    assert(d);
    length = d->length;
    //printf("length = %3d\n",length);
#if SYMDEB_TDB
    if (config.fulltypes == CVTDB)
    {
            idx_t result;

#if 1
            assert(length);
            debtyp_check(d);
            result = tdb_typidx(&d->length);
#else
            unsigned char *buf;

            // Allocate buffer
            buf = malloc(6 + length);
            if (!buf)
                err_nomem();                    // out of memory

            // Fill the buffer
            TOLONG(buf,cgcv.signature);
            memcpy(buf + 4,(char *)d + sizeof(unsigned),2 + length);

#if 0
{int i;
 for (i=0;i<length;i++)
 printf("%02x ",buf[6+i]);
 printf("\n");
}
#endif
            result = tdb_typidx(buf,6 + length);
#endif
            //printf("result = x%x\n",result);
            debtyp_free(d);
            return result;
    }
#endif
    if (length)
    {   unsigned hash;

        hash = length;
        if (length >= sizeof(unsigned))
        {
            // Hash consists of the sum of the first 4 bytes with the last 4 bytes
            union { unsigned char* cp; unsigned* up; } u;
            u.cp = d->data;
            hash += *u.up;
            u.cp += length - sizeof(unsigned);
            hash += *u.up;
        }
        hashi = hash % DEBTYPHASHDIM;
        hash %= DEBTYPVECDIM;
//printf(" hashi = %d", hashi);

        if (vec_testbit(hash,debtypvec))
        {
//printf(" test");
#if 1
            // Threaded list is much faster
            for (u = debtyphash[hashi]; u; u = debtyp[u]->prev)
#else
            for (u = debtyptop; u--; )
#endif
            {
                if (length == debtyp[u]->length &&
                    memcmp(d->data,debtyp[u]->data,length) == 0)
                {   debtyp_free(d);
//printf(" match %d\n",u);
                    return u + cgcv.deb_offset;
                }
            }
        }
        else
            vec_setbit(hash,debtypvec);
    }
    else
        hashi = 1;
//printf(" add   %d\n",debtyptop);
    d->prev = debtyphash[hashi];
    debtyphash[hashi] = debtyptop;

    /* It's not already in the array, so add it */
L1:
    if (debtyptop == debtypmax)
    {
        //printf("reallocate debtyp[] %p\n", debtyp);
#ifdef DEBUG
        debtypmax += 10;
#else
        debtypmax += debtypmax + 16;
        if (debtypmax > 0xE000)
            debtypmax = 0xE000;
#if SCPP
        if (debtyptop >= debtypmax)
            err_fatal(EM_2manytypes,debtypmax);         // too many types
#endif
#endif
        // Don't use MEM here because we can allocate pretty big
        // arrays with this, and we don't want to overflow the PH
        // page size.
        debtyp = (debtyp_t **) util_realloc(debtyp,sizeof(*debtyp),debtypmax);
    }
    debtyp[debtyptop] = d;
    return debtyptop++ + cgcv.deb_offset;
}

idx_t cv_numdebtypes()
{
    return debtyptop;
}

/****************************
 * Store a null record at DEB_NULL.
 */

void cv_init()
{   debtyp_t *d;

    //printf("cv_init()\n");

    // Initialize statics
    debtyp = NULL;
    debtyptop = 0;
    debtypmax = 0;
    if (!ftdbname)
        ftdbname = (char *)"symc.tdb";

    memset(&cgcv,0,sizeof(cgcv));
    cgcv.sz_idx = 2;
    cgcv.LCFDoffset = LCFD32offset;
    cgcv.LCFDpointer = LCFD16pointer;

    debtypvec = vec_calloc(DEBTYPVECDIM);
    memset(debtyphash,0,sizeof(debtyphash));

    /* Reset for different OBJ file formats     */
    if (I32 || I64)
    {
        // Adjust values in old CV tables for 32 bit ints
        dttab[TYenum] = dttab[TYlong];
        dttab[TYint]  = dttab[TYlong];
        dttab[TYuint] = dttab[TYulong];

        // Adjust Codeview 4 values for 32 bit ints and 32 bit pointer offsets
        dttab4[TYenum] = 0x74;
        dttab4[TYint]  = 0x74;
        dttab4[TYuint] = 0x75;
        if (I64)
        {
            dttab4[TYptr]  = 0x600;
            dttab4[TYnptr] = 0x600;
            dttab4[TYjhandle] = 0x600;
        }
        else
        {
            dttab4[TYptr]  = 0x400;
            dttab4[TYnptr] = 0x400;
            dttab4[TYjhandle] = 0x400;
        }
#if TARGET_SEGMENTED
        dttab4[TYsptr] = 0x400;
        dttab4[TYcptr] = 0x400;
        dttab4[TYfptr] = 0x500;
#endif

        if (config.flags & CFGeasyomf)
        {   cgcv.LCFDoffset  = EASY_LCFDoffset;
            cgcv.LCFDpointer = EASY_LCFDpointer;
            assert(config.fulltypes == CVOLD);
        }
        else
            cgcv.LCFDpointer = LCFD32pointer;

        if (config.exe & EX_flat)
            cgcv.FD_code = 0x10;
    }

    if (config.fulltypes >= CV4)
    {   int flags;
        static unsigned short memmodel[5] = {0,0x100,0x20,0x120,0x120};
        char version[1 + sizeof(VERSION)];
        unsigned char debsym[8 + sizeof(version)];

        // Put out signature indicating CV4 format
        switch (config.fulltypes)
        {
            case CV4:
                cgcv.signature = 1;
                break;

            case CV8:
                cgcv.signature = 4;
                break;

            default:
            {   const char *x = "1MYS";
                cgcv.signature = *(int *) x;
                break;
            }
        }

        cgcv.deb_offset = 0x1000;

        if (config.fulltypes == CV8)
        {   cgcv.sz_idx = 4;
            return;     // figure out rest later
        }

        if (config.fulltypes >= CVSYM)
        {   cgcv.sz_idx = 4;
            if (!(config.flags2 & CFG2phgen))
                cgcv.deb_offset = 0x80000000;
        }

        objmod->write_bytes(SegData[DEBSYM],4,&cgcv.signature);

        // Allocate an LF_ARGLIST with no arguments
        if (config.fulltypes == CV4)
        {   d = debtyp_alloc(4);
            TOWORD(d->data,LF_ARGLIST);
            TOWORD(d->data + 2,0);
        }
        else
        {   d = debtyp_alloc(6);
            TOWORD(d->data,LF_ARGLIST);
            TOLONG(d->data + 2,0);
        }

        // Put out S_COMPILE record
        TOWORD(debsym + 2,S_COMPILE);
        switch (config.target_cpu)
        {   case TARGET_8086:   debsym[4] = 0;  break;
            case TARGET_80286:  debsym[4] = 2;  break;
            case TARGET_80386:  debsym[4] = 3;  break;
            case TARGET_80486:  debsym[4] = 4;  break;
            case TARGET_Pentium:
            case TARGET_PentiumMMX:
                                debsym[4] = 5;  break;
            case TARGET_PentiumPro:
            case TARGET_PentiumII:
                                debsym[4] = 6;  break;
            default:    assert(0);
        }
        debsym[5] = (CPP != 0);         // 0==C, 1==C++
        flags = (config.inline8087) ? (0<<3) : (1<<3);
        if (I32)
            flags |= 0x80;              // 32 bit addresses
        flags |= memmodel[config.memmodel];
        TOWORD(debsym + 6,flags);
        version[0] = 'Z';
        strcpy(version + 1,VERSION);
        cv_namestring(debsym + 8,version);
        TOWORD(debsym,6 + sizeof(version));
        objmod->write_bytes(SegData[DEBSYM],8 + sizeof(version),debsym);

#if SYMDEB_TDB
        // Put out S_TDBNAME record
        if (config.fulltypes == CVTDB)
        {
            unsigned char buf[50];

            pstate.STtdbtimestamp = tdb_gettimestamp();
            size_t len = cv_stringbytes(ftdbname);
            unsigned char *ds = (8 + len <= sizeof(buf)) ? buf : (unsigned char *) malloc(8 + len);
            assert(ds);
            TOWORD(ds,6 + len);
            TOWORD(ds + 2,S_TDBNAME);
            TOLONG(ds + 4,pstate.STtdbtimestamp);
            cv_namestring(ds + 8,ftdbname);
            objmod->write_bytes(SegData[DEBSYM],8 + len,ds);
            if (ds != buf)
                free(ds);
        }
#endif
    }
    else
    {
        assert(0);
    }
#if SYMDEB_TDB
    if (config.fulltypes == CVTDB)
        cgcv.deb_offset = cv_debtyp(d);
    else
#endif
        cv_debtyp(d);
}

/////////////////////////// CodeView 4 ///////////////////////////////

/***********************************
 * Return number of bytes required to store a numeric leaf.
 */

unsigned cv4_numericbytes(targ_size_t value)
{   unsigned u;

    if (value < 0x8000)
        u = 2;
    else if (value < 0x10000)
        u = 4;
    else
        u = 6;
    return u;
}

/********************************
 * Store numeric leaf.
 * Must use exact same number of bytes as cv4_numericbytes().
 */

void cv4_storenumeric(unsigned char *p,targ_size_t value)
{
    if (value < 0x8000)
        TOWORD(p,value);
    else if (value < 0x10000)
    {   TOWORD(p,LF_USHORT);
        p += 2;
        TOWORD(p,value);
    }
    else
    {   TOWORD(p,LF_ULONG);
        *(targ_ulong *)(p + 2) = (unsigned long) value;
    }
}

/*********************************
 * Generate a type index for a parameter list.
 */

idx_t cv4_arglist(type *t,unsigned *pnparam)
{   unsigned u;
    unsigned nparam;
    idx_t paramidx;
    debtyp_t *d;
    param_t *p;

    // Compute nparam, number of parameters
    nparam = 0;
    for (p = t->Tparamtypes; p; p = p->Pnext)
        nparam++;
    *pnparam = nparam;

    // Construct an LF_ARGLIST of those parameters
    if (nparam == 0)
    {
        if (config.fulltypes == CV8)
        {
            d = debtyp_alloc(2 + 4 + 4);
            TOWORD(d->data,LF_ARGLIST_V2);
            TOLONG(d->data + 2,1);
            TOLONG(d->data + 6,0);
            paramidx = cv_debtyp(d);
        }
        else
            paramidx = DEB_NULL;
    }
    else
    {
        switch (config.fulltypes)
        {
            case CV8:
                d = debtyp_alloc(2 + 4 + nparam * 4);
                TOWORD(d->data,LF_ARGLIST_V2);
                TOLONG(d->data + 2,nparam);

                p = t->Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOLONG(d->data + 6 + u * 4,cv4_typidx(p->Ptype));
                    p = p->Pnext;
                }
                break;

            case CV4:
                d = debtyp_alloc(2 + 2 + nparam * 2);
                TOWORD(d->data,LF_ARGLIST);
                TOWORD(d->data + 2,nparam);

                p = t->Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOWORD(d->data + 4 + u * 2,cv4_typidx(p->Ptype));
                    p = p->Pnext;
                }
                break;

            default:
                d = debtyp_alloc(2 + 4 + nparam * 4);
                TOWORD(d->data,LF_ARGLIST);
                TOLONG(d->data + 2,nparam);

                p = t->Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOLONG(d->data + 6 + u * 4,cv4_typidx(p->Ptype));
                    p = p->Pnext;
                }
                break;
        }
        paramidx = cv_debtyp(d);
    }
    return paramidx;
}

/*****************************
 * Build LF_METHODLIST for overloaded member function.
 * Output:
 *      *pcount         # of entries in method list
 * Returns:
 *      type index of method list
 *      0 don't do this one
 */

#if SCPP

STATIC int cv4_methodlist(symbol *sf,int *pcount)
{   int count;
    int mlen;
    symbol *s;
    debtyp_t *d;
    unsigned char *p;
    unsigned short attribute;

    symbol_debug(sf);

    // First, compute how big the method list is
    count = 0;
    mlen = 2;
    for (s = sf; s; s = s->Sfunc->Foversym)
    {
        if (s->Sclass == SCtypedef || s->Sclass == SCfunctempl)
            continue;
        if (s->Sfunc->Fflags & Fnodebug)
            continue;
        if (s->Sfunc->Fflags & Fintro)
            mlen += 4;
        mlen += cgcv.sz_idx * 2;
        count++;
    }

    if (!count)
        return 0;

    // Allocate and fill it in
    d = debtyp_alloc(mlen);
    p = d->data;
    TOWORD(p,LF_METHODLIST);
    p += 2;
    for (s = sf; s; s = s->Sfunc->Foversym)
    {
        if (s->Sclass == SCtypedef || s->Sclass == SCfunctempl)
            continue;
        if (s->Sfunc->Fflags & Fnodebug)
            continue;
        attribute = SFLtoATTR(s->Sflags);
        // Make sure no overlapping bits
        assert((Fvirtual | Fpure | Fintro | Fstatic) == (Fvirtual ^ Fpure ^ Fintro ^ Fstatic));
        switch ((s->Sfunc->Fflags & (Fvirtual | Fstatic)) |
                (s->Sfunc->Fflags & (Fpure | Fintro)))
        {
            // BUG: should we have 0x0C, friend functions?
            case Fstatic:                       attribute |= 0x08; break;
            case Fvirtual:                      attribute |= 0x04; break;
            case Fvirtual | Fintro:             attribute |= 0x10; break;
            case Fvirtual | Fpure:              attribute |= 0x14; break;
            case Fvirtual | Fintro | Fpure:     attribute |= 0x18; break;
            case 0:
                break;
            default:
                symbol_print(s);
                assert(0);
        }
        TOIDX(p,attribute);
        p += cgcv.sz_idx;
        TOIDX(p,cv4_symtypidx(s));
        p += cgcv.sz_idx;
        if (s->Sfunc->Fflags & Fintro)
        {   TOLONG(p,cpp_vtbloffset((Classsym *)s->Sscope,s));
            p += 4;
        }
    }
    assert(p - d->data == mlen);

    *pcount = count;
    return cv_debtyp(d);
}

#endif

/**********************************
 * Pretty-print indentifier for CV4 types.
 */

#if SCPP

STATIC char * cv4_prettyident(symbol *s)
{   symbol *stmp;
    char *p;

    stmp = s->Sscope;
    s->Sscope = NULL;           // trick cpp_prettyident into leaving off ::
    p = cpp_prettyident(s);
    s->Sscope = (Classsym *)stmp;
    return p;
}

#endif

/****************************
 * Return type index of struct.
 * Input:
 *      s       struct tag symbol
 *      flags
 *          0   generate a reference to s
 *          1   just saw the definition of s
 *          2   saw key function for class s
 *          3   no longer have a key function for class s
 */

idx_t cv4_struct(Classsym *s,int flags)
{   targ_size_t size;
    debtyp_t *d,*dt;
    unsigned len;
    unsigned nfields,fnamelen;
    idx_t typidx;
    type *t;
    symlist_t sl;
    struct_t *st;
    char *id;
#if SCPP
    baseclass_t *b;
#endif
    unsigned numidx;
    unsigned leaf;
    unsigned property;
    unsigned attribute;
    unsigned char *p;
    int refonly;
    int i;
    int count;                  // COUNT field in LF_CLASS

    _chkstack();
    symbol_debug(s);
    assert(config.fulltypes >= CV4);
    st = s->Sstruct;
    if (st->Sflags & STRanonymous)      // if anonymous class/union
        return 0;

    //dbg_printf("cv4_struct(%s,%d)\n",s->Sident,flags);
    t = s->Stype;
    //printf("t = %p, Tflags = x%x\n", t, t->Tflags);
    type_debug(t);

    // Determine if we should do a reference or a definition
    refonly = 1;                        // assume reference only
    if (MARS || t->Tflags & TFsizeunknown || st->Sflags & STRoutdef)
    {
        //printf("ref only\n");
    }
    else
    {
        // We have a definition that we have not put out yet
        switch (flags)
        {   case 0:                     // reference to s
#if SCPP
                if (!CPP ||
                    config.flags2 & (CFG2fulltypes | CFG2hdrdebug) ||
                    !(st->Sflags & STRvtblext))
                    refonly = 0;
#else
                refonly = 0;
#endif
                break;
            case 1:                     // saw def of s
                if (!s->Stypidx)        // if not forward referenced
                    return 0;
#if SCPP
                if (!CPP ||
                    config.flags2 & CFG2fulltypes ||
                    !(st->Sflags & STRvtblext))
                    refonly = 0;
#endif
                break;
#if SCPP
            case 2:                     // saw key func for s
                if (config.flags2 & CFG2fulltypes)
                    return 0;
                refonly = 0;
                break;
            case 3:                     // no longer have key func for s
                if (!s->Stypidx || config.flags2 & CFG2fulltypes)
                    return 0;
                refonly = 0;
                break;
#endif
            default:
                assert(0);
        }
    }

    if (MARS || refonly)
    {
        if (s->Stypidx)                 // if reference already generated
        {   //assert(s->Stypidx - cgcv.deb_offset < debtyptop);
            return s->Stypidx;          // use already existing reference
        }
        size = 0;
        property = 0x80;                // class is forward referenced
    }
    else
    {   size = type_size(t);
        st->Sflags |= STRoutdef;
        property = 0;
    }

#if SCPP
    if (CPP)
    {
        if (s->Sscope)                  // if class is nested
            property |= 8;
        if (st->Sctor || st->Sdtor)
            property |= 2;              // class has ctors and/or dtors
        if (st->Sopoverload)
            property |= 4;              // class has overloaded operators
        if (st->Scastoverload)
            property |= 0x40;           // class has casting methods
        if (st->Sopeq && !(st->Sopeq->Sfunc->Fflags & Fnodebug))
            property |= 0x20;           // class has overloaded assignment
    }
#endif
    id = prettyident(s);
    if (config.fulltypes == CV4)
    {   numidx = (st->Sflags & STRunion) ? 8 : 12;
        len = numidx + cv4_numericbytes(size);
        d = debtyp_alloc(len + cv_stringbytes(id));
        cv4_storenumeric(d->data + numidx,size);
    }
    else
    {   numidx = (st->Sflags & STRunion) ? 10 : 18;
        len = numidx + 4;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOLONG(d->data + numidx,size);
    }
    len += cv_namestring(d->data + len,id);
    switch (s->Sclass)
    {   case SCstruct:
            leaf = LF_STRUCTURE;
            if (st->Sflags & STRunion)
            {   leaf = LF_UNION;
                break;
            }
            if (st->Sflags & STRclass)
                leaf = LF_CLASS;
            goto L1;
        L1:
            if (config.fulltypes == CV4)
                TOWORD(d->data + 8,0);          // dList
            else
                TOLONG(d->data + 10,0);         // dList
#if SCPP
        if (CPP)
        {   debtyp_t *vshape;
            unsigned n;
            unsigned char descriptor;
            list_t vl;

            vl = st->Svirtual;
            n = list_nitems(vl);
            if (n == 0)                         // if no virtual functions
            {
                if (config.fulltypes == CV4)
                    TOWORD(d->data + 10,0);             // vshape is 0
                else
                    TOLONG(d->data + 14,0);             // vshape is 0
            }
            else
            {
                vshape = debtyp_alloc(4 + (n + 1) / 2);
                TOWORD(vshape->data,LF_VTSHAPE);
                TOWORD(vshape->data + 2,1);

                n = 0;
                descriptor = 0;
                for (; vl; vl = list_next(vl))
                {   mptr_t *m;
                    tym_t ty;

                    m = list_mptr(vl);
                    symbol_debug(m->MPf);
                    ty = tybasic(m->MPf->ty());
                    assert(tyfunc(ty));
                    if (intsize == 4)
                        descriptor |= 5;
                    if (tyfarfunc(ty))
                        descriptor++;
                    vshape->data[4 + n / 2] = descriptor;
                    descriptor <<= 4;
                    n++;
                }
                if (config.fulltypes == CV4)
                    TOWORD(d->data + 10,cv_debtyp(vshape));     // vshape
                else
                    TOLONG(d->data + 14,cv_debtyp(vshape));     // vshape
            }
        }
        else
#endif
        {
            if (config.fulltypes == CV4)
                TOWORD(d->data + 10,0);         // vshape
            else
                TOLONG(d->data + 14,0);         // vshape
        }
            break;
        default:
#if SCPP
            symbol_print(s);
#endif
            assert(0);
    }
    TOWORD(d->data,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
#if SYMDEB_TDB
    if (config.fulltypes == CVTDB)
    {
        TOWORD(d->data + 2,0);          // number of fields
        TOLONG(d->data + 6,0);          // field list is 0
        TOWORD(d->data + 4,property | 0x80);    // set fwd ref bit
#if 0
printf("fwd struct ref\n");
{int i;
 printf("len = %d, length = %d\n",len,d->length);
 for (i=0;i<d->length;i++)
 printf("%02x ",d->data[i]);
 printf("\n");
}
#endif
        debtyp_check(d);
        s->Stypidx = tdb_typidx(&d->length);    // forward reference it
    }
    else
#endif
    {
        d->length = 0;                  // so cv_debtyp() will allocate new
        s->Stypidx = cv_debtyp(d);
        d->length = len;                // restore length
    }

    if (refonly)                        // if reference only
    {
        //printf("refonly\n");
        TOWORD(d->data + 2,0);          // count: number of fields is 0
        if (config.fulltypes == CV4)
        {   TOWORD(d->data + 4,0);              // field list is 0
            TOWORD(d->data + 6,property);
        }
        else
        {   TOLONG(d->data + 6,0);              // field list is 0
            TOWORD(d->data + 4,property);
        }
        return s->Stypidx;
    }

#if MARS
    util_progress();
#else
    file_progress();
#endif

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;
#if SCPP
    if (CPP)
    {
    // Base classes come first
    for (b = st->Sbase; b; b = b->BCnext)
    {
        if (b->BCflags & BCFvirtual)    // skip virtual base classes
            continue;
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                    cv4_numericbytes(b->BCoffset);
    }

    // Now virtual base classes (direct and indirect)
    for (b = st->Svirtbase; b; b = b->BCnext)
    {
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 8 : 12) +
                        cv4_numericbytes(st->Svbptr_off) +
                        cv4_numericbytes(b->BCvbtbloff / intsize);
    }

    // Now friend classes
    i = list_nitems(st->Sfriendclass);
    nfields += i;
    fnamelen += i * ((config.fulltypes == CV4) ? 4 : 8);

    // Now friend functions
    for (sl = st->Sfriendfuncs; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        if (sf->Sclass == SCfunctempl)
            continue;
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 4 : 6) +
                    cv_stringbytes(cpp_unmangleident(sf->Sident));
    }
    }
#endif
    count = nfields;
    for (sl = st->Sfldlst; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);
        targ_size_t offset;
        char *id;
        unsigned len;

        symbol_debug(sf);
        id = sf->Sident;
        switch (sf->Sclass)
        {   case SCmember:
            case SCfield:
#if SCPP
                if (CPP && sf == s->Sstruct->Svptr)
                    fnamelen += ((config.fulltypes == CV4) ? 4 : 8);
                else
#endif
                {   offset = sf->Smemoff;
                    fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                                cv4_numericbytes(offset) + cv_stringbytes(id);
                }
                break;
#if SCPP
            case SCstruct:
                if (sf->Sstruct->Sflags & STRanonymous)
                    continue;
                if (sf->Sstruct->Sflags & STRnotagname)
                    id = cpp_name_none;
                property |= 0x10;       // class contains nested classes
                goto Lnest2;

            case SCenum:
                if (sf->Senum->SEflags & SENnotagname)
                    id = cpp_name_none;
                goto Lnest2;

            case SCtypedef:
            Lnest2:
                fnamelen += ((config.fulltypes == CV4) ? 4 : 8) +
                            cv_stringbytes(id);
                break;

            case SCextern:
            case SCcomdef:
            case SCglobal:
            case SCstatic:
            case SCinline:
            case SCsinline:
            case SCeinline:
            case SCcomdat:
                if (tyfunc(sf->ty()))
                {   symbol *so;
                    int nfuncs;

                    nfuncs = 0;
                    for (so = sf; so; so = so->Sfunc->Foversym)
                    {
                        if (so->Sclass == SCtypedef ||
                            so->Sclass == SCfunctempl ||
                            so->Sfunc->Fflags & Fnodebug)       // if compiler generated
                            continue;                   // skip it
                        nfuncs++;
                    }
                    if (nfuncs == 0)
                        continue;

                    if (nfuncs > 1)
                        count += nfuncs - 1;

                    id = cv4_prettyident(sf);
                }
                fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                            cv_stringbytes(id);
                break;
#endif
            default:
                continue;
        }
        nfields++;
        count++;
    }

    TOWORD(d->data + 2,count);
    if (config.fulltypes == CV4)
        TOWORD(d->data + 6,property);
    else
        TOWORD(d->data + 4,property);

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    p = dt->data;
    TOWORD(p,LF_FIELDLIST);

    // And fill it in
    p += 2;
#if SCPP
    if (CPP)
    {
    // Put out real base classes
    for (b = st->Sbase; b; b = b->BCnext)
    {   targ_size_t offset;

        if (b->BCflags & BCFvirtual)    // skip virtual base classes
            continue;
        offset = b->BCoffset;
        typidx = cv4_symtypidx(b->BCbase);

        attribute = (b->BCflags & BCFpmask);
        if (attribute & 4)
            attribute = 1;
        else
            attribute = 4 - attribute;

        TOWORD(p,LF_BCLASS);
        if (config.fulltypes == CV4)
        {   TOWORD(p + 2,typidx);
            TOWORD(p + 4,attribute);
            p += 6;
        }
        else
        {   TOLONG(p + 4,typidx);
            TOWORD(p + 2,attribute);
            p += 8;
        }

        cv4_storenumeric(p,offset);
        p += cv4_numericbytes(offset);
    }

    // Now direct followed by indirect virtual base classes
    i = LF_VBCLASS;
    do
    {
        for (b = st->Svirtbase; b; b = b->BCnext)
        {   targ_size_t vbpoff,vboff;
            type *vbptype;              // type of virtual base pointer
            idx_t vbpidx;

            if (baseclass_find(st->Sbase,b->BCbase))    // if direct vbase
            {   if (i == LF_IVBCLASS)
                    continue;
            }
            else
            {   if (i == LF_VBCLASS)
                    continue;
            }

            typidx = cv4_symtypidx(b->BCbase);

            vbptype = type_allocn(TYarray,tsint);
            vbptype->Tflags |= TFsizeunknown;
            vbptype = newpointer(vbptype);
            vbptype->Tcount++;
            vbpidx = cv4_typidx(vbptype);
            type_free(vbptype);

            attribute = (b->BCflags & BCFpmask);
            if (attribute & 4)
                attribute = 1;
            else
                attribute = 4 - attribute;

            vbpoff = st->Svbptr_off;
            vboff = b->BCvbtbloff / intsize;

            if (config.fulltypes == CV4)
            {   TOWORD(p,i);
                TOWORD(p + 2,typidx);
                TOWORD(p + 4,vbpidx);
                TOWORD(p + 6,attribute);
                p += 8;
            }
            else
            {   TOWORD(p,i);
                TOLONG(p + 4,typidx);           // btype
                TOLONG(p + 8,vbpidx);           // vbtype
                TOWORD(p + 2,attribute);
                p += 12;
            }

            cv4_storenumeric(p,vbpoff);
            p += cv4_numericbytes(vbpoff);
            cv4_storenumeric(p,vboff);
            p += cv4_numericbytes(vboff);
        }
        i ^= LF_VBCLASS ^ LF_IVBCLASS;          // toggle between them
    } while (i != LF_VBCLASS);

    // Now friend classes
    for (sl = s->Sstruct->Sfriendclass; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        typidx = cv4_symtypidx(sf);
        if (config.fulltypes == CV4)
        {   TOWORD(p,LF_FRIENDCLS);
            TOWORD(p + 2,typidx);
            p += 4;
        }
        else
        {   TOLONG(p,LF_FRIENDCLS);
            TOLONG(p + 4,typidx);
            p += 8;
        }
    }

    // Now friend functions
    for (sl = s->Sstruct->Sfriendfuncs; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        if (sf->Sclass == SCfunctempl)
            continue;
        typidx = cv4_symtypidx(sf);
        TOWORD(p,LF_FRIENDFCN);
        if (config.fulltypes == CV4)
        {   TOWORD(p + 2,typidx);
            p += 4;
        }
        else
        {   TOLONG(p + 2,typidx);
            p += 6;
        }
        p += cv_namestring(p,cpp_unmangleident(sf->Sident));
    }
    }
#endif
    for (sl = s->Sstruct->Sfldlst; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);
        targ_size_t offset;
        char *id;

        symbol_debug(sf);
        id = sf->Sident;
        switch (sf->Sclass)
        {   case SCfield:
            {   debtyp_t *db;

                if (config.fulltypes == CV4)
                {   db = debtyp_alloc(6);
                    TOWORD(db->data,LF_BITFIELD);
                    db->data[2] = sf->Swidth;
                    db->data[3] = sf->Sbit;
                    TOWORD(db->data + 4,cv4_symtypidx(sf));
                }
                else
                {   db = debtyp_alloc(8);
                    TOWORD(db->data,LF_BITFIELD);
                    db->data[6] = sf->Swidth;
                    db->data[7] = sf->Sbit;
                    TOLONG(db->data + 2,cv4_symtypidx(sf));
                }
                typidx = cv_debtyp(db);
                goto L3;
            }
            case SCmember:
                typidx = cv4_symtypidx(sf);
            L3:
#if SCPP
                if (CPP && sf == s->Sstruct->Svptr)
                {
                    if (config.fulltypes == CV4)
                    {   TOWORD(p,LF_VFUNCTAB);
                        TOWORD(p + 2,typidx);
                        p += 4;
                    }
                    else
                    {   TOLONG(p,LF_VFUNCTAB);          // 0 fill 2 bytes
                        TOLONG(p + 4,typidx);
                        p += 8;
                    }
                    break;
                }
#endif
                offset = sf->Smemoff;
                TOWORD(p,LF_MEMBER);
#if SCPP
                attribute = CPP ? SFLtoATTR(sf->Sflags) : 0;
                assert((attribute & ~3) == 0);
#else
                attribute = 0;
#endif
                if (config.fulltypes == CV4)
                {   TOWORD(p + 2,typidx);
                    TOWORD(p + 4,attribute);
                    p += 6;
                }
                else
                {   TOLONG(p + 4,typidx);
                    TOWORD(p + 2,attribute);
                    p += 8;
                }
                cv4_storenumeric(p,offset);
                p += cv4_numericbytes(offset);
                p += cv_namestring(p,id);
                break;
#if SCPP
            case SCstruct:
                if (sf->Sstruct->Sflags & STRanonymous)
                    continue;
                if (sf->Sstruct->Sflags & STRnotagname)
                    id = cpp_name_none;
                goto Lnest;

            case SCenum:
                if (sf->Senum->SEflags & SENnotagname)
                    id = cpp_name_none;
                goto Lnest;

            case SCtypedef:
            Lnest:
                TOWORD(p,LF_NESTTYPE);
                typidx = cv4_symtypidx(sf);
                if (config.fulltypes == CV4)
                {   TOWORD(p + 2,typidx);
                    p += 4;
                }
                else
                {   TOLONG(p + 4,typidx);
                    p += 8;
                }
            L2:
                p += cv_namestring(p,id);
                break;

            case SCextern:
            case SCcomdef:
            case SCglobal:
            case SCstatic:
            case SCinline:
            case SCsinline:
            case SCeinline:
            case SCcomdat:
                if (tyfunc(sf->ty()))
                {   int count;

                    typidx = cv4_methodlist(sf,&count);
                    if (!typidx)
                        break;
                    id = cv4_prettyident(sf);
                    TOWORD(p,LF_METHOD);
                    TOWORD(p + 2,count);
                    p += 4;
                    TOIDX(p,typidx);
                    p += cgcv.sz_idx;
                    goto L2;
                }
                else
                {
                    TOWORD(p,LF_STMEMBER);
                    typidx = cv4_symtypidx(sf);
                    attribute = SFLtoATTR(sf->Sflags);
                    if (config.fulltypes == CV4)
                    {   TOWORD(p + 2,typidx);
                        TOWORD(p + 4,attribute);
                        p += 6;
                    }
                    else
                    {   TOLONG(p + 4,typidx);
                        TOWORD(p + 2,attribute);
                        p += 8;
                    }
                    goto L2;
                }
                break;
#endif
            default:
                continue;
        }
    }
    //dbg_printf("fnamelen = %d, p-dt->data = %d\n",fnamelen,p-dt->data);
    assert(p - dt->data == fnamelen);
    if (config.fulltypes == CV4)
        TOWORD(d->data + 4,cv_debtyp(dt));
    else
        TOLONG(d->data + 6,cv_debtyp(dt));

#if SYMDEB_TDB
    if (config.fulltypes == CVTDB)
        s->Stypidx = cv_debtyp(d);
#endif
#if SCPP
    if (CPP)
    {
        symbol_debug(s);
        if (st->Sflags & STRglobal)
            list_prepend(&cgcv.list,s);
        else
            cv4_outsym(s);
    }
#endif
    return s->Stypidx;
}

/****************************
 * Return type index of enum.
 */

#if SCPP

STATIC unsigned cv4_enum(symbol *s)
{
    debtyp_t *d,*dt;
    unsigned nfields,fnamelen;
    unsigned len;
    type *t;
    type *tbase;
    symlist_t sl;
    unsigned property;
    unsigned attribute;
    int i;
    char *id;

    _chkstack();
    symbol_debug(s);
    if (s->Stypidx)                     // if already converted
    {   //assert(s->Stypidx - cgcv.deb_offset < debtyptop);
        return s->Stypidx;
    }

    //dbg_printf("cv4_enum(%s)\n",s->Sident);
    t = s->Stype;
    type_debug(t);
    tbase = t->Tnext;
    property = 0;
    if (s->Senum->SEflags & SENforward)
        property |= 0x80;               // enum is forward referenced

    id = s->Sident;
    if (s->Senum->SEflags & SENnotagname)
        id = cpp_name_none;
    if (config.fulltypes == CV4)
    {   len = 10;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOWORD(d->data,LF_ENUM);
        TOWORD(d->data + 4,cv4_typidx(tbase));
        TOWORD(d->data + 8,property);
    }
    else
    {   len = 14;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOWORD(d->data,LF_ENUM);
        TOLONG(d->data + 6,cv4_typidx(tbase));
        TOWORD(d->data + 4,property);
    }
    len += cv_namestring(d->data + len,id);

    // Assign a number to prevent infinite recursion if an enum member
    // references the same enum.
#if SYMDEB_TDB
    if (config.fulltypes == CVTDB)
    {   debtyp_t *df;

        TOWORD(d->data + 2,0);
        TOWORD(d->data + 6,0);
        debtyp_check(d);
        s->Stypidx = tdb_typidx(&d->length);    // forward reference it
    }
    else
#endif
    {
        d->length = 0;                  // so cv_debtyp() will allocate new
        s->Stypidx = cv_debtyp(d);
        d->length = len;                // restore length
    }

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;
    for (sl = s->Senumlist; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);
        unsigned long value;

        symbol_debug(sf);
        value = el_tolongt(sf->Svalue);
        nfields++;
        fnamelen += 4 + cv4_numericbytes(value) + cv_stringbytes(sf->Sident);
    }

    TOWORD(d->data + 2,nfields);

    // If forward reference, then field list is 0
    if (s->Senum->SEflags & SENforward)
    {
        TOWORD(d->data + 6,0);
        return s->Stypidx;
    }

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    TOWORD(dt->data,LF_FIELDLIST);

    // And fill it in
    i = 2;
    for (sl = s->Senumlist; sl; sl = list_next(sl))
    {   symbol *sf = list_symbol(sl);
        unsigned long value;

        symbol_debug(sf);
        value = el_tolongt(sf->Svalue);
        TOWORD(dt->data + i,LF_ENUMERATE);
        attribute = SFLtoATTR(sf->Sflags);
        TOWORD(dt->data + i + 2,attribute);
        cv4_storenumeric(dt->data + i + 4,value);
        i += 4 + cv4_numericbytes(value);
        i += cv_namestring(dt->data + i,sf->Sident);

        // If enum is not a member of a class, output enum members as constants
        if (!isclassmember(s))
        {   symbol_debug(sf);
            cv4_outsym(sf);
        }
    }
    assert(i == fnamelen);
    if (config.fulltypes == CV4)
        TOWORD(d->data + 6,cv_debtyp(dt));
    else
        TOLONG(d->data + 10,cv_debtyp(dt));

    symbol_debug(s);
    if (CPP)
        cv4_outsym(s);
    return s->Stypidx;
}

#endif

/************************************************
 * Return 'calling convention' type of function.
 */

unsigned char cv4_callconv(type *t)
{   unsigned char call;

    switch (tybasic(t->Tty))
    {
#if TARGET_SEGMENTED
        case TYffunc:   call = 1;       break;
        case TYfpfunc:  call = 3;       break;
        case TYf16func: call = 3;       break;
        case TYfsfunc:  call = 8;       break;
        case TYnsysfunc: call = 9;      break;
        case TYfsysfunc: call = 10;     break;
#endif
        case TYnfunc:   call = 0;       break;
        case TYnpfunc:  call = 2;       break;
        case TYnsfunc:  call = 7;       break;
        case TYifunc:   call = 1;       break;
        case TYjfunc:   call = 2;       break;
        case TYmfunc:   call = 11;      break;  // this call
        default:
            assert(0);
    }
    return call;
}

/**********************************************
 * Return type index for the type of a symbol.
 */

#if MARS

STATIC unsigned cv4_symtypidx(symbol *s)
{
    return cv4_typidx(s->Stype);
}

#endif

#if SCPP

STATIC unsigned cv4_symtypidx(symbol *s)
{   type *t;
    debtyp_t *d;
    unsigned char *p;

    if (!CPP)
        return cv4_typidx(s->Stype);
    symbol_debug(s);
    if (isclassmember(s))
    {   t = s->Stype;
        if (tyfunc(t->Tty))
        {   param_t *pa;
            unsigned nparam;
            idx_t paramidx;
            idx_t thisidx;
            unsigned u;
            func_t *f;
            unsigned char call;

            // It's a member function, which gets a special type record

            f = s->Sfunc;
            if (f->Fflags & Fstatic)
                thisidx = dttab4[TYvoid];
            else
            {   type *tthis = cpp_thistype(s->Stype,(Classsym *)s->Sscope);

                thisidx = cv4_typidx(tthis);
                type_free(tthis);
            }

            paramidx = cv4_arglist(t,&nparam);
            call = cv4_callconv(t);

            if (config.fulltypes == CV4)
            {
                d = debtyp_alloc(18);
                p = d->data;
                TOWORD(p,LF_MFUNCTION);
                TOWORD(p + 2,cv4_typidx(t->Tnext));
                TOWORD(p + 4,cv4_symtypidx(s->Sscope));
                TOWORD(p + 6,thisidx);
                p[8] = call;
                p[9] = 0;                               // reserved
                TOWORD(p + 10,nparam);
                TOWORD(p + 12,paramidx);
                TOLONG(p + 14,0);                       // thisadjust
            }
            else
            {
                d = debtyp_alloc(26);
                p = d->data;
                TOWORD(p,LF_MFUNCTION);
                TOLONG(p + 2,cv4_typidx(t->Tnext));
                TOLONG(p + 6,cv4_symtypidx(s->Sscope));
                TOLONG(p + 10,thisidx);
                p[14] = call;
                p[15] = 0;                              // reserved
                TOWORD(p + 16,nparam);
                TOLONG(p + 18,paramidx);
                TOLONG(p + 22,0);                       // thisadjust
            }
            return cv_debtyp(d);
        }
    }
    return cv4_typidx(s->Stype);
}

#endif

/***********************************
 * Return CV4 type index for a type.
 */

unsigned cv4_typidx(type *t)
{   unsigned typidx;
    unsigned u;
    unsigned next;
    unsigned key;
    debtyp_t *d;
    targ_size_t size;
    tym_t tym;
    tym_t tycv;
    tym_t tymnext;
    type *tv;
    unsigned dt;
    unsigned attribute;
    unsigned char call;

    //dbg_printf("cv4_typidx(%p)\n",t);
    if (!t)
        return dttab4[TYint];           // assume int
    type_debug(t);
    next = cv4_typidx(t->Tnext);
    tycv = t->Tty;
    tym = tybasic(tycv);
    tycv &= mTYconst | mTYvolatile | mTYimmutable;
    attribute = 0;
L1:
    dt = dttab4[tym];
    switch (tym)
    {
        case TYllong:
            if (t->Tnext)
                goto Ldelegate;
            assert(dt);
            typidx = dt;
            break;

        case TYullong:
            if (t->Tnext)
                goto Ldarray;
            assert(dt);
            typidx = dt;
            break;

        case TYvoid:
        case TYchar:
        case TYschar:
        case TYuchar:
        case TYchar16:
        case TYshort:
        case TYushort:
        case TYint:
        case TYuint:
        case TYulong:
        case TYlong:
        case TYfloat:
        case TYdouble:
        case TYdouble_alias:
        case TYldouble:
        case TYifloat:
        case TYidouble:
        case TYildouble:
        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
        case TYbool:
        case TYwchar_t:
        case TYdchar:
            assert(dt);
            typidx = dt;
            break;

        case TYnptr:
#if MARS
            if (t->Tkey)
                goto Laarray;
#endif
#if TARGET_SEGMENTED
        case TYsptr:
        case TYcptr:
#endif
        Lptr:
                        attribute |= I32 ? 10 : 0;      goto L2;
#if TARGET_SEGMENTED
        case TYfptr:
        case TYvptr:    attribute |= I32 ? 11 : 1;      goto L2;
        case TYhptr:    attribute |= 2; goto L2;
#endif

        L2:
            if (config.fulltypes == CV4)
            {
                // This is a hack to duplicate bugs in VC, so that the VC
                // debugger will work.
                tymnext = t->Tnext->Tty;
                if (tymnext & (mTYconst | mTYimmutable | mTYvolatile) &&
                    !tycv &&
                    tyarithmetic(tymnext) &&
                    !(attribute & 0xE0)
                   )
                {
                    typidx = dt | dttab4[tybasic(tymnext)];
                    break;
                }
            }
            if ((next & 0xFF00) == 0 && !(attribute & 0xE0))
                typidx = next | dt;
            else
            {
                if (tycv & (mTYconst | mTYimmutable))
                    attribute |= 0x400;
                if (tycv & mTYvolatile)
                    attribute |= 0x200;
                tycv = 0;
                switch (config.fulltypes)
                {
                    case CV4:
                        d = debtyp_alloc(6);
                        TOWORD(d->data,LF_POINTER);
                        TOWORD(d->data + 2,attribute);
                        TOWORD(d->data + 4,next);
                        break;

                    case CV8:
                        d = debtyp_alloc(10);
                        TOWORD(d->data,0x1002);
                        TOLONG(d->data + 2,next);
                        // The visual studio debugger gets confused with pointers to arrays, emit a reference instead.
                        // This especially happens when passing arrays as function arguments because 64bit ABI demands
                        // passing structs > 8 byte as pointers.
                        if((config.flags2 & CFG2gms) && t->Tnext && t->Tnext->Tty == TYdarray)
                            TOLONG(d->data + 6,attribute | 0x20);
                        else
                        {
                            /* BUG: attribute bits are unknown, 0x1000C is maaaagic
                             */
                            TOLONG(d->data + 6,attribute | 0x1000C);
                        }
                        break;

                    default:
                        d = debtyp_alloc(10);
                        TOWORD(d->data,LF_POINTER);
                        TOLONG(d->data + 2,attribute);
                        TOLONG(d->data + 6,next);
                        break;
                }
                typidx = cv_debtyp(d);
            }
            break;

        Ldarray:
            switch (config.fulltypes)
            {
#if MARS
                case CV8:
                {
                    typidx = cv8_darray(t, next);
                    break;
                }
#endif
                case CV4:
#if 1
                    d = debtyp_alloc(12);
                    TOWORD(d->data, LF_OEM);
                    TOWORD(d->data + 2, OEM);
                    TOWORD(d->data + 4, 1);     // 1 = dynamic array
                    TOWORD(d->data + 6, 2);     // count of type indices to follow
                    TOWORD(d->data + 8, 0x12);  // index type, T_LONG
                    TOWORD(d->data + 10, next); // element type
#else
                    d = debtyp_alloc(6);
                    TOWORD(d->data,LF_DYN_ARRAY);
                    TOWORD(d->data + 2, 0x12);  // T_LONG
                    TOWORD(d->data + 4, next);
#endif
                    typidx = cv_debtyp(d);
                    break;

                default:
                    assert(0);
            }

            break;

        Laarray:
#if MARS
            key = cv4_typidx(t->Tkey);
            switch (config.fulltypes)
            {
                case CV8:
                    typidx = cv8_daarray(t, key, next);
                    break;

                case CV4:
#if 1
                    d = debtyp_alloc(12);
                    TOWORD(d->data, LF_OEM);
                    TOWORD(d->data + 2, OEM);
                    TOWORD(d->data + 4, 2);     // 2 = associative array
                    TOWORD(d->data + 6, 2);     // count of type indices to follow
                    TOWORD(d->data + 8, key);   // key type
                    TOWORD(d->data + 10, next); // element type
#else
                    d = debtyp_alloc(6);
                    TOWORD(d->data,LF_ASSOC_ARRAY);
                    TOWORD(d->data + 2, key);   // key type
                    TOWORD(d->data + 4, next);  // element type
#endif
                    typidx = cv_debtyp(d);
                    break;
                default:
                    assert(0);
            }
#endif
            break;

        Ldelegate:
            switch (config.fulltypes)
            {
#if MARS
                case CV8:
                    typidx = cv8_ddelegate(t, next);
                    break;
#endif
                case CV4:
                    tv = type_fake(TYnptr);
                    tv->Tcount++;
                    key = cv4_typidx(tv);
                    type_free(tv);
#if 1
                    d = debtyp_alloc(12);
                    TOWORD(d->data, LF_OEM);
                    TOWORD(d->data + 2, OEM);
                    TOWORD(d->data + 4, 3);     // 3 = delegate
                    TOWORD(d->data + 6, 2);     // count of type indices to follow
                    TOWORD(d->data + 8, key);   // type of 'this', which is void*
                    TOWORD(d->data + 10, next); // function type
#else
                    d = debtyp_alloc(6);
                    TOWORD(d->data,LF_DELEGATE);
                    TOWORD(d->data + 2, key);   // type of 'this', which is void*
                    TOWORD(d->data + 4, next);  // function type
#endif
                    typidx = cv_debtyp(d);
                    break;
                default:
                    assert(0);
            }
            break;

        case TYcent:
            if (t->Tnext)
                goto Ldelegate;
            assert(dt);
            typidx = dt;
            break;

        case TYucent:
            if (t->Tnext)
                goto Ldarray;
            assert(dt);
            typidx = dt;
            break;

        case TYarray:
        {   if (t->Tflags & TFsizeunknown)
                size = 0;               // don't complain if don't know size
            else
                size = type_size(t);
        Larray:
            u = cv4_numericbytes(size);
            unsigned idxtype = I32 ? 0x12 : 0x11;  // T_LONG : T_SHORT
            if (I64)
                idxtype = 0x23;                    // T_UQUAD
            if(next == dttab4[TYvoid])    // do not encode void[n], this confuses the debugger
                next = dttab4[TYuchar];   // use ubyte instead
            switch (config.fulltypes)
            {
                case CV8:
                    d = debtyp_alloc(10 + u + 1);
                    TOWORD(d->data,0x1503);
                    TOLONG(d->data + 2,next);
                    TOLONG(d->data + 6,idxtype);
                    d->data[10 + u] = 0;             // no name
                    cv4_storenumeric(d->data + 10,size);
                    break;

                case CV4:
                    d = debtyp_alloc(6 + u + 1);
                    TOWORD(d->data,LF_ARRAY);
                    TOWORD(d->data + 2,next);
                    TOWORD(d->data + 4,idxtype);
                    d->data[6 + u] = 0;             // no name
                    cv4_storenumeric(d->data + 6,size);
                    break;

                default:
                    d = debtyp_alloc(10 + u + 1);
                    TOWORD(d->data,LF_ARRAY);
                    TOLONG(d->data + 2,next);
                    TOLONG(d->data + 6,idxtype);
                    d->data[10 + u] = 0;            // no name
                    cv4_storenumeric(d->data + 10,size);
                    break;
            }
            typidx = cv_debtyp(d);
            break;
        }
#if TARGET_SEGMENTED
        case TYffunc:
        case TYfpfunc:
        case TYf16func:
        case TYfsfunc:
        case TYnsysfunc:
        case TYfsysfunc:
#endif
        case TYnfunc:
        case TYnpfunc:
        case TYnsfunc:
        case TYmfunc:
        case TYjfunc:
        case TYifunc:
        {   param_t *p;
            unsigned nparam;
            idx_t paramidx;
            unsigned u;

            call = cv4_callconv(t);
            paramidx = cv4_arglist(t,&nparam);

            // Construct an LF_PROCEDURE
            switch (config.fulltypes)
            {
                case CV8:
                    d = debtyp_alloc(2 + 4 + 1 + 1 + 2 + 4);
                    TOWORD(d->data,LF_PROCEDURE_V2);
                    TOLONG(d->data + 2,next);       // return type
                    d->data[6] = call;
                    d->data[7] = 0;                 // reserved
                    TOWORD(d->data + 8,nparam);
                    TOLONG(d->data + 10,paramidx);
                    break;

                case CV4:
                    d = debtyp_alloc(2 + 2 + 1 + 1 + 2 + 2);
                    TOWORD(d->data,LF_PROCEDURE);
                    TOWORD(d->data + 2,next);               // return type
                    d->data[4] = call;
                    d->data[5] = 0;                 // reserved
                    TOWORD(d->data + 6,nparam);
                    TOWORD(d->data + 8,paramidx);
                    break;

                default:
                    d = debtyp_alloc(2 + 4 + 1 + 1 + 2 + 4);
                    TOWORD(d->data,LF_PROCEDURE);
                    TOLONG(d->data + 2,next);               // return type
                    d->data[6] = call;
                    d->data[7] = 0;                 // reserved
                    TOWORD(d->data + 8,nparam);
                    TOLONG(d->data + 10,paramidx);
                    break;
            }

            typidx = cv_debtyp(d);
            break;
        }

        case TYstruct:
        {
#if MARS
            if (config.fulltypes == CV8)
                typidx = cv8_fwdref(t->Ttag);
            else
#endif
            {
                int foo = t->Ttag->Stypidx;
                typidx = cv4_struct(t->Ttag,0);
                //printf("struct '%s' %x %x\n", t->Ttag->Sident, foo, typidx);
            }
            break;
        }

        case TYenum:
#if SCPP
            if (CPP)
                typidx = cv4_enum(t->Ttag);
            else
#endif
                typidx = dttab4[t->Tnext->Tty];
            break;

#if SCPP
        case TYvtshape:
        {   unsigned count;
            unsigned char *p;
            unsigned char descriptor;

            count = 1 + list_nitems(t->Ttag->Sstruct->Svirtual);
            d = debtyp_alloc(4 + ((count + 1) >> 1));
            p = d->data;
            TOWORD(p,LF_VTSHAPE);
            TOWORD(p + 2,count);
            descriptor = I32 ? 0x55 : (LARGECODE ? 0x11 : 0);
            memset(p + 4,descriptor,(count + 1) >> 1);

            typidx = cv_debtyp(d);
            break;
        }

        case TYref:
        case TYnref:
        case TYfref:
            attribute |= 0x20;          // indicate reference pointer
        case TYmemptr:
            tym = tybasic(tym_conv(t)); // convert to C data type
            goto L1;                    // and try again
#endif
#if MARS
        case TYref:
        case TYnref:
            attribute |= 0x20;          // indicate reference pointer
            tym = TYnptr;               // convert to C data type
            goto L1;                    // and try again
#endif
        case TYnullptr:
            tym = TYnptr;
            next = cv4_typidx(tsvoid);  // rewrite as void*
            t = tspvoid;
            goto L1;

        // vector types
        case TYfloat4:  size = 16; next = dttab4[TYfloat];  goto Larray;
        case TYdouble2: size = 16; next = dttab4[TYdouble]; goto Larray;
        case TYschar16: size = 16; next = dttab4[TYschar];  goto Larray;
        case TYuchar16: size = 16; next = dttab4[TYuchar];  goto Larray;
        case TYshort8:  size = 16; next = dttab4[TYshort];  goto Larray;
        case TYushort8: size = 16; next = dttab4[TYushort]; goto Larray;
        case TYlong4:   size = 16; next = dttab4[TYlong];   goto Larray;
        case TYulong4:  size = 16; next = dttab4[TYulong];  goto Larray;
        case TYllong2:  size = 16; next = dttab4[TYllong];  goto Larray;
        case TYullong2: size = 16; next = dttab4[TYullong]; goto Larray;

        default:
#ifdef DEBUG
            WRTYxx(tym);
#endif
            assert(0);
    }

    // Add in const and/or volatile modifiers
    if (tycv & (mTYconst | mTYimmutable | mTYvolatile))
    {   unsigned modifier;

        modifier = (tycv & (mTYconst | mTYimmutable)) ? 1 : 0;
        modifier |= (tycv & mTYvolatile) ? 2 : 0;
        switch (config.fulltypes)
        {
            case CV8:
                d = debtyp_alloc(8);
                TOWORD(d->data,0x1001);
                TOLONG(d->data + 2,typidx);
                TOWORD(d->data + 6,modifier);
                break;

            case CV4:
                d = debtyp_alloc(6);
                TOWORD(d->data,LF_MODIFIER);
                TOWORD(d->data + 2,modifier);
                TOWORD(d->data + 4,typidx);
                break;

            default:
                d = debtyp_alloc(10);
                TOWORD(d->data,LF_MODIFIER);
                TOLONG(d->data + 2,modifier);
                TOLONG(d->data + 6,typidx);
                break;
        }
        typidx = cv_debtyp(d);
    }

    assert(typidx);
    return typidx;
}

/******************************************
 * Write out symbol s.
 */

STATIC void cv4_outsym(symbol *s)
{
    unsigned len;
    type *t;
    unsigned length;
    unsigned u;
    tym_t tym;
    const char *id;
    unsigned char *debsym = NULL;
    unsigned char buf[64];

    //dbg_printf("cv4_outsym(%s)\n",s->Sident);
    symbol_debug(s);
#if MARS
    if (s->Sflags & SFLnodebug)
        return;
#endif
    t = s->Stype;
    type_debug(t);
    tym = tybasic(t->Tty);
    if (tyfunc(tym) && s->Sclass != SCtypedef)
    {   int framedatum,targetdatum,fd;
        char idfree;
        idx_t typidx;

        if (s != funcsym_p)
            return;
#if SCPP
        if (CPP && isclassmember(s))            // if method
        {   Outbuffer buf;

            param_tostring(&buf,s->Stype);
            buf.prependBytes(cpp_prettyident(s));
            id = alloca_strdup(buf.toString());
        }
        else
        {
            id = prettyident(s);
        }
#else
        id = s->prettyIdent ? s->prettyIdent : s->Sident;
#endif
        len = cv_stringbytes(id);

        // Length of record
        length = 2 + 2 + 4 * 3 + intsize * 4 + 2 + cgcv.sz_idx + 1;
        debsym = (length + len <= sizeof(buf)) ? buf : (unsigned char *) malloc(length + len);
        assert(debsym);
        memset(debsym,0,length + len);

        // Symbol type
        u = (s->Sclass == SCstatic) ? S_LPROC16 : S_GPROC16;
        if (I32)
            u += S_GPROC32 - S_GPROC16;
        TOWORD(debsym + 2,u);

        if (config.fulltypes == CV4)
        {
            // Offsets
            if (I32)
            {   TOLONG(debsym + 16,s->Ssize);           // proc length
                TOLONG(debsym + 20,startoffset);        // debug start
                TOLONG(debsym + 24,retoffset);          // debug end
                u = 28;                                 // offset to fixup
            }
            else
            {   TOWORD(debsym + 16,s->Ssize);           // proc length
                TOWORD(debsym + 18,startoffset);        // debug start
                TOWORD(debsym + 20,retoffset);          // debug end
                u = 22;                                 // offset to fixup
            }
            length += cv_namestring(debsym + u + intsize + 2 + cgcv.sz_idx + 1,id);
            typidx = cv4_symtypidx(s);
            TOIDX(debsym + u + intsize + 2,typidx);     // proc type
            debsym[u + intsize + 2 + cgcv.sz_idx] = tyfarfunc(tym) ? 4 : 0;
            TOWORD(debsym,length - 2);
        }
        else
        {
            // Offsets
            if (I32)
            {   TOLONG(debsym + 16 + cgcv.sz_idx,s->Ssize);             // proc length
                TOLONG(debsym + 20 + cgcv.sz_idx,startoffset);  // debug start
                TOLONG(debsym + 24 + cgcv.sz_idx,retoffset);            // debug end
                u = 28;                                         // offset to fixup
            }
            else
            {   TOWORD(debsym + 16 + cgcv.sz_idx,s->Ssize);             // proc length
                TOWORD(debsym + 18 + cgcv.sz_idx,startoffset);  // debug start
                TOWORD(debsym + 20 + cgcv.sz_idx,retoffset);            // debug end
                u = 22;                                         // offset to fixup
            }
            u += cgcv.sz_idx;
            length += cv_namestring(debsym + u + intsize + 2 + 1,id);
            typidx = cv4_symtypidx(s);
            TOIDX(debsym + 16,typidx);                  // proc type
            debsym[u + intsize + 2] = tyfarfunc(tym) ? 4 : 0;
            TOWORD(debsym,length - 2);
        }

        unsigned soffset = Offset(DEBSYM);
        objmod->write_bytes(SegData[DEBSYM],length,debsym);

        // Put out fixup for function start offset
        objmod->reftoident(DEBSYM,soffset + u,s,0,CFseg | CFoff);
    }
    else
    {   targ_size_t base;
        int reg;
        unsigned fd;
        unsigned idx1,idx2;
        unsigned long value;
        unsigned fixoff;
        idx_t typidx;

        typidx = cv4_typidx(t);
#if MARS
        id = s->prettyIdent ? s->prettyIdent : prettyident(s);
#else
        id = prettyident(s);
#endif
        len = strlen(id);
        debsym = (39 + IDOHD + len <= sizeof(buf)) ? buf : (unsigned char *) malloc(39 + IDOHD + len);
        assert(debsym);
        switch (s->Sclass)
        {
            case SCparameter:
            case SCregpar:
                if (s->Sfl == FLreg)
                {
                    s->Sfl = FLpara;
                    cv4_outsym(s);
                    s->Sfl = FLreg;
                    goto case_register;
                }
                base = Para.size - BPoff;    // cancel out add of BPoff
                goto L1;
            case SCauto:
                if (s->Sfl == FLreg)
                    goto case_register;
            case_auto:
                base = Auto.size;
            L1:
                TOWORD(debsym + 2,I32 ? S_BPREL32 : S_BPREL16);
                if (config.fulltypes == CV4)
                {   TOOFFSET(debsym + 4,s->Soffset + base + BPoff);
                    TOIDX(debsym + 4 + intsize,typidx);
                }
                else
                {   TOOFFSET(debsym + 4 + cgcv.sz_idx,s->Soffset + base + BPoff);
                    TOIDX(debsym + 4,typidx);
                }
                length = 2 + 2 + intsize + cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;
            case SCbprel:
                base = -BPoff;
                goto L1;

            case SCfastpar:
                if (s->Sfl != FLreg)
                {   base = Fast.size;
                    goto L1;
                }
                goto case_register;

            case SCregister:
                if (s->Sfl != FLreg)
                    goto case_auto;
            case SCpseudo:
            case_register:
                TOWORD(debsym + 2,S_REGISTER);
                reg = cv_regnum(s);
                TOIDX(debsym + 4,typidx);
                TOWORD(debsym + 4 + cgcv.sz_idx,reg);
                length = 2 * 3 + cgcv.sz_idx;
                length += 1 + cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;

            case SCextern:
            case SCcomdef:
                // Common blocks have a non-zero Sxtrnnum and an UNKNOWN seg
                if (!(s->Sxtrnnum && s->Sseg == UNKNOWN)) // if it's not really a common block
                {
                        goto Lret;
                }
                /* FALL-THROUGH */
            case SCglobal:
            case SCcomdat:
                u = S_GDATA16;
                goto L2;
            case SCstatic:
            case SClocstat:
                u = S_LDATA16;
            L2:
                if (I32)
                    u += S_GDATA32 - S_GDATA16;
                TOWORD(debsym + 2,u);
                if (config.fulltypes == CV4)
                {
                    fixoff = 4;
                    length = 2 + 2 + intsize + 2;
                    TOOFFSET(debsym + fixoff,s->Soffset);
                    TOWORD(debsym + fixoff + intsize,0);
                    TOIDX(debsym + length,typidx);
                }
                else
                {
                    fixoff = 8;
                    length = 2 + 2 + intsize + 2;
                    TOOFFSET(debsym + fixoff,s->Soffset);
                    TOWORD(debsym + fixoff + intsize,0);        // segment
                    TOIDX(debsym + 4,typidx);
                }
                length += cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                assert(length <= 40 + len);

                if (s->Sseg == UNKNOWN || s->Sclass == SCcomdat) // if common block
                {
                    if (config.exe & EX_flat)
                    {
                        fd = 0x16;
                        idx1 = DGROUPIDX;
                        idx2 = s->Sxtrnnum;
                    }
                    else
                    {
                        fd = 0x26;
                        idx1 = idx2 = s->Sxtrnnum;
                    }
                }
#if TARGET_SEGMENTED
                else if (s->ty() & (mTYfar | mTYcs))
                {   fd = 0x04;
                    idx1 = idx2 = SegData[s->Sseg]->segidx;
                }
#endif
                else
                {   fd = 0x14;
                    idx1 = DGROUPIDX;
                    idx2 = SegData[s->Sseg]->segidx;
                }
                /* Because of the linker limitations, the length cannot
                 * exceed 0x1000.
                 * See optlink\cv\cvhashes.asm
                 */
                assert(length <= 0x1000);
                if (idx2 != 0)
                {   unsigned offset = Offset(DEBSYM);
                    objmod->write_bytes(SegData[DEBSYM],length,debsym);
                    objmod->write_long(DEBSYM,offset + fixoff,s->Soffset,
                        cgcv.LCFDpointer + fd,idx1,idx2);
                }
                goto Lret;

#if 1
            case SCtypedef:
                s->Stypidx = typidx;
                goto L4;

            case SCstruct:
                if (s->Sstruct->Sflags & STRnotagname)
                    goto Lret;
                goto L4;

            case SCenum:
#if SCPP
                if (CPP && s->Senum->SEflags & SENnotagname)
                    goto Lret;
#endif
            L4:
                // Output a 'user-defined type' for the tag name
                TOWORD(debsym + 2,S_UDT);
                TOIDX(debsym + 4,typidx);
                length = 2 + 2 + cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                list_subtract(&cgcv.list,s);
                break;

            case SCconst:
                // The only constants are enum members
                value = el_tolongt(s->Svalue);
                TOWORD(debsym + 2,S_CONST);
                TOIDX(debsym + 4,typidx);
                length = 4 + cgcv.sz_idx;
                cv4_storenumeric(debsym + length,value);
                length += cv4_numericbytes(value);
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;
#endif
            default:
                goto Lret;
        }
        assert(length <= 40 + len);
        objmod->write_bytes(SegData[DEBSYM],length,debsym);
    }
Lret:
    if (debsym != buf)
        free(debsym);
}

/******************************************
 * Write out any deferred symbols.
 */

STATIC void cv_outlist()
{
    while (cgcv.list)
        cv_outsym((Symbol *) list_pop(&cgcv.list));
}

/******************************************
 * Write out symbol table for current function.
 */

STATIC void cv4_func(Funcsym *s)
{
    SYMIDX si;
    int endarg;

    cv4_outsym(s);              // put out function symbol

    // Put out local symbols
    endarg = 0;
    for (si = 0; si < globsym.top; si++)
    {   //printf("globsym.tab[%d] = %p\n",si,globsym.tab[si]);
        symbol *sa = globsym.tab[si];
#if MARS
        if (endarg == 0 && sa->Sclass != SCparameter && sa->Sclass != SCfastpar)
        {   static unsigned short endargs[] = { 2,S_ENDARG };

            objmod->write_bytes(SegData[DEBSYM],sizeof(endargs),endargs);
            endarg = 1;
        }
#endif
        cv4_outsym(sa);
    }

    // Put out function return record
    if (1)
    {   unsigned char sreturn[2+2+2+1+1+4];
        unsigned short flags;
        unsigned char style;
        tym_t ty;
        tym_t tyret;
        unsigned u;

        u = 2+2+1;
        ty = tybasic(s->ty());

        flags = tyrevfunc(ty) ? 0 : 1;
        flags |= typfunc(ty) ? 0 : 2;
        TOWORD(sreturn + 4,flags);

        tyret = tybasic(s->Stype->Tnext->Tty);
        switch (tyret)
        {
            case TYvoid:
            default:
                style = 0;
                break;
            case TYbool:
            case TYchar:
            case TYschar:
            case TYuchar:
                sreturn[7] = 1;
                sreturn[8] = 1;         // AL
                goto L1;

            case TYwchar_t:
            case TYchar16:
            case TYshort:
            case TYushort:
                goto case_ax;

            case TYint:
            case TYuint:
#if TARGET_SEGMENTED
            case TYsptr:
            case TYcptr:
#endif
            case TYnullptr:
            case TYnptr:
            case TYnref:
                if (I32)
                    goto case_eax;
                else
                    goto case_ax;

            case TYfloat:
            case TYifloat:
                if (config.exe & EX_flat)
                    goto case_st0;
            case TYlong:
            case TYulong:
            case TYdchar:
                if (I32)
                    goto case_eax;
                else
                    goto case_dxax;

#if TARGET_SEGMENTED
            case TYfptr:
            case TYhptr:
                if (I32)
                    goto case_edxeax;
                else
                    goto case_dxax;

            case TYvptr:
                if (I32)
                    goto case_edxebx;
                else
                    goto case_dxbx;
#endif

            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                if (config.exe & EX_flat)
                    goto case_st0;
                if (I32)
                    goto case_edxeax;
                else
                    goto case_axbxcxdx;

            case TYllong:
            case TYullong:
                assert(I32);
                goto case_edxeax;

            case TYldouble:
            case TYildouble:
                goto case_st0;

            case TYcfloat:
            case TYcdouble:
            case TYcldouble:
                goto case_st01;

            case_ax:
                sreturn[7] = 1;
                sreturn[8] = 9;         // AX
                goto L1;

            case_eax:
                sreturn[7] = 1;
                sreturn[8] = 17;        // EAX
                goto L1;


            case_dxax:
                sreturn[7] = 2;
                sreturn[8] = 11;        // DX
                sreturn[9] = 9;         // AX
                goto L1;

            case_dxbx:
                sreturn[7] = 2;
                sreturn[8] = 11;        // DX
                sreturn[9] = 12;        // BX
                goto L1;

            case_axbxcxdx:
                sreturn[7] = 4;
                sreturn[8] = 9;         // AX
                sreturn[9] = 12;        // BX
                sreturn[10] = 10;       // CX
                sreturn[11] = 11;       // DX
                goto L1;

            case_edxeax:
                sreturn[7] = 2;
                sreturn[8] = 19;        // EDX
                sreturn[9] = 17;        // EAX
                goto L1;

            case_edxebx:
                sreturn[7] = 2;
                sreturn[8] = 19;        // EDX
                sreturn[9] = 20;        // EBX
                goto L1;

            case_st0:
                sreturn[7] = 1;
                sreturn[8] = 128;       // ST0
                goto L1;

            case_st01:
                sreturn[7] = 2;
                sreturn[8] = 128;       // ST0 (imaginary)
                sreturn[9] = 129;       // ST1 (real)
                goto L1;

            L1:
                style = 1;
                u += sreturn[7] + 1;
                break;
        }
        sreturn[6] = style;

        TOWORD(sreturn,u);
        TOWORD(sreturn + 2,S_RETURN);
        objmod->write_bytes(SegData[DEBSYM],u + 2,sreturn);
    }

    // Put out end scope
    {   static unsigned short endproc[] = { 2,S_END };

        objmod->write_bytes(SegData[DEBSYM],sizeof(endproc),endproc);
    }

    cv_outlist();
}

//////////////////////////////////////////////////////////

/******************************************
 * Write out data to .OBJ file.
 */

void cv_term()
{
    //printf("cv_term(): debtyptop = %d\n",debtyptop);

    segidx_t typeseg = objmod->seg_debugT();

    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
            cv_outlist();
        case CV8:
            objmod->write_bytes(SegData[typeseg],4,&cgcv.signature);
            if (debtyptop != 1 || config.fulltypes == CV8)
            {
                for (unsigned u = 0; u < debtyptop; u++)
                {   debtyp_t *d = debtyp[u];

                    objmod->write_bytes(SegData[typeseg],2 + d->length,(char *)d + sizeof(unsigned));
#if TERMCODE || _WIN32 || MARS
                    debtyp_free(d);
#endif
                }
            }
            else if (debtyptop)
            {
#if TERMCODE || _WIN32 || MARS
                debtyp_free(debtyp[0]);
#endif
            }
            break;

#if SYMDEB_TDB
        case CVTDB:
            cv_outlist();
#if 1
            tdb_term();
#else
        {   unsigned char *buf;
            unsigned char *p;
            size_t len;

            // Calculate size of buffer
            len = 4;
            for (unsigned u = 0; u < debtyptop; u++)
            {   debtyp_t *d = debtyp[u];

                len += 2 + d->length;
            }

            // Allocate buffer
            buf = malloc(len);
            if (!buf)
                err_nomem();                    // out of memory

            // Fill the buffer
            TOLONG(buf,cgcv.signature);
            p = buf + 4;
            for (unsigned u = 0; u < debtyptop; u++)
            {   debtyp_t *d = debtyp[u];

                len = 2 + d->length;
                memcpy(p,(char *)d + sizeof(unsigned),len);
                p += len;
            }

            tdb_write(buf,len,debtyptop);
        }
#endif
            break;
#endif
        default:
            assert(0);
    }
#if TERMCODE || _WIN32 || MARS
    util_free(debtyp);
    debtyp = NULL;
    vec_free(debtypvec);
    debtypvec = NULL;
#endif
}

/******************************************
 * Write out symbol table for current function.
 */

#if TARGET_WINDOS
void cv_func(Funcsym *s)
{
#if SCPP
    if (errcnt)                 // if we had any errors
        return;                 // don't bother putting stuff in .OBJ file
#endif

    //dbg_printf("cv_func('%s')\n",s->Sident);
#if MARS
    if (s->Sflags & SFLnodebug)
        return;
#else
    if (CPP && s->Sfunc->Fflags & Fnodebug)     // if don't generate debug info
        return;
#endif
    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
        case CVTDB:
            cv4_func(s);
            break;
        default:
            assert(0);
    }
}
#endif

/******************************************
 * Write out symbol table for current function.
 */

#if TARGET_WINDOS
void cv_outsym(symbol *s)
{
    //printf("cv_outsym('%s')\n",s->Sident);
    symbol_debug(s);
#if MARS
    if (s->Sflags & SFLnodebug)
        return;
#endif
    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
        case CVTDB:
            cv4_outsym(s);
            break;
#if MARS
        case CV8:
            cv8_outsym(s);
            break;
#endif
        default:
            assert(0);
    }
}
#endif

/******************************************
 * Return cv type index for a type.
 */

unsigned cv_typidx(type *t)
{   unsigned ti;

    //dbg_printf("cv_typidx(%p)\n",t);
    switch (config.fulltypes)
    {
        case CV4:
        case CVTDB:
        case CVSYM:
        case CV8:
            ti = cv4_typidx(t);
            break;
        default:
#ifdef DEBUG
            printf("fulltypes = %d\n",config.fulltypes);
#endif
            assert(0);
    }
    return ti;
}

#endif // !SPP
