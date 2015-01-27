// Compiler implementation of the D programming language
// Copyright (c) 2012-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt
// https://github.com/D-Programming-Language/dmd/blob/master/src/backend/cv8.c

// This module generates the .debug$S and .debug$T sections for Win64,
// which are the MS-Coff symbolic debug info and type debug info sections.

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "dt.h"
#include        "exh.h"
#include        "cgcv.h"
#include        "cv4.h"
#include        "obj.h"
#include        "outbuf.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#if _MSC_VER || __sun
#include        <alloca.h>
#endif

#if MARS
#if TARGET_WINDOS

// if symbols get longer than 65500 bytes, the linker reports corrupt debug info or exits with
// 'fatal error LNK1318: Unexpected PDB error; RPC (23) '(0x000006BA)'
#define CV8_MAX_SYMBOL_LENGTH 0xffd8

#include        <direct.h>

// The "F1" section, which is the symbols
static Outbuffer *F1_buf;

// The "F2" section, which is the line numbers
static Outbuffer *F2_buf;

// The "F3" section, which is global and a string table of source file names.
static Outbuffer *F3_buf;

// The "F4" section, which is global and a lists info about source files.
static Outbuffer *F4_buf;

/* Fixups that go into F1 section
 */
struct F1_Fixups
{
    Symbol *s;
    unsigned offset;
};

static Outbuffer *F1fixup;      // array of F1_Fixups

/* Struct in which to collect per-function data, for later emission
 * into .debug$S.
 */
struct FuncData
{
    Symbol *sfunc;
    unsigned section_length;
    const char *srcfilename;
    unsigned srcfileoff;
    unsigned linepairstart;     // starting index of offset/line pairs in linebuf[]
    unsigned linepairnum;       // number of offset/line pairs
    Outbuffer *f1buf;
    Outbuffer *f1fixup;
};

FuncData currentfuncdata;

static Outbuffer *funcdata;     // array of FuncData's

static Outbuffer *linepair;     // array of offset/line pairs

unsigned cv8_addfile(const char *filename);
void cv8_writesection(int seg, unsigned type, Outbuffer *buf);

void cv8_writename(Outbuffer *buf, const char* name, size_t len)
{
    if(config.flags2 & CFG2gms)
    {
        const char* start = name;
        const char* cur = strchr(start, '.');
        const char* end = start + len;
        while(cur != NULL)
        {
            if(cur >= end)
            {
                buf->writen(start, end - start);
                return;
            }
            buf->writen(start, cur - start);
            buf->writeByte('@');
            start = cur + 1;
            if(start >= end)
                return;
            cur = strchr(start, '.');
        }
        buf->writen(start, end - start);
    }
    else
        buf->writen(name, len);
}

/************************************************
 * Called at the start of an object file generation.
 * One source file can generate multiple object files; this starts an object file.
 * Input:
 *      filename        source file name
 */
void cv8_initfile(const char *filename)
{
    //printf("cv8_initfile()\n");

    // Recycle buffers; much faster than delete/renew

    if (!F1_buf)
        F1_buf = new Outbuffer(1024);
    F1_buf->setsize(0);

    if (!F1fixup)
        F1fixup = new Outbuffer(1024);
    F1fixup->setsize(0);

    if (!F2_buf)
        F2_buf = new Outbuffer(1024);
    F2_buf->setsize(0);

    if (!F3_buf)
        F3_buf = new Outbuffer(1024);
    F3_buf->setsize(0);
    F3_buf->writeByte(0);       // first "filename"

    if (!F4_buf)
        F4_buf = new Outbuffer(1024);
    F4_buf->setsize(0);

    if (!funcdata)
        funcdata = new Outbuffer(1024);
    funcdata->setsize(0);

    if (!linepair)
        linepair = new Outbuffer(1024);
    linepair->setsize(0);

    memset(&currentfuncdata, 0, sizeof(currentfuncdata));
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;

    cv_init();
}

void cv8_termfile(const char *objfilename)
{
    //printf("cv8_termfile()\n");

    /* Write out the debug info sections.
     */

    int seg = MsCoffObj::seg_debugS();

    unsigned v = 4;
    objmod->bytes(seg,0,4,&v);

    /* Start with starting symbol in separate "F1" section
     */
    Outbuffer buf(1024);
    size_t len = strlen(objfilename);
    buf.writeWord(2 + 4 + len + 1);
    buf.writeWord(S_COMPILAND_V3);
    buf.write32(0);
    buf.write(objfilename, len + 1);
    cv8_writesection(seg, 0xF1, &buf);

    // Write out "F2" sections
    unsigned length = funcdata->size();
    unsigned char *p = funcdata->buf;
    for (unsigned u = 0; u < length; u += sizeof(FuncData))
    {   FuncData *fd = (FuncData *)(p + u);

        F2_buf->setsize(0);

        F2_buf->write32(fd->sfunc->Soffset);
        F2_buf->write32(0);
        F2_buf->write32(fd->section_length);
        F2_buf->write32(fd->srcfileoff);
        F2_buf->write32(fd->linepairnum);
        F2_buf->write32(fd->linepairnum * 8 + 12);
        F2_buf->write(linepair->buf + fd->linepairstart * 8, fd->linepairnum * 8);

        int f2seg = seg;
        if (symbol_iscomdat(fd->sfunc))
        {
            f2seg = MsCoffObj::seg_debugS_comdat(fd->sfunc);
            objmod->bytes(f2seg,0,4,&v);
        }

        unsigned offset = SegData[f2seg]->SDoffset + 8;
        cv8_writesection(f2seg, 0xF2, F2_buf);
        objmod->reftoident(f2seg, offset, fd->sfunc, 0, CFseg | CFoff);

        if (f2seg != seg && fd->f1buf->size())
        {
            // Write out "F1" section
            unsigned f1offset = SegData[f2seg]->SDoffset;
            cv8_writesection(f2seg, 0xF1, fd->f1buf);

            // Fixups for "F1" section
            unsigned length = fd->f1fixup->size();
            unsigned char *p = fd->f1fixup->buf;
            for (unsigned u = 0; u < length; u += sizeof(F1_Fixups))
            {   F1_Fixups *f = (F1_Fixups *)(p + u);

                objmod->reftoident(f2seg, f1offset + 8 + f->offset, f->s, 0, CFseg | CFoff);
            }
        }
    }

    // Write out "F3" section
    cv8_writesection(seg, 0xF3, F3_buf);

    // Write out "F4" section
    cv8_writesection(seg, 0xF4, F4_buf);

    if (F1_buf->size())
    {
        // Write out "F1" section
        unsigned f1offset = SegData[seg]->SDoffset;
        cv8_writesection(seg, 0xF1, F1_buf);

        // Fixups for "F1" section
        length = F1fixup->size();
        p = F1fixup->buf;
        for (unsigned u = 0; u < length; u += sizeof(F1_Fixups))
        {   F1_Fixups *f = (F1_Fixups *)(p + u);

            objmod->reftoident(seg, f1offset + 8 + f->offset, f->s, 0, CFseg | CFoff);
        }
    }

    // Write out .debug$T section
    cv_term();
}

/************************************************
 * Called at the start of a module.
 * Note that there can be multiple modules in one object file.
 * cv8_initfile() must be called first.
 */
void cv8_initmodule(const char *filename, const char *modulename)
{
    //printf("cv8_initmodule(filename = %s, modulename = %s)\n", filename, modulename);

    /* Experiments show that filename doesn't have to be qualified if
     * it is relative to the directory the .exe file is in.
     */
    currentfuncdata.srcfileoff = cv8_addfile(filename);
}

void cv8_termmodule()
{
    //printf("cv8_termmodule()\n");
    assert(config.objfmt == OBJ_MSCOFF);
}

/******************************************
 * Called at the start of a function.
 */
void cv8_func_start(Symbol *sfunc)
{
    //printf("cv8_func_start(%s)\n", sfunc->Sident);
    currentfuncdata.sfunc = sfunc;
    currentfuncdata.section_length = 0;
    currentfuncdata.srcfilename = NULL;
    currentfuncdata.srcfileoff = 0;
    currentfuncdata.linepairstart += currentfuncdata.linepairnum;
    currentfuncdata.linepairnum = 0;
    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
    if (symbol_iscomdat(sfunc))
    {
        currentfuncdata.f1buf = new Outbuffer(128);
        currentfuncdata.f1fixup = new Outbuffer(128);
    }
}

void cv8_func_term(Symbol *sfunc)
{
    //printf("cv8_func_term(%s)\n", sfunc->Sident);

    assert(currentfuncdata.sfunc == sfunc);
    currentfuncdata.section_length = retoffset + retsize;

    funcdata->write(&currentfuncdata, sizeof(currentfuncdata));

    // Write function symbol
    assert(tyfunc(sfunc->ty()));
    idx_t typidx;
    func_t* fn = sfunc->Sfunc;
    if(fn->Fclass)
    {
        // generate member function type info
        // it would be nicer if this could be in cv4_typidx, but the function info is not available there
        unsigned nparam;
        unsigned char call = cv4_callconv(sfunc->Stype);
        idx_t paramidx = cv4_arglist(sfunc->Stype,&nparam);
        unsigned next = cv4_typidx(sfunc->Stype->Tnext);

        type* classtype = (type*)fn->Fclass;
        unsigned classidx = cv4_typidx(classtype);
        type *tp = type_allocn(TYnptr, classtype);
        unsigned thisidx = cv4_typidx(tp);  // TODO
        debtyp_t *d = debtyp_alloc(2 + 4 + 4 + 4 + 1 + 1 + 2 + 4 + 4);
        TOWORD(d->data,LF_MFUNCTION_V2);
        TOLONG(d->data + 2,next);       // return type
        TOLONG(d->data + 6,classidx);   // class type
        TOLONG(d->data + 10,thisidx);   // this type
        d->data[14] = call;
        d->data[15] = 0;                // reserved
        TOWORD(d->data + 16,nparam);
        TOLONG(d->data + 18,paramidx);
        TOLONG(d->data + 22,0);  // this adjust
        typidx = cv_debtyp(d);
    }
    else
        typidx = cv_typidx(sfunc->Stype);

    const char *id = sfunc->prettyIdent ? sfunc->prettyIdent : prettyident(sfunc);
    size_t len = strlen(id);
    if(len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;
    /*
     *  2       length (not including these 2 bytes)
     *  2       S_GPROC_V3
     *  4       parent
     *  4       pend
     *  4       pnext
     *  4       size of function
     *  4       size of function prolog
     *  4       offset to function epilog
     *  4       type index
     *  6       seg:offset of function start
     *  1       flags
     *  n       0 terminated name string
     */
    Outbuffer *buf = currentfuncdata.f1buf;
    buf->reserve(2 + 2 + 4 * 7 + 6 + 1 + len + 1);
    buf->writeWordn( 2 + 4 * 7 + 6 + 1 + len + 1);
    buf->writeWordn(sfunc->Sclass == SCstatic ? S_LPROC_V3 : S_GPROC_V3);
    buf->write32(0);            // parent
    buf->write32(0);            // pend
    buf->write32(0);            // pnext
    buf->write32(currentfuncdata.section_length);       // size of function
    buf->write32(startoffset);          // size of prolog
    buf->write32(retoffset);                    // offset to epilog
    buf->write32(typidx);

    F1_Fixups f1f;
    f1f.s = sfunc;
    f1f.offset = buf->size();
    currentfuncdata.f1fixup->write(&f1f, sizeof(f1f));
    buf->write32(0);
    buf->writeWordn(0);

    buf->writeByte(0);
    buf->writen(id, len);
    buf->writeByte(0);

    // Write local symbol table
    bool endarg = false;
    for (SYMIDX si = 0; si < globsym.top; si++)
    {   //printf("globsym.tab[%d] = %p\n",si,globsym.tab[si]);
        symbol *sa = globsym.tab[si];
        if (endarg == false &&
            sa->Sclass != SCparameter &&
            sa->Sclass != SCfastpar &&
            sa->Sclass != SCshadowreg)
        {
            buf->writeWord(2);
            buf->writeWord(S_ENDARG);
            endarg = true;
        }
        cv8_outsym(sa);
    }

    /* Put out function return record S_RETURN
     * (VC doesn't, so we won't bother, either.)
     */

    // Write function end symbol
    buf->writeWord(2);
    buf->writeWord(S_END);

    currentfuncdata.f1buf = F1_buf;
    currentfuncdata.f1fixup = F1fixup;
}

/**********************************************
 */

void cv8_linnum(Srcpos srcpos, targ_size_t offset)
{
    //printf("cv8_linnum(file = %s, line = %d, offset = x%x)\n", srcpos.Sfilename, (int)srcpos.Slinnum, (unsigned)offset);
    if (currentfuncdata.srcfilename)
    {
        /* Ignore line numbers from different files in the same function.
         * This can happen with inlined functions.
         * To make this work would require a separate F2 section for each different file.
         */
        if (currentfuncdata.srcfilename != srcpos.Sfilename &&
            strcmp(currentfuncdata.srcfilename, srcpos.Sfilename))
            return;
    }
    else
    {
        currentfuncdata.srcfilename = srcpos.Sfilename;
        currentfuncdata.srcfileoff  = cv8_addfile(srcpos.Sfilename);
    }

    static unsigned lastoffset;
    static unsigned lastlinnum;
    if (currentfuncdata.linepairnum)
    {
        if (offset <= lastoffset || srcpos.Slinnum <= lastlinnum)
            return;
    }
    lastoffset = offset;
    lastlinnum = srcpos.Slinnum;

    linepair->write32((unsigned)offset);
    linepair->write32((unsigned)srcpos.Slinnum | 0x80000000);
    ++currentfuncdata.linepairnum;
}

/**********************************************
 * Add source file, if it isn't already there.
 * Return offset into F4.
 */

unsigned cv8_addfile(const char *filename)
{
    //printf("cv8_addfile('%s')\n", filename);

    /* The algorithms here use a linear search. This is acceptable only
     * because we expect only 1 or 2 files to appear.
     * Unlike C, there won't be lots of .h source files to be accounted for.
     */

    unsigned length = F3_buf->size();
    unsigned char *p = F3_buf->buf;
    size_t len = strlen(filename);

    // ensure the filename is absolute to help the debugger to find the source
    // without having to know the working directory during compilation
    static char cwd[260];
    static unsigned cwdlen;
    bool abs = (*filename == '\\') ||
               (*filename == '/')  ||
               (*filename && filename[1] == ':');

    if (!abs && cwd[0] == 0)
    {
        if (getcwd(cwd, sizeof(cwd)))
        {
            cwdlen = strlen(cwd);
            if(cwd[cwdlen - 1] != '\\' && cwd[cwdlen - 1] != '/')
                cwd[cwdlen++] = '\\';
        }
    }
    unsigned off = 1;
    while (off + len < length)
    {
        if (!abs)
        {
            if (memcmp(p + off, cwd, cwdlen) == 0 &&
                memcmp(p + off + cwdlen, filename, len + 1) == 0)
                goto L1;
        }
        else if (memcmp(p + off, filename, len + 1) == 0)
        {   // Already there
            //printf("\talready there at %x\n", off);
            goto L1;
        }
        off += strlen((const char *)(p + off)) + 1;
    }
    off = length;
    // Add it
    if(!abs)
        F3_buf->write(cwd, cwdlen);
    F3_buf->write(filename, len + 1);

L1:
    // off is the offset of the filename in F3.
    // Find it in F4.

    length = F4_buf->size();
    p = F4_buf->buf;

    unsigned u = 0;
    while (u + 8 <= length)
    {
        //printf("\t%x\n", *(unsigned *)(p + u));
        if (off == *(unsigned *)(p + u))
        {
            //printf("\tfound %x\n", u);
            return u;
        }
        u += 4;
        unsigned short type = *(unsigned short *)(p + u);
        u += 2;
        if (type == 0x0110)
            u += 16;            // MD5 checksum
        u += 2;
    }

    // Not there. Add it.
    F4_buf->write32(off);

    /* Write 10 01 [MD5 checksum]
     *   or
     * 00 00
     */
    F4_buf->writeShort(0);

    // 2 bytes of pad
    F4_buf->writeShort(0);

    //printf("\tadded %x\n", length);
    return length;
}

void cv8_writesection(int seg, unsigned type, Outbuffer *buf)
{
    /* Write out as:
     *  bytes   desc
     *  -------+----
     *  4       type
     *  4       length
     *  length  data
     *  pad     pad to 4 byte boundary
     */
    unsigned off = SegData[seg]->SDoffset;
    objmod->bytes(seg,off,4,&type);
    unsigned length = buf->size();
    objmod->bytes(seg,off+4,4,&length);
    objmod->bytes(seg,off+8,length,buf->buf);
    // Align to 4
    unsigned pad = ((length + 3) & ~3) - length;
    objmod->lidata(seg,off+8+length,pad);
}

void cv8_outsym(Symbol *s)
{
    //printf("cv8_outsym(s = '%s')\n", s->Sident);
    //type_print(s->Stype);
    //symbol_print(s);
    if (s->Sflags & SFLnodebug)
        return;

    idx_t typidx = cv_typidx(s->Stype);
    //printf("typidx = %x\n", typidx);
    const char *id = s->prettyIdent ? s->prettyIdent : prettyident(s);
    size_t len = strlen(id);

    if(len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;

    F1_Fixups f1f;
    Outbuffer *buf = currentfuncdata.f1buf;

    unsigned sr;
    unsigned base;
    switch (s->Sclass)
    {
        case SCparameter:
        case SCregpar:
        case SCshadowreg:
            if (s->Sfl == FLreg)
            {
                s->Sfl = FLpara;
                cv8_outsym(s);
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
#if 1
            // Register relative addressing
            buf->reserve(2 + 2 + 4 + 4 + 2 + len + 1);
            buf->writeWordn( 2 + 4 + 4 + 2 + len + 1);
            buf->writeWordn(0x1111);
            buf->write32(s->Soffset + base + BPoff);
            buf->write32(typidx);
            buf->writeWordn(I64 ? 334 : 22);       // relative to RBP/EBP
            cv8_writename(buf, id, len);
            buf->writeByte(0);
#else
            // This is supposed to work, implicit BP relative addressing, but it does not
            buf->reserve(2 + 2 + 4 + 4 + len + 1);
            buf->writeWordn( 2 + 4 + 4 + len + 1);
            buf->writeWordn(S_BPREL_V3);
            buf->write32(s->Soffset + base + BPoff);
            buf->write32(typidx);
            cv8_writename(buf, id, len);
            buf->writeByte(0);
#endif
            break;

        case SCbprel:
            base = -BPoff;
            goto L1;

        case SCfastpar:
            if (s->Sfl != FLreg)
            {   base = Fast.size;
                goto L1;
            }
            goto L2;

        case SCregister:
            if (s->Sfl != FLreg)
                goto case_auto;
        case SCpseudo:
        case_register:
        L2:
            buf->reserve(2 + 2 + 4 + 2 + len + 1);
            buf->writeWordn( 2 + 4 + 2 + len + 1);
            buf->writeWordn(S_REGISTER_V3);
            buf->write32(typidx);
            buf->writeWordn(cv8_regnum(s));
            cv8_writename(buf, id, len);
            buf->writeByte(0);
            break;

        case SCextern:
            break;

        case SCstatic:
        case SClocstat:
            sr = S_LDATA_V3;
            goto Ldata;
        case SCglobal:
        case SCcomdat:
        case SCcomdef:
            sr = S_GDATA_V3;
        Ldata:
//return;
            /*
             *  2       length (not including these 2 bytes)
             *  2       S_GDATA_V2
             *  4       typidx
             *  6       ref to symbol
             *  n       0 terminated name string
             */
            if (s->ty() & mTYthread)            // thread local storage
                sr = (sr == S_GDATA_V3) ? 0x1113 : 0x1112;

            buf->reserve(2 + 2 + 4 + 6 + len + 1);
            buf->writeWordn(2 + 4 + 6 + len + 1);
            buf->writeWordn(sr);
            buf->write32(typidx);

            f1f.s = s;
            f1f.offset = buf->size();
            F1fixup->write(&f1f, sizeof(f1f));
            buf->write32(0);
            buf->writeWordn(0);

            cv8_writename(buf, id, len);
            buf->writeByte(0);
            break;

        default:
            break;
    }
}


/*******************************************
 * Put out a name for a user defined type.
 * Input:
 *      id      the name
 *      typidx  and its type
 */
void cv8_udt(const char *id, idx_t typidx)
{
    //printf("cv8_udt('%s', %x)\n", id, typidx);
    Outbuffer *buf = currentfuncdata.f1buf;
    size_t len = strlen(id);

    if (len > CV8_MAX_SYMBOL_LENGTH)
        len = CV8_MAX_SYMBOL_LENGTH;
    buf->reserve(2 + 2 + 4 + len + 1);
    buf->writeWordn( 2 + 4 + len + 1);
    buf->writeWordn(S_UDT_V3);
    buf->write32(typidx);
    cv8_writename(buf, id, len);
    buf->writeByte(0);
}

/*********************************************
 * Get Codeview register number for symbol s.
 */
int cv8_regnum(Symbol *s)
{
    int reg = s->Sreglsw;
    assert(s->Sfl == FLreg);
    if (mask[reg] & XMMREGS)
        return reg - XMM0 + 154;
    switch (type_size(s->Stype))
    {
        case 1:
            if (reg < 4)
                reg += 1;
            else if (reg >= 4 && reg < 8)
                reg += 324 - 4;
            else
                reg += 344 - 4;
            break;
        case 2:
            if (reg < 8)
                reg += 9;
            else
                reg += 352 - 8;
            break;
        case 4:
            if (reg < 8)
                reg += 17;
            else
                reg += 360 - 8;
            break;
        case 8:
            reg += 328;
            break;
        default:
            reg = 0;
            break;
    }
    return reg;
}

/***************************************
 * Put out a forward ref for structs, unions, and classes.
 * Only put out the real definitions with toDebug().
 */
idx_t cv8_fwdref(Symbol *s)
{
    assert(config.fulltypes == CV8);
//    if (s->Stypidx && !global.params.multiobj)
//      return s->Stypidx;
    struct_t *st = s->Sstruct;
    unsigned leaf;
    unsigned numidx;
    if (st->Sflags & STRunion)
    {
        leaf = LF_UNION_V3;
        numidx = 10;
    }
    else if (st->Sflags & STRclass)
    {
        leaf = LF_CLASS_V3;
        numidx = 18;
    }
    else
    {
        leaf = LF_STRUCTURE_V3;
        numidx = 18;
    }
    unsigned len = numidx + cv4_numericbytes(0);
    int idlen = strlen(s->Sident);

    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

    debtyp_t *d = debtyp_alloc(len + idlen + 1);
    TOWORD(d->data, leaf);
    TOWORD(d->data + 2, 0);     // number of fields
    TOWORD(d->data + 4, 0x80);  // property
    TOLONG(d->data + 6, 0);     // field list
    if (leaf == LF_CLASS_V3 || leaf == LF_STRUCTURE_V3)
    {
        TOLONG(d->data + 10, 0);        // dList
        TOLONG(d->data + 14, 0);        // vshape
    }
    cv4_storenumeric(d->data + numidx, 0);
    cv_namestring(d->data + len, s->Sident, idlen);
    d->data[len + idlen] = 0;
    idx_t typidx = cv_debtyp(d);
    s->Stypidx = typidx;

    return typidx;
}

/****************************************
 * Return type index for a darray of type E[]
 * Input:
 *      t       darray type
 *      etypidx type index for E
 */
idx_t cv8_darray(type *t, idx_t etypidx)
{
    //printf("cv8_darray(etypidx = %x)\n", etypidx);
    /* Put out a struct:
     *    struct dArray {
     *      size_t length;
     *      E* ptr;
     *    }
     */

#if 0
    d = debtyp_alloc(18);
    TOWORD(d->data, 0x100F);
    TOWORD(d->data + 2, OEM);
    TOWORD(d->data + 4, 1);     // 1 = dynamic array
    TOLONG(d->data + 6, 2);     // count of type indices to follow
    TOLONG(d->data + 10, 0x23); // index type, T_UQUAD
    TOLONG(d->data + 14, next); // element type
    return cv_debtyp(d);
#endif

    type *tp = type_pointer(t->Tnext);
    idx_t ptridx = cv4_typidx(tp);
    type_free(tp);

    static const unsigned char fl[] =
    {
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x23, 0x00, 0x00, 0x00, // size_t
        0x00, 0x00,             // offset
        'l', 'e', 'n', 'g', 't', 'h', 0x00,
        0xf3, 0xf2, 0xf1,       // align to 4-byte including length word before data
        0x0d, 0x15,
        0x03, 0x00,
        0x00, 0x00, 0x00, 0x00, // etypidx
        0x08, 0x00,
        'p', 't', 'r', 0x00,
        0xf2, 0xf1,
    };

    debtyp_t *f = debtyp_alloc(sizeof(fl));
    memcpy(f->data,fl,sizeof(fl));
    TOLONG(f->data + 6, I64 ? 0x23 : 0x22); // size_t
    TOLONG(f->data + 26, ptridx);
    TOWORD(f->data + 30, NPTRSIZE);
    idx_t fieldlist = cv_debtyp(f);

    const char *id;
    switch (t->Tnext->Tty)
    {
        case mTYimmutable | TYchar:
            id = "string";
            break;

        case mTYimmutable | TYwchar_t:
            id = "wstring";
            break;

        case mTYimmutable | TYdchar:
            id = "dstring";
            break;

        default:
            id = t->Tident ? t->Tident : "dArray";
            break;
    }

    int idlen = strlen(id);

    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

    debtyp_t *d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d->data, LF_STRUCTURE_V3);
    TOWORD(d->data + 2, 2);     // count
    TOWORD(d->data + 4, 0);     // property
    TOLONG(d->data + 6, fieldlist);
    TOLONG(d->data + 10, 0);    // dList
    TOLONG(d->data + 14, 0);    // vtshape
    TOWORD(d->data + 18, 2 * NPTRSIZE);   // size
    cv_namestring(d->data + 20, id, idlen);
    d->data[20 + idlen] = 0;

    idx_t top = cv_numdebtypes();
    idx_t debidx = cv_debtyp(d);
    if(top != cv_numdebtypes())
        cv8_udt(id, debidx);

    return debidx;
}

/****************************************
 * Return type index for a delegate
 * Input:
 *      t          delegate type
 *      functypidx type index for pointer to function
 */
idx_t cv8_ddelegate(type *t, idx_t functypidx)
{
    //printf("cv8_ddelegate(functypidx = %x)\n", functypidx);
    /* Put out a struct:
     *    struct dDelegate {
     *      void* ptr;
     *      function* funcptr;
     *    }
     */

    type *tv = type_fake(TYnptr);
    tv->Tcount++;
    idx_t pvidx = cv4_typidx(tv);
    type_free(tv);

    type *tp = type_pointer(t->Tnext);
    idx_t ptridx = cv4_typidx(tp);
    type_free(tp);

#if 0
    debtyp_t *d = debtyp_alloc(18);
    TOWORD(d->data, 0x100F);
    TOWORD(d->data + 2, OEM);
    TOWORD(d->data + 4, 3);     // 3 = delegate
    TOLONG(d->data + 6, 2);     // count of type indices to follow
    TOLONG(d->data + 10, key);  // void* type
    TOLONG(d->data + 14, functypidx); // function type
#else
    static const unsigned char fl[] =
    {
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x00, 0x00, 0x00, 0x00, // void*
        0x00, 0x00,             // offset
        'p','t','r',0,          // "ptr"
        0xf2, 0xf1,             // align to 4-byte including length word before data
        0x0d, 0x15,
        0x03, 0x00,
        0x00, 0x00, 0x00, 0x00, // ptrtypidx
        0x08, 0x00,
        'f', 'u','n','c','p','t','r', 0,        // "funcptr"
        0xf2, 0xf1,
    };

    debtyp_t *f = debtyp_alloc(sizeof(fl));
    memcpy(f->data,fl,sizeof(fl));
    TOLONG(f->data + 6, pvidx);
    TOLONG(f->data + 22, ptridx);
    TOWORD(f->data + 26, NPTRSIZE);
    idx_t fieldlist = cv_debtyp(f);

    const char *id = "dDelegate";
    int idlen = strlen(id);
    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

    debtyp_t *d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d->data, LF_STRUCTURE_V3);
    TOWORD(d->data + 2, 2);     // count
    TOWORD(d->data + 4, 0);     // property
    TOLONG(d->data + 6, fieldlist);
    TOLONG(d->data + 10, 0);    // dList
    TOLONG(d->data + 14, 0);    // vtshape
    TOWORD(d->data + 18, 2 * NPTRSIZE);   // size
    memcpy(d->data + 20, id, idlen);
    d->data[20 + idlen] = 0;
#endif
    return cv_debtyp(d);
}

/****************************************
 * Return type index for a aarray of type Value[Key]
 * Input:
 *      t          associative array type
 *      keyidx     key type
 *      validx     value type
 */
idx_t cv8_daarray(type *t, idx_t keyidx, idx_t validx)
{
    //printf("cv8_daarray(keyidx = %x, validx = %x)\n", keyidx, validx);
    /* Put out a struct:
     *    struct dAssocArray {
     *      void* ptr;
     *    }
     */

#if 0
    debtyp_t *d = debtyp_alloc(18);
    TOWORD(d->data, 0x100F);
    TOWORD(d->data + 2, OEM);
    TOWORD(d->data + 4, 2);     // 2 = associative array
    TOLONG(d->data + 6, 2);     // count of type indices to follow
    TOLONG(d->data + 10, keyidx);  // key type
    TOLONG(d->data + 14, validx);  // element type
#else
    type *tv = type_fake(TYnptr);
    tv->Tcount++;
    idx_t pvidx = cv4_typidx(tv);
    type_free(tv);

    static const unsigned char fl[] =
    {
        0x03, 0x12,             // LF_FIELDLIST_V2
        0x0d, 0x15,             // LF_MEMBER_V3
        0x03, 0x00,             // attribute
        0x00, 0x00, 0x00, 0x00, // void*
        0x00, 0x00,             // offset
        'p','t','r',0,          // "ptr"
        0xf2, 0xf1,             // align to 4-byte including length word before data
    };

    debtyp_t *f = debtyp_alloc(sizeof(fl));
    memcpy(f->data,fl,sizeof(fl));
    TOLONG(f->data + 6, pvidx);
    idx_t fieldlist = cv_debtyp(f);

    const char *id = "dAssocArray";
    int idlen = strlen(id);
    if (idlen > CV8_MAX_SYMBOL_LENGTH)
        idlen = CV8_MAX_SYMBOL_LENGTH;

    debtyp_t *d = debtyp_alloc(20 + idlen + 1);
    TOWORD(d->data, LF_STRUCTURE_V3);
    TOWORD(d->data + 2, 1);     // count
    TOWORD(d->data + 4, 0);     // property
    TOLONG(d->data + 6, fieldlist);
    TOLONG(d->data + 10, 0);    // dList
    TOLONG(d->data + 14, 0);    // vtshape
    TOWORD(d->data + 18, NPTRSIZE);   // size
    memcpy(d->data + 20, id, idlen);
    d->data[20 + idlen] = 0;

#endif
    return cv_debtyp(d);
}

#endif
#endif
#endif
