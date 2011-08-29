
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_PARSE_H
#define DMD_PARSE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "arraytypes.h"
#include "lexer.h"
#include "enum.h"

struct Type;
struct TypeQualified;
struct Expression;
struct Declaration;
struct Statement;
struct Import;
struct Initializer;
struct FuncDeclaration;
struct CtorDeclaration;
struct PostBlitDeclaration;
struct DtorDeclaration;
struct StaticCtorDeclaration;
struct StaticDtorDeclaration;
struct SharedStaticCtorDeclaration;
struct SharedStaticDtorDeclaration;
struct ConditionalDeclaration;
struct InvariantDeclaration;
struct UnitTestDeclaration;
struct NewDeclaration;
struct DeleteDeclaration;
struct Condition;
struct Module;
struct ModuleDeclaration;
struct TemplateDeclaration;
struct TemplateInstance;
struct StaticAssert;

/************************************
 * These control how parseStatement() works.
 */

enum ParseStatementFlags
{
    PSsemi = 1,         // empty ';' statements are allowed
    PSscope = 2,        // start a new scope
    PScurly = 4,        // { } statement is required
    PScurlyscope = 8,   // { } starts a new scope
};


struct Parser : Lexer
{
    ModuleDeclaration *md;
    enum LINK linkage;
    Loc endloc;                 // set to location of last right curly
    int inBrackets;             // inside [] of array index or slice
    Loc lookingForElse;         // location of lonely if looking for an else

    Parser(Module *module, unsigned char *base, unsigned length, int doDocComment);

    Dsymbols *parseModule();
    Dsymbols *parseDeclDefs(int once);
    Dsymbols *parseAutoDeclarations(StorageClass storageClass, unsigned char *comment);
    Dsymbols *parseBlock();
    void composeStorageClass(StorageClass stc);
    StorageClass parseAttribute();
    StorageClass parsePostfix();
    Expression *parseConstraint();
    TemplateDeclaration *parseTemplateDeclaration(int ismixin);
    TemplateParameters *parseTemplateParameterList(int flag = 0);
    Dsymbol *parseMixin();
    Objects *parseTemplateArgumentList();
    Objects *parseTemplateArgumentList2();
    Objects *parseTemplateArgument();
    StaticAssert *parseStaticAssert();
    TypeQualified *parseTypeof();
    enum LINK parseLinkage();
    Condition *parseDebugCondition();
    Condition *parseVersionCondition();
    Condition *parseStaticIfCondition();
    Dsymbol *parseCtor();
    PostBlitDeclaration *parsePostBlit();
    DtorDeclaration *parseDtor();
    StaticCtorDeclaration *parseStaticCtor();
    StaticDtorDeclaration *parseStaticDtor();
    SharedStaticCtorDeclaration *parseSharedStaticCtor();
    SharedStaticDtorDeclaration *parseSharedStaticDtor();
    InvariantDeclaration *parseInvariant();
    UnitTestDeclaration *parseUnitTest();
    NewDeclaration *parseNew();
    DeleteDeclaration *parseDelete();
    Parameters *parseParameters(int *pvarargs);
    EnumDeclaration *parseEnum();
    Dsymbol *parseAggregate();
    BaseClasses *parseBaseClasses();
    Import *parseImport(Dsymbols *decldefs, int isstatic);
    Type *parseType(Identifier **pident = NULL, TemplateParameters **tpl = NULL);
    Type *parseBasicType();
    Type *parseBasicType2(Type *t);
    Type *parseDeclarator(Type *t, Identifier **pident, TemplateParameters **tpl = NULL, StorageClass storage_class = 0);
    Dsymbols *parseDeclarations(StorageClass storage_class, unsigned char *comment);
    void parseContracts(FuncDeclaration *f);
    void checkDanglingElse(Loc elseloc);
    Statement *parseStatement(int flags);
    Initializer *parseInitializer();
    Expression *parseDefaultInitExp();
    void check(Loc loc, enum TOK value);
    void check(enum TOK value);
    void check(enum TOK value, const char *string);
    void checkParens(enum TOK value, Expression *e);
    int isDeclaration(Token *t, int needId, enum TOK endtok, Token **pt);
    int isBasicType(Token **pt);
    int isDeclarator(Token **pt, int *haveId, enum TOK endtok);
    int isParameters(Token **pt);
    int isExpression(Token **pt);
    int isTemplateInstance(Token *t, Token **pt);
    int skipParens(Token *t, Token **pt);
    int skipAttributes(Token *t, Token **pt);

    Expression *parseExpression();
    Expression *parsePrimaryExp();
    Expression *parseUnaryExp();
    Expression *parsePostExp(Expression *e);
    Expression *parseMulExp();
    Expression *parseAddExp();
    Expression *parseShiftExp();
#if DMDV1
    Expression *parseRelExp();
    Expression *parseEqualExp();
#endif
    Expression *parseCmpExp();
    Expression *parseAndExp();
    Expression *parseXorExp();
    Expression *parseOrExp();
    Expression *parseAndAndExp();
    Expression *parseOrOrExp();
    Expression *parseCondExp();
    Expression *parseAssignExp();

    Expressions *parseArguments();

    Expression *parseNewExp(Expression *thisexp);

    void addComment(Dsymbol *s, unsigned char *blockComment);
};

// Operator precedence - greater values are higher precedence

enum PREC
{
    PREC_zero,
    PREC_expr,
    PREC_assign,
    PREC_cond,
    PREC_oror,
    PREC_andand,
    PREC_or,
    PREC_xor,
    PREC_and,
    PREC_equal,
    PREC_rel,
    PREC_shift,
    PREC_add,
    PREC_mul,
    PREC_pow,
    PREC_unary,
    PREC_primary,
};

extern enum PREC precedence[TOKMAX];

void initPrecedence();

#endif /* DMD_PARSE_H */
