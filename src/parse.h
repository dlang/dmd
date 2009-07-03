
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
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
    PSsemi = 1,		// empty ';' statements are allowed
    PSscope = 2,	// start a new scope
    PScurly = 4,	// { } statement is required
    PScurlyscope = 8,	// { } starts a new scope
};


struct Parser : Lexer
{
    ModuleDeclaration *md;
    enum LINK linkage;
    Loc endloc;			// set to location of last right curly
    int inBrackets;		// inside [] of array index or slice

    Parser(Module *module, unsigned char *base, unsigned length, int doDocComment);

    Array *parseModule();
    Array *parseDeclDefs(int once);
    Array *parseAutoDeclarations(unsigned storageClass, unsigned char *comment);
    Array *parseBlock();
    Expression *parseConstraint();
    TemplateDeclaration *parseTemplateDeclaration();
    TemplateParameters *parseTemplateParameterList(int flag = 0);
    Dsymbol *parseMixin();
    Objects *parseTemplateArgumentList();
    Objects *parseTemplateArgumentList2();
    StaticAssert *parseStaticAssert();
    TypeQualified *parseTypeof();
    enum LINK parseLinkage();
    Condition *parseDebugCondition();
    Condition *parseVersionCondition();
    Condition *parseStaticIfCondition();
    FuncDeclaration *parseCtor();
    PostBlitDeclaration *parsePostBlit();
    DtorDeclaration *parseDtor();
    StaticCtorDeclaration *parseStaticCtor();
    StaticDtorDeclaration *parseStaticDtor();
    InvariantDeclaration *parseInvariant();
    UnitTestDeclaration *parseUnitTest();
    NewDeclaration *parseNew();
    DeleteDeclaration *parseDelete();
    Arguments *parseParameters(int *pvarargs);
    EnumDeclaration *parseEnum();
    Dsymbol *parseAggregate();
    BaseClasses *parseBaseClasses();
    Import *parseImport(Array *decldefs, int isstatic);
    Type *parseType(Identifier **pident = NULL, TemplateParameters **tpl = NULL);
    Type *parseBasicType();
    Type *parseBasicType2(Type *t);
    Type *parseDeclarator(Type *t, Identifier **pident, TemplateParameters **tpl = NULL);
    Array *parseDeclarations(unsigned storage_class);
    void parseContracts(FuncDeclaration *f);
    Statement *parseStatement(int flags);
    Initializer *parseInitializer();
    Expression *parseDefaultInitExp();
    void check(Loc loc, enum TOK value);
    void check(enum TOK value);
    void check(enum TOK value, char *string);
    int isDeclaration(Token *t, int needId, enum TOK endtok, Token **pt);
    int isBasicType(Token **pt);
    int isDeclarator(Token **pt, int *haveId, enum TOK endtok);
    int isParameters(Token **pt);
    int isExpression(Token **pt);
    int isTemplateInstance(Token *t, Token **pt);
    int skipParens(Token *t, Token **pt);

    Expression *parseExpression();
    Expression *parsePrimaryExp();
    Expression *parseUnaryExp();
    Expression *parsePostExp(Expression *e);
    Expression *parseMulExp();
    Expression *parseAddExp();
    Expression *parseShiftExp();
    Expression *parseRelExp();
    Expression *parseEqualExp();
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

#endif /* DMD_PARSE_H */
