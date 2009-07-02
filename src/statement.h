
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_STATEMENT_H
#define DMD_STATEMENT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"

#include "dsymbol.h"

struct OutBuffer;
struct Scope;
struct Expression;
struct LabelDsymbol;
struct Identifier;
struct DeclarationStatement;
struct DefaultStatement;
struct VarDeclaration;
struct Condition;
struct Module;
struct Token;
struct InlineCostState;
struct InlineDoState;
struct InlineScanState;
struct ReturnStatement;
struct CompoundStatement;
struct Argument;

// Back end
struct IRState;
struct Blockx;
struct block;
struct elem;
struct code;

struct Statement : Object
{
    Loc loc;

    Statement(Loc loc);
    virtual Statement *syntaxCopy();

    void print();
    char *toChars();

    void error(const char *format, ...);
    virtual void toCBuffer(OutBuffer *buf);
    virtual Statement *semantic(Scope *sc);
    Statement *semanticScope(Scope *sc, Statement *sbreak, Statement *scontinue);
    virtual int hasBreak();
    virtual int hasContinue();
    virtual int usesEH();
    virtual Statement *callAutoDtor();
    virtual Array *flatten();

    virtual int inlineCost(InlineCostState *ics);
    virtual Expression *doInline(InlineDoState *ids);
    virtual Statement *inlineScan(InlineScanState *iss);

    // Back end
    virtual void toIR(IRState *irs);

    // Avoid dynamic_cast
    virtual DeclarationStatement *isDeclarationStatement() { return NULL; }
    virtual CompoundStatement *isCompoundStatement() { return NULL; }
    virtual ReturnStatement *isReturnStatement() { return NULL; }
};

struct ExpStatement : Statement
{
    Expression *exp;

    ExpStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct DeclarationStatement : ExpStatement
{
    // Doing declarations as an expression, rather than a statement,
    // makes inlining functions much easier.

    DeclarationStatement(Loc loc, Dsymbol *s);
    DeclarationStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *callAutoDtor();

    DeclarationStatement *isDeclarationStatement() { return this; }
};

struct CompoundStatement : Statement
{
    Array *statements;

    CompoundStatement(Loc loc, Array *s);
    CompoundStatement(Loc loc, Statement *s1, Statement *s2);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);
    int usesEH();
    Array *flatten();

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);

    CompoundStatement *isCompoundStatement() { return this; }
};

#if 0
// Same as CompoundStatement, but introduces a new scope

struct BlockStatement : CompoundStatement
{
    BlockStatement(Loc loc, Array *s);
    BlockStatement(Loc loc, Statement *s1, Statement *s2);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);

    void toIR(IRState *irs);
};
#endif

struct ScopeStatement : Statement
{
    Statement *statement;

    ScopeStatement(Loc loc, Statement *s);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);

    void toIR(IRState *irs);
};

struct WhileStatement : Statement
{
    Expression *condition;
    Statement *body;

    WhileStatement(Loc loc, Expression *c, Statement *b);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct DoStatement : Statement
{
    Statement *body;
    Expression *condition;

    DoStatement(Loc loc, Statement *b, Expression *c);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ForStatement : Statement
{
    Statement *init;
    Expression *condition;
    Expression *increment;
    Statement *body;

    ForStatement(Loc loc, Statement *init, Expression *condition, Expression *increment, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ForeachStatement : Statement
{
    Argument *arg;
    Expression *aggr;
    Statement *body;

    VarDeclaration *var;
    Array cases;	// put breaks, continues, gotos and returns here
    Array gotos;	// forward referenced goto's go here

    ForeachStatement(Loc loc, Argument *arg, Expression *aggr, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct IfStatement : Statement
{
    Expression *condition;
    Statement *ifbody;
    Statement *elsebody;

    IfStatement(Loc loc, Expression *condition, Statement *ifbody, Statement *elsebody);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    int usesEH();

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ConditionalStatement : Statement
{
    Condition *condition;
    Statement *ifbody;
    Statement *elsebody;

    ConditionalStatement(Loc loc, Condition *condition, Statement *ifbody, Statement *elsebody);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int usesEH();

    void toCBuffer(OutBuffer *buf);
};

struct SwitchStatement : Statement
{
    Expression *condition;
    Statement *body;
    DefaultStatement *sdefault;

    Array *cases;		// array of CaseStatement's

    SwitchStatement(Loc loc, Expression *c, Statement *b);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct CaseStatement : Statement
{
    Expression *exp;
    Statement *statement;
    int index;		// which case it is (since we sort this)

    CaseStatement(Loc loc, Expression *exp, Statement *s);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int compare(Object *obj);
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct DefaultStatement : Statement
{
    Statement *statement;

    DefaultStatement(Loc loc, Statement *s);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct SwitchErrorStatement : Statement
{
    SwitchErrorStatement(Loc loc);

    void toIR(IRState *irs);
};

struct ReturnStatement : Statement
{
    Expression *exp;

    ReturnStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);

    ReturnStatement *isReturnStatement() { return this; }
};

struct BreakStatement : Statement
{
    Identifier *ident;

    BreakStatement(Loc loc, Identifier *ident);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    void toIR(IRState *irs);
};

struct ContinueStatement : Statement
{
    Identifier *ident;

    ContinueStatement(Loc loc, Identifier *ident);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    void toIR(IRState *irs);
};

struct SynchronizedStatement : Statement
{
    Expression *exp;
    Statement *body;

    SynchronizedStatement(Loc loc, Expression *exp, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

// Back end
    elem *esync;
    SynchronizedStatement(Loc loc, elem *esync, Statement *body);
    void toIR(IRState *irs);
};

struct WithStatement : Statement
{
    Expression *exp;
    Statement *body;
    VarDeclaration *wthis;

    WithStatement(Loc loc, Expression *exp, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct TryCatchStatement : Statement
{
    Statement *body;
    Array *catches;

    TryCatchStatement(Loc loc, Statement *body, Array *catches);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct Catch : Object
{
    Loc loc;
    Type *type;
    Identifier *ident;
    VarDeclaration *var;
    Statement *handler;

    Catch(Loc loc, Type *t, Identifier *id, Statement *handler);
    Catch *syntaxCopy();
    void semantic(Scope *sc);
};

struct TryFinallyStatement : Statement
{
    Statement *body;
    Statement *finalbody;

    TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf);
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ThrowStatement : Statement
{
    Expression *exp;

    ThrowStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct VolatileStatement : Statement
{
    Statement *statement;

    VolatileStatement(Loc loc, Statement *statement);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Array *flatten();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct GotoStatement : Statement
{
    Identifier *ident;
    LabelDsymbol *label;

    GotoStatement(Loc loc, Identifier *ident);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    void toIR(IRState *irs);
};

struct LabelStatement : Statement
{
    Identifier *ident;
    Statement *statement;
    block *lblock;		// back end
    int isReturnLabel;

    LabelStatement(Loc loc, Identifier *ident, Statement *statement);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Array *flatten();
    int usesEH();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct LabelDsymbol : Dsymbol
{
    LabelStatement *statement;

    LabelDsymbol(Identifier *ident);
    LabelDsymbol *isLabel();
};

struct AsmStatement : Statement
{
    Token *tokens;
    code *asmcode;
    unsigned asmalign;		// alignment of this statement
    unsigned refparam;		// !=0 if function parameter is referenced
    unsigned naked;		// !=0 if function is to be naked
    unsigned regs;		// mask of registers modified

    AsmStatement(Loc loc, Token *tokens);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    void toCBuffer(OutBuffer *buf);

    void toIR(IRState *irs);
};

#endif /* DMD_STATEMENT_H */
