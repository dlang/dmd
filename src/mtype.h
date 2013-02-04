
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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

#include "arraytypes.h"
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
struct CppMangleState;
struct TemplateDeclaration;
struct JsonOut;
enum LINK;

struct TypeBasic;
struct HdrGenState;
struct Parameter;
struct TypeFunction;

void functionToCBuffer2(TypeFunction *t, OutBuffer *buf, HdrGenState *hgs, int mod, const char *kind);

// Back end
#ifdef IN_GCC
union tree_node; typedef union tree_node TYPE;
typedef TYPE type;
#else
typedef struct TYPE type;
#endif
struct Symbol;
struct TypeTuple;

enum ENUMTY
{
    Tarray,             // slice array, aka T[]
    Tsarray,            // static array, aka T[dimension]
    Taarray,            // associative array, aka T[type]
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
    Tbool,
    Tchar,
    Twchar,
    Tdchar,
    Terror,
    Tinstance,
    Ttypeof,
    Ttuple,
    Tslice,

    Treturn,
    Tnull,
    Tvector,
    Tint128,
    Tuns128,
    TMAX
};
typedef unsigned char TY;       // ENUMTY

#define Tascii Tchar

extern int Tsize_t;
extern int Tptrdiff_t;


struct Type : Object
{
    TY ty;
    unsigned char mod;  // modifiers MODxxxx
        /* pick this order of numbers so switch statements work better
         */
        #define MODconst     1  // type is const
        #define MODimmutable 4  // type is immutable
        #define MODshared    2  // type is shared
        #define MODwild      8  // type is wild
        #define MODmutable   0x10       // type is mutable (only used in wildcard matching)
    char *deco;

    /* These are cached values that are lazily evaluated by constOf(), invariantOf(), etc.
     * They should not be referenced by anybody but mtype.c.
     * They can be NULL if not lazily evaluated yet.
     * Note that there is no "shared immutable", because that is just immutable
     * Naked == no MOD bits
     */

    Type *cto;          // MODconst ? naked version of this type : const version
    Type *ito;          // MODimmutable ? naked version of this type : immutable version
    Type *sto;          // MODshared ? naked version of this type : shared mutable version
    Type *scto;         // MODshared|MODconst ? naked version of this type : shared const version
    Type *wto;          // MODwild ? naked version of this type : wild version
    Type *swto;         // MODshared|MODwild ? naked version of this type : shared wild version

    Type *pto;          // merged pointer to this type
    Type *rto;          // reference to this type
    Type *arrayof;      // array of this type
    TypeInfoDeclaration *vtinfo;        // TypeInfo object for this Type

    type *ctype;        // for back end

    #define tvoid       basic[Tvoid]
    #define tint8       basic[Tint8]
    #define tuns8       basic[Tuns8]
    #define tint16      basic[Tint16]
    #define tuns16      basic[Tuns16]
    #define tint32      basic[Tint32]
    #define tuns32      basic[Tuns32]
    #define tint64      basic[Tint64]
    #define tuns64      basic[Tuns64]
    #define tint128     basic[Tint128]
    #define tuns128     basic[Tuns128]
    #define tfloat32    basic[Tfloat32]
    #define tfloat64    basic[Tfloat64]
    #define tfloat80    basic[Tfloat80]

    #define timaginary32 basic[Timaginary32]
    #define timaginary64 basic[Timaginary64]
    #define timaginary80 basic[Timaginary80]

    #define tcomplex32  basic[Tcomplex32]
    #define tcomplex64  basic[Tcomplex64]
    #define tcomplex80  basic[Tcomplex80]

    #define tbool       basic[Tbool]
    #define tchar       basic[Tchar]
    #define twchar      basic[Twchar]
    #define tdchar      basic[Tdchar]

    // Some special types
    #define tshiftcnt   tint32          // right side of shift expression
//    #define tboolean  tint32          // result of boolean expression
    #define tboolean    tbool           // result of boolean expression
    #define tindex      tsize_t         // array/ptr index
    static Type *tvoidptr;              // void*
    static Type *tstring;               // immutable(char)[]
    static Type *tvalist;               // va_list alias
    #define terror      basic[Terror]   // for error recovery

    #define tnull       basic[Tnull]    // for null type

    #define tsize_t     basic[Tsize_t]          // matches size_t alias
    #define tptrdiff_t  basic[Tptrdiff_t]       // matches ptrdiff_t alias
    #define thash_t     tsize_t                 // matches hash_t alias

    static ClassDeclaration *typeinfo;
    static ClassDeclaration *typeinfoclass;
    static ClassDeclaration *typeinfointerface;
    static ClassDeclaration *typeinfostruct;
    static ClassDeclaration *typeinfotypedef;
    static ClassDeclaration *typeinfopointer;
    static ClassDeclaration *typeinfoarray;
    static ClassDeclaration *typeinfostaticarray;
    static ClassDeclaration *typeinfoassociativearray;
    static ClassDeclaration *typeinfovector;
    static ClassDeclaration *typeinfoenum;
    static ClassDeclaration *typeinfofunction;
    static ClassDeclaration *typeinfodelegate;
    static ClassDeclaration *typeinfotypelist;
    static ClassDeclaration *typeinfoconst;
    static ClassDeclaration *typeinfoinvariant;
    static ClassDeclaration *typeinfoshared;
    static ClassDeclaration *typeinfowild;

    static TemplateDeclaration *associativearray;
    static TemplateDeclaration *rtinfo;

    static Type *basic[TMAX];
    static unsigned char mangleChar[TMAX];
    static unsigned char sizeTy[TMAX];
    static StringTable stringtable;

    // These tables are for implicit conversion of binary ops;
    // the indices are the type of operand one, followed by operand two.
    static unsigned char impcnvResult[TMAX][TMAX];
    static unsigned char impcnvType1[TMAX][TMAX];
    static unsigned char impcnvType2[TMAX][TMAX];

    // If !=0, give warning on implicit conversion
    static unsigned char impcnvWarn[TMAX][TMAX];

    Type(TY ty);
    virtual const char *kind();
    virtual Type *syntaxCopy();
    int equals(Object *o);
    int dyncast() { return DYNCAST_TYPE; } // kludge for template.isType()
    int covariant(Type *t, StorageClass *pstc = NULL);
    char *toChars();
    static char needThisPrefix();
    static void init();
    d_uns64 size();
    virtual d_uns64 size(Loc loc);
    virtual unsigned alignsize();
    virtual Type *semantic(Loc loc, Scope *sc);
    Type *trySemantic(Loc loc, Scope *sc);
    virtual void toDecoBuffer(OutBuffer *buf, int flag = 0);
    Type *merge();
    Type *merge2();
    virtual void toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs);
    virtual void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toCBuffer3(OutBuffer *buf, HdrGenState *hgs, int mod);
    void modToBuffer(OutBuffer *buf);
    char *modToChars();
    void toJsonProperty(JsonOut *json, const char *);
    virtual void toJson(JsonOut *json);
#if CPP_MANGLE
    virtual void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif
    virtual int isintegral();
    virtual int isfloating();   // real, imaginary, or complex
    virtual int isreal();
    virtual int isimaginary();
    virtual int iscomplex();
    virtual int isscalar();
    virtual int isunsigned();
    virtual int isscope();
    virtual int isString();
    virtual int isAssignable();
    virtual int checkBoolean(); // if can be converted to boolean value
    virtual void checkDeprecated(Loc loc, Scope *sc);
    int isConst()       { return mod & MODconst; }
    int isImmutable()   { return mod & MODimmutable; }
    int isMutable()     { return !(mod & (MODconst | MODimmutable | MODwild)); }
    int isShared()      { return mod & MODshared; }
    int isSharedConst() { return mod == (MODshared | MODconst); }
    int isWild()        { return mod & MODwild; }
    int isSharedWild()  { return mod == (MODshared | MODwild); }
    int isNaked()       { return mod == 0; }
    Type *constOf();
    Type *invariantOf();
    Type *mutableOf();
    Type *sharedOf();
    Type *sharedConstOf();
    Type *unSharedOf();
    Type *wildOf();
    Type *sharedWildOf();
    void fixTo(Type *t);
    void check();
    Type *addSTC(StorageClass stc);
    Type *castMod(unsigned mod);
    Type *addMod(unsigned mod);
    virtual Type *addStorageClass(StorageClass stc);
    Type *pointerTo();
    Type *referenceTo();
    Type *arrayOf();
    Type *aliasthisOf();
    virtual Type *makeConst();
    virtual Type *makeInvariant();
    virtual Type *makeShared();
    virtual Type *makeSharedConst();
    virtual Type *makeWild();
    virtual Type *makeSharedWild();
    virtual Type *makeMutable();
    virtual Dsymbol *toDsymbol(Scope *sc);
    virtual Type *toBasetype();
    virtual int isBaseOf(Type *t, int *poffset);
    virtual MATCH implicitConvTo(Type *to);
    virtual MATCH constConv(Type *to);
    virtual unsigned wildConvTo(Type *tprm);
    Type *substWildTo(unsigned mod);
    virtual Type *toHeadMutable();
    virtual ClassDeclaration *isClassHandle();
    virtual Expression *getProperty(Loc loc, Identifier *ident);
    virtual Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    virtual structalign_t alignment();
    Expression *noMember(Scope *sc, Expression *e, Identifier *ident);
    virtual Expression *defaultInit(Loc loc = 0);
    virtual Expression *defaultInitLiteral(Loc loc);
    virtual Expression *voidInitLiteral(VarDeclaration *var);
    virtual int isZeroInit(Loc loc = 0);                // if initializer is 0
    virtual dt_t **toDt(dt_t **pdt);
    Identifier *getTypeInfoIdent(int internal);
    virtual MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    virtual void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    Expression *getInternalTypeInfo(Scope *sc);
    Expression *getTypeInfo(Scope *sc);
    virtual TypeInfoDeclaration *getTypeInfoDeclaration();
    virtual int builtinTypeInfo();
    virtual Type *reliesOnTident(TemplateParameters *tparams = NULL);
    virtual int hasWild();
    virtual Expression *toExpression();
    virtual int hasPointers();
    virtual TypeTuple *toArgTypes();
    virtual Type *nextOf();
    uinteger_t sizemask();
    virtual int needsDestruction();
    virtual bool needsNested();

    static void error(Loc loc, const char *format, ...);
    static void warning(Loc loc, const char *format, ...);

    // For backend
    virtual unsigned totym();
    virtual type *toCtype();
    virtual type *toCParamtype();
    virtual Symbol *toSymbol();

    // For eliminating dynamic_cast
    virtual TypeBasic *isTypeBasic();
};

struct TypeError : Type
{
    TypeError();
    Type *syntaxCopy();

    void toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs);

    d_uns64 size(Loc loc);
    Expression *getProperty(Loc loc, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit(Loc loc);
    Expression *defaultInitLiteral(Loc loc);
    TypeTuple *toArgTypes();
};

struct TypeNext : Type
{
    Type *next;

    TypeNext(TY ty, Type *next);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void checkDeprecated(Loc loc, Scope *sc);
    Type *reliesOnTident(TemplateParameters *tparams = NULL);
    int hasWild();
    Type *nextOf();
    Type *makeConst();
    Type *makeInvariant();
    Type *makeShared();
    Type *makeSharedConst();
    Type *makeWild();
    Type *makeSharedWild();
    Type *makeMutable();
    MATCH constConv(Type *to);
    unsigned wildConvTo(Type *tprm);
    void transitive();
};

struct TypeBasic : Type
{
    const char *dstring;
    unsigned flags;

    TypeBasic(TY ty);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    Expression *getProperty(Loc loc, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    char *toChars();
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif
    int isintegral();
    int isfloating();
    int isreal();
    int isimaginary();
    int iscomplex();
    int isscalar();
    int isunsigned();
    MATCH implicitConvTo(Type *to);
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
    int builtinTypeInfo();
    TypeTuple *toArgTypes();

    // For eliminating dynamic_cast
    TypeBasic *isTypeBasic();
};

struct TypeVector : Type
{
    Type *basetype;

    TypeVector(Loc loc, Type *basetype);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
    unsigned alignsize();
    Expression *getProperty(Loc loc, Identifier *ident);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    char *toChars();
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toJson(JsonOut *json);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif
    int isintegral();
    int isfloating();
    int isscalar();
    int isunsigned();
    int checkBoolean();
    MATCH implicitConvTo(Type *to);
    Expression *defaultInit(Loc loc);
    TypeBasic *elementType();
    int isZeroInit(Loc loc);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    TypeTuple *toArgTypes();

    type *toCtype();
};

struct TypeArray : TypeNext
{
    TypeArray(TY ty, Type *next);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
};

// Static array, one with a fixed dimension
struct TypeSArray : TypeArray
{
    Expression *dim;

    TypeSArray(Type *t, Expression *dim);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    Type *semantic(Loc loc, Scope *sc);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int isString();
    int isZeroInit(Loc loc);
    structalign_t alignment();
    MATCH constConv(Type *to);
    MATCH implicitConvTo(Type *to);
    Expression *defaultInit(Loc loc);
    Expression *defaultInitLiteral(Loc loc);
    Expression *voidInitLiteral(VarDeclaration *var);
    dt_t **toDt(dt_t **pdt);
    dt_t **toDtElem(dt_t **pdt, Expression *e);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    Expression *toExpression();
    int hasPointers();
    int needsDestruction();
    bool needsNested();
    TypeTuple *toArgTypes();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
    type *toCParamtype();
};

// Dynamic array, no dimension
struct TypeDArray : TypeArray
{
    TypeDArray(Type *t);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    Type *semantic(Loc loc, Scope *sc);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int isString();
    int isZeroInit(Loc loc);
    int checkBoolean();
    MATCH implicitConvTo(Type *to);
    Expression *defaultInit(Loc loc);
    int builtinTypeInfo();
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
};

struct TypeAArray : TypeArray
{
    Type *index;                // key type
    Loc loc;
    Scope *sc;

    StructDeclaration *impl;    // implementation

    TypeAArray(Type *t, Type *index);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    Type *semantic(Loc loc, Scope *sc);
    StructDeclaration *getImpl();
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit(Loc loc);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    int isZeroInit(Loc loc);
    int checkBoolean();
    TypeInfoDeclaration *getTypeInfoDeclaration();
    Type *reliesOnTident(TemplateParameters *tparams);
    Expression *toExpression();
    int hasPointers();
    TypeTuple *toArgTypes();
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    // Back end
    Symbol *aaGetSymbol(const char *func, int flags);

    type *toCtype();
};

struct TypePointer : TypeNext
{
    TypePointer(Type *t);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
    int isscalar();
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
};

struct TypeReference : TypeNext
{
    TypeReference(Type *t);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif
};

enum RET
{
    RETregs     = 1,    // returned in registers
    RETstack    = 2,    // returned on stack
};

enum TRUST
{
    TRUSTdefault = 0,
    TRUSTsystem = 1,    // @system (same as TRUSTdefault)
    TRUSTtrusted = 2,   // @trusted
    TRUSTsafe = 3,      // @safe
};

enum PURE
{
    PUREimpure = 0,     // not pure at all
    PUREweak = 1,       // no mutable globals are read or written
    PUREconst = 2,      // parameters are values or const
    PUREstrong = 3,     // parameters are values or immutable
    PUREfwdref = 4,     // it's pure, but not known which level yet
};

struct TypeFunction : TypeNext
{
    // .next is the return type

    Parameters *parameters;     // function parameters
    int varargs;        // 1: T t, ...) style for variable number of arguments
                        // 2: T t ...) style for variable number of arguments
    bool isnothrow;     // true: nothrow
    bool isproperty;    // can be called without parentheses
    bool isref;         // true: returns a reference
    enum LINK linkage;  // calling convention
    enum TRUST trust;   // level of trust
    enum PURE purity;   // PURExxxx
    bool iswild;        // is inout function
    Expressions *fargs; // function arguments

    int inuse;

    TypeFunction(Parameters *parameters, Type *treturn, int varargs, enum LINK linkage, StorageClass stc = 0);
    const char *kind();
    TypeFunction *copy();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    void purityLevel();
    bool hasMutableIndirectionParams();
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs);
    void toCBufferWithAttributes(OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TypeFunction *attrs, TemplateDeclaration *td);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    void attributesToCBuffer(OutBuffer *buf, int mod);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    Type *reliesOnTident(TemplateParameters *tparams = NULL);
    bool hasLazyParameters();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif
    bool parameterEscapes(Parameter *p);
    Type *addStorageClass(StorageClass stc);

    MATCH callMatch(Expression *ethis, Expressions *toargs, int flag = 0);
    type *toCtype();
    enum RET retStyle();

    unsigned totym();

    Expression *defaultInit(Loc loc);
};

struct TypeDelegate : TypeNext
{
    // .next is a TypeFunction

    TypeDelegate(Type *t);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
    unsigned alignsize();
    MATCH implicitConvTo(Type *to);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
    int checkBoolean();
    TypeInfoDeclaration *getTypeInfoDeclaration();
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    int hasPointers();
    TypeTuple *toArgTypes();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
};

struct TypeQualified : Type
{
    Loc loc;
    Identifiers idents;       // array of Identifier's representing ident.ident.ident etc.

    TypeQualified(TY ty, Loc loc);
    void syntaxCopyHelper(TypeQualified *t);
    void addIdent(Identifier *ident);
    void toCBuffer2Helper(OutBuffer *buf, HdrGenState *hgs);
    void toJson(JsonOut *json);
    d_uns64 size(Loc loc);
    void resolveHelper(Loc loc, Scope *sc, Dsymbol *s, Dsymbol *scopesym,
        Expression **pe, Type **pt, Dsymbol **ps);
};

struct TypeIdentifier : TypeQualified
{
    Identifier *ident;
    Dsymbol *originalSymbol; // The symbol representing this identifier, before alias resolution

    TypeIdentifier(Loc loc, Identifier *ident);
    const char *kind();
    Type *syntaxCopy();
    //char *toChars();
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    Dsymbol *toDsymbol(Scope *sc);
    Type *semantic(Loc loc, Scope *sc);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    Type *reliesOnTident(TemplateParameters *tparams = NULL);
    Expression *toExpression();
};

/* Similar to TypeIdentifier, but with a TemplateInstance as the root
 */
struct TypeInstance : TypeQualified
{
    TemplateInstance *tempinst;

    TypeInstance(Loc loc, TemplateInstance *tempinst);
    const char *kind();
    Type *syntaxCopy();
    //char *toChars();
    //void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    Type *semantic(Loc loc, Scope *sc);
    Dsymbol *toDsymbol(Scope *sc);
    Type *reliesOnTident(TemplateParameters *tparams = NULL);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
};

struct TypeTypeof : TypeQualified
{
    Expression *exp;
    int inuse;

    TypeTypeof(Loc loc, Expression *exp);
    const char *kind();
    Type *syntaxCopy();
    Dsymbol *toDsymbol(Scope *sc);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    Type *semantic(Loc loc, Scope *sc);
    d_uns64 size(Loc loc);
};

struct TypeReturn : TypeQualified
{
    TypeReturn(Loc loc);
    const char *kind();
    Type *syntaxCopy();
    Dsymbol *toDsymbol(Scope *sc);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    Type *semantic(Loc loc, Scope *sc);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
};

struct TypeStruct : Type
{
    StructDeclaration *sym;

    TypeStruct(StructDeclaration *sym);
    const char *kind();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    char *toChars();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    Dsymbol *toDsymbol(Scope *sc);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    structalign_t alignment();
    Expression *defaultInit(Loc loc);
    Expression *defaultInitLiteral(Loc loc);
    Expression *voidInitLiteral(VarDeclaration *var);
    int isZeroInit(Loc loc);
    int isAssignable();
    int checkBoolean();
    int needsDestruction();
    bool needsNested();
    dt_t **toDt(dt_t **pdt);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
    unsigned wildConvTo(Type *tprm);
    Type *toHeadMutable();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
};

struct TypeEnum : Type
{
    EnumDeclaration *sym;

    TypeEnum(EnumDeclaration *sym);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    Dsymbol *toDsymbol(Scope *sc);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *getProperty(Loc loc, Identifier *ident);
    int isintegral();
    int isfloating();
    int isreal();
    int isimaginary();
    int iscomplex();
    int isscalar();
    int isunsigned();
    int checkBoolean();
    int isAssignable();
    int needsDestruction();
    bool needsNested();
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
    Type *toBasetype();
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
};

struct TypeTypedef : Type
{
    TypedefDeclaration *sym;

    TypeTypedef(TypedefDeclaration *sym);
    const char *kind();
    Type *syntaxCopy();
    d_uns64 size(Loc loc);
    unsigned alignsize();
    char *toChars();
    Type *semantic(Loc loc, Scope *sc);
    Dsymbol *toDsymbol(Scope *sc);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    structalign_t alignment();
    Expression *getProperty(Loc loc, Identifier *ident);
    int isintegral();
    int isfloating();
    int isreal();
    int isimaginary();
    int iscomplex();
    int isscalar();
    int isunsigned();
    int checkBoolean();
    int isAssignable();
    int needsDestruction();
    bool needsNested();
    Type *toBasetype();
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
    Type *toHeadMutable();
    Expression *defaultInit(Loc loc);
    Expression *defaultInitLiteral(Loc loc);
    int isZeroInit(Loc loc);
    dt_t **toDt(dt_t **pdt);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
    int hasWild();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();
    type *toCParamtype();
};

struct TypeClass : Type
{
    ClassDeclaration *sym;

    TypeClass(ClassDeclaration *sym);
    const char *kind();
    d_uns64 size(Loc loc);
    char *toChars();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    Dsymbol *toDsymbol(Scope *sc);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
    Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    ClassDeclaration *isClassHandle();
    int isBaseOf(Type *t, int *poffset);
    MATCH implicitConvTo(Type *to);
    MATCH constConv(Type *to);
    unsigned wildConvTo(Type *tprm);
    Type *toHeadMutable();
    Expression *defaultInit(Loc loc);
    int isZeroInit(Loc loc);
    MATCH deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes, unsigned *wildmatch = NULL);
    int isscope();
    int checkBoolean();
    TypeInfoDeclaration *getTypeInfoDeclaration();
    int hasPointers();
    TypeTuple *toArgTypes();
    int builtinTypeInfo();
#if CPP_MANGLE
    void toCppMangle(OutBuffer *buf, CppMangleState *cms);
#endif

    type *toCtype();

    Symbol *toSymbol();
};

struct TypeTuple : Type
{
    Parameters *arguments;      // types making up the tuple

    TypeTuple(Parameters *arguments);
    TypeTuple(Expressions *exps);
    TypeTuple();
    TypeTuple(Type *t1);
    TypeTuple(Type *t1, Type *t2);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    int equals(Object *o);
    Type *reliesOnTident(TemplateParameters *tparams = NULL);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toDecoBuffer(OutBuffer *buf, int flag);
    void toJson(JsonOut *json);
    Expression *getProperty(Loc loc, Identifier *ident);
    Expression *defaultInit(Loc loc);
    TypeInfoDeclaration *getTypeInfoDeclaration();
};

struct TypeSlice : TypeNext
{
    Expression *lwr;
    Expression *upr;

    TypeSlice(Type *next, Expression *lwr, Expression *upr);
    const char *kind();
    Type *syntaxCopy();
    Type *semantic(Loc loc, Scope *sc);
    void resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps);
    void toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod);
    void toJson(JsonOut *json);
};

struct TypeNull : Type
{
    TypeNull();
    const char *kind();

    Type *syntaxCopy();
    void toDecoBuffer(OutBuffer *buf, int flag);
    MATCH implicitConvTo(Type *to);
    int checkBoolean();

    void toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs);
    void toJson(JsonOut *json);

    d_uns64 size(Loc loc);
    //Expression *getProperty(Loc loc, Identifier *ident);
    //Expression *dotExp(Scope *sc, Expression *e, Identifier *ident);
    Expression *defaultInit(Loc loc);
    //Expression *defaultInitLiteral(Loc loc);
};

/**************************************************************/

//enum InOut { None, In, Out, InOut, Lazy };

struct Parameter : Object
{
    //enum InOut inout;
    StorageClass storageClass;
    Type *type;
    Identifier *ident;
    Expression *defaultArg;

    Parameter(StorageClass storageClass, Type *type, Identifier *ident, Expression *defaultArg);
    Parameter *syntaxCopy();
    Type *isLazyArray();
    void toDecoBuffer(OutBuffer *buf);
    int dyncast() { return DYNCAST_PARAMETER; } // kludge for template.isType()
    void toJson(JsonOut *json);
    static Parameters *arraySyntaxCopy(Parameters *args);
    static char *argsTypesToChars(Parameters *args, int varargs);
    static void argsCppMangle(OutBuffer *buf, CppMangleState *cms, Parameters *arguments, int varargs);
    static void argsToCBuffer(OutBuffer *buf, HdrGenState *hgs, Parameters *arguments, int varargs);
    static void argsToDecoBuffer(OutBuffer *buf, Parameters *arguments);
    static int isTPL(Parameters *arguments);
    static size_t dim(Parameters *arguments);
    static Parameter *getNth(Parameters *arguments, size_t nth, size_t *pn = NULL);

    typedef int (*ForeachDg)(void *ctx, size_t paramidx, Parameter *param);
    static int foreach(Parameters *args, ForeachDg dg, void *ctx, size_t *pn=NULL);
};

extern int Tsize_t;
extern int Tptrdiff_t;

int arrayTypeCompatible(Loc loc, Type *t1, Type *t2);
int arrayTypeCompatibleWithoutCasting(Loc loc, Type *t1, Type *t2);
void MODtoBuffer(OutBuffer *buf, unsigned char mod);
char *MODtoChars(unsigned char mod);
int MODimplicitConv(unsigned char modfrom, unsigned char modto);
int MODmethodConv(unsigned char modfrom, unsigned char modto);
int MODmerge(unsigned char mod1, unsigned char mod2);
void identifierToDocBuffer(Identifier* ident, OutBuffer *buf, HdrGenState *hgs);

#endif /* DMD_MTYPE_H */
