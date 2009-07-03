
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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
struct TemplateInstance;
struct TemplateDeclaration;
struct ClassDeclaration;
struct HdrGenState;
struct BinExp;

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
FuncDeclaration *search_function(AggregateDeclaration *ad, Identifier *funcid);
void inferApplyArgTypes(Array *arguments, Type *taggr);
void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);
void argsToCBuffer(OutBuffer *buf, Expressions *arguments, HdrGenState *hgs);

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
    void rvalue();

    static Expression *combine(Expression *e1, Expression *e2);
    static Expressions *arraySyntaxCopy(Expressions *exps);

    virtual integer_t toInteger();
    virtual uinteger_t toUInteger();
    virtual real_t toReal();
    virtual real_t toImaginary();
    virtual complex_t toComplex();
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual void toMangleBuffer(OutBuffer *buf);
    virtual Expression *toLvalue(Expression *e);
    virtual Expression *modifiableLvalue(Scope *sc, Expression *e);
    Expression *implicitCastTo(Type *t);
    virtual int implicitConvTo(Type *t);
    virtual Expression *castTo(Type *t);
    virtual void checkEscape();
    void checkScalar();
    void checkNoBool();
    Expression *checkIntegral();
    void checkArithmetic();
    void checkDeprecated(Scope *sc, Dsymbol *s);
    virtual Expression *checkToBoolean();
    Expression *checkToPointer();
    Expression *addressOf();
    Expression *deref();
    Expression *integralPromotions();

    virtual Expression *optimize(int result);
    #define WANTflags	1
    #define WANTvalue	2

    virtual Expression *constFold();
    virtual int isConst();
    virtual int isBool(int result);
    virtual int isBit();
    virtual void checkSideEffect(int flag);

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
    char *toChars();
    void dump(int indent);
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    int isConst();
    int isBool(int result);
    int implicitConvTo(Type *t);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    Expression *toLvalue(Expression *e);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct RealExp : Expression
{
    real_t value;

    RealExp(Loc loc, real_t value, Type *type);
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    char *toChars();
    integer_t toInteger();
    uinteger_t toUInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    Expression *castTo(Type *t);
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
    char *toChars();
    integer_t toInteger();
    uinteger_t toUInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    Expression *castTo(Type *t);
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
    Expression *toLvalue(Expression *e);
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
    Expression *toLvalue(Expression *e);
};

struct ThisExp : Expression
{
    Declaration *var;

    ThisExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *toLvalue(Expression *e);

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

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

struct NullExp : Expression
{
    NullExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct StringExp : Expression
{
    void *string;	// char, wchar, or dchar data
    unsigned len;	// number of chars, wchars, or dchars
    unsigned char sz;	// 1: char, 2: wchar, 4: dchar
    unsigned char committed;	// !=0 if type is committed
    unsigned char postfix;	// 'c', 'w', 'd'

    StringExp(Loc loc, char *s);
    StringExp(Loc loc, void *s, unsigned len);
    StringExp(Loc loc, void *s, unsigned len, unsigned char postfix);
    int equals(Object *o);
    char *toChars();
    Expression *semantic(Scope *sc);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    int compare(Object *obj);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toMangleBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
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

    NewExp(Loc loc, Expression *thisexp, Expressions *newargs,
	Type *newtype, Expressions *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    void checkSideEffect(int flag);
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
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);

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
    void dump(int indent);
    char *toChars();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void checkEscape();
    Expression *toLvalue(Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);

    //int inlineCost(InlineCostState *ics);
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
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);

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
    void checkSideEffect(int flag);

    elem *toElem(IRState *irs);
};

struct IftypeExp : Expression
{
    /* is(targ id tok tspec)
     * is(targ id == tok2)
     */
    Type *targ;
    Identifier *id;	// can be NULL
    enum TOK tok;	// ':' or '=='
    Type *tspec;	// can be NULL
    enum TOK tok2;	// 'struct', 'union', 'typedef', etc.

    IftypeExp(Loc loc, Type *targ, Identifier *id, enum TOK tok, Type *tspec, enum TOK tok2);
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
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *scaleFactor();
    Expression *typeCombine();
    Expression *optimize(int result);
    int isunsigned();
    void incompatibleTypes();
    void dump(int indent);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    Expression *op_overload(Scope *sc);

    elem *toElemBin(IRState *irs, int op);
};

struct BinAssignExp : BinExp
{
    BinAssignExp(Loc loc, enum TOK op, int size, Expression *e1, Expression *e2);
    void checkSideEffect(int flag);
};

/****************************************************************/

struct AssertExp : UnaExp
{
    Expression *msg;

    AssertExp(Loc loc, Expression *e, Expression *msg = NULL);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
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

struct DotVarExp : UnaExp
{
    Declaration *var;

    DotVarExp(Loc loc, Expression *e, Declaration *var);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Expression *e);
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
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
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
    Expressions *arguments;	// Array of Expression's

    CallExp(Loc loc, Expression *e, Expressions *arguments);
    CallExp(Loc loc, Expression *e);
    CallExp(Loc loc, Expression *e, Expression *earg1);
    CallExp(Loc loc, Expression *e, Expression *earg1, Expression *earg2);

    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct AddrExp : UnaExp
{
    AddrExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    Expression *optimize(int result);
};

struct PtrExp : UnaExp
{
    PtrExp(Loc loc, Expression *e);
    PtrExp(Loc loc, Expression *e, Type *t);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    elem *toElem(IRState *irs);
    Expression *optimize(int result);
};

struct NegExp : UnaExp
{
    NegExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *constFold();

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
    Expression *constFold();

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct NotExp : UnaExp
{
    NotExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *constFold();
    int isBit();
    elem *toElem(IRState *irs);
};

struct BoolExp : UnaExp
{
    BoolExp(Loc loc, Expression *e, Type *type);
    Expression *semantic(Scope *sc);
    Expression *constFold();
    int isBit();
    elem *toElem(IRState *irs);
};

struct DeleteExp : UnaExp
{
    DeleteExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    void checkSideEffect(int flag);
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
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *constFold();
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
    Expression *toLvalue(Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    void dump(int indent);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct ArrayLengthExp : UnaExp
{
    ArrayLengthExp(Loc loc, Expression *e1);
    Expression *semantic(Scope *sc);
    Expression *optimize(int result);
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
    Expression *toLvalue(Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

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
    Expression *toLvalue(Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    int isBool(int result);
    void checkSideEffect(int flag);
    Expression *optimize(int result);
    elem *toElem(IRState *irs);
};

struct IndexExp : BinExp
{
    VarDeclaration *lengthVar;
    int modifiable;

    IndexExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *toLvalue(Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Expression *optimize(int result);
    Expression *doInline(InlineDoState *ids);

    elem *toElem(IRState *irs);
};

struct PostIncExp : BinExp
{
    PostIncExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

struct PostDecExp : BinExp
{
    PostDecExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

struct AssignExp : BinExp
{
    AssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    elem *toElem(IRState *irs);
};

struct AddAssignExp : BinExp
{
    AddAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    Identifier *opId();    // For operator overloading

    elem *toElem(IRState *irs);
};

struct MinAssignExp : BinExp
{
    MinAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct CatAssignExp : BinExp
{
    CatAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct MulAssignExp : BinExp
{
    MulAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct DivAssignExp : BinExp
{
    DivAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct ModAssignExp : BinExp
{
    ModAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct ShlAssignExp : BinExp
{
    ShlAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct ShrAssignExp : BinExp
{
    ShrAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct UshrAssignExp : BinExp
{
    UshrAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct AndAssignExp : BinExp
{
    AndAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct OrAssignExp : BinExp
{
    OrAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct XorAssignExp : BinExp
{
    XorAssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);

    // For operator overloading
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct AddExp : BinExp
{
    AddExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();
    Expression *optimize(int result);

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
    Expression *constFold();
    Expression *optimize(int result);

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

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct MulExp : BinExp
{
    MulExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

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
    Expression *constFold();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ModExp : BinExp
{
    ModExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ShlExp : BinExp
{
    ShlExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct ShrExp : BinExp
{
    ShrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct UshrExp : BinExp
{
    UshrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

    // For operator overloading
    Identifier *opId();
    Identifier *opId_r();

    elem *toElem(IRState *irs);
};

struct AndExp : BinExp
{
    AndExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

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
    Expression *constFold();

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
    Expression *constFold();

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
    Expression *constFold();
    Expression *optimize(int result);
    void checkSideEffect(int flag);
    elem *toElem(IRState *irs);
};

struct AndAndExp : BinExp
{
    AndAndExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *checkToBoolean();
    int isBit();
    Expression *constFold();
    Expression *optimize(int result);
    void checkSideEffect(int flag);
    elem *toElem(IRState *irs);
};

struct CmpExp : BinExp
{
    CmpExp(enum TOK op, Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();
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
    Expression *constFold();
    Expression *optimize(int result);
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
    Expression *constFold();
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
    Expression *constFold();
    void checkEscape();
    Expression *toLvalue(Expression *e);
    Expression *modifiableLvalue(Scope *sc, Expression *e);
    Expression *checkToBoolean();
    void checkSideEffect(int flag);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};

#endif /* DMD_EXPRESSION_H */
