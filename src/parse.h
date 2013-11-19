
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

class Type;
class TypeQualified;
class Expression;
class Declaration;
class Statement;
class Import;
class Initializer;
class FuncDeclaration;
class CtorDeclaration;
class PostBlitDeclaration;
class DtorDeclaration;
class StaticCtorDeclaration;
class StaticDtorDeclaration;
class SharedStaticCtorDeclaration;
class SharedStaticDtorDeclaration;
class ConditionalDeclaration;
class InvariantDeclaration;
class UnitTestDeclaration;
class NewDeclaration;
class DeleteDeclaration;
class Condition;
class Module;
struct ModuleDeclaration;
class TemplateDeclaration;
class TemplateInstance;
class StaticAssert;

/************************************
 * These control how parseStatement() works.
 */

enum ParseStatementFlags
{
    PSsemi = 1,         // empty ';' statements are allowed, but deprecated
    PSscope = 2,        // start a new scope
    PScurly = 4,        // { } statement is required
    PScurlyscope = 8,   // { } starts a new scope
    PSsemi_ok = 0x10,   // empty ';' are really ok
};


class Parser : public Lexer
{
public:
    ModuleDeclaration *md;
    LINK linkage;
    Loc endloc;                 // set to location of last right curly
    int inBrackets;             // inside [] of array index or slice
    Loc lookingForElse;         // location of lonely if looking for an else

    Parser(Loc loc, Module *module, const utf8_t *base, size_t length, int doDocComment);
    Parser(Module *module, const utf8_t *base, size_t length, int doDocComment);

    Dsymbols *parseModule();
    Dsymbols *parseDeclDefs(int once, Dsymbol **pLastDecl = NULL);
    Dsymbols *parseAutoDeclarations(StorageClass storageClass, const utf8_t *comment);
    Dsymbols *parseBlock(Dsymbol **pLastDecl);
    void composeStorageClass(StorageClass stc);
    StorageClass parseAttribute(Expressions **pexps);
    StorageClass parsePostfix();
    StorageClass parseTypeCtor();
    Expression *parseConstraint();
    TemplateDeclaration *parseTemplateDeclaration(bool ismixin = false);
    TemplateParameters *parseTemplateParameterList(int flag = 0);
    Dsymbol *parseMixin();
    Objects *parseTemplateArgumentList();
    Objects *parseTemplateArgumentList2();
    Objects *parseTemplateArgument();
    StaticAssert *parseStaticAssert();
    TypeQualified *parseTypeof();
    Type *parseVector();
    LINK parseLinkage();
    Condition *parseDebugCondition();
    Condition *parseVersionCondition();
    Condition *parseStaticIfCondition();
    Dsymbol *parseCtor();
    DtorDeclaration *parseDtor();
    StaticCtorDeclaration *parseStaticCtor();
    StaticDtorDeclaration *parseStaticDtor();
    SharedStaticCtorDeclaration *parseSharedStaticCtor();
    SharedStaticDtorDeclaration *parseSharedStaticDtor();
    InvariantDeclaration *parseInvariant();
    UnitTestDeclaration *parseUnitTest();
    NewDeclaration *parseNew();
    DeleteDeclaration *parseDelete();
    Parameters *parseParameters(int *pvarargs, TemplateParameters **tpl = NULL);
    EnumDeclaration *parseEnum();
    Dsymbol *parseAggregate();
    BaseClasses *parseBaseClasses();
    Import *parseImport(Dsymbols *decldefs, int isstatic);
    Type *parseType(Identifier **pident = NULL, TemplateParameters **tpl = NULL);
    Type *parseBasicType();
    Type *parseBasicType2(Type *t);
    Type *parseDeclarator(Type *t, Identifier **pident, TemplateParameters **tpl = NULL, StorageClass storage_class = 0, int* pdisable = NULL);
    Dsymbols *parseDeclarations(StorageClass storage_class, const utf8_t *comment);
    void parseContracts(FuncDeclaration *f);
    void checkDanglingElse(Loc elseloc);
    /** endPtr used for documented unittests */
    Statement *parseStatement(int flags, const utf8_t** endPtr = NULL);
    Initializer *parseInitializer();
    Expression *parseDefaultInitExp();
    void check(Loc loc, TOK value);
    void check(TOK value);
    void check(TOK value, const char *string);
    void checkParens(TOK value, Expression *e);
    int isDeclaration(Token *t, int needId, TOK endtok, Token **pt);
    int isBasicType(Token **pt);
    int isDeclarator(Token **pt, int *haveId, int *haveTpl, TOK endtok);
    int isParameters(Token **pt);
    int isExpression(Token **pt);
    int skipParens(Token *t, Token **pt);
    int skipAttributes(Token *t, Token **pt);

    Expression *parseExpression();
    Expression *parsePrimaryExp();
    Expression *parseUnaryExp();
    Expression *parsePostExp(Expression *e);
    Expression *parseMulExp();
    Expression *parseAddExp();
    Expression *parseShiftExp();
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

    void addComment(Dsymbol *s, const utf8_t *blockComment);
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

extern PREC precedence[TOKMAX];

void initPrecedence();

#endif /* DMD_PARSE_H */
