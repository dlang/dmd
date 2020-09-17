/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2015-2020 by The D Language Foundation, All Rights Reserved
 * Authors:     Rainer Schuetze
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dvarstats.d, backend/dvarstats.d)
 */

module dmd.backend.dvarstats;

/******************************************
 * support for lexical scope of local variables
 */

import core.stdc.string;
import core.stdc.stdlib;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.code;
import dmd.backend.symtab;

extern (C++):

nothrow:

alias _compare_fp_t = extern(C) nothrow int function(const void*, const void*);
extern(C) void qsort(void* base, size_t nmemb, size_t size, _compare_fp_t compar);

version (all) // free function version
{
    import dmd.backend.dvarstats;

    void varStats_writeSymbolTable(symtab_t* symtab,
            void function(Symbol*) nothrow fnWriteVar, void function() nothrow fnEndArgs,
            void function(int off,int len) nothrow fnBeginBlock, void function() nothrow fnEndBlock)
    {
        varStats.writeSymbolTable(symtab, fnWriteVar, fnEndArgs, fnBeginBlock, fnEndBlock);
    }

    void varStats_startFunction()
    {
        varStats.startFunction();
    }

    void varStats_recordLineOffset(Srcpos src, targ_size_t off)
    {
        varStats.recordLineOffset(src, off);
    }

    __gshared VarStatistics varStats;
}


// estimate of variable life time
struct LifeTime
{
    Symbol* sym;
    int offCreate;  // variable created before this code offset
    int offDestroy; // variable destroyed after this code offset
}

struct LineOffset
{
    targ_size_t offset;
    uint linnum;
    uint diffNextOffset;
}

struct VarStatistics
{
private:
nothrow:
    LifeTime[] lifeTimes;
    int cntUsedLifeTimes;

    // symbol table sorted by offset of variable creation
    symtab_t sortedSymtab;
    SYMIDX* nextSym;      // next symbol with identifier with same hash, same size as sortedSymtab
    int uniquecnt;        // number of variables that have unique name and don't need lexical scope

    // line number records for the current function
    LineOffset[] lineOffsets;
    int cntUsedLineOffsets;
    const(char)* srcfile;  // only one file supported, no inline

public void startFunction()
{
    cntUsedLineOffsets = 0;
    srcfile = null;
}

// figure if can we can add a lexical scope for the variable
// (this should exclude variables from inlined functions as there is
//  no support for gathering stats from different files)
private bool isLexicalScopeVar(Symbol* sa)
{
    if (sa.lnoscopestart <= 0 || sa.lnoscopestart > sa.lnoscopeend)
        return false;

    // is it inside the function? Unfortunately we cannot verify the source file in case of inlining
    if (sa.lnoscopestart < funcsym_p.Sfunc.Fstartline.Slinnum)
        return false;
    if (sa.lnoscopeend > funcsym_p.Sfunc.Fendline.Slinnum)
        return false;

    return true;
}

// compare function to sort symbols by line offsets of their creation
private extern (C) static int cmpLifeTime(scope const void* p1, scope const void* p2)
{
    const LifeTime* lt1 = cast(const(LifeTime)*)p1;
    const LifeTime* lt2 = cast(const(LifeTime)*)p2;

    return lt1.offCreate - lt2.offCreate;
}

// a parent scope contains the creation offset of the child scope
private static extern(D) SYMIDX isParentScope(LifeTime[] lifetimes, SYMIDX parent, SYMIDX si)
{
    if(parent < 0) // full function
        return true;
    return lifetimes[parent].offCreate <= lifetimes[si].offCreate &&
           lifetimes[parent].offDestroy > lifetimes[si].offCreate;
}

// find a symbol that includes the creation of the given symbol as part of its life time
private static extern(D) SYMIDX findParentScope(LifeTime[] lifetimes, SYMIDX si)
{
    for(SYMIDX sj = si - 1; sj >= 0; --sj)
        if(isParentScope(lifetimes, sj, si))
           return sj;
    return -1;
}

private static int getHash(const(char)* s)
{
    int hash = 0;
    for (; *s; s++)
        hash = hash * 11 + *s;
    return hash;
}

private bool hashSymbolIdentifiers(symtab_t* symtab)
{
    // build circular-linked lists of symbols with same identifier hash
    bool hashCollisions = false;
    SYMIDX[256] firstSym = void;
    memset(firstSym.ptr, -1, (firstSym).sizeof);
    for (SYMIDX si = 0; si < symtab.length; si++)
    {
        Symbol* sa = symtab.tab[si];
        int hash = getHash(sa.Sident.ptr) & 255;
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

private bool hasUniqueIdentifier(symtab_t* symtab, SYMIDX si)
{
    Symbol* sa = symtab.tab[si];
    for (SYMIDX sj = nextSym[si]; sj != si; sj = nextSym[sj])
        if (strcmp(sa.Sident.ptr, symtab.tab[sj].Sident.ptr) == 0)
            return false;
    return true;
}

// gather statistics about creation and destructions of variables that are
//  used by the current function
private symtab_t* calcLexicalScope(symtab_t* symtab) return
{
    // make a copy of the symbol table
    // - arguments should be kept at the very beginning
    // - variables with unique name come first (will be emitted with full function scope)
    // - variables with duplicate names are added with ascending code offset
    if (sortedSymtab.symmax < symtab.length)
    {
        nextSym = cast(int*)util_realloc(nextSym, symtab.length, (*nextSym).sizeof);
        sortedSymtab.tab = cast(Symbol**) util_realloc(sortedSymtab.tab, symtab.length, (Symbol*).sizeof);
        sortedSymtab.symmax = symtab.length;
    }

    if (!hashSymbolIdentifiers(symtab))
    {
        // without any collisions, there are no duplicate symbol names, so bail out early
        uniquecnt = symtab.length;
        return symtab;
    }

    SYMIDX argcnt;
    for (argcnt = 0; argcnt < symtab.length; argcnt++)
    {
        Symbol* sa = symtab.tab[argcnt];
        if (sa.Sclass != SCparameter && sa.Sclass != SCregpar && sa.Sclass != SCfastpar && sa.Sclass != SCshadowreg)
            break;
        sortedSymtab.tab[argcnt] = sa;
    }

    // find symbols with identical names, only these need lexical scope
    uniquecnt = argcnt;
    SYMIDX dupcnt = 0;
    for (SYMIDX sj, si = argcnt; si < symtab.length; si++)
    {
        Symbol* sa = symtab.tab[si];
        if (!isLexicalScopeVar(sa) || hasUniqueIdentifier(symtab, si))
            sortedSymtab.tab[uniquecnt++] = sa;
        else
            sortedSymtab.tab[symtab.length - 1 - dupcnt++] = sa; // fill from the top
    }
    sortedSymtab.length = symtab.length;
    if(dupcnt == 0)
        return symtab;

    sortLineOffsets();

    // precalc the lexical blocks to emit so that identically named symbols don't overlap
    if (lifeTimes.length < dupcnt)
        lifeTimes = (cast(LifeTime*) util_realloc(lifeTimes.ptr, dupcnt, (LifeTime).sizeof))[0 .. dupcnt];

    for (SYMIDX si = 0; si < dupcnt; si++)
    {
        lifeTimes[si].sym = sortedSymtab.tab[uniquecnt + si];
        lifeTimes[si].offCreate = cast(int)getLineOffset(lifeTimes[si].sym.lnoscopestart);
        lifeTimes[si].offDestroy = cast(int)getLineOffset(lifeTimes[si].sym.lnoscopeend);
    }
    cntUsedLifeTimes = dupcnt;
    qsort(lifeTimes.ptr, dupcnt, (lifeTimes[0]).sizeof, &cmpLifeTime);

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
            else if (strcmp(lifeTimes[si].sym.Sident.ptr, lifeTimes[sj].sym.Sident.ptr) == 0)
                break;

        lifeTimes[si].offDestroy = cast(int)(sj < dupcnt ? lifeTimes[sj].offCreate : retoffset + retsize); // function length
    }

    // store duplicate symbols back with new ordering
    for (SYMIDX si = 0; si < dupcnt; si++)
        sortedSymtab.tab[uniquecnt + si] = lifeTimes[si].sym;

    return &sortedSymtab;
}

public void writeSymbolTable(symtab_t* symtab,
            void function(Symbol*) nothrow fnWriteVar, void function() nothrow fnEndArgs,
            void function(int off,int len) nothrow fnBeginBlock, void function() nothrow fnEndBlock)
{
    symtab = calcLexicalScope(symtab);

    int openBlocks = 0;
    int lastOffset = 0;

    // Write local symbol table
    bool endarg = false;
    for (SYMIDX si = 0; si < symtab.length; si++)
    {
        Symbol *sa = symtab.tab[si];
        if (endarg == false &&
            sa.Sclass != SCparameter &&
            sa.Sclass != SCfastpar &&
            sa.Sclass != SCregpar &&
            sa.Sclass != SCshadowreg)
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
private extern (C) static int cmpLineOffsets(scope const void* off1, scope const void* off2)
{
    const LineOffset* loff1 = cast(const(LineOffset)*)off1;
    const LineOffset* loff2 = cast(const(LineOffset)*)off2;

    if (loff1.linnum == loff2.linnum)
        return cast(int)(loff1.offset - loff2.offset);
    return loff1.linnum - loff2.linnum;
}

private void sortLineOffsets()
{
    if (cntUsedLineOffsets == 0)
        return;

    // remember the offset to the next recorded offset on another line
    for (int i = 1; i < cntUsedLineOffsets; i++)
        lineOffsets[i-1].diffNextOffset = cast(uint)(lineOffsets[i].offset - lineOffsets[i-1].offset);
    lineOffsets[cntUsedLineOffsets - 1].diffNextOffset = cast(uint)(retoffset + retsize - lineOffsets[cntUsedLineOffsets - 1].offset);

    // sort line records and remove duplicate lines preferring smaller offsets
    qsort(lineOffsets.ptr, cntUsedLineOffsets, (lineOffsets[0]).sizeof, &cmpLineOffsets);
    int j = 0;
    for (int i = 1; i < cntUsedLineOffsets; i++)
        if (lineOffsets[i].linnum > lineOffsets[j].linnum)
            lineOffsets[++j] = lineOffsets[i];
    cntUsedLineOffsets = j + 1;
}

private targ_size_t getLineOffset(int linnum)
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
private int findLineIndex(uint line)
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

public void recordLineOffset(Srcpos src, targ_size_t off)
{
    version (MARS)
        const sfilename = src.Sfilename;
    else
        const sfilename = srcpos_name(src);

    // only record line numbers from one file, symbol info does not include source file
    if (!sfilename || !src.Slinnum)
        return;
    if (!srcfile)
        srcfile = sfilename;
    if (srcfile != sfilename && strcmp(srcfile, sfilename) != 0)
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
    if (lineOffsets.length <= cntUsedLineOffsets)
    {
        const newSize = 2 * cntUsedLineOffsets + 16;
        lineOffsets = (cast(LineOffset*) util_realloc(lineOffsets.ptr, newSize, (lineOffsets[0]).sizeof))[0 .. newSize];
    }
    lineOffsets[cntUsedLineOffsets].linnum = src.Slinnum;
    lineOffsets[cntUsedLineOffsets].offset = off;
    cntUsedLineOffsets++;
}

}
