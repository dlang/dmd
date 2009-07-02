
// Copyright (c) 1999-2002 by Digital Mars
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

// Back end
struct IRState;
struct elem;
struct dt_t;

void accessCheck(Loc loc, Scope *sc, Expression *e, Declaration *d);

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

    int compare(Object *o) { return 5; }	// kludge for template.isExpression()

    void print();
    char *toChars();
    virtual void dump(int indent);
    void error(const char *format, ...);
    void rvalue();

    static Expression *combine(Expression *e1, Expression *e2);
    static Array *arraySyntaxCopy(Array *exps);

    virtual integer_t toInteger();
    virtual real_t toReal();
    virtual real_t toImaginary();
    virtual complex_t toComplex();
    virtual void toCBuffer(OutBuffer *buf);
    virtual Expression *toLvalue();
    virtual Expression *modifiableLvalue(Scope *sc);
    Expression *implicitCastTo(Type *t);
    virtual int implicitConvTo(Type *t);
    virtual Expression *castTo(Type *t);
    void checkScalar();
    void checkIntegral();
    void checkArithmetic();
    void checkDeprecated(Dsymbol *s);
    virtual void checkBoolean();
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
    int equals(Object *o);
    Expression *semantic(Scope *sc);
    char *toChars();
    void dump(int indent);
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    int isConst();
    int isBool(int result);
    int implicitConvTo(Type *t);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct RealExp : Expression
{
    real_t value;

    RealExp(Loc loc, real_t value, Type *type);
    Expression *semantic(Scope *sc);
    char *toChars();
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    int isConst();
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct ImaginaryExp : Expression
{
    real_t value;

    ImaginaryExp(Loc loc, real_t value, Type *type);
    Expression *semantic(Scope *sc);
    char *toChars();
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    int isConst();
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct ComplexExp : Expression
{
    complex_t value;

    ComplexExp(Loc loc, complex_t value, Type *type);
    Expression *semantic(Scope *sc);
    char *toChars();
    integer_t toInteger();
    real_t toReal();
    real_t toImaginary();
    complex_t toComplex();
    int isConst();
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
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
    void toCBuffer(OutBuffer *buf);
    Expression *toLvalue();
};

struct ThisExp : Expression
{
    Declaration *var;

    ThisExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
    Expression *toLvalue();

    //int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};

struct SuperExp : ThisExp
{
    SuperExp(Loc loc);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);

    //int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

struct NullExp : Expression
{
    NullExp(Loc loc);
    Expression *semantic(Scope *sc);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct StringExp : Expression
{
    wchar_t *string;
    unsigned len;
    int committed;	// !=0 if type is committed

    StringExp(Loc loc, wchar_t *s, unsigned len);
    char *toChars();
    Expression *semantic(Scope *sc);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    int compare(Object *obj);
    int isBool(int result);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

struct TypeDotIdExp : Expression
{
    Identifier *ident;

    TypeDotIdExp(Loc loc, Type *type, Identifier *ident);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

struct TypeExp : Expression
{
    TypeExp(Loc loc, Type *type);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

struct ScopeExp : Expression
{
    ScopeDsymbol *sds;

    ScopeExp(Loc loc, ScopeDsymbol *sds);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    void toCBuffer(OutBuffer *buf);
};

struct NewExp : Expression
{
    Array *newargs;		// Array of Expression's to call new operator
    Array *arguments;		// Array of Expression's
    CtorDeclaration *member;	// constructor function
    NewDeclaration *allocator;	// allocator function

    NewExp(Loc loc, Array *newargs, Type *type, Array *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    elem *toElem(IRState *irs);
    void toCBuffer(OutBuffer *buf);
};

// Offset from symbol

struct SymOffExp : Expression
{
    Declaration *var;
    unsigned offset;

    SymOffExp(Loc loc, Declaration *var, unsigned offset);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    int isConst();

    elem *toElem(IRState *irs);
    dt_t **toDt(dt_t **pdt);
};

// Variable

struct VarExp : Expression
{
    Declaration *var;

    VarExp(Loc loc, Declaration *var);
    Expression *semantic(Scope *sc);
    void dump(int indent);
    char *toChars();
    void toCBuffer(OutBuffer *buf);
    Expression *toLvalue();
    Expression *modifiableLvalue(Scope *sc);
    elem *toElem(IRState *irs);

    //int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    //Expression *inlineScan(InlineScanState *iss);
};

// Function/Delegate literal

struct FuncExp : Expression
{
    FuncLiteralDeclaration *fd;

    FuncExp(Loc loc, FuncLiteralDeclaration *fd);
    Expression *semantic(Scope *sc);
    char *toChars();
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);

    //int inlineCost(InlineCostState *ics);
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
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

/****************************************************************/

struct UnaExp : Expression
{
    Expression *e1;

    UnaExp(Loc loc, enum TOK op, int size, Expression *e1);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
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
    Expression *commonSemanticAssign(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    Expression *scaleFactor();
    Expression *typeCombine();
    Expression *optimize(int result);
    int isunsigned();
    void dump(int indent);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    Expression *op_overload(Scope *sc);

    elem *toElemBin(IRState *irs, int op);
};

/****************************************************************/

struct AssertExp : UnaExp
{
    AssertExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

struct DotIdExp : UnaExp
{
    Identifier *ident;

    DotIdExp(Loc loc, Expression *e, Identifier *ident);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct DotVarExp : UnaExp
{
    Declaration *var;

    DotVarExp(Loc loc, Expression *e, Declaration *var);
    Expression *semantic(Scope *sc);
    Expression *toLvalue();
    void toCBuffer(OutBuffer *buf);
    void dump(int indent);
    elem *toElem(IRState *irs);
};

struct DelegateExp : UnaExp
{
    FuncDeclaration *func;

    DelegateExp(Loc loc, Expression *e, FuncDeclaration *func);
    Expression *semantic(Scope *sc);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);
    void toCBuffer(OutBuffer *buf);
    void dump(int indent);
    elem *toElem(IRState *irs);
};

struct DotTypeExp : UnaExp
{
    Dsymbol *sym;		// symbol that represents a type

    DotTypeExp(Loc loc, Expression *e, Dsymbol *sym);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

struct ArrowExp : UnaExp
{
    Identifier *ident;

    ArrowExp(Loc loc, Expression *e, Identifier *ident);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct CallExp : UnaExp
{
    Array *arguments;		// Array of Expression's

    CallExp(Loc loc, Expression *e, Array *arguments);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
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
    Expression *toLvalue();
    void toCBuffer(OutBuffer *buf);
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
    void checkBoolean();
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
    void toCBuffer(OutBuffer *buf);
    Expression *constFold();
    elem *toElem(IRState *irs);
};


struct ArrayRangeExp : UnaExp
{
    Expression *upr;		// NULL if implicit 0
    Expression *lwr;		// NULL if implicit [length - 1]

    ArrayRangeExp(Loc loc, Expression *e1, Expression *lwr, Expression *upr);
    Expression *syntaxCopy();
    Expression *semantic(Scope *sc);
    Expression *toLvalue();
    Expression *modifiableLvalue(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);
};

struct ArrayLengthExp : UnaExp
{
    ArrayLengthExp(Loc loc, Expression *e1);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

/****************************************************************/

struct CommaExp : BinExp
{
    CommaExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *toLvalue();
    int isBool(int result);
    Expression *optimize(int result);
    elem *toElem(IRState *irs);
};

struct ArrayExp : BinExp
{
    ArrayExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *toLvalue();
    void toCBuffer(OutBuffer *buf);
    elem *toElem(IRState *irs);
};

struct PostIncExp : BinExp
{
    PostIncExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

struct PostDecExp : BinExp
{
    PostDecExp(Loc loc, Expression *e);
    Expression *semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    Identifier *opId();    // For operator overloading
    elem *toElem(IRState *irs);
};

struct AssignExp : BinExp
{
    AssignExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    void checkBoolean();
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

    // For operator overloading
    int isCommutative();
    Identifier *opId();

    elem *toElem(IRState *irs);
};

struct MinExp : BinExp
{
    MinExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();

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

    elem *toElem(IRState *irs);
};

struct OrOrExp : BinExp
{
    OrOrExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    void checkBoolean();
    int isBit();
    Expression *constFold();
    Expression *optimize(int result);
    elem *toElem(IRState *irs);
};

struct AndAndExp : BinExp
{
    AndAndExp(Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    void checkBoolean();
    int isBit();
    Expression *constFold();
    Expression *optimize(int result);
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
    elem *toElem(IRState *irs);
};

// == and !=

struct EqualExp : BinExp
{
    EqualExp(enum TOK op, Loc loc, Expression *e1, Expression *e2);
    Expression *semantic(Scope *sc);
    Expression *constFold();
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
    Expression *toLvalue();
    void checkBoolean();
    void toCBuffer(OutBuffer *buf);
    int implicitConvTo(Type *t);
    Expression *castTo(Type *t);

    int inlineCost(InlineCostState *ics);
    Expression *doInline(InlineDoState *ids);
    Expression *inlineScan(InlineScanState *iss);

    elem *toElem(IRState *irs);
};

#endif /* DMD_EXPRESSION_H */
