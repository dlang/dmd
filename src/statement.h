
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_STATEMENT_H
#define DMD_STATEMENT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"

#include "arraytypes.h"
#include "dsymbol.h"

struct OutBuffer;
struct Scope;
struct Expression;
struct LabelDsymbol;
struct Identifier;
struct IfStatement;
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
struct StaticAssert;
struct AsmStatement;
struct GotoStatement;
struct ScopeStatement;
struct TryCatchStatement;
struct HdrGenState;
struct InterState;

enum TOK;

// Back end
struct IRState;
struct Blockx;
#if IN_GCC
union tree_node; typedef union tree_node block;
union tree_node; typedef union tree_node elem;
#else
struct block;
struct elem;
#endif
struct code;

struct Statement : Object
{
    Loc loc;

    Statement(Loc loc);
    virtual Statement *syntaxCopy();

    void print();
    char *toChars();

    void error(const char *format, ...);
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual TryCatchStatement *isTryCatchStatement() { return NULL; }
    virtual GotoStatement *isGotoStatement() { return NULL; }
    virtual AsmStatement *isAsmStatement() { return NULL; }
#ifdef _DH
    int incontract;
#endif
    virtual ScopeStatement *isScopeStatement() { return NULL; }
    virtual Statement *semantic(Scope *sc);
    Statement *semanticScope(Scope *sc, Statement *sbreak, Statement *scontinue);
    virtual int hasBreak();
    virtual int hasContinue();
    virtual int usesEH();
    virtual int fallOffEnd();
    virtual int comeFrom();
    virtual void scopeCode(Statement **sentry, Statement **sexit, Statement **sfinally);
    virtual Statements *flatten(Scope *sc);
    virtual Expression *interpret(InterState *istate);

    virtual int inlineCost(InlineCostState *ics);
    virtual Expression *doInline(InlineDoState *ids);
    virtual Statement *inlineScan(InlineScanState *iss);

    // Back end
    virtual void toIR(IRState *irs);

    // Avoid dynamic_cast
    virtual DeclarationStatement *isDeclarationStatement() { return NULL; }
    virtual CompoundStatement *isCompoundStatement() { return NULL; }
    virtual ReturnStatement *isReturnStatement() { return NULL; }
    virtual IfStatement *isIfStatement() { return NULL; }
};

struct ExpStatement : Statement
{
    Expression *exp;

    ExpStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int fallOffEnd();

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct CompileStatement : Statement
{
    Expression *exp;

    CompileStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
};

struct DeclarationStatement : ExpStatement
{
    // Doing declarations as an expression, rather than a statement,
    // makes inlining functions much easier.

    DeclarationStatement(Loc loc, Dsymbol *s);
    DeclarationStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void scopeCode(Statement **sentry, Statement **sexit, Statement **sfinally);

    DeclarationStatement *isDeclarationStatement() { return this; }
};

struct CompoundStatement : Statement
{
    Statements *statements;

    CompoundStatement(Loc loc, Statements *s);
    CompoundStatement(Loc loc, Statement *s1, Statement *s2);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Statements *flatten(Scope *sc);
    ReturnStatement *isReturnStatement();
    Expression *interpret(InterState *istate);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);

    CompoundStatement *isCompoundStatement() { return this; }
};

/* The purpose of this is so that continue will go to the next
 * of the statements, and break will go to the end of the statements.
 */
struct UnrolledLoopStatement : Statement
{
    Statements *statements;

    UnrolledLoopStatement(Loc loc, Statements *statements);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ScopeStatement : Statement
{
    Statement *statement;

    ScopeStatement(Loc loc, Statement *s);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    ScopeStatement *isScopeStatement() { return this; }
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);

    Statement *inlineScan(InlineScanState *iss);

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
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    void scopeCode(Statement **sentry, Statement **sexit, Statement **sfinally);
    int hasBreak();
    int hasContinue();
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct ForeachStatement : Statement
{
    enum TOK op;	// TOKforeach or TOKforeach_reverse
    Arguments *arguments;	// array of Argument*'s
    Expression *aggr;
    Statement *body;

    VarDeclaration *key;
    VarDeclaration *value;

    FuncDeclaration *func;	// function we're lexically in

    Array cases;	// put breaks, continues, gotos and returns here
    Array gotos;	// forward referenced goto's go here

    ForeachStatement(Loc loc, enum TOK op, Arguments *arguments, Expression *aggr, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct IfStatement : Statement
{
    Argument *arg;
    Expression *condition;
    Statement *ifbody;
    Statement *elsebody;

    VarDeclaration *match;	// for MatchExpression results

    IfStatement(Loc loc, Argument *arg, Expression *condition, Statement *ifbody, Statement *elsebody);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int usesEH();
    int fallOffEnd();
    IfStatement *isIfStatement() { return this; }

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
    Statements *flatten(Scope *sc);
    int usesEH();

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct PragmaStatement : Statement
{
    Identifier *ident;
    Expressions *args;		// array of Expression's
    Statement *body;

    PragmaStatement(Loc loc, Identifier *ident, Expressions *args, Statement *body);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int usesEH();
    int fallOffEnd();

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct StaticAssertStatement : Statement
{
    StaticAssert *sa;

    StaticAssertStatement(StaticAssert *sa);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct SwitchStatement : Statement
{
    Expression *condition;
    Statement *body;
    DefaultStatement *sdefault;

    Array gotoCases;		// array of unresolved GotoCaseStatement's
    Array *cases;		// array of CaseStatement's
    int hasNoDefault;		// !=0 if no default statement

    SwitchStatement(Loc loc, Expression *c, Statement *b);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int hasBreak();
    int usesEH();
    int fallOffEnd();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct CaseStatement : Statement
{
    Expression *exp;
    Statement *statement;
    int index;		// which case it is (since we sort this)
    block *cblock;	// back end: label for the block

    CaseStatement(Loc loc, Expression *exp, Statement *s);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int compare(Object *obj);
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct DefaultStatement : Statement
{
    Statement *statement;
#if IN_GCC
    block *cblock;	// back end: label for the block
#endif

    DefaultStatement(Loc loc, Statement *s);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct GotoDefaultStatement : Statement
{
    SwitchStatement *sw;

    GotoDefaultStatement(Loc loc);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toIR(IRState *irs);
};

struct GotoCaseStatement : Statement
{
    Expression *exp;		// NULL, or which case to goto
    CaseStatement *cs;		// case statement it resolves to

    GotoCaseStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toIR(IRState *irs);
};

struct SwitchErrorStatement : Statement
{
    SwitchErrorStatement(Loc loc);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toIR(IRState *irs);
};

struct ReturnStatement : Statement
{
    Expression *exp;

    ReturnStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
    int fallOffEnd();
    Expression *interpret(InterState *istate);

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
    Expression *interpret(InterState *istate);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toIR(IRState *irs);
};

struct ContinueStatement : Statement
{
    Identifier *ident;

    ContinueStatement(Loc loc, Identifier *ident);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int usesEH();
    int fallOffEnd();

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
    int fallOffEnd();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    TryCatchStatement *isTryCatchStatement() { return this; }
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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct TryFinallyStatement : Statement
{
    Statement *body;
    Statement *finalbody;

    TryFinallyStatement(Loc loc, Statement *body, Statement *finalbody);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
    int hasBreak();
    int hasContinue();
    int usesEH();
    int fallOffEnd();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct OnScopeStatement : Statement
{
    TOK tok;
    Statement *statement;

    OnScopeStatement(Loc loc, TOK tok, Statement *statement);
    Statement *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Statement *semantic(Scope *sc);
    int usesEH();
    void scopeCode(Statement **sentry, Statement **sexit, Statement **sfinally);

    void toIR(IRState *irs);
};

struct ThrowStatement : Statement
{
    Expression *exp;

    ThrowStatement(Loc loc, Expression *exp);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int fallOffEnd();

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct VolatileStatement : Statement
{
    Statement *statement;

    VolatileStatement(Loc loc, Statement *statement);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Statements *flatten(Scope *sc);
    int fallOffEnd();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct GotoStatement : Statement
{
    Identifier *ident;
    LabelDsymbol *label;
    TryFinallyStatement *tf;

    GotoStatement(Loc loc, Identifier *ident);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    int fallOffEnd();
    Expression *interpret(InterState *istate);

    void toIR(IRState *irs);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    GotoStatement *isGotoStatement() { return this; }
};

struct LabelStatement : Statement
{
    Identifier *ident;
    Statement *statement;
    TryFinallyStatement *tf;
    block *lblock;		// back end
    int isReturnLabel;

    LabelStatement(Loc loc, Identifier *ident, Statement *statement);
    Statement *syntaxCopy();
    Statement *semantic(Scope *sc);
    Statements *flatten(Scope *sc);
    int usesEH();
    int fallOffEnd();
    int comeFrom();
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Statement *inlineScan(InlineScanState *iss);

    void toIR(IRState *irs);
};

struct LabelDsymbol : Dsymbol
{
    LabelStatement *statement;
#if IN_GCC
    unsigned asmLabelNum;       // GCC-specific
#endif

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
    int comeFrom();

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual AsmStatement *isAsmStatement() { return this; }

    void toIR(IRState *irs);
};

#endif /* DMD_STATEMENT_H */
