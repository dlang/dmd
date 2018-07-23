/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2015-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     Rainer Schuetze
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/varstats.d, backend/varstats.d)
 */
module dmd.backend.varstats;

/******************************************
 * support for lexical scope of local variables
 */

import dmd.backend.cc;
import dmd.backend.cdef;

extern(C++):

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
    uint linnum;
    uint diffNextOffset;
};

struct VarStatistics
{
    //this();

    void writeSymbolTable(symtab_t* symtab,
                          void function(Symbol*) fnWriteVar, void function() fnEndArgs,
                          void function(int off,int len) fnBeginBlock, void function() fnEndBlock);

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
    int findLineIndex(uint line);

    bool hashSymbolIdentifiers(symtab_t* symtab);
    bool hasUniqueIdentifier(symtab_t* symtab, SYMIDX si);
    bool isLexicalScopeVar(Symbol* sa);
    symtab_t* calcLexicalScope(symtab_t* symtab);
};
