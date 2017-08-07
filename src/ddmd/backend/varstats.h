/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 2015-2017 by Digital Mars, All Rights Reserved
 * Authors:     Rainer Schuetze
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/varstats.h
 */

/******************************************
 * support for lexical scope of local variables
 */

#ifndef VARSTATS_H
#define VARSTATS_H   1

#include        "cc.h"

// estimate of variable life time
struct LifeTime
{
    Symbol* sym;
    int offCreate;  // variable created before this code offset
    int offDestroy; // variable destroyed after this code offset
};

struct LineOffset
{
    targ_size_t offset;
    unsigned linnum;
    unsigned diffNextOffset;
};

struct VarStatistics
{
    VarStatistics();

    void writeSymbolTable(symtab_t* symtab,
                          void (*fnWriteVar)(Symbol*), void (*fnEndArgs)(),
                          void (*fnBeginBlock)(int off,int len), void (*fnEndBlock)());

    void startFunction();
    void recordLineOffset(Srcpos src, targ_size_t off);

private:
    LifeTime* lifeTimes;
    int cntAllocLifeTimes;
    int cntUsedLifeTimes;

    // symbol table sorted by offset of variable creation
    symtab_t sortedSymtab;
    SYMIDX* nextSym;      // next symbol with identifier with same hash, same size as sortedSymtab
    int uniquecnt;        // number of variables that have unique name and don't need lexical scope

    // line number records for the current function
    LineOffset* lineOffsets;
    int cntAllocLineOffsets;
    int cntUsedLineOffsets;
    const char* srcfile;  // only one file supported, no inline

    targ_size_t getLineOffset(int linnum);
    void sortLineOffsets();
    int findLineIndex(unsigned line);

    bool hashSymbolIdentifiers(symtab_t* symtab);
    bool hasUniqueIdentifier(symtab_t* symtab, SYMIDX si);
    bool isLexicalScopeVar(symbol* sa);
    symtab_t* calcLexicalScope(symtab_t* symtab);
};

extern VarStatistics varStats;

#endif // VARSTATS_H
