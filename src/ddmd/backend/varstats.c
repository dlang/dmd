/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2015-2017 by Digital Mars, All Rights Reserved
 * Authors:     Rainer Schuetze
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/varstats.c
 */

/******************************************
 * support for lexical scope of local variables
 */

#include <string.h>
#include <stdlib.h>

#include "varstats.h"
#include "global.h"
#include "code.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

VarStatistics::VarStatistics()
{
    memset (this, 0, sizeof (VarStatistics));
}

void VarStatistics::startFunction()
{
    cntUsedLineOffsets = 0;
    srcfile = NULL;
}

// figure if can we can add a lexical scope for the variable
// (this should exclude variables from inlined functions as there is
//  no support for gathering stats from different files)
bool VarStatistics::isLexicalScopeVar(symbol* sa)
{
    if (sa->lnoscopestart <= 0 || sa->lnoscopestart > sa->lnoscopeend)
        return false;

    // is it inside the function? Unfortunately we cannot verify the source file in case of inlining
    if (sa->lnoscopestart < funcsym_p->Sfunc->Fstartline.Slinnum)
        return false;
    if (sa->lnoscopeend > funcsym_p->Sfunc->Fendline.Slinnum)
        return false;

    return true;
}

// compare function to sort symbols by line offsets of their creation
static int cmpLifeTime(const void* p1, const void* p2)
{
    const LifeTime* lt1 = (const LifeTime*)p1;
    const LifeTime* lt2 = (const LifeTime*)p2;

    return lt1->offCreate - lt2->offCreate;
}

// a parent scope contains the creation offset of the child scope
static SYMIDX isParentScope(LifeTime* lifetimes, SYMIDX parent, SYMIDX si)
{
    if(parent < 0) // full function
        return true;
    return lifetimes[parent].offCreate <= lifetimes[si].offCreate &&
           lifetimes[parent].offDestroy > lifetimes[si].offCreate;
}

// find a symbol that includes the creation of the given symbol as part of its life time
static SYMIDX findParentScope(LifeTime* lifetimes, SYMIDX si)
{
    for(SYMIDX sj = si - 1; sj >= 0; --sj)
        if(isParentScope(lifetimes, sj, si))
           return sj;
    return -1;
}

static int getHash(const char* s)
{
    int hash = 0;
    for (; *s; s++)
        hash = hash * 11 + *s;
    return hash;
}

bool VarStatistics::hashSymbolIdentifiers(symtab_t* symtab)
{
    // build circular-linked lists of symbols with same identifier hash
    bool hashCollisions = false;
    SYMIDX firstSym[256];
    memset(firstSym, -1, sizeof(firstSym));
    for (SYMIDX si = 0; si < symtab->top; si++)
    {
        Symbol* sa = symtab->tab[si];
        int hash = getHash(sa->Sident) & 255;
        SYMIDX first = firstSym[hash];
        if (first == -1)
        {
            // connect full circle, so we don't have to recalculate the hash
            nextSym[si] = si;
            firstSym[hash] = si;
        }
        else
        {
            // insert after first entry
            nextSym[si] = nextSym[first];
            nextSym[first] = si;
            hashCollisions = true;
        }
    }
    return hashCollisions;
}

bool VarStatistics::hasUniqueIdentifier(symtab_t* symtab, SYMIDX si)
{
    Symbol* sa = symtab->tab[si];
    for (SYMIDX sj = nextSym[si]; sj != si; sj = nextSym[sj])
        if (strcmp(sa->Sident, symtab->tab[sj]->Sident) == 0)
            return false;
    return true;
}

// gather statistics about creation and destructions of variables that are
//  used by the current function
symtab_t* VarStatistics::calcLexicalScope(symtab_t* symtab)
{
    // make a copy of the symbol table
    // - arguments should be kept at the very beginning
    // - variables with unique name come first (will be emitted with full function scope)
    // - variables with duplicate names are added with ascending code offset
    if (sortedSymtab.symmax < symtab->top)
    {
        nextSym = (int*)util_realloc(nextSym, symtab->top, sizeof(*nextSym));
        sortedSymtab.tab = (Symbol**) util_realloc(sortedSymtab.tab, symtab->top, sizeof(Symbol*));
        sortedSymtab.symmax = symtab->top;
    }

    if (!hashSymbolIdentifiers(symtab))
    {
        // without any collisions, there are no duplicate symbol names, so bail out early
        uniquecnt = symtab->top;
        return symtab;
    }

    SYMIDX argcnt;
    for (argcnt = 0; argcnt < symtab->top; argcnt++)
    {
        Symbol* sa = symtab->tab[argcnt];
        if (sa->Sclass != SCparameter && sa->Sclass != SCregpar && sa->Sclass != SCfastpar && sa->Sclass != SCshadowreg)
            break;
        sortedSymtab.tab[argcnt] = sa;
    }

    // find symbols with identical names, only these need lexical scope
    uniquecnt = argcnt;
    SYMIDX dupcnt = 0;
    for (SYMIDX sj, si = argcnt; si < symtab->top; si++)
    {
        Symbol* sa = symtab->tab[si];
        if (!isLexicalScopeVar(sa) || hasUniqueIdentifier(symtab, si))
            sortedSymtab.tab[uniquecnt++] = sa;
        else
            sortedSymtab.tab[symtab->top - 1 - dupcnt++] = sa; // fill from the top
    }
    sortedSymtab.top = symtab->top;
    if(dupcnt == 0)
        return symtab;

    sortLineOffsets();

    // precalc the lexical blocks to emit so that identically named symbols don't overlap
    if (cntAllocLifeTimes < dupcnt)
    {
        lifeTimes = (LifeTime*) util_realloc(lifeTimes, dupcnt, sizeof(LifeTime));
        cntAllocLifeTimes = dupcnt;
    }

    for (SYMIDX si = 0; si < dupcnt; si++)
    {
        lifeTimes[si].sym = sortedSymtab.tab[uniquecnt + si];
        lifeTimes[si].offCreate = getLineOffset(lifeTimes[si].sym->lnoscopestart);
        lifeTimes[si].offDestroy = getLineOffset(lifeTimes[si].sym->lnoscopeend);
    }
    cntUsedLifeTimes = dupcnt;
    qsort(lifeTimes, dupcnt, sizeof(LifeTime), cmpLifeTime);

    // ensure that an inner block does not extend beyond the end of a parent block
    for (SYMIDX si = 0; si < dupcnt; si++)
    {
        SYMIDX sj = findParentScope(lifeTimes, si);
        if(sj >= 0 && lifeTimes[si].offDestroy > lifeTimes[sj].offDestroy)
            lifeTimes[si].offDestroy = lifeTimes[sj].offDestroy;
    }

    // extend life time to the creation of the next symbol that is not contained in the parent scope
    // or that has the same name
    for (SYMIDX sj, si = 0; si < dupcnt; si++)
    {
        SYMIDX parent = findParentScope(lifeTimes, si);

        for (sj = si + 1; sj < dupcnt; sj++)
            if(!isParentScope(lifeTimes, parent, sj))
                break;
            else if (strcmp(lifeTimes[si].sym->Sident, lifeTimes[sj].sym->Sident) == 0)
                break;

        lifeTimes[si].offDestroy = (sj < dupcnt ? lifeTimes[sj].offCreate : retoffset + retsize); // function length
    }

    // store duplicate symbols back with new ordering
    for (SYMIDX si = 0; si < dupcnt; si++)
        sortedSymtab.tab[uniquecnt + si] = lifeTimes[si].sym;

    return &sortedSymtab;
}

void VarStatistics::writeSymbolTable(symtab_t* symtab,
                                     void (*fnWriteVar)(Symbol*), void (*fnEndArgs)(),
                                     void (*fnBeginBlock)(int off,int len), void (*fnEndBlock)())
{
    symtab = calcLexicalScope(symtab);

    int openBlocks = 0;
    int lastOffset = 0;

    // Write local symbol table
    bool endarg = false;
    for (SYMIDX si = 0; si < symtab->top; si++)
    {
        symbol *sa = symtab->tab[si];
        if (endarg == false &&
            sa->Sclass != SCparameter &&
            sa->Sclass != SCfastpar &&
            sa->Sclass != SCregpar &&
            sa->Sclass != SCshadowreg)
        {
            if(fnEndArgs)
                (*fnEndArgs)();
            endarg = true;
        }
        if (si >= uniquecnt)
        {
            int off = lifeTimes[si - uniquecnt].offCreate;
            // close scopes that end before the creation of this symbol
            for (SYMIDX sj = si - 1; sj >= uniquecnt; --sj)
            {
                if (lastOffset < lifeTimes[sj - uniquecnt].offDestroy && lifeTimes[sj - uniquecnt].offDestroy <= off)
                {
                    assert(openBlocks > 0);
                    if(fnEndBlock)
                        (*fnEndBlock)();
                    openBlocks--;
                }
            }
            int len = lifeTimes[si - uniquecnt].offDestroy - off;
            // don't emit a block for length 0, it isn't captured by the close condition above
            if (len > 0)
            {
                if(fnBeginBlock)
                    (*fnBeginBlock)(off, len);
                openBlocks++;
            }
            lastOffset = off;
        }
        (*fnWriteVar)(sa);
    }

    while (openBlocks > 0)
    {
        if(fnEndBlock)
            (*fnEndBlock)();
        openBlocks--;
    }
}

// compare function to sort line offsets ascending by line (and offset on identical line)
static int cmpLineOffsets(const void* off1, const void* off2)
{
    const LineOffset* loff1 = (const LineOffset*)off1;
    const LineOffset* loff2 = (const LineOffset*)off2;

    if (loff1->linnum == loff2->linnum)
        return loff1->offset - loff2->offset;
    return loff1->linnum - loff2->linnum;
}

void VarStatistics::sortLineOffsets()
{
    if (cntUsedLineOffsets == 0)
        return;

    // remember the offset to the next recorded offset on another line
    for (int i = 1; i < cntUsedLineOffsets; i++)
        lineOffsets[i-1].diffNextOffset = lineOffsets[i].offset - lineOffsets[i-1].offset;
    lineOffsets[cntUsedLineOffsets - 1].diffNextOffset = retoffset + retsize - lineOffsets[cntUsedLineOffsets - 1].offset;

    // sort line records and remove duplicate lines preferring smaller offsets
    qsort(lineOffsets, cntUsedLineOffsets, sizeof(*lineOffsets), &cmpLineOffsets);
    int j = 0;
    for (int i = 1; i < cntUsedLineOffsets; i++)
        if (lineOffsets[i].linnum > lineOffsets[j].linnum)
            lineOffsets[++j] = lineOffsets[i];
    cntUsedLineOffsets = j + 1;
}

targ_size_t VarStatistics::getLineOffset(int linnum)
{
    int idx = findLineIndex(linnum);
    if (idx >= cntUsedLineOffsets || lineOffsets[idx].linnum < linnum)
        return retoffset + retsize; // function length
    if (idx > 0 && lineOffsets[idx].linnum != linnum)
        // for inexact line numbers, use the offset following the previous line
        return lineOffsets[idx-1].offset + lineOffsets[idx-1].diffNextOffset;
    return lineOffsets[idx].offset;
}

// return the first record index in the lineOffsets array with linnum >= line
int VarStatistics::findLineIndex(unsigned line)
{
    int low = 0;
    int high = cntUsedLineOffsets;
    while (low < high)
    {
        int mid = (low + high) >> 1;
        int ln = lineOffsets[mid].linnum;
        if (line < ln)
            high = mid;
        else if (line > ln)
            low = mid + 1;
        else
            return mid;
    }
    return low;
}

void VarStatistics::recordLineOffset(Srcpos src, targ_size_t off)
{
    // only record line numbers from one file, symbol info does not include source file
    if (!src.Sfilename || !src.Slinnum)
        return;
    if (!srcfile)
        srcfile = src.Sfilename;
    if (srcfile != src.Sfilename && strcmp (srcfile, src.Sfilename) != 0)
        return;

    // assume ascending code offsets generated during codegen, ignore any other
    //  (e.g. there is an additional line number emitted at the end of the function
    //   or multiple line numbers at the same offset)
    if (cntUsedLineOffsets > 0 && lineOffsets[cntUsedLineOffsets-1].offset >= off)
        return;

    if (cntUsedLineOffsets > 0 && lineOffsets[cntUsedLineOffsets-1].linnum == src.Slinnum)
    {
        // optimize common case: new offset on same line
        return;
    }
    // don't care for lineOffsets being ordered now, that is taken care of later (calcLexicalScope)
    if (cntUsedLineOffsets >= cntAllocLineOffsets)
    {
        cntAllocLineOffsets = 2 * cntUsedLineOffsets + 16;
        lineOffsets = (LineOffset*) util_realloc(lineOffsets, cntAllocLineOffsets, sizeof(*lineOffsets));
    }
    lineOffsets[cntUsedLineOffsets].linnum = src.Slinnum;
    lineOffsets[cntUsedLineOffsets].offset = off;
    cntUsedLineOffsets++;
}
