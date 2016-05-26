// Compiler implementation of the D programming language
// Copyright (c) 2015-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Rainer Schuetze
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

/******************************************
 * support for lexical scope of local variables
 */

#include <string.h>
#include <stdlib.h>

#include "varstats.h"
#include "global.h"
#include "code.h"

VarStatistics::VarStatistics()
{
    memset (this, 0, sizeof (VarStatistics));
}

void VarStatistics::startFunction()
{
    cntUsedLineOffsets = 0;
    srcfile = NULL;
}

// record lines of creation and destruction of a variable
void VarStatistics::markVarStats(int startLine, int endLine)
{
    if (endLine <= startLine) // single line functions
        endLine = startLine + 1;
    if (cntUsedVarStats == 0)
        firstVarStatsLine = startLine;

    if(startLine < firstVarStatsLine)
    {
        int cnt = firstVarStatsLine - startLine;
        if (cnt + cntUsedVarStats > cntAllocVarStats)
        {
            cntAllocVarStats = cnt + cntUsedVarStats;
            varStats = (VarStats*) util_realloc(varStats, cntAllocVarStats, sizeof(*varStats));
        }
        memmove(varStats + cnt, varStats, cntUsedVarStats * sizeof(*varStats));
        memset(varStats, 0, cnt * sizeof(*varStats));
        cntUsedVarStats += cnt;
        firstVarStatsLine = startLine;
    }

    int cnt = endLine - firstVarStatsLine + 1;
    if (cnt > cntAllocVarStats)
    {
        varStats = (VarStats*) util_realloc(varStats, cnt, sizeof(*varStats));
        cntAllocVarStats = cnt;
    }
    if (cnt > cntUsedVarStats)
    {
        memset(varStats + cntUsedVarStats, 0, (cnt - cntUsedVarStats) * sizeof(*varStats));
        cntUsedVarStats = cnt;
    }

    varStats[startLine - firstVarStatsLine].numNew++;
    varStats[endLine   - firstVarStatsLine].numDel++;
    varStats[startLine - firstVarStatsLine].endLine = endLine;
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

    // verify that the variable does not violate the assumption that scopes are stacked inside
    // each other (might happen with optimizations/inlining)
    int start = (sa->lnoscopestart < firstVarStatsLine ? firstVarStatsLine : sa->lnoscopestart + 1);
    int end   = firstVarStatsLine + cntUsedVarStats;
    end = (sa->lnoscopeend < end ? sa->lnoscopeend : end);
    for (int i = start; i < end; i++)
        if (varStats[i - firstVarStatsLine].numNew || varStats[i - firstVarStatsLine].numDel)
            return false;
    return true;
}

// compare function to sort line offsets by line
static int cmpLineOffsets(const void* off1, const void* off2)
{
    const LineOffset* loff1 = (const LineOffset*)off1;
    const LineOffset* loff2 = (const LineOffset*)off2;

    if (loff1->linnum == loff2->linnum)
        return loff1->offset - loff2->offset;
    return loff1->linnum - loff2->linnum;
}

// gather statistics about creation and destructions of variables that are
//  used by the current function
void VarStatistics::calcLexicalScope(Funcsym *s, symtab_t* symtab)
{
    // sort line records and remove duplicate lines
    qsort(lineOffsets, cntUsedLineOffsets, sizeof(*lineOffsets), &cmpLineOffsets);
    int j = 0;
    for (int i = 1; i < cntUsedLineOffsets; i++)
        if (lineOffsets[i].linnum > lineOffsets[j].linnum)
            lineOffsets[++j] = lineOffsets[i];
    cntUsedLineOffsets = j + 1;

    cntUsedVarStats = 0;
    if (cntAllocLexVars < symtab->top)
    {
        isLexVar = (bool*) util_realloc(isLexVar, symtab->top, sizeof(*isLexVar));
        cntAllocLexVars = symtab->top;
    }
    memset(isLexVar, 0, symtab->top);

    SYMIDX si;
    for (si = 0; si < symtab->top; si++)
    {
        symbol *sa = symtab->tab[si];
        isLexVar[si] = isLexicalScopeVar(sa);
        if(isLexVar[si])
            markVarStats(sa->lnoscopestart, sa->lnoscopeend);
    }
    // todo: optimize out multiple blocks for multiple variables added and removed at the same locations

    Srcpos src = funcsym_p->Sfunc->Fstartline;
    for (int i = 0; i < cntUsedVarStats; i++)
        if (varStats[i].numDel > 0 || varStats[i].numNew > 0)
        {
            src.Slinnum = firstVarStatsLine + i;
            varStats[i].offset = getLineOffset (src);
        }

    nextVarStatsLine = firstVarStatsLine;
}

targ_size_t VarStatistics::getLineOffset(Srcpos src)
{
    if (!src.Sfilename || !srcfile)
        return 0;
    if (src.Sfilename != srcfile && strcmp (src.Sfilename, srcfile) != 0)
        return 0;
    int idx = findLineIndex(src.Slinnum);
    if (idx >= cntUsedLineOffsets || lineOffsets[idx].linnum < src.Slinnum)
        return retoffset + retsize; // function length
    return lineOffsets[idx].offset;
}

int VarStatistics::findLineIndex(unsigned line)
{
    int low = 0;
    int high = cntUsedLineOffsets - 1;
    while (low <= high)
    {
        int mid = (low + high) >> 1;
        int ln = lineOffsets[mid].linnum;
        if (line < ln)
            high = mid - 1;
        else if (line > ln)
            low = mid + 1;
        else
            return mid;
    }
    return low;
}

void VarStatistics::recordLineOffset(Srcpos src, targ_size_t off)
{
    if (!src.Sfilename || !src.Slinnum)
        return;
    if (!srcfile)
        srcfile = src.Sfilename;
    if (srcfile != src.Sfilename && strcmp (srcfile, src.Sfilename) != 0)
        return;

    if (cntUsedLineOffsets > 0 && lineOffsets[cntUsedLineOffsets-1].linnum == src.Slinnum)
    {
        // optimize common case: new offset on same line, use minimum
        if (off < lineOffsets[cntUsedLineOffsets-1].offset)
            lineOffsets[cntUsedLineOffsets-1].offset = off;
        return;
    }
    if (cntUsedLineOffsets >= cntAllocLineOffsets)
    {
        cntAllocLineOffsets = 2 * cntUsedLineOffsets + 16;
        lineOffsets = (LineOffset*) util_realloc(lineOffsets, cntAllocLineOffsets, sizeof(*lineOffsets));
    }
    lineOffsets[cntUsedLineOffsets].linnum = src.Slinnum;
    lineOffsets[cntUsedLineOffsets].offset = off;
    cntUsedLineOffsets++;
}
