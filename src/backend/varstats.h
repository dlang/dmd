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

#ifndef VARSTATS_H
#define VARSTATS_H   1

#include        "cc.h"

// variable creation/destruction information per line
struct VarStats
{
    int numNew;  // number of variables introduced at this line
    int numDel;  // number of variables which are destroyed at this line
    int endLine; // closing line for variables introduced at this line
    int offset;  // code offset in function (only evaluated for lines that are the beginning or the end of a scope)
};

struct LineOffset
{
    unsigned linnum;
    targ_size_t offset;
};

struct VarStatistics
{
    VarStatistics();

    // statistics for the current functions
    VarStats* varStats; // keeps information for the lines [firstVarStatsLine, firstVarStatsLine+cntUsedVarStats[
    int cntAllocVarStats;
    int cntUsedVarStats;
    int firstVarStatsLine;

    bool* isLexVar;       // is the variable handled? (variables from inlined functions usually excluded)
    int cntAllocLexVars;
    int nextVarStatsLine; // line not yet emitted during variable dump

    LineOffset* lineOffsets;
    int cntAllocLineOffsets;
    int cntUsedLineOffsets;
    const char* srcfile;  // only one file supported, no inline

    void startFunction();
    void recordLineOffset(Srcpos src, targ_size_t off);
    targ_size_t getLineOffset(Srcpos src);
    int findLineIndex(unsigned line);
    void markVarStats(int startLine, int endLine);
    bool isLexicalScopeVar(symbol* sa);
    void calcLexicalScope(Funcsym *s, symtab_t* symtab);
    void sanitizeLineOffsets();
};

extern VarStatistics varStats;

#endif // VARSTATS_H
