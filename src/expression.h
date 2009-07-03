
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_EXPRESSION_H
#define DMD_EXPRESSION_H

#include "mars.h"
#include "identifier.h"
#include "lexer.h"
#include "arraytypes.h"

struct Type;
struct Scope;
struct TupleDeclaration;
struct VarDeclaration;
struct FuncDeclaration;
struct FuncLiteralDeclaration;
struct Declaration;
struct CtorDeclaration;
struct NewDeclaration;
struct Dsymbol;
struct Import;
struct Module;
struct ScopeDsymbol;
struct InlineCostState;
struct InlineDoState;
struct InlineScanState;
struct Expression;
struct Declaration;
struct AggregateDeclaration;
struct StructDeclaration;
struct TemplateInstance;
struct TemplateDeclaration;
struct ClassDeclaration;
struct HdrGenState;
struct BinExp;
struct InterState;
struct Symbol;		// back end symbol

enum TOK;

// Back end
struct IRState;
struct dt_t;

#ifdef IN_GCC
union tree_node; typedef union tree_node elem;
#else
struct elem;
#endif

void initPrecedence();

Expression *resolveProperties(Scope *sc, Expression *e);
void accessCheck(Loc loc, Scope *sc, Expression *e, Declaration *d);
Dsymbol *search_function(AggregateDeclaration *ad, Identifier *funcid);
void inferApplyArgTypes(enum TOK op, Arguments *arguments, Expression *aggr);
void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);
void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);
void expandTuples(Expressions *exps);
FuncDeclaration *hasThis(Scope *sc);
Expression *fromConstInitializer(int result, Expression *e);

struct Expression : Object
{
    Loc loc;			// file location
    enum TOK op;		// handy to minimize use of dynamic_cast
    Type *type;			// !=NULL means that semantic() has been run
    int size;			// # of bytes in Expression so we can copy() it

    Expression(Loc loc, enum TOK op, int size);
    Expression *copy();
    virtual Expression *syntaxCopy();
    virtual Expression *semantic(Scope *sc);

    int dyncast() { return DYNCAST_EXPRESSION; }	// kludge for template.isExpression()

    void print();
    char *toChars();
    virtual void dump(int indent);
    void error(const char *format, ...);
    virtual void rvalue();

    static Expression *combine(Expression *e1, Expression *e2);
    static Expressions *arraySyntaxCopy(Expressions *exps);

    virtual integer_t toInteger();
    virtual uinteger_t toUInteger();
    virtual real_t toReal();
    virtual real_t toImaginary();
    virtual complex_t toComplex();
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual void toMangleBuffer(OutBuffer *buf);
    virtual Expression *toLvalue(Scope *sc, Expression *e);
    virtual Expression *modifiableLvalue(Scope *sc, Expression *e);
    Expression *implicitCastTo(Scope *sc, Type *t);
    virtual MATCH implicitConvTo(Type *t);
    virtual Expression *castTo(Scope *sc, Type *t);
    virtual void checkEscape();
    void checkScalar();
    void checkNoBool();
    Expression *checkIntegral();
    Expression *checkArithmetic();
    void checkDeprecated(Scope *sc, Dsymbol *s);
    virtual Expression *checkToBoolean();
    Expression *checkToPointer();
    Expression *addressOf(Scope *sc);
    Expression *deref();
    Expression *integralPromotions(Scope *sc);

    Expression *toDelegate(Scope *sc, Type *t);
    virtual void scanForNestedRef(Scope *sc);

    virtual Expression *optimize(int result);
    #define WANTflags	1
    #define WANTvalue	2
    #define WANTinterpret 4

    virtual Expression *interpret(InterState *istate);

    virtual int isConst();
    virtual int isBool(int result);
    virtual int isBit();
    virtual int checkSideEffect(int flag);

    virtual int inlineCost(InlineCostState *ics);
    virtual Expression *doInline(InlineDoState *ids);
    virtual Expression *inlineScan(InlineScanState *iss);

    // For operator overloading
    virtual int isCommutative();
    virtual Identifier *opId();
    virtual Identifier *opId_r();

    // Back end
    virtual elem *toElem(IRState *irs);
    virtual dt_t **toDt(dt_t **pdt);
};

struct IntegerExp : Expression
{
    integer_t value;

    IntegerExp(Loc loc, integer_t value, Type *type);
    IntegerExp(integer_t value);
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    char *toChars();
    void dump(int indent);
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    int isConst();
    int isBool(int result);
    MATCH implicitConvTo(Type *t);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    Expression *toLvalue(Scope *sc, Expression *e);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct RealExp : Expression
{
    real_t value;

    RealExp(Loc loc, real_t value, Type *type);
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    char *toChars();
    integer_t toInteger();
    uinteger_t toUInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    Expression *castTo(Scope *sc, Type *t);
    int isConst();
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct ComplexExp : Expression
{
    complex_t value;

    ComplexExp(Loc loc, complex_t value, Type *type);
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    char *toChars();
    integer_t toInteger();
    uinteger_t toUInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    Expression *castTo(Scope *sc, Type *t);
    int isConst();
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
#ifdef _DH
    OutBuffer hexp;
#endif
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct IdentifierExp : Expression
{
    Identifier *ident;
    Declaration *var;

    IdentifierExp(Loc loc, Identifier *ident);
    IdentifierExp(Loc loc, Declaration *var);
    Expression *semantic(Scope *sc);
    char *toChars();
    void dump(int indent);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *toLvalue(Scope *sc, Expression *e);
};

struct DollarExp : IdentifierExp
{
    DollarExp(Loc loc);
};

struct DsymbolExp : Expression
{
    Dsymbol *s;

    DsymbolExp(Loc loc, Dsymbol *s);
    Expression *semantic(Scope *sc);
    char *toChars();
    void dump(int indent);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *toLvalue(Scope *sc, Expression *e);
};

struct ThisExp : Expression
{
    Declaration *var;

    ThisExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *toLvalue(Scope *sc, Expression *e);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};

struct SuperExp : ThisExp
{
    SuperExp(Loc loc);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

struct NullExp : Expression
{
    unsigned char committed;	// !=0 if type is committed

    NullExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    Expression *interpret(InterState *istate);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct StringExp : Expression
{
    void *string;	// char, wchar, or dchar data
    size_t len;		// number of chars, wchars, or dchars
    unsigned char sz;	// 1: char, 2: wchar, 4: dchar
    unsigned char committed;	// !=0 if type is committed
    unsigned char postfix;	// 'c', 'w', 'd'

    StringExp(Loc loc, char *s);
    StringExp(Loc loc, void *s, size_t len);
    StringExp(Loc loc, void *s, size_t len, unsigned char postfix);
    //Expression *syntaxCopy();
    int equals(Object *o);
    char *toChars();
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    StringExp *toUTF8(Scope *sc);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    int compare(Object *obj);
    int isBool(int result);
    unsigned charAt(size_t i);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

// Tuple

struct TupleExp : Expression
{
    Expressions *exps;

    TupleExp(Loc loc, Expressions *exps);
    TupleExp(Loc loc, TupleDeclaration *tup);
    Expression *syntaxCopy();
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void scanForNestedRef(Scope *sc);
    void checkEscape();
    int checkSideEffect(int flag);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    Expression *castTo(Scope *sc, Type *t);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct ArrayLiteralExp : Expression
{
    Expressions *elements;

    ArrayLiteralExp(Loc loc, Expressions *elements);
    ArrayLiteralExp(Loc loc, Expression *e);

    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    int isBool(int result);
    elem *toElem(IRState *irs);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    void scanForNestedRef(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    dt_t **toDt(dt_t **pdt);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct AssocArrayLiteralExp : Expression
{
    Expressions *keys;
    Expressions *values;

    AssocArrayLiteralExp(Loc loc, Expressions *keys, Expressions *values);

    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    int isBool(int result);
    elem *toElem(IRState *irs);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    void scanForNestedRef(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct StructLiteralExp : Expression
{
    StructDeclaration *sd;		// which aggregate this is for
    Expressions *elements;	// parallels sd->fields[] with
				// NULL entries for fields to skip

    Symbol *sym;		// back end symbol to initialize with literal
    size_t soffset;		// offset from start of s
    int fillHoles;		// fill alignment 'holes' with zero

    StructLiteralExp(Loc loc, StructDeclaration *sd, Expressions *elements);

    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *getField(Type *type, unsigned offset);
    int getFieldIndex(Type *type, unsigned offset);
    elem *toElem(IRState *irs);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    void scanForNestedRef(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    dt_t **toDt(dt_t **pdt);
    Expression *toLvalue(Scope *sc, Expression *e);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct TypeDotIdExp : Expression
{
    Identifier *ident;

    TypeDotIdExp(Loc loc, Type *type, Identifier *ident);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
};

struct TypeExp : Expression
{
    TypeExp(Loc loc, Type *type);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    elem *toElem(IRState *irs);
};

struct ScopeExp : Expression
{
    ScopeDsymbol *sds;

    ScopeExp(Loc loc, ScopeDsymbol *sds);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct TemplateExp : Expression
{
    TemplateDeclaration *td;

    TemplateExp(Loc loc, TemplateDeclaration *td);
    void rvalue();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct NewExp : Expression
{
    /* thisexp.new(newargs) newtype(arguments)
     */
    Expression *thisexp;	// if !NULL, 'this' for class being allocated
    Expressions *newargs;	// Array of Expression's to call new operator
    Type *newtype;
    Expressions *arguments;	// Array of Expression's

    CtorDeclaration *member;	// constructor function
    NewDeclaration *allocator;	// allocator function
    int onstack;		// allocate on stack

    NewExp(Loc loc, Expression *thisexp, Expressions *newargs,
	Type *newtype, Expressions *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void scanForNestedRef(Scope *sc);

    //int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

struct NewAnonClassExp : Expression
{
    /* thisexp.new(newargs) class baseclasses { } (arguments)
     */
    Expression *thisexp;	// if !NULL, 'this' for class being allocated
    Expressions *newargs;	// Array of Expression's to call new operator
    ClassDeclaration *cd;	// class being instantiated
    Expressions *arguments;	// Array of Expression's to call class constructor

    NewAnonClassExp(Loc loc, Expression *thisexp, Expressions *newargs,
	ClassDeclaration *cd, Expressions *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

// Offset from symbol

struct SymOffExp : Expression
{
    Declaration *var;
    unsigned offset;

    SymOffExp(Loc loc, Declaration *var, unsigned offset);
    Expression *semantic(Scope *sc);
    void checkEscape();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int isConst();
    int isBool(int result);
    Expression *doInline(InlineDoState *ids);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    void scanForNestedRef(Scope *sc);

    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

// Variable

struct VarExp : Expression
{
    Declaration *var;

    VarExp(Loc loc, Declaration *var);
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    void dump(int indent);
    char *toChars();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void checkEscape();
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

// Function/Delegate literal

struct FuncExp : Expression
{
    FuncLiteralDeclaration *fd;

    FuncExp(Loc loc, FuncLiteralDeclaration *fd);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void scanForNestedRef(Scope *sc);
    char *toChars();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    //Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

// Declaration of a symbol

struct DeclarationExp : Expression
{
    Dsymbol *declaration;

    DeclarationExp(Loc loc, Dsymbol *declaration);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct TypeidExp : Expression
{
    Type *typeidType;

    TypeidExp(Loc loc, Type *typeidType);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct HaltExp : Expression
{
    HaltExp(Loc loc);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int checkSideEffect(int flag);

    elem *toElem(IRState *irs);
};

struct IsExp : Expression
{
    /* is(targ id tok tspec)
     * is(targ id == tok2)
     */
    Type *targ;
    Identifier *id;	// can be NULL
    enum TOK tok;	// ':' or '=='
    Type *tspec;	// can be NULL
    enum TOK tok2;	// 'struct', 'union', 'typedef', etc.

    IsExp(Loc loc, Type *targ, Identifier *id, enum TOK tok, Type *tspec, enum TOK tok2);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

/****************************************************************/

struct UnaExp : Expression
{
    Expression *e1;

    UnaExp(Loc loc, enum TOK op, int size, Expression *e1);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    void dump(int indent);
    void scanForNestedRef(Scope *sc);
    Expression *interpretCommon(InterState *istate, Expression *(*fp)(Type *, Expression *));

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    Expression *op_overload(Scope *sc);	// doesn't need to be virtual
};

struct BinExp : Expression
{
    Expression *e1;
    Expression *e2;

    BinExp(Loc loc, enum TOK op, int size, Expression *e1, Expression *e2);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *semanticp(Scope *sc);
    Expression *commonSemanticAssign(Scope *sc);
    Expression *commonSemanticAssignIntegral(Scope *sc);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *scaleFactor(Scope *sc);
    Expression *typeCombine(Scope *sc);
    Expression *optimize(int result);
    int isunsigned();
    void incompatibleTypes();
    void dump(int indent);
    void scanForNestedRef(Scope *sc);
    Expression *interpretCommon(InterState *istate, Expression *(*fp)(Type *, Expression *, Expression *));
    Expression *interpretCommon2(InterState *istate, Expression *(*fp)(TOK, Type *, Expression *, Expression *));
    Expression *interpretAssignCommon(InterState *istate, Expression *(*fp)(Type *, Expression *, Expression *), int post = 0);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    Expression *op_overload(Scope *sc);

    elem *toElemBin(IRState *irs, int op);
};

struct BinAssignExp : BinExp
{
    BinAssignExp(Loc loc, enum TOK op, int size, Expression *e1, Expression *e2);
    int checkSideEffect(int flag);
};

/****************************************************************/

struct CompileExp : UnaExp
{
    CompileExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct FileExp : UnaExp
{
    FileExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct AssertExp : UnaExp
{
    Expression *msg;

    AssertExp(Loc loc, Expression *e, Expression *msg = NULL);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};

struct DotIdExp : UnaExp
{
    Identifier *ident;

    DotIdExp(Loc loc, Expression *e, Identifier *ident);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void dump(int i);
};

struct DotTemplateExp : UnaExp
{
    TemplateDeclaration *td;
    
    DotTemplateExp(Loc loc, Expression *e, TemplateDeclaration *td);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct DotVarExp : UnaExp
{
    Declaration *var;

    DotVarExp(Loc loc, Expression *e, Declaration *var);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void dump(int indent);
    elem *toElem(IRState *irs);
};

struct DotTemplateInstanceExp : UnaExp
{
    TemplateInstance *ti;

    DotTemplateInstanceExp(Loc loc, Expression *e, TemplateInstance *ti);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void dump(int indent);
};

struct DelegateExp : UnaExp
{
    FuncDeclaration *func;

    DelegateExp(Loc loc, Expression *e, FuncDeclaration *func);
    Expression *semantic(Scope *sc);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void dump(int indent);

    int inlineCost(InlineCostState *ics);
    elem *toElem(IRState *irs);
};

struct DotTypeExp : UnaExp
{
    Dsymbol *sym;		// symbol that represents a type

    DotTypeExp(Loc loc, Expression *e, Dsymbol *sym);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
};

struct CallExp : UnaExp
{
    Expressions *arguments;	// function arguments

    CallExp(Loc loc, Expression *e, Expressions *exps);
    CallExp(Loc loc, Expression *e);
    CallExp(Loc loc, Expression *e, Expression *earg1);
    CallExp(Loc loc, Expression *e, Expression *earg1, Expression *earg2);

    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void dump(int indent);
    elem *toElem(IRState *irs);
    void scanForNestedRef(Scope *sc);
    Expression *toLvalue(Scope *sc, Expression *e);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct AddrExp : UnaExp
{
    AddrExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    Expression *optimize(int result);
};

struct PtrExp : UnaExp
{
    PtrExp(Loc loc, Expression *e);
    PtrExp(Loc loc, Expression *e, Type *t);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
};

struct NegExp : UnaExp
{
    NegExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct UAddExp : UnaExp
{
    UAddExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();
};

struct ComExp : UnaExp
{
    ComExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct NotExp : UnaExp
{
    NotExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int isBit();
    elem *toElem(IRState *irs);
};

struct BoolExp : UnaExp
{
    BoolExp(Loc loc, Expression *e, Type *type);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int isBit();
    elem *toElem(IRState *irs);
};

struct DeleteExp : UnaExp
{
    DeleteExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
};

struct CastExp : UnaExp
{
    // Possible to cast to one type while painting to another type
    Type *to;			// type to cast to

    CastExp(Loc loc, Expression *e, Type *t);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    void checkEscape();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);

    // For operator overloading
    Identifier *opId();
};


struct SliceExp : UnaExp
{
    Expression *upr;		// NULL if implicit 0
    Expression *lwr;		// NULL if implicit [length - 1]
    VarDeclaration *lengthVar;

    SliceExp(Loc loc, Expression *e1, Expression *lwr, Expression *upr);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void checkEscape();
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    void dump(int indent);
    elem *toElem(IRState *irs);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct ArrayLengthExp : UnaExp
{
    ArrayLengthExp(Loc loc, Expression *e1);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
};

// e1[a0,a1,a2,a3,...]

struct ArrayExp : UnaExp
{
    Expressions *arguments;		// Array of Expression's

    ArrayExp(Loc loc, Expression *e1, Expressions *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void scanForNestedRef(Scope *sc);

    // For operator overloading
    Identifier *opId();

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

/****************************************************************/

struct DotExp : BinExp
{
    DotExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
};

struct CommaExp : BinExp
{
    CommaExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    void checkEscape();
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    int isBool(int result);
    int checkSideEffect(int flag);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    elem *toElem(IRState *irs);
};

struct IndexExp : BinExp
{
    VarDeclaration *lengthVar;
    int modifiable;

    IndexExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    Expression *doInline(InlineDoState *ids);
    void scanForNestedRef(Scope *sc);

    elem *toElem(IRState *irs);
};

/* For both i++ and i--
 */
struct PostExp : BinExp
{
    PostExp(enum TOK op, Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *interpret(InterState *istate);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

struct AssignExp : BinExp
{   int ismemset;	// !=0 if setting the contents of an array

    AssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    Expression *interpret(InterState *istate);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

#define ASSIGNEXP(op)	\
struct op##AssignExp : BinExp					\
{								\
    op##AssignExp(Loc loc, Expression *e1, Expression *e2);	\
    Expression *semantic(Scope *sc);				\
    Expression *interpret(InterState *istate);			\
								\
    Identifier *opId();    /* For operator overloading */	\
								\
    elem *toElem(IRState *irs);					\
};

ASSIGNEXP(Add)
ASSIGNEXP(Min)
ASSIGNEXP(Cat)
ASSIGNEXP(Mul)
ASSIGNEXP(Div)
ASSIGNEXP(Mod)
ASSIGNEXP(Shl)
ASSIGNEXP(Shr)
ASSIGNEXP(Ushr)
ASSIGNEXP(And)
ASSIGNEXP(Or)
ASSIGNEXP(Xor)

#undef ASSIGNEXP

struct AddExp : BinExp
{
    AddExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    int isCommutative();
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct MinExp : BinExp
{
    MinExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct CatExp : BinExp
{
    CatExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct MulExp : BinExp
{
    MulExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    int isCommutative();
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct DivExp : BinExp
{
    DivExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ModExp : BinExp
{
    ModExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ShlExp : BinExp
{
    ShlExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ShrExp : BinExp
{
    ShrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct UshrExp : BinExp
{
    UshrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct AndExp : BinExp
{
    AndExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    int isCommutative();
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct OrExp : BinExp
{
    OrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    int isCommutative();
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct XorExp : BinExp
{
    XorExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);

    // For operator overloading
    int isCommutative();
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct OrOrExp : BinExp
{
    OrOrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    int isBit();
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    elem *toElem(IRState *irs);
};

struct AndAndExp : BinExp
{
    AndAndExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    int isBit();
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int checkSideEffect(int flag);
    elem *toElem(IRState *irs);
};

struct CmpExp : BinExp
{
    CmpExp(enum TOK op, Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int isBit();

    // For operator overloading
    int isCommutative();
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct InExp : BinExp
{
    InExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    int isBit();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct RemoveExp : BinExp
{
    RemoveExp(Loc loc, Expression *e1, Expression *e2);
    elem *toElem(IRState *irs);
};

// == and !=

struct EqualExp : BinExp
{
    EqualExp(enum TOK op, Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    int isBit();

    // For operator overloading
    int isCommutative();
    Identifier *opId();

    elem *toElem(IRState *irs);
};

// === and !===

struct IdentityExp : BinExp
{
    IdentityExp(enum TOK op, Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    int isBit();
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    elem *toElem(IRState *irs);
};

/****************************************************************/

struct CondExp : BinExp
{
    Expression *econd;

    CondExp(Loc loc, Expression *econd, Expression *e1, Expression *e2);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
    Expression *interpret(InterState *istate);
    void checkEscape();
    Expression *toLvalue(Scope *sc, Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    Expression *checkToBoolean();
    int checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    MATCH implicitConvTo(Type *t);
    Expression *castTo(Scope *sc, Type *t);
    void scanForNestedRef(Scope *sc);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};


/****************************************************************/

/* Special values used by the interpreter
 */
#define EXP_CANT_INTERPRET	((Expression *)1)
#define EXP_CONTINUE_INTERPRET	((Expression *)2)
#define EXP_BREAK_INTERPRET	((Expression *)3)
#define EXP_GOTO_INTERPRET	((Expression *)4)
#define EXP_VOID_INTERPRET	((Expression *)5)

Expression *expType(Type *type, Expression *e);

Expression *Neg(Type *type, Expression *e1);
Expression *Com(Type *type, Expression *e1);
Expression *Not(Type *type, Expression *e1);
Expression *Bool(Type *type, Expression *e1);
Expression *Cast(Type *type, Type *to, Expression *e1);
Expression *ArrayLength(Type *type, Expression *e1);
Expression *Ptr(Type *type, Expression *e1);

Expression *Add(Type *type, Expression *e1, Expression *e2);
Expression *Min(Type *type, Expression *e1, Expression *e2);
Expression *Mul(Type *type, Expression *e1, Expression *e2);
Expression *Div(Type *type, Expression *e1, Expression *e2);
Expression *Mod(Type *type, Expression *e1, Expression *e2);
Expression *Shl(Type *type, Expression *e1, Expression *e2);
Expression *Shr(Type *type, Expression *e1, Expression *e2);
Expression *Ushr(Type *type, Expression *e1, Expression *e2);
Expression *And(Type *type, Expression *e1, Expression *e2);
Expression *Or(Type *type, Expression *e1, Expression *e2);
Expression *Xor(Type *type, Expression *e1, Expression *e2);
Expression *Index(Type *type, Expression *e1, Expression *e2);
Expression *Cat(Type *type, Expression *e1, Expression *e2);

Expression *Equal(enum TOK op, Type *type, Expression *e1, Expression *e2);
Expression *Cmp(enum TOK op, Type *type, Expression *e1, Expression *e2);
Expression *Identity(enum TOK op, Type *type, Expression *e1, Expression *e2);

Expression *Slice(Type *type, Expression *e1, Expression *lwr, Expression *upr);

#endif /* DMD_EXPRESSION_H */
