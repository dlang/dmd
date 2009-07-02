
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_MTYPE_H
#define DMD_MTYPE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "stringtable.h"

#include "expression.h"

struct Scope;
struct Identifier;
struct Expression;
struct StructDeclaration;
struct ClassDeclaration;
struct VarDeclaration;
struct EnumDeclaration;
struct TypedefDeclaration;
struct TypeInfoDeclaration;
struct Dsymbol;
struct TemplateInstance;
enum LINK;

struct TypeBasic;

// Back end
typedef struct TYPE type;
struct Symbol;

enum TY
{
    Tarray,		// dynamic array
    Tsarray,		// static array
    Taarray,		// associative array
    Tpointer,
    Treference,
    Tfunction,
    Tident,
    Tclass,
    Tstruct,
    Tenum,
    Ttypedef,
    Tdelegate,

    Tnone,
    Tvoid,
    Tint8,
    Tuns8,
    Tint16,
    Tuns16,
    Tint32,
    Tuns32,
    Tint64,
    Tuns64,
    Tfloat32,
    Tfloat64,
    Tfloat80,

    Timaginary32,
    Timaginary64,
    Timaginary80,

    Tcomplex32,
    Tcomplex64,
    Tcomplex80,

    Tbit,
    Tchar,
    Twchar,
    Tdchar,

    Terror,
    Tinstance,
    TMAX
};

#define Tascii Tchar

enum MATCH
{
    MATCHnomatch,	// no match
    MATCHconvert,	// match with conversions
    MATCHexact		// exact match
};


struct Type : Object
{
    TY ty;
    Type *next;
    char *deco;
    Type *pto;		// merged pointer to this type
    Type *rto;		// reference to this type
    Type *arrayof;	// array of this type
    TypeInfoDeclaration *vtinfo;	// TypeInfo object for this Type

    #define tvoid	basic[Tvoid]
    #define tint8	basic[Tint8]
    #define tuns8	basic[Tuns8]
    #define tint16	basic[Tint16]
    #define tuns16	basic[Tuns16]
    #define tint32	basic[Tint32]
    #define tuns32	basic[Tuns32]
    #define tint64	basic[Tint64]
    #define tuns64	basic[Tuns64]
    #define tfloat32	basic[Tfloat32]
    #define tfloat64	basic[Tfloat64]
    #define tfloat80	basic[Tfloat80]

    #define timaginary32 basic[Timaginary32]
    #define timaginary64 basic[Timaginary64]
    #define timaginary80 basic[Timaginary80]

    #define tcomplex32	basic[Tcomplex32]
    #define tcomplex64	basic[Tcomplex64]
    #define tcomplex80	basic[Tcomplex80]

    #define tbit	basic[Tbit]
    #define tchar	basic[Tchar]
    #define twchar	basic[Twchar]
    #define tdchar	basic[Tdchar]

    // Some special types
    #define tshiftcnt	tint32		// right side of shift expression
    #define tboolean	tint32		// result of boolean expression
    #define tindex	tint32		// array/ptr index
    #define tvoidptr	tint32		// size for void*
    #define terror	basic[Terror]	// for error recovery

    static ClassDeclaration *typeinfo;

    static Type *basic[TMAX];
    static unsigned char mangleChar[TMAX];
    static StringTable stringtable;

    // These tables are for implicit conversion of binary ops;
    // the indices are the type of operand one, followed by operand two.
    static unsigned char impcnvResult[TMAX][TMAX];
    static unsigned char impcnvType1[TMAX][TMAX];
    static unsigned char impcnvType2[TMAX][TMAX];

    Type(TY ty, Type *next);
    virtual Type *syntaxCopy();
    int equals(Object *o);
    int compare(Object *o) { return 6; } // kludge for template.isType()
    int covariant(Type *t);
    char *toChars();
    static void init();
    virtual unsigned size();
    virtual unsigned alignsize();
    virtual Type *semantic(Loc loc, Scope *sc);
    virtual void toDecoBuffer(OutBuffer *buf);
    virtual void toTypeInfoBuffer(OutBuffer *buf);
    Type *merge();
    void toCBuffer(OutBuffer *buf, Identifier *ident);
    virtual void toCBuffer2(OutBuffer *buf, Identifier *ident);
    virtual int isbit();
    virtual int isintegral();
    virtual int isfloating();	// real, imaginary, or complex
    virtual int isreal();
    virtual int isimaginary();
    virtual int iscomplex();
    virtual int isscalar();
    virtual int isunsigned();
    virtual int isauto();
    virtual int isString();
    virtual int checkBoolean();	// if can be converted to boolean value
    Type *pointerTo();
    Type *referenceTo();
    Type *arrayOf();
    virtual Type *toBasetype();
    virtual int implicitConvTo(Type *to);
    virtual ClassDeclaration *isClassHandle();
    virtual Expression *getProperty(Loc loc, Identifier *ident);
    virtual Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    virtual unsigned memalign(unsigned salign);
    virtual Expression *defaultInit();
    virtual int isZeroInit();		// if initializer is 0
    virtual dt_t **toDt(dt_t **pdt);
    Identifier *getTypeInfoIdent();
    virtual MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    static void error(Loc loc, const char *format, ...);

    // For backend
    virtual unsigned totym();
    virtual type *toCtype();
    virtual type *toCParamtype();
    virtual Symbol *toSymbol();

    // For eliminating dynamic_cast
    virtual TypeBasic *isTypeBasic();
};

struct TypeBasic : Type
{
    char *dstring;
    char *cstring;
    unsigned flags;

    TypeBasic(TY ty);
    Type *syntaxCopy();
    unsigned size();
    unsigned alignsize();
    Expression *getProperty(Loc loc, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    char *toChars();
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    int isintegral();
    int isbit();
    int isfloating();
    int isreal();
    int isimaginary();
    int iscomplex();
    int isscalar();
    int isunsigned();
    int implicitConvTo(Type *to);
    Expression *defaultInit();
    int isZeroInit();

    // For eliminating dynamic_cast
    TypeBasic *isTypeBasic();
};

struct TypeArray : Type
{
    TypeArray(TY ty, Type *next);
    virtual void toPrettyBracket(OutBuffer *buf) = 0;
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
};

// Static array, one with a fixed dimension
struct TypeSArray : TypeArray
{
    Expression *dim;

    TypeSArray(Type *t, Expression *dim);
    Type *syntaxCopy();
    unsigned size();
    unsigned alignsize();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toTypeInfoBuffer(OutBuffer *buf);
    void toPrettyBracket(OutBuffer *buf);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int isString();
    unsigned memalign(unsigned salign);
    int implicitConvTo(Type *to);
    Expression *defaultInit();
    dt_t **toDt(dt_t **pdt);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    type *toCtype();
    type *toCParamtype();
};

// Dynamic array, no dimension
struct TypeDArray : TypeArray
{
    TypeDArray(Type *t);
    Type *syntaxCopy();
    unsigned size();
    unsigned alignsize();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toTypeInfoBuffer(OutBuffer *buf);
    void toPrettyBracket(OutBuffer *buf);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int isString();
    int checkBoolean();
    int implicitConvTo(Type *to);
    Expression *defaultInit();
};

struct TypeAArray : TypeArray
{
    Type *index;		// key type for type checking
    Type *key;			// actual key type

    TypeAArray(Type *t, Type *index);
    Type *syntaxCopy();
    unsigned size();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toPrettyBracket(OutBuffer *buf);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit();
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);
    int checkBoolean();

    // Back end
    Symbol *aaGetSymbol(char *func, int flags);
};

struct TypePointer : Type
{
    TypePointer(Type *t);
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    unsigned size();
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    int implicitConvTo(Type *to);
    int isscalar();
    Expression *defaultInit();
    int isZeroInit();
};

struct TypeReference : Type
{
    TypeReference(Type *t);
    Type *syntaxCopy();
    unsigned size();
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit();
    int isZeroInit();
};

enum RET
{
    RETregs	= 1,	// returned in registers
    RETstack	= 2,	// returned on stack
};

struct TypeFunction : Type
{
    Array *arguments;	// Array of Argument's
    int varargs;	// if variable number of arguments
    enum LINK linkage;	// calling convention

    TypeFunction(Array *arguments, Type *treturn, int varargs, enum LINK linkage);
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    void argsToCBuffer(OutBuffer *buf);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    int callMatch(Array *toargs);
    type *toCtype();
    enum RET retStyle();

    unsigned totym();
};

struct TypeDelegate : Type
{
    TypeDelegate(Type *t);
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    unsigned size();
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *defaultInit();
    int isZeroInit();
    int checkBoolean();
};

struct TypeIdentifier : Type
{
    Loc loc;
    Array idents;	// array of Identifier's representing ident.ident.ident etc.

    TypeIdentifier(Loc loc, Identifier *ident);
    Type *syntaxCopy();
    void addIdent(Identifier *ident);
    unsigned size();
    //char *toChars();
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    void resolve(Scope *sc, Expression **pe, Type **pt);
    Type *semantic(Loc loc, Scope *sc);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);
};

/* Similar to TypeIdentifier, but with a TemplateInstance as the root
 */
struct TypeInstance : Type
{
    Loc loc;
    TemplateInstance *tempinst;
    Array idents;	// array of Identifier's representing tempinst.ident.ident.ident etc.

    TypeInstance(Loc loc, TemplateInstance *tempinst);
    Type *syntaxCopy();
    void addIdent(Identifier *ident);
    unsigned size();
    //char *toChars();
    //void toDecoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    void resolve(Scope *sc, Expression **pe, Type **pt);
    Type *semantic(Loc loc, Scope *sc);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);
};

struct TypeStruct : Type
{
    StructDeclaration *sym;

    TypeStruct(StructDeclaration *sym);
    unsigned size();
    unsigned alignsize();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toTypeInfoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    unsigned memalign(unsigned salign);
    Expression *defaultInit();
    int isZeroInit();
    dt_t **toDt(dt_t **pdt);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    type *toCtype();
};

struct TypeEnum : Type
{
    EnumDeclaration *sym;

    TypeEnum(EnumDeclaration *sym);
    unsigned size();
    unsigned alignsize();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toTypeInfoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *getProperty(Loc loc, Identifier *ident);
    int isintegral();
    int isfloating();
    int isscalar();
    int isunsigned();
    int implicitConvTo(Type *to);
    Type *toBasetype();
    Expression *defaultInit();
    int isZeroInit();
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    type *toCtype();
};

struct TypeTypedef : Type
{
    TypedefDeclaration *sym;

    TypeTypedef(TypedefDeclaration *sym);
    unsigned size();
    unsigned alignsize();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toTypeInfoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int isbit();
    int isintegral();
    int isfloating();
    int isscalar();
    int isunsigned();
    int checkBoolean();
    Type *toBasetype();
    int implicitConvTo(Type *to);
    Expression *defaultInit();
    int isZeroInit();
    dt_t **toDt(dt_t **pdt);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);

    type *toCtype();
};

struct TypeClass : Type
{
    ClassDeclaration *sym;

    TypeClass(ClassDeclaration *sym);
    unsigned size();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    void toDecoBuffer(OutBuffer *buf);
    void toCBuffer2(OutBuffer *buf, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    ClassDeclaration *isClassHandle();
    int implicitConvTo(Type *to);
    Expression *defaultInit();
    int isZeroInit();
    Expression *getProperty(Loc loc, Identifier *ident);
    MATCH deduceType(Type *tparam, Array *parameters, Array *atypes);
    int isauto();
    int checkBoolean();

    Symbol *toSymbol();
};

enum InOut { In, Out, InOut };

struct Argument : Object
{
    Type *type;
    Identifier *ident;
    enum InOut inout;

    Argument(Type *type, Identifier *ident, enum InOut inout);
};

#endif /* DMD_MTYPE_H */
