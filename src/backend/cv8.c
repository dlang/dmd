// Compiler implementation of the D programming language
// Copyright (c) 2012-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
#include        "obj.h"
#include        "outbuf.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#if _MSC_VER || __sun
#include        <alloca.h>
#endif

#if MARS
#if TARGET_WINDOS

// The "F2" section, which is the line numbers
static Outbuffer *F2_buf;

// The "F3" section, which is global and a string table of source file names.
static Outbuffer *F3_buf;

// The "F4" section, which is global and a lists info about source files.
static Outbuffer *F4_buf;

static const char *srcfilename;
static unsigned srcfileoff;
static Symbol *sfunc;

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
};

static Outbuffer *funcdata;     // array of FuncData's

static Outbuffer *linepair;     // array of offset/line pairs
static unsigned linepairstart;
static unsigned linepairnum;

unsigned cv8_addfile(const char *filename);
void cv8_writesection(int seg, unsigned type, Outbuffer *buf);

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
    linepairstart = 0;
    linepairnum = 0;
}

void cv8_termfile()
{
    //printf("cv8_termfile()\n");

    /* Write out the debug info sections.
     */

    int seg = MsCoffObj::seg_debugS();

    unsigned v = 4;
    objmod->bytes(seg,0,4,&v);

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
    }

    // Write out "F3" section
    cv8_writesection(seg, 0xF3, F3_buf);

    // Write out "F4" section
    cv8_writesection(seg, 0xF4, F4_buf);
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
    srcfileoff = cv8_addfile(filename);
}

void cv8_termmodule()
{
    //printf("cv8_termmodule()\n");
    assert(config.exe == EX_WIN64);
}

/******************************************
 * Called at the start of a function.
 */
void cv8_func_start(Symbol *sfunc)
{
    //printf("cv8_func_start(%s)\n", sfunc->Sident);
    linepairstart += linepairnum;
    linepairnum = 0;
    srcfilename = NULL;
}

void cv8_func_term(Symbol *sfunc)
{
    //printf("cv8_func_term(%s)\n", sfunc->Sident);

    FuncData fd;
    memset(&fd, 0, sizeof(fd));

    fd.sfunc = sfunc;
    fd.section_length = retoffset + retsize;
    fd.srcfilename = srcfilename;
    fd.srcfileoff = srcfileoff;
    fd.linepairstart = linepairstart;
    fd.linepairnum = linepairnum;

    funcdata->write(&fd, sizeof(fd));
}

/**********************************************
 */

void cv8_linnum(Srcpos srcpos, targ_size_t offset)
{
    //printf("cv8_linnum(file = %s, line = %d, offset = x%x)\n", srcpos.Sfilename, (int)srcpos.Slinnum, (unsigned)offset);
    if (srcfilename)
    {
        /* Ignore line numbers from different files in the same function.
         * This can happen with inlined functions.
         * To make this work would require a separate F2 section for each different file.
         */
        if (srcfilename != srcpos.Sfilename &&
            strcmp(srcfilename, srcpos.Sfilename))
            return;
    }
    else
    {
        srcfilename = srcpos.Sfilename;
        srcfileoff  = cv8_addfile(srcpos.Sfilename);
    }
    linepair->write32((unsigned)offset);
    linepair->write32((unsigned)srcpos.Slinnum | 0x80000000);
    ++linepairnum;
}

/**********************************************
 * Add source file, if it isn't already there.
 * Return offset into F4.
 */

unsigned cv8_addfile(const char *filename)
{
    /* The algorithms here use a linear search. This is acceptable only
     * because we expect only 1 or 2 files to appear.
     * Unlike C, there won't be lots of .h source files to be accounted for.
     */

    unsigned length = F3_buf->size();
    unsigned char *p = F3_buf->buf;
    size_t len = strlen(filename);

    unsigned off = 1;
    while (off + len < length)
    {
        if (memcmp(p + off, filename, len + 1) == 0)
            // Already there
            goto L1;
        off += strlen((const char *)(p + off)) + 1;
    }
    off = length;
    // Add it
    F3_buf->write(filename, len + 1);

L1:
    // off is the offset of the filename in F3.
    // Find it in F4.

    length = F4_buf->size();
    p = F4_buf->buf;

    unsigned u = 0;
    while (u + 8 < length)
    {
        if (off == *(unsigned *)(p + u))
            return u;
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

#endif
#endif
#endif
