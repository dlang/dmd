// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.ctfeexpr;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.complex;
import ddmd.constfold;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dinterpret;
import ddmd.dstruct;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.mtype;
import ddmd.root.longdouble;
import ddmd.root.outbuffer;
import ddmd.root.port;
import ddmd.root.rmem;
import ddmd.target;
import ddmd.tokens;
import ddmd.utf;
import ddmd.visitor;

/***********************************************************
 * Global status of the CTFE engine. Mostly used for performance diagnostics
 */
struct CtfeStatus
{
    extern (C++) static __gshared int callDepth = 0;        // current number of recursive calls

    // When printing a stack trace, suppress this number of calls
    extern (C++) static __gshared int stackTraceCallsToSuppress = 0;

    extern (C++) static __gshared int maxCallDepth = 0;     // highest number of recursive calls
    extern (C++) static __gshared int numArrayAllocs = 0;   // Number of allocated arrays
    extern (C++) static __gshared int numAssignments = 0;   // total number of assignments executed
}

/***********************************************************
 * A reference to a class, or an interface. We need this when we
 * point to a base class (we must record what the type is).
 */
extern (C++) final class ClassReferenceExp : Expression
{
public:
    StructLiteralExp value;

    extern (D) this(Loc loc, StructLiteralExp lit, Type type)
    {
        super(loc, TOKclassreference, __traits(classInstanceSize, ClassReferenceExp));
        assert(lit && lit.sd && lit.sd.isClassDeclaration());
        this.value = lit;
        this.type = type;
    }

    ClassDeclaration originalClass()
    {
        return value.sd.isClassDeclaration();
    }

    VarDeclaration getFieldAt(uint index)
    {
        ClassDeclaration cd = originalClass();
        uint fieldsSoFar = 0;
        while (index - fieldsSoFar >= cd.fields.dim)
        {
            fieldsSoFar += cd.fields.dim;
            cd = cd.baseClass;
        }
        return cd.fields[index - fieldsSoFar];
    }

    // Return index of the field, or -1 if not found
    int getFieldIndex(Type fieldtype, uint fieldoffset)
    {
        ClassDeclaration cd = originalClass();
        uint fieldsSoFar = 0;
        for (size_t j = 0; j < value.elements.dim; j++)
        {
            while (j - fieldsSoFar >= cd.fields.dim)
            {
                fieldsSoFar += cd.fields.dim;
                cd = cd.baseClass;
            }
            VarDeclaration v2 = cd.fields[j - fieldsSoFar];
            if (fieldoffset == v2.offset && fieldtype.size() == v2.type.size())
            {
                return cast(int)(value.elements.dim - fieldsSoFar - cd.fields.dim + (j - fieldsSoFar));
            }
        }
        return -1;
    }

    // Return index of the field, or -1 if not found
    // Same as getFieldIndex, but checks for a direct match with the VarDeclaration
    int findFieldIndexByName(VarDeclaration v)
    {
        ClassDeclaration cd = originalClass();
        size_t fieldsSoFar = 0;
        for (size_t j = 0; j < value.elements.dim; j++)
        {
            while (j - fieldsSoFar >= cd.fields.dim)
            {
                fieldsSoFar += cd.fields.dim;
                cd = cd.baseClass;
            }
            VarDeclaration v2 = cd.fields[j - fieldsSoFar];
            if (v == v2)
            {
                return cast(int)(value.elements.dim - fieldsSoFar - cd.fields.dim + (j - fieldsSoFar));
            }
        }
        return -1;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * An uninitialized value
 */
extern (C++) final class VoidInitExp : Expression
{
public:
    VarDeclaration var;

    extern (D) this(VarDeclaration var, Type type)
    {
        super(var.loc, TOKvoid, __traits(classInstanceSize, VoidInitExp));
        this.var = var;
        this.type = var.type;
    }

    override char* toChars()
    {
        return cast(char*)"void";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

// Return index of the field, or -1 if not found
// Same as getFieldIndex, but checks for a direct match with the VarDeclaration
extern (C++) int findFieldIndexByName(StructDeclaration sd, VarDeclaration v)
{
    for (size_t i = 0; i < sd.fields.dim; ++i)
    {
        if (sd.fields[i] == v)
            return cast(int)i;
    }
    return -1;
}

/***********************************************************
 * Fake class which holds the thrown exception.
 * Used for implementing exception handling.
 */
extern (C++) final class ThrownExceptionExp : Expression
{
public:
    ClassReferenceExp thrown;   // the thing being tossed

    extern (D) this(Loc loc, ClassReferenceExp victim)
    {
        super(loc, TOKthrownexception, __traits(classInstanceSize, ThrownExceptionExp));
        this.thrown = victim;
        this.type = victim.type;
    }

    override char* toChars()
    {
        return cast(char*)"CTFE ThrownException";
    }

    // Generate an error message when this exception is not caught
    void generateUncaughtError()
    {
        Expression e = resolveSlice((*thrown.value.elements)[0]);
        StringExp se = e.toStringExp();
        thrown.error("uncaught CTFE exception %s(%s)", thrown.type.toChars(), se ? se.toChars() : e.toChars());
        /* Also give the line where the throw statement was. We won't have it
         * in the case where the ThrowStatement is generated internally
         * (eg, in ScopeStatement)
         */
        if (loc.filename && !loc.equals(thrown.loc))
            errorSupplemental(loc, "thrown from here");
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * This type is only used by the interpreter.
 */
extern (C++) final class CTFEExp : Expression
{
public:
    extern (D) this(TOK tok)
    {
        super(Loc(), tok, __traits(classInstanceSize, CTFEExp));
        type = Type.tvoid;
    }

    override char* toChars()
    {
        switch (op)
        {
        case TOKcantexp:
            return cast(char*)"<cant>";
        case TOKvoidexp:
            return cast(char*)"<void>";
        case TOKbreak:
            return cast(char*)"<break>";
        case TOKcontinue:
            return cast(char*)"<continue>";
        case TOKgoto:
            return cast(char*)"<goto>";
        default:
            assert(0);
        }
    }

    extern (C++) static __gshared CTFEExp cantexp;
    extern (C++) static __gshared CTFEExp voidexp;
    extern (C++) static __gshared CTFEExp breakexp;
    extern (C++) static __gshared CTFEExp continueexp;
    extern (C++) static __gshared CTFEExp gotoexp;

    static bool isCantExp(Expression e)
    {
        return e && e.op == TOKcantexp;
    }

    static bool isGotoExp(Expression e)
    {
        return e && e.op == TOKgoto;
    }
}

// True if 'e' is CTFEExp::cantexp, or an exception
extern (C++) bool exceptionOrCantInterpret(Expression e)
{
    return e && (e.op == TOKcantexp || e.op == TOKthrownexception);
}

/************** Aggregate literals (AA/string/array/struct) ******************/
// Given expr, which evaluates to an array/AA/string literal,
// return true if it needs to be copied
extern (C++) bool needToCopyLiteral(Expression expr)
{
    for (;;)
    {
        switch (expr.op)
        {
        case TOKarrayliteral:
            return (cast(ArrayLiteralExp)expr).ownedByCtfe == OWNEDcode;
        case TOKassocarrayliteral:
            return (cast(AssocArrayLiteralExp)expr).ownedByCtfe == OWNEDcode;
        case TOKstructliteral:
            return (cast(StructLiteralExp)expr).ownedByCtfe == OWNEDcode;
        case TOKstring:
        case TOKthis:
        case TOKvar:
            return false;
        case TOKassign:
            return false;
        case TOKindex:
        case TOKdotvar:
        case TOKslice:
        case TOKcast:
            expr = (cast(UnaExp)expr).e1;
            continue;
        case TOKcat:
            return needToCopyLiteral((cast(BinExp)expr).e1) || needToCopyLiteral((cast(BinExp)expr).e2);
        case TOKcatass:
            expr = (cast(BinExp)expr).e2;
            continue;
        default:
            return false;
        }
    }
}

extern (C++) Expressions* copyLiteralArray(Expressions* oldelems, Expression basis = null)
{
    if (!oldelems)
        return oldelems;
    CtfeStatus.numArrayAllocs++;
    auto newelems = new Expressions();
    newelems.setDim(oldelems.dim);
    for (size_t i = 0; i < oldelems.dim; i++)
    {
        auto el = (*oldelems)[i];
        if (!el)
            el = basis;
        (*newelems)[i] = copyLiteral(el).copy();
    }
    return newelems;
}

// Make a copy of the ArrayLiteral, AALiteral, String, or StructLiteral.
// This value will be used for in-place modification.
extern (C++) UnionExp copyLiteral(Expression e)
{
    UnionExp ue;
    if (e.op == TOKstring) // syntaxCopy doesn't make a copy for StringExp!
    {
        StringExp se = cast(StringExp)e;
        char* s = cast(char*)mem.xcalloc(se.len + 1, se.sz);
        memcpy(s, se.string, se.len * se.sz);
        emplaceExp!(StringExp)(&ue, se.loc, s, se.len);
        StringExp se2 = cast(StringExp)ue.exp();
        se2.committed = se.committed;
        se2.postfix = se.postfix;
        se2.type = se.type;
        se2.sz = se.sz;
        se2.ownedByCtfe = OWNEDctfe;
        return ue;
    }
    if (e.op == TOKarrayliteral)
    {
        auto ale = cast(ArrayLiteralExp)e;
        auto basis = ale.basis ? copyLiteral(ale.basis).copy() : null;
        auto elements = copyLiteralArray(ale.elements, ale.basis);

        emplaceExp!(ArrayLiteralExp)(&ue, e.loc, elements);

        ArrayLiteralExp r = cast(ArrayLiteralExp)ue.exp();
        r.type = e.type;
        r.ownedByCtfe = OWNEDctfe;
        return ue;
    }
    if (e.op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp aae = cast(AssocArrayLiteralExp)e;
        emplaceExp!(AssocArrayLiteralExp)(&ue, e.loc, copyLiteralArray(aae.keys), copyLiteralArray(aae.values));
        AssocArrayLiteralExp r = cast(AssocArrayLiteralExp)ue.exp();
        r.type = e.type;
        r.ownedByCtfe = OWNEDctfe;
        return ue;
    }
    if (e.op == TOKstructliteral)
    {
        /* syntaxCopy doesn't work for struct literals, because of a nasty special
         * case: block assignment is permitted inside struct literals, eg,
         * an int[4] array can be initialized with a single int.
         */
        StructLiteralExp se = cast(StructLiteralExp)e;
        Expressions* oldelems = se.elements;
        auto newelems = new Expressions();
        newelems.setDim(oldelems.dim);
        for (size_t i = 0; i < newelems.dim; i++)
        {
            Expression m = (*oldelems)[i];
            // We need the struct definition to detect block assignment
            AggregateDeclaration sd = se.sd;
            VarDeclaration v = sd.fields[i];
            // If it is a void assignment, use the default initializer
            if (!m)
                m = voidInitLiteral(v.type, v).copy();
            if ((v.type.ty != m.type.ty) && v.type.ty == Tsarray)
            {
                // Block assignment from inside struct literals
                TypeSArray tsa = cast(TypeSArray)v.type;
                uinteger_t length = tsa.dim.toInteger();
                m = createBlockDuplicatedArrayLiteral(e.loc, v.type, m, cast(size_t)length);
            }
            else if (v.type.ty != Tarray && v.type.ty != Taarray) // NOTE: do not copy array references
                m = copyLiteral(m).copy();
            (*newelems)[i] = m;
        }
        emplaceExp!(StructLiteralExp)(&ue, e.loc, se.sd, newelems, se.stype);
        StructLiteralExp r = cast(StructLiteralExp)ue.exp();
        r.type = e.type;
        r.ownedByCtfe = OWNEDctfe;
        r.origin = (cast(StructLiteralExp)e).origin;
        return ue;
    }
    if (e.op == TOKfunction || e.op == TOKdelegate || e.op == TOKsymoff || e.op == TOKnull || e.op == TOKvar || e.op == TOKdotvar || e.op == TOKint64 || e.op == TOKfloat64 || e.op == TOKchar || e.op == TOKcomplex80 || e.op == TOKvoid || e.op == TOKvector || e.op == TOKtypeid)
    {
        // Simple value types
        // Keep e1 for DelegateExp and DotVarExp
        emplaceExp!(UnionExp)(&ue, e);
        Expression r = ue.exp();
        r.type = e.type;
        return ue;
    }
    if (isPointer(e.type))
    {
        // For pointers, we only do a shallow copy.
        if (e.op == TOKaddress)
            emplaceExp!(AddrExp)(&ue, e.loc, (cast(AddrExp)e).e1);
        else if (e.op == TOKindex)
            emplaceExp!(IndexExp)(&ue, e.loc, (cast(IndexExp)e).e1, (cast(IndexExp)e).e2);
        else if (e.op == TOKdotvar)
        {
            emplaceExp!(DotVarExp)(&ue, e.loc, (cast(DotVarExp)e).e1, (cast(DotVarExp)e).var, (cast(DotVarExp)e).hasOverloads);
        }
        else
            assert(0);
        Expression r = ue.exp();
        r.type = e.type;
        return ue;
    }
    if (e.op == TOKslice)
    {
        SliceExp se = cast(SliceExp)e;
        if (se.type.toBasetype().ty == Tsarray)
        {
            // same with resolveSlice()
            if (se.e1.op == TOKnull)
            {
                emplaceExp!(NullExp)(&ue, se.loc, se.type);
                return ue;
            }
            ue = Slice(se.type, se.e1, se.lwr, se.upr);
            assert(ue.exp().op == TOKarrayliteral);
            ArrayLiteralExp r = cast(ArrayLiteralExp)ue.exp();
            r.elements = copyLiteralArray(r.elements);
            r.ownedByCtfe = OWNEDctfe;
            return ue;
        }
        else
        {
            // Array slices only do a shallow copy
            emplaceExp!(SliceExp)(&ue, e.loc, se.e1, se.lwr, se.upr);
            Expression r = ue.exp();
            r.type = e.type;
            return ue;
        }
    }
    if (e.op == TOKclassreference)
    {
        emplaceExp!(ClassReferenceExp)(&ue, e.loc, (cast(ClassReferenceExp)e).value, e.type);
        return ue;
    }
    if (e.op == TOKerror)
    {
        emplaceExp!(UnionExp)(&ue, e);
        return ue;
    }
    e.error("CTFE internal error: literal %s", e.toChars());
    assert(0);
}

/* Deal with type painting.
 * Type painting is a major nuisance: we can't just set
 * e->type = type, because that would change the original literal.
 * But, we can't simply copy the literal either, because that would change
 * the values of any pointers.
 */
extern (C++) Expression paintTypeOntoLiteral(Type type, Expression lit)
{
    if (lit.type.equals(type))
        return lit;
    return paintTypeOntoLiteralCopy(type, lit).copy();
}

extern (C++) UnionExp paintTypeOntoLiteralCopy(Type type, Expression lit)
{
    UnionExp ue;
    if (lit.type.equals(type))
    {
        emplaceExp!(UnionExp)(&ue, lit);
        return ue;
    }
    // If it is a cast to inout, retain the original type of the referenced part.
    if (type.hasWild() && type.hasPointers())
    {
        emplaceExp!(UnionExp)(&ue, lit);
        ue.exp().type = type;
        return ue;
    }
    if (lit.op == TOKslice)
    {
        SliceExp se = cast(SliceExp)lit;
        emplaceExp!(SliceExp)(&ue, lit.loc, se.e1, se.lwr, se.upr);
    }
    else if (lit.op == TOKindex)
    {
        IndexExp ie = cast(IndexExp)lit;
        emplaceExp!(IndexExp)(&ue, lit.loc, ie.e1, ie.e2);
    }
    else if (lit.op == TOKarrayliteral)
    {
        emplaceExp!(SliceExp)(&ue, lit.loc, lit, new IntegerExp(Loc(), 0, Type.tsize_t), ArrayLength(Type.tsize_t, lit).copy());
    }
    else if (lit.op == TOKstring)
    {
        // For strings, we need to introduce another level of indirection
        emplaceExp!(SliceExp)(&ue, lit.loc, lit, new IntegerExp(Loc(), 0, Type.tsize_t), ArrayLength(Type.tsize_t, lit).copy());
    }
    else if (lit.op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp aae = cast(AssocArrayLiteralExp)lit;
        // TODO: we should be creating a reference to this AAExp, not
        // just a ref to the keys and values.
        OwnedBy wasOwned = aae.ownedByCtfe;
        emplaceExp!(AssocArrayLiteralExp)(&ue, lit.loc, aae.keys, aae.values);
        aae = cast(AssocArrayLiteralExp)ue.exp();
        aae.ownedByCtfe = wasOwned;
    }
    else
    {
        // Can't type paint from struct to struct*; this needs another
        // level of indirection
        if (lit.op == TOKstructliteral && isPointer(type))
            lit.error("CTFE internal error: painting %s", type.toChars());
        ue = copyLiteral(lit);
    }
    ue.exp().type = type;
    return ue;
}

extern (C++) Expression resolveSlice(Expression e)
{
    if (e.op != TOKslice)
        return e;
    SliceExp se = cast(SliceExp)e;
    if (se.e1.op == TOKnull)
        return se.e1;
    return Slice(e.type, se.e1, se.lwr, se.upr).copy();
}

/* Determine the array length, without interpreting it.
 * e must be an array literal, or a slice
 * It's very wasteful to resolve the slice when we only
 * need the length.
 */
extern (C++) uinteger_t resolveArrayLength(Expression e)
{
    if (e.op == TOKvector)
        e = (cast(VectorExp)e).e1;
    if (e.op == TOKnull)
        return 0;
    if (e.op == TOKslice)
    {
        uinteger_t ilo = (cast(SliceExp)e).lwr.toInteger();
        uinteger_t iup = (cast(SliceExp)e).upr.toInteger();
        return iup - ilo;
    }
    if (e.op == TOKstring)
    {
        return (cast(StringExp)e).len;
    }
    if (e.op == TOKarrayliteral)
    {
        ArrayLiteralExp ale = cast(ArrayLiteralExp)e;
        return ale.elements ? ale.elements.dim : 0;
    }
    if (e.op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp ale = cast(AssocArrayLiteralExp)e;
        return ale.keys.dim;
    }
    assert(0);
}

/******************************
 * Helper for NewExp
 * Create an array literal consisting of 'elem' duplicated 'dim' times.
 */
extern (C++) ArrayLiteralExp createBlockDuplicatedArrayLiteral(Loc loc, Type type, Expression elem, size_t dim)
{
    auto elements = new Expressions();
    elements.setDim(dim);
    bool mustCopy = needToCopyLiteral(elem);
    if (type.ty == Tsarray && type.nextOf().ty == Tsarray && elem.type.ty != Tsarray)
    {
        // If it is a multidimensional array literal, do it recursively
        elem = createBlockDuplicatedArrayLiteral(loc, type.nextOf(), elem, cast(size_t)(cast(TypeSArray)type.nextOf()).dim.toInteger());
        mustCopy = true;
    }
    for (size_t i = 0; i < dim; i++)
    {
        (*elements)[i] = mustCopy ? copyLiteral(elem).copy() : elem;
    }
    auto ale = new ArrayLiteralExp(loc, elements);
    ale.type = type;
    ale.ownedByCtfe = OWNEDctfe;
    return ale;
}

/******************************
 * Helper for NewExp
 * Create a string literal consisting of 'value' duplicated 'dim' times.
 */
extern (C++) StringExp createBlockDuplicatedStringLiteral(Loc loc, Type type, uint value, size_t dim, ubyte sz)
{
    char* s = cast(char*)mem.xcalloc(dim + 1, sz);
    for (size_t elemi = 0; elemi < dim; ++elemi)
    {
        switch (sz)
        {
        case 1:
            s[elemi] = cast(char)value;
            break;
        case 2:
            (cast(ushort*)s)[elemi] = cast(ushort)value;
            break;
        case 4:
            (cast(uint*)s)[elemi] = value;
            break;
        default:
            assert(0);
        }
    }
    auto se = new StringExp(loc, s, dim);
    se.type = type;
    se.sz = sz;
    se.committed = true;
    se.ownedByCtfe = OWNEDctfe;
    return se;
}

// Return true if t is an AA
extern (C++) bool isAssocArray(Type t)
{
    t = t.toBasetype();
    if (t.ty == Taarray)
        return true;
    return false;
}

// Given a template AA type, extract the corresponding built-in AA type
extern (C++) TypeAArray toBuiltinAAType(Type t)
{
    t = t.toBasetype();
    if (t.ty == Taarray)
        return cast(TypeAArray)t;
    assert(0);
}

/************** TypeInfo operations ************************************/
// Return true if type is TypeInfo_Class
extern (C++) bool isTypeInfo_Class(Type type)
{
    return type.ty == Tclass && (Type.dtypeinfo == (cast(TypeClass)type).sym || Type.dtypeinfo.isBaseOf((cast(TypeClass)type).sym, null));
}

/************** Pointer operations ************************************/
// Return true if t is a pointer (not a function pointer)
extern (C++) bool isPointer(Type t)
{
    Type tb = t.toBasetype();
    return tb.ty == Tpointer && tb.nextOf().ty != Tfunction;
}

// For CTFE only. Returns true if 'e' is true or a non-null pointer.
extern (C++) bool isTrueBool(Expression e)
{
    return e.isBool(true) || ((e.type.ty == Tpointer || e.type.ty == Tclass) && e.op != TOKnull);
}

/* Is it safe to convert from srcPointee* to destPointee* ?
 * srcPointee is the genuine type (never void).
 * destPointee may be void.
 */
extern (C++) bool isSafePointerCast(Type srcPointee, Type destPointee)
{
    // It's safe to cast S** to D** if it's OK to cast S* to D*
    while (srcPointee.ty == Tpointer && destPointee.ty == Tpointer)
    {
        srcPointee = srcPointee.nextOf();
        destPointee = destPointee.nextOf();
    }
    // It's OK if both are the same (modulo const)
    if (srcPointee.constConv(destPointee))
        return true;
    // It's OK if function pointers differ only in safe/pure/nothrow
    if (srcPointee.ty == Tfunction && destPointee.ty == Tfunction)
        return srcPointee.covariant(destPointee) == 1;
    // it's OK to cast to void*
    if (destPointee.ty == Tvoid)
        return true;
    // It's OK to cast from V[K] to void*
    if (srcPointee.ty == Taarray && destPointee == Type.tvoidptr)
        return true;
    // It's OK if they are the same size (static array of) integers, eg:
    //     int*     --> uint*
    //     int[5][] --> uint[5][]
    if (srcPointee.ty == Tsarray && destPointee.ty == Tsarray)
    {
        if (srcPointee.size() != destPointee.size())
            return false;
        srcPointee = srcPointee.baseElemOf();
        destPointee = destPointee.baseElemOf();
    }
    return srcPointee.isintegral() && destPointee.isintegral() && srcPointee.size() == destPointee.size();
}

extern (C++) Expression getAggregateFromPointer(Expression e, dinteger_t* ofs)
{
    *ofs = 0;
    if (e.op == TOKaddress)
        e = (cast(AddrExp)e).e1;
    if (e.op == TOKsymoff)
        *ofs = (cast(SymOffExp)e).offset;
    if (e.op == TOKdotvar)
    {
        Expression ex = (cast(DotVarExp)e).e1;
        VarDeclaration v = (cast(DotVarExp)e).var.isVarDeclaration();
        assert(v);
        StructLiteralExp se = ex.op == TOKclassreference ? (cast(ClassReferenceExp)ex).value : cast(StructLiteralExp)ex;
        // We can't use getField, because it makes a copy
        uint i;
        if (ex.op == TOKclassreference)
            i = (cast(ClassReferenceExp)ex).getFieldIndex(e.type, v.offset);
        else
            i = se.getFieldIndex(e.type, v.offset);
        e = (*se.elements)[i];
    }
    if (e.op == TOKindex)
    {
        IndexExp ie = cast(IndexExp)e;
        // Note that each AA element is part of its own memory block
        if ((ie.e1.type.ty == Tarray || ie.e1.type.ty == Tsarray || ie.e1.op == TOKstring || ie.e1.op == TOKarrayliteral) && ie.e2.op == TOKint64)
        {
            *ofs = ie.e2.toInteger();
            return ie.e1;
        }
    }
    if (e.op == TOKslice && e.type.toBasetype().ty == Tsarray)
    {
        SliceExp se = cast(SliceExp)e;
        if ((se.e1.type.ty == Tarray || se.e1.type.ty == Tsarray || se.e1.op == TOKstring || se.e1.op == TOKarrayliteral) && se.lwr.op == TOKint64)
        {
            *ofs = se.lwr.toInteger();
            return se.e1;
        }
    }
    return e;
}

/** Return true if agg1 and agg2 are pointers to the same memory block
 */
extern (C++) bool pointToSameMemoryBlock(Expression agg1, Expression agg2)
{
    if (agg1 == agg2)
        return true;
    // For integers cast to pointers, we regard them as non-comparable
    // unless they are identical. (This may be overly strict).
    if (agg1.op == TOKint64 && agg2.op == TOKint64 && agg1.toInteger() == agg2.toInteger())
    {
        return true;
    }
    // Note that type painting can occur with VarExp, so we
    // must compare the variables being pointed to.
    if (agg1.op == TOKvar && agg2.op == TOKvar && (cast(VarExp)agg1).var == (cast(VarExp)agg2).var)
    {
        return true;
    }
    if (agg1.op == TOKsymoff && agg2.op == TOKsymoff && (cast(SymOffExp)agg1).var == (cast(SymOffExp)agg2).var)
    {
        return true;
    }
    return false;
}

// return e1 - e2 as an integer, or error if not possible
extern (C++) UnionExp pointerDifference(Loc loc, Type type, Expression e1, Expression e2)
{
    UnionExp ue;
    dinteger_t ofs1, ofs2;
    Expression agg1 = getAggregateFromPointer(e1, &ofs1);
    Expression agg2 = getAggregateFromPointer(e2, &ofs2);
    if (agg1 == agg2)
    {
        Type pointee = (cast(TypePointer)agg1.type).next;
        dinteger_t sz = pointee.size();
        emplaceExp!(IntegerExp)(&ue, loc, (ofs1 - ofs2) * sz, type);
    }
    else if (agg1.op == TOKstring && agg2.op == TOKstring)
    {
        if ((cast(StringExp)agg1).string == (cast(StringExp)agg2).string)
        {
            Type pointee = (cast(TypePointer)agg1.type).next;
            dinteger_t sz = pointee.size();
            emplaceExp!(IntegerExp)(&ue, loc, (ofs1 - ofs2) * sz, type);
        }
    }
    else if (agg1.op == TOKsymoff && agg2.op == TOKsymoff && (cast(SymOffExp)agg1).var == (cast(SymOffExp)agg2).var)
    {
        emplaceExp!(IntegerExp)(&ue, loc, ofs1 - ofs2, type);
    }
    else
    {
        error(loc, "%s - %s cannot be interpreted at compile time: cannot subtract pointers to two different memory blocks", e1.toChars(), e2.toChars());
        emplaceExp!(CTFEExp)(&ue, TOKcantexp);
    }
    return ue;
}

// Return eptr op e2, where eptr is a pointer, e2 is an integer,
// and op is TOKadd or TOKmin
extern (C++) UnionExp pointerArithmetic(Loc loc, TOK op, Type type, Expression eptr, Expression e2)
{
    UnionExp ue;
    if (eptr.type.nextOf().ty == Tvoid)
    {
        error(loc, "cannot perform arithmetic on void* pointers at compile time");
    Lcant:
        emplaceExp!(CTFEExp)(&ue, TOKcantexp);
        return ue;
    }
    dinteger_t ofs1;
    if (eptr.op == TOKaddress)
        eptr = (cast(AddrExp)eptr).e1;
    Expression agg1 = getAggregateFromPointer(eptr, &ofs1);
    if (agg1.op == TOKsymoff)
    {
        if ((cast(SymOffExp)agg1).var.type.ty != Tsarray)
        {
            error(loc, "cannot perform pointer arithmetic on arrays of unknown length at compile time");
            goto Lcant;
        }
    }
    else if (agg1.op != TOKstring && agg1.op != TOKarrayliteral)
    {
        error(loc, "cannot perform pointer arithmetic on non-arrays at compile time");
        goto Lcant;
    }
    dinteger_t ofs2 = e2.toInteger();
    Type pointee = (cast(TypeNext)agg1.type.toBasetype()).next;
    dinteger_t sz = pointee.size();
    sinteger_t indx;
    dinteger_t len;
    if (agg1.op == TOKsymoff)
    {
        indx = ofs1 / sz;
        len = (cast(TypeSArray)(cast(SymOffExp)agg1).var.type).dim.toInteger();
    }
    else
    {
        Expression dollar = ArrayLength(Type.tsize_t, agg1).copy();
        assert(!CTFEExp.isCantExp(dollar));
        indx = ofs1;
        len = dollar.toInteger();
    }
    if (op == TOKadd || op == TOKaddass || op == TOKplusplus)
        indx += ofs2 / sz;
    else if (op == TOKmin || op == TOKminass || op == TOKminusminus)
        indx -= ofs2 / sz;
    else
    {
        error(loc, "CTFE internal error: bad pointer operation");
        goto Lcant;
    }
    if (indx < 0 || len < indx)
    {
        error(loc, "cannot assign pointer to index %lld inside memory block [0..%lld]", indx, len);
        goto Lcant;
    }
    if (agg1.op == TOKsymoff)
    {
        emplaceExp!(SymOffExp)(&ue, loc, (cast(SymOffExp)agg1).var, indx * sz);
        SymOffExp se = cast(SymOffExp)ue.exp();
        se.type = type;
        return ue;
    }
    if (agg1.op != TOKarrayliteral && agg1.op != TOKstring)
    {
        error(loc, "CTFE internal error: pointer arithmetic %s", agg1.toChars());
        goto Lcant;
    }
    if (eptr.type.toBasetype().ty == Tsarray)
    {
        dinteger_t dim = (cast(TypeSArray)eptr.type.toBasetype()).dim.toInteger();
        // Create a CTFE pointer &agg1[indx .. indx+dim]
        auto se = new SliceExp(loc, agg1, new IntegerExp(loc, indx, Type.tsize_t), new IntegerExp(loc, indx + dim, Type.tsize_t));
        se.type = type.toBasetype().nextOf();
        emplaceExp!(AddrExp)(&ue, loc, se);
        ue.exp().type = type;
        return ue;
    }
    // Create a CTFE pointer &agg1[indx]
    auto ofs = new IntegerExp(loc, indx, Type.tsize_t);
    Expression ie = new IndexExp(loc, agg1, ofs);
    ie.type = type.toBasetype().nextOf(); // Bugzilla 13992
    emplaceExp!(AddrExp)(&ue, loc, ie);
    ue.exp().type = type;
    return ue;
}

// Return 1 if true, 0 if false
// -1 if comparison is illegal because they point to non-comparable memory blocks
extern (C++) int comparePointers(Loc loc, TOK op, Type type, Expression agg1, dinteger_t ofs1, Expression agg2, dinteger_t ofs2)
{
    if (pointToSameMemoryBlock(agg1, agg2))
    {
        int n;
        switch (op)
        {
        case TOKlt:
            n = (ofs1 < ofs2);
            break;
        case TOKle:
            n = (ofs1 <= ofs2);
            break;
        case TOKgt:
            n = (ofs1 > ofs2);
            break;
        case TOKge:
            n = (ofs1 >= ofs2);
            break;
        case TOKidentity:
        case TOKequal:
            n = (ofs1 == ofs2);
            break;
        case TOKnotidentity:
        case TOKnotequal:
            n = (ofs1 != ofs2);
            break;
        default:
            assert(0);
        }
        return n;
    }
    bool null1 = (agg1.op == TOKnull);
    bool null2 = (agg2.op == TOKnull);
    int cmp;
    if (null1 || null2)
    {
        switch (op)
        {
        case TOKlt:
            cmp = null1 && !null2;
            break;
        case TOKgt:
            cmp = !null1 && null2;
            break;
        case TOKle:
            cmp = null1;
            break;
        case TOKge:
            cmp = null2;
            break;
        case TOKidentity:
        case TOKequal:
        case TOKnotidentity:
            // 'cmp' gets inverted below
        case TOKnotequal:
            cmp = (null1 == null2);
            break;
        default:
            assert(0);
        }
    }
    else
    {
        switch (op)
        {
        case TOKidentity:
        case TOKequal:
        case TOKnotidentity:
            // 'cmp' gets inverted below
        case TOKnotequal:
            cmp = 0;
            break;
        default:
            return -1; // memory blocks are different
        }
    }
    if (op == TOKnotidentity || op == TOKnotequal)
        cmp ^= 1;
    return cmp;
}

// True if conversion from type 'from' to 'to' involves a reinterpret_cast
// floating point -> integer or integer -> floating point
extern (C++) bool isFloatIntPaint(Type to, Type from)
{
    return from.size() == to.size() && (from.isintegral() && to.isfloating() || from.isfloating() && to.isintegral());
}

// Reinterpret float/int value 'fromVal' as a float/integer of type 'to'.
extern (C++) Expression paintFloatInt(Expression fromVal, Type to)
{
    if (exceptionOrCantInterpret(fromVal))
        return fromVal;
    assert(to.size() == 4 || to.size() == 8);
    return Target.paintAsType(fromVal, to);
}

/***********************************************
 Primitive integer operations
 ***********************************************/
/**   e = OP e
 */
/* DEAD: Logic is now found in constfold.d in functions:
    Neg, Com */
extern (C++) void intUnary(TOK op, IntegerExp e)
{
    switch (op)
    {
    case TOKneg:
        e.setInteger(-e.getInteger());
        break;
    case TOKtilde:
        e.setInteger(~e.getInteger());
        break;
    default:
        assert(0);
    }
}

/** dest = e1 OP e2;
 */
/* DEAD: Logic is now found in constfold.d in functions:
    And, Or, Xor, Add, Min, Mul, Div, Mod, Pow, Shl, Shr, Ushr, Identity, Equal */
extern (C++) void intBinary(TOK op, IntegerExp dest, Type type, IntegerExp e1, IntegerExp e2)
{
    dinteger_t result;
    switch (op)
    {
    case TOKand:
        result = e1.getInteger() & e2.getInteger();
        break;
    case TOKor:
        result = e1.getInteger() | e2.getInteger();
        break;
    case TOKxor:
        result = e1.getInteger() ^ e2.getInteger();
        break;
    case TOKadd:
        result = e1.getInteger() + e2.getInteger();
        break;
    case TOKmin:
        result = e1.getInteger() - e2.getInteger();
        break;
    case TOKmul:
        result = e1.getInteger() * e2.getInteger();
        break;
    case TOKdiv:
        {
            sinteger_t n1 = e1.getInteger();
            sinteger_t n2 = e2.getInteger();
            if (n2 == 0)
            {
                e2.error("divide by 0");
                result = 1;
            }
            else if (e1.type.isunsigned() || e2.type.isunsigned())
                result = (cast(dinteger_t)n1) / (cast(dinteger_t)n2);
            else
                result = n1 / n2;
            break;
        }
    case TOKmod:
        {
            sinteger_t n1 = e1.getInteger();
            sinteger_t n2 = e2.getInteger();
            if (n2 == 0)
            {
                e2.error("divide by 0");
                n2 = 1;
            }
            if (n2 == -1 && !type.isunsigned())
            {
                // Check for int.min % -1
                if (n1 == 0xFFFFFFFF80000000UL && type.toBasetype().ty != Tint64)
                {
                    e2.error("integer overflow: int.min % -1");
                    n2 = 1;
                }
                else if (n1 == 0x8000000000000000L) // long.min % -1
                {
                    e2.error("integer overflow: long.min % -1");
                    n2 = 1;
                }
            }
            if (e1.type.isunsigned() || e2.type.isunsigned())
                result = (cast(dinteger_t)n1) % (cast(dinteger_t)n2);
            else
                result = n1 % n2;
            break;
        }
    case TOKpow:
        {
            dinteger_t n = e2.getInteger();
            if (!e2.type.isunsigned() && cast(sinteger_t)n < 0)
            {
                e2.error("integer ^^ -integer: total loss of precision");
                n = 1;
            }
            uinteger_t r = e1.getInteger();
            result = 1;
            while (n != 0)
            {
                if (n & 1)
                    result = result * r;
                n >>= 1;
                r = r * r;
            }
            break;
        }
    case TOKshl:
        result = e1.getInteger() << e2.getInteger();
        break;
    case TOKshr:
        {
            dinteger_t value = e1.getInteger();
            dinteger_t dcount = e2.getInteger();
            assert(dcount <= 0xFFFFFFFF);
            uint count = cast(uint)dcount;
            switch (e1.type.toBasetype().ty)
            {
            case Tint8:
                result = cast(d_int8)value >> count;
                break;
            case Tuns8:
            case Tchar:
                result = cast(d_uns8)value >> count;
                break;
            case Tint16:
                result = cast(d_int16)value >> count;
                break;
            case Tuns16:
            case Twchar:
                result = cast(d_uns16)value >> count;
                break;
            case Tint32:
                result = cast(d_int32)value >> count;
                break;
            case Tuns32:
            case Tdchar:
                result = cast(d_uns32)value >> count;
                break;
            case Tint64:
                result = cast(d_int64)value >> count;
                break;
            case Tuns64:
                result = cast(d_uns64)value >> count;
                break;
            default:
                assert(0);
            }
            break;
        }
    case TOKushr:
        {
            dinteger_t value = e1.getInteger();
            dinteger_t dcount = e2.getInteger();
            assert(dcount <= 0xFFFFFFFF);
            uint count = cast(uint)dcount;
            switch (e1.type.toBasetype().ty)
            {
            case Tint8:
            case Tuns8:
            case Tchar:
                // Possible only with >>>=. >>> always gets promoted to int.
                result = (value & 0xFF) >> count;
                break;
            case Tint16:
            case Tuns16:
            case Twchar:
                // Possible only with >>>=. >>> always gets promoted to int.
                result = (value & 0xFFFF) >> count;
                break;
            case Tint32:
            case Tuns32:
            case Tdchar:
                result = (value & 0xFFFFFFFF) >> count;
                break;
            case Tint64:
            case Tuns64:
                result = cast(d_uns64)value >> count;
                break;
            default:
                assert(0);
            }
            break;
        }
    case TOKequal:
    case TOKidentity:
        result = (e1.getInteger() == e2.getInteger());
        break;
    case TOKnotequal:
    case TOKnotidentity:
        result = (e1.getInteger() != e2.getInteger());
        break;
    default:
        assert(0);
    }
    dest.setInteger(result);
    dest.type = type;
}

/******** Constant folding, with support for CTFE ***************************/
/// Return true if non-pointer expression e can be compared
/// with >,is, ==, etc, using ctfeCmp, ctfeEqual, ctfeIdentity
extern (C++) bool isCtfeComparable(Expression e)
{
    if (e.op == TOKslice)
        e = (cast(SliceExp)e).e1;
    if (e.isConst() != 1)
    {
        if (e.op == TOKnull || e.op == TOKstring || e.op == TOKfunction || e.op == TOKdelegate || e.op == TOKarrayliteral || e.op == TOKstructliteral || e.op == TOKassocarrayliteral || e.op == TOKclassreference)
        {
            return true;
        }
        // Bugzilla 14123: TypeInfo object is comparable in CTFE
        if (e.op == TOKtypeid)
            return true;
        return false;
    }
    return true;
}

/// Map TOK comparison ops
private bool numCmp(N)(TOK op, N n1, N n2)
{
    switch (op)
    {
    case TOKlt:
        return n1 < n2;
    case TOKle:
        return n1 <= n2;
    case TOKgt:
        return n1 > n2;
    case TOKge:
        return n1 >= n2;
    case TOKleg:
        return true;
    case TOKlg:
        return n1 != n2;

    case TOKunord:
        return false;
    case TOKue:
        return n1 == n2;
    case TOKug:
        return n1 > n2;
    case TOKuge:
        return n1 >= n2;
    case TOKul:
        return n1 < n2;
    case TOKule:
        return n1 <= n2;

    default:
        assert(0);
    }
}

/// Returns cmp OP 0; where OP is ==, !=, <, >=, etc. Result is 0 or 1
extern (C++) int specificCmp(TOK op, int rawCmp)
{
    return numCmp!int(op, rawCmp, 0);
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
extern (C++) int intUnsignedCmp(TOK op, dinteger_t n1, dinteger_t n2)
{
    return numCmp!dinteger_t(op, n1, n2);
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
extern (C++) int intSignedCmp(TOK op, sinteger_t n1, sinteger_t n2)
{
    return numCmp!sinteger_t(op, n1, n2);
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
extern (C++) int realCmp(TOK op, real_t r1, real_t r2)
{
    // Don't rely on compiler, handle NAN arguments separately
    if (Port.isNan(r1) || Port.isNan(r2)) // if unordered
    {
        switch (op)
        {
        case TOKlt:
        case TOKle:
        case TOKgt:
        case TOKge:
        case TOKleg:
        case TOKlg:
            return 0;

        case TOKunord:
        case TOKue:
        case TOKug:
        case TOKuge:
        case TOKul:
        case TOKule:
            return 1;

        default:
            assert(0);
        }
    }
    else
    {
        return numCmp!real_t(op, r1, r2);
    }
}

/* Conceptually the same as memcmp(e1, e2).
 * e1 and e2 may be strings, arrayliterals, or slices.
 * For string types, return <0 if e1 < e2, 0 if e1==e2, >0 if e1 > e2.
 * For all other types, return 0 if e1 == e2, !=0 if e1 != e2.
 */
extern (C++) int ctfeCmpArrays(Loc loc, Expression e1, Expression e2, uinteger_t len)
{
    // Resolve slices, if necessary
    uinteger_t lo1 = 0;
    uinteger_t lo2 = 0;
    Expression x = e1;
    if (x.op == TOKslice)
    {
        lo1 = (cast(SliceExp)x).lwr.toInteger();
        x = (cast(SliceExp)x).e1;
    }
    StringExp se1 = (x.op == TOKstring) ? cast(StringExp)x : null;
    ArrayLiteralExp ae1 = (x.op == TOKarrayliteral) ? cast(ArrayLiteralExp)x : null;
    x = e2;
    if (x.op == TOKslice)
    {
        lo2 = (cast(SliceExp)x).lwr.toInteger();
        x = (cast(SliceExp)x).e1;
    }
    StringExp se2 = (x.op == TOKstring) ? cast(StringExp)x : null;
    ArrayLiteralExp ae2 = (x.op == TOKarrayliteral) ? cast(ArrayLiteralExp)x : null;
    // Now both must be either TOKarrayliteral or TOKstring
    if (se1 && se2)
        return sliceCmpStringWithString(se1, se2, cast(size_t)lo1, cast(size_t)lo2, cast(size_t)len);
    if (se1 && ae2)
        return sliceCmpStringWithArray(se1, ae2, cast(size_t)lo1, cast(size_t)lo2, cast(size_t)len);
    if (se2 && ae1)
        return -sliceCmpStringWithArray(se2, ae1, cast(size_t)lo2, cast(size_t)lo1, cast(size_t)len);
    assert(ae1 && ae2);
    // Comparing two array literals. This case is potentially recursive.
    // If they aren't strings, we just need an equality check rather than
    // a full cmp.
    bool needCmp = ae1.type.nextOf().isintegral();
    for (size_t i = 0; i < cast(size_t)len; i++)
    {
        Expression ee1 = (*ae1.elements)[cast(size_t)(lo1 + i)];
        Expression ee2 = (*ae2.elements)[cast(size_t)(lo2 + i)];
        if (needCmp)
        {
            sinteger_t c = ee1.toInteger() - ee2.toInteger();
            if (c > 0)
                return 1;
            if (c < 0)
                return -1;
        }
        else
        {
            if (ctfeRawCmp(loc, ee1, ee2))
                return 1;
        }
    }
    return 0;
}

/* Given a delegate expression e, return .funcptr.
 * If e is NullExp, return NULL.
 */
extern (C++) FuncDeclaration funcptrOf(Expression e)
{
    assert(e.type.ty == Tdelegate);
    if (e.op == TOKdelegate)
        return (cast(DelegateExp)e).func;
    if (e.op == TOKfunction)
        return (cast(FuncExp)e).fd;
    assert(e.op == TOKnull);
    return null;
}

extern (C++) bool isArray(Expression e)
{
    return e.op == TOKarrayliteral || e.op == TOKstring || e.op == TOKslice || e.op == TOKnull;
}

/* For strings, return <0 if e1 < e2, 0 if e1==e2, >0 if e1 > e2.
 * For all other types, return 0 if e1 == e2, !=0 if e1 != e2.
 */
extern (C++) int ctfeRawCmp(Loc loc, Expression e1, Expression e2)
{
    if (e1.op == TOKclassreference || e2.op == TOKclassreference)
    {
        if (e1.op == TOKclassreference && e2.op == TOKclassreference && (cast(ClassReferenceExp)e1).value == (cast(ClassReferenceExp)e2).value)
            return 0;
        return 1;
    }
    if (e1.op == TOKtypeid && e2.op == TOKtypeid)
    {
        // printf("e1: %s\n", e1->toChars());
        // printf("e2: %s\n", e2->toChars());
        Type t1 = isType((cast(TypeidExp)e1).obj);
        Type t2 = isType((cast(TypeidExp)e2).obj);
        assert(t1);
        assert(t2);
        return t1 != t2;
    }
    // null == null, regardless of type
    if (e1.op == TOKnull && e2.op == TOKnull)
        return 0;
    if (e1.type.ty == Tpointer && e2.type.ty == Tpointer)
    {
        // Can only be an equality test.
        dinteger_t ofs1, ofs2;
        Expression agg1 = getAggregateFromPointer(e1, &ofs1);
        Expression agg2 = getAggregateFromPointer(e2, &ofs2);
        if ((agg1 == agg2) || (agg1.op == TOKvar && agg2.op == TOKvar && (cast(VarExp)agg1).var == (cast(VarExp)agg2).var))
        {
            if (ofs1 == ofs2)
                return 0;
        }
        return 1;
    }
    if (e1.type.ty == Tdelegate && e2.type.ty == Tdelegate)
    {
        // If .funcptr isn't the same, they are not equal
        if (funcptrOf(e1) != funcptrOf(e2))
            return 1;
        // If both are delegate literals, assume they have the
        // same closure pointer. TODO: We don't support closures yet!
        if (e1.op == TOKfunction && e2.op == TOKfunction)
            return 0;
        assert(e1.op == TOKdelegate && e2.op == TOKdelegate);
        // Same .funcptr. Do they have the same .ptr?
        Expression ptr1 = (cast(DelegateExp)e1).e1;
        Expression ptr2 = (cast(DelegateExp)e2).e1;
        dinteger_t ofs1, ofs2;
        Expression agg1 = getAggregateFromPointer(ptr1, &ofs1);
        Expression agg2 = getAggregateFromPointer(ptr2, &ofs2);
        // If they are TOKvar, it means they are FuncDeclarations
        if ((agg1 == agg2 && ofs1 == ofs2) || (agg1.op == TOKvar && agg2.op == TOKvar && (cast(VarExp)agg1).var == (cast(VarExp)agg2).var))
        {
            return 0;
        }
        return 1;
    }
    if (isArray(e1) && isArray(e2))
    {
        uinteger_t len1 = resolveArrayLength(e1);
        uinteger_t len2 = resolveArrayLength(e2);
        // workaround for dmc optimizer bug calculating wrong len for
        // uinteger_t len = (len1 < len2 ? len1 : len2);
        // if (len == 0) ...
        if (len1 > 0 && len2 > 0)
        {
            uinteger_t len = (len1 < len2 ? len1 : len2);
            int res = ctfeCmpArrays(loc, e1, e2, len);
            if (res != 0)
                return res;
        }
        return cast(int)(len1 - len2);
    }
    if (e1.type.isintegral())
    {
        return e1.toInteger() != e2.toInteger();
    }
    real_t r1;
    real_t r2;
    if (e1.type.isreal())
    {
        r1 = e1.toReal();
        r2 = e2.toReal();
        goto L1;
    }
    else if (e1.type.isimaginary())
    {
        r1 = e1.toImaginary();
        r2 = e2.toImaginary();
    L1:
        if (Port.isNan(r1) || Port.isNan(r2)) // if unordered
        {
            return 1;
        }
        else
        {
            return (r1 != r2);
        }
    }
    else if (e1.type.iscomplex())
    {
        return e1.toComplex() != e2.toComplex();
    }
    if (e1.op == TOKstructliteral && e2.op == TOKstructliteral)
    {
        StructLiteralExp es1 = cast(StructLiteralExp)e1;
        StructLiteralExp es2 = cast(StructLiteralExp)e2;
        // For structs, we only need to return 0 or 1 (< and > aren't legal).
        if (es1.sd != es2.sd)
            return 1;
        else if ((!es1.elements || !es1.elements.dim) && (!es2.elements || !es2.elements.dim))
            return 0; // both arrays are empty
        else if (!es1.elements || !es2.elements)
            return 1;
        else if (es1.elements.dim != es2.elements.dim)
            return 1;
        else
        {
            for (size_t i = 0; i < es1.elements.dim; i++)
            {
                Expression ee1 = (*es1.elements)[i];
                Expression ee2 = (*es2.elements)[i];
                if (ee1 == ee2)
                    continue;
                if (!ee1 || !ee2)
                    return 1;
                int cmp = ctfeRawCmp(loc, ee1, ee2);
                if (cmp)
                    return 1;
            }
            return 0; // All elements are equal
        }
    }
    if (e1.op == TOKassocarrayliteral && e2.op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp es1 = cast(AssocArrayLiteralExp)e1;
        AssocArrayLiteralExp es2 = cast(AssocArrayLiteralExp)e2;
        size_t dim = es1.keys.dim;
        if (es2.keys.dim != dim)
            return 1;
        bool* used = cast(bool*)mem.xmalloc(bool.sizeof * dim);
        memset(used, 0, bool.sizeof * dim);
        for (size_t i = 0; i < dim; ++i)
        {
            Expression k1 = (*es1.keys)[i];
            Expression v1 = (*es1.values)[i];
            Expression v2 = null;
            for (size_t j = 0; j < dim; ++j)
            {
                if (used[j])
                    continue;
                Expression k2 = (*es2.keys)[j];
                if (ctfeRawCmp(loc, k1, k2))
                    continue;
                used[j] = true;
                v2 = (*es2.values)[j];
                break;
            }
            if (!v2 || ctfeRawCmp(loc, v1, v2))
            {
                mem.xfree(used);
                return 1;
            }
        }
        mem.xfree(used);
        return 0;
    }
    error(loc, "CTFE internal error: bad compare");
    assert(0);
}

/// Evaluate ==, !=.  Resolves slices before comparing. Returns 0 or 1
extern (C++) int ctfeEqual(Loc loc, TOK op, Expression e1, Expression e2)
{
    int cmp = !ctfeRawCmp(loc, e1, e2);
    if (op == TOKnotequal)
        cmp ^= 1;
    return cmp;
}

/// Evaluate is, !is.  Resolves slices before comparing. Returns 0 or 1
extern (C++) int ctfeIdentity(Loc loc, TOK op, Expression e1, Expression e2)
{
    //printf("ctfeIdentity op = '%s', e1 = %s %s, e2 = %s %s\n", Token::toChars(op),
    //    Token::toChars(e1->op), e1->toChars(), Token::toChars(e2->op), e1->toChars());
    int cmp;
    if (e1.op == TOKnull)
    {
        cmp = (e2.op == TOKnull);
    }
    else if (e2.op == TOKnull)
    {
        cmp = 0;
    }
    else if (e1.op == TOKsymoff && e2.op == TOKsymoff)
    {
        SymOffExp es1 = cast(SymOffExp)e1;
        SymOffExp es2 = cast(SymOffExp)e2;
        cmp = (es1.var == es2.var && es1.offset == es2.offset);
    }
    else if (e1.type.isreal())
        cmp = RealEquals(e1.toReal(), e2.toReal());
    else if (e1.type.isimaginary())
        cmp = RealEquals(e1.toImaginary(), e2.toImaginary());
    else if (e1.type.iscomplex())
    {
        complex_t v1 = e1.toComplex();
        complex_t v2 = e2.toComplex();
        cmp = RealEquals(creall(v1), creall(v2)) && RealEquals(cimagl(v1), cimagl(v1));
    }
    else
        cmp = !ctfeRawCmp(loc, e1, e2);
    if (op == TOKnotidentity || op == TOKnotequal)
        cmp ^= 1;
    return cmp;
}

/// Evaluate >,<=, etc. Resolves slices before comparing. Returns 0 or 1
extern (C++) int ctfeCmp(Loc loc, TOK op, Expression e1, Expression e2)
{
    Type t1 = e1.type.toBasetype();
    Type t2 = e2.type.toBasetype();

    if (t1.isString() && t2.isString())
        return specificCmp(op, ctfeRawCmp(loc, e1, e2));
    else if (t1.isreal())
        return realCmp(op, e1.toReal(), e2.toReal());
    else if (t1.isimaginary())
        return realCmp(op, e1.toImaginary(), e2.toImaginary());
    else if (t1.isunsigned() || t2.isunsigned())
        return intUnsignedCmp(op, e1.toInteger(), e2.toInteger());
    else
        return intSignedCmp(op, e1.toInteger(), e2.toInteger());
}

extern (C++) UnionExp ctfeCat(Loc loc, Type type, Expression e1, Expression e2)
{
    Type t1 = e1.type.toBasetype();
    Type t2 = e2.type.toBasetype();
    UnionExp ue;
    if (e2.op == TOKstring && e1.op == TOKarrayliteral && t1.nextOf().isintegral())
    {
        // [chars] ~ string => string (only valid for CTFE)
        StringExp es1 = cast(StringExp)e2;
        ArrayLiteralExp es2 = cast(ArrayLiteralExp)e1;
        size_t len = es1.len + es2.elements.dim;
        ubyte sz = es1.sz;
        void* s = mem.xmalloc((len + 1) * sz);
        memcpy(cast(char*)s + sz * es2.elements.dim, es1.string, es1.len * sz);
        for (size_t i = 0; i < es2.elements.dim; i++)
        {
            Expression es2e = (*es2.elements)[i];
            if (es2e.op != TOKint64)
            {
                emplaceExp!(CTFEExp)(&ue, TOKcantexp);
                return ue;
            }
            dinteger_t v = es2e.toInteger();
            memcpy(cast(char*)s + i * sz, &v, sz);
        }
        // Add terminating 0
        memset(cast(char*)s + len * sz, 0, sz);
        emplaceExp!(StringExp)(&ue, loc, s, len);
        StringExp es = cast(StringExp)ue.exp();
        es.sz = sz;
        es.committed = 0;
        es.type = type;
        return ue;
    }
    if (e1.op == TOKstring && e2.op == TOKarrayliteral && t2.nextOf().isintegral())
    {
        // string ~ [chars] => string (only valid for CTFE)
        // Concatenate the strings
        StringExp es1 = cast(StringExp)e1;
        ArrayLiteralExp es2 = cast(ArrayLiteralExp)e2;
        size_t len = es1.len + es2.elements.dim;
        ubyte sz = es1.sz;
        void* s = mem.xmalloc((len + 1) * sz);
        memcpy(s, es1.string, es1.len * sz);
        for (size_t i = 0; i < es2.elements.dim; i++)
        {
            Expression es2e = (*es2.elements)[i];
            if (es2e.op != TOKint64)
            {
                emplaceExp!(CTFEExp)(&ue, TOKcantexp);
                return ue;
            }
            dinteger_t v = es2e.toInteger();
            memcpy(cast(char*)s + (es1.len + i) * sz, &v, sz);
        }
        // Add terminating 0
        memset(cast(char*)s + len * sz, 0, sz);
        emplaceExp!(StringExp)(&ue, loc, s, len);
        StringExp es = cast(StringExp)ue.exp();
        es.sz = sz;
        es.committed = 0; //es1->committed;
        es.type = type;
        return ue;
    }
    if (e1.op == TOKarrayliteral && e2.op == TOKarrayliteral && t1.nextOf().equals(t2.nextOf()))
    {
        //  [ e1 ] ~ [ e2 ] ---> [ e1, e2 ]
        ArrayLiteralExp es1 = cast(ArrayLiteralExp)e1;
        ArrayLiteralExp es2 = cast(ArrayLiteralExp)e2;
        emplaceExp!(ArrayLiteralExp)(&ue, es1.loc, copyLiteralArray(es1.elements));
        es1 = cast(ArrayLiteralExp)ue.exp();
        es1.elements.insert(es1.elements.dim, copyLiteralArray(es2.elements));
        es1.type = type;
        return ue;
    }
    if (e1.op == TOKarrayliteral && e2.op == TOKnull && t1.nextOf().equals(t2.nextOf()))
    {
        //  [ e1 ] ~ null ----> [ e1 ].dup
        ue = paintTypeOntoLiteralCopy(type, copyLiteral(e1).exp());
        return ue;
    }
    if (e1.op == TOKnull && e2.op == TOKarrayliteral && t1.nextOf().equals(t2.nextOf()))
    {
        //  null ~ [ e2 ] ----> [ e2 ].dup
        ue = paintTypeOntoLiteralCopy(type, copyLiteral(e2).exp());
        return ue;
    }
    ue = Cat(type, e1, e2);
    return ue;
}

/*  Given an AA literal 'ae', and a key 'e2':
 *  Return ae[e2] if present, or NULL if not found.
 */
extern (C++) Expression findKeyInAA(Loc loc, AssocArrayLiteralExp ae, Expression e2)
{
    /* Search the keys backwards, in case there are duplicate keys
     */
    for (size_t i = ae.keys.dim; i;)
    {
        i--;
        Expression ekey = (*ae.keys)[i];
        int eq = ctfeEqual(loc, TOKequal, ekey, e2);
        if (eq)
        {
            return (*ae.values)[i];
        }
    }
    return null;
}

/* Same as for constfold.Index, except that it only works for static arrays,
 * dynamic arrays, and strings. We know that e1 is an
 * interpreted CTFE expression, so it cannot have side-effects.
 */
extern (C++) Expression ctfeIndex(Loc loc, Type type, Expression e1, uinteger_t indx)
{
    //printf("ctfeIndex(e1 = %s)\n", e1->toChars());
    assert(e1.type);
    if (e1.op == TOKstring)
    {
        StringExp es1 = cast(StringExp)e1;
        if (indx >= es1.len)
        {
            error(loc, "string index %llu is out of bounds [0 .. %llu]", indx, cast(ulong)es1.len);
            return CTFEExp.cantexp;
        }
        return new IntegerExp(loc, es1.charAt(indx), type);
    }
    assert(e1.op == TOKarrayliteral);
    {
        ArrayLiteralExp ale = cast(ArrayLiteralExp)e1;
        if (indx >= ale.elements.dim)
        {
            error(loc, "array index %llu is out of bounds %s[0 .. %llu]", indx, e1.toChars(), cast(ulong)ale.elements.dim);
            return CTFEExp.cantexp;
        }
        Expression e = (*ale.elements)[cast(size_t)indx];
        return paintTypeOntoLiteral(type, e);
    }
}

extern (C++) Expression ctfeCast(Loc loc, Type type, Type to, Expression e)
{
    if (e.op == TOKnull)
        return paintTypeOntoLiteral(to, e);
    if (e.op == TOKclassreference)
    {
        // Disallow reinterpreting class casts. Do this by ensuring that
        // the original class can implicitly convert to the target class
        ClassDeclaration originalClass = (cast(ClassReferenceExp)e).originalClass();
        if (originalClass.type.implicitConvTo(to.mutableOf()))
            return paintTypeOntoLiteral(to, e);
        else
            return new NullExp(loc, to);
    }
    // Allow TypeInfo type painting
    if (isTypeInfo_Class(e.type) && e.type.implicitConvTo(to))
        return paintTypeOntoLiteral(to, e);
    // Allow casting away const for struct literals
    if (e.op == TOKstructliteral && e.type.toBasetype().castMod(0) == to.toBasetype().castMod(0))
    {
        return paintTypeOntoLiteral(to, e);
    }
    Expression r;
    if (e.type.equals(type) && type.equals(to))
    {
        // necessary not to change e's address for pointer comparisons
        r = e;
    }
    else if (to.toBasetype().ty == Tarray && type.toBasetype().ty == Tarray && to.toBasetype().nextOf().size() == type.toBasetype().nextOf().size())
    {
        // Bugzilla 12495: Array reinterpret casts: eg. string to immutable(ubyte)[]
        return paintTypeOntoLiteral(to, e);
    }
    else
    {
        r = Cast(loc, type, to, e).copy();
    }
    if (CTFEExp.isCantExp(r))
        error(loc, "cannot cast %s to %s at compile time", e.toChars(), to.toChars());
    if (e.op == TOKarrayliteral)
        (cast(ArrayLiteralExp)e).ownedByCtfe = OWNEDctfe;
    if (e.op == TOKstring)
        (cast(StringExp)e).ownedByCtfe = OWNEDctfe;
    return r;
}

/******** Assignment helper functions ***************************/
/* Set dest = src, where both dest and src are container value literals
 * (ie, struct literals, or static arrays (can be an array literal or a string))
 * Assignment is recursively in-place.
 * Purpose: any reference to a member of 'dest' will remain valid after the
 * assignment.
 */
extern (C++) void assignInPlace(Expression dest, Expression src)
{
    assert(dest.op == TOKstructliteral || dest.op == TOKarrayliteral || dest.op == TOKstring);
    Expressions* oldelems;
    Expressions* newelems;
    if (dest.op == TOKstructliteral)
    {
        assert(dest.op == src.op);
        oldelems = (cast(StructLiteralExp)dest).elements;
        newelems = (cast(StructLiteralExp)src).elements;
        if ((cast(StructLiteralExp)dest).sd.isNested() && oldelems.dim == newelems.dim - 1)
            oldelems.push(null);
    }
    else if (dest.op == TOKarrayliteral && src.op == TOKarrayliteral)
    {
        oldelems = (cast(ArrayLiteralExp)dest).elements;
        newelems = (cast(ArrayLiteralExp)src).elements;
    }
    else if (dest.op == TOKstring && src.op == TOKstring)
    {
        sliceAssignStringFromString(cast(StringExp)dest, cast(StringExp)src, 0);
        return;
    }
    else if (dest.op == TOKarrayliteral && src.op == TOKstring)
    {
        sliceAssignArrayLiteralFromString(cast(ArrayLiteralExp)dest, cast(StringExp)src, 0);
        return;
    }
    else if (src.op == TOKarrayliteral && dest.op == TOKstring)
    {
        sliceAssignStringFromArrayLiteral(cast(StringExp)dest, cast(ArrayLiteralExp)src, 0);
        return;
    }
    else
        assert(0);
    assert(oldelems.dim == newelems.dim);
    for (size_t i = 0; i < oldelems.dim; ++i)
    {
        Expression e = (*newelems)[i];
        Expression o = (*oldelems)[i];
        if (e.op == TOKstructliteral)
        {
            assert(o.op == e.op);
            assignInPlace(o, e);
        }
        else if (e.type.ty == Tsarray && e.op != TOKvoid && o.type.ty == Tsarray)
        {
            assignInPlace(o, e);
        }
        else
        {
            (*oldelems)[i] = (*newelems)[i];
        }
    }
}

// Duplicate the elements array, then set field 'indexToChange' = newelem.
extern (C++) Expressions* changeOneElement(Expressions* oldelems, size_t indexToChange, Expression newelem)
{
    auto expsx = new Expressions();
    ++CtfeStatus.numArrayAllocs;
    expsx.setDim(oldelems.dim);
    for (size_t j = 0; j < expsx.dim; j++)
    {
        if (j == indexToChange)
            (*expsx)[j] = newelem;
        else
            (*expsx)[j] = (*oldelems)[j];
    }
    return expsx;
}

// Create a new struct literal, which is the same as se except that se.field[offset] = elem
extern (C++) Expression modifyStructField(Type type, StructLiteralExp se, size_t offset, Expression newval)
{
    int fieldi = se.getFieldIndex(newval.type, cast(uint)offset);
    if (fieldi == -1)
        return CTFEExp.cantexp;
    /* Create new struct literal reflecting updated fieldi
     */
    Expressions* expsx = changeOneElement(se.elements, fieldi, newval);
    auto ee = new StructLiteralExp(se.loc, se.sd, expsx);
    ee.type = se.type;
    ee.ownedByCtfe = OWNEDctfe;
    return ee;
}

// Given an AA literal aae,  set aae[index] = newval and return newval.
extern (C++) Expression assignAssocArrayElement(Loc loc, AssocArrayLiteralExp aae, Expression index, Expression newval)
{
    /* Create new associative array literal reflecting updated key/value
     */
    Expressions* keysx = aae.keys;
    Expressions* valuesx = aae.values;
    int updated = 0;
    for (size_t j = valuesx.dim; j;)
    {
        j--;
        Expression ekey = (*aae.keys)[j];
        int eq = ctfeEqual(loc, TOKequal, ekey, index);
        if (eq)
        {
            (*valuesx)[j] = newval;
            updated = 1;
        }
    }
    if (!updated)
    {
        // Append index/newval to keysx[]/valuesx[]
        valuesx.push(newval);
        keysx.push(index);
    }
    return newval;
}

/// Given array literal oldval of type ArrayLiteralExp or StringExp, of length
/// oldlen, change its length to newlen. If the newlen is longer than oldlen,
/// all new elements will be set to the default initializer for the element type.
extern (C++) UnionExp changeArrayLiteralLength(Loc loc, TypeArray arrayType, Expression oldval, size_t oldlen, size_t newlen)
{
    UnionExp ue;
    Type elemType = arrayType.next;
    assert(elemType);
    Expression defaultElem = elemType.defaultInitLiteral(loc);
    auto elements = new Expressions();
    elements.setDim(newlen);
    // Resolve slices
    size_t indxlo = 0;
    if (oldval.op == TOKslice)
    {
        indxlo = cast(size_t)(cast(SliceExp)oldval).lwr.toInteger();
        oldval = (cast(SliceExp)oldval).e1;
    }
    size_t copylen = oldlen < newlen ? oldlen : newlen;
    if (oldval.op == TOKstring)
    {
        StringExp oldse = cast(StringExp)oldval;
        void* s = mem.xcalloc(newlen + 1, oldse.sz);
        memcpy(s, oldse.string, copylen * oldse.sz);
        uint defaultValue = cast(uint)defaultElem.toInteger();
        for (size_t elemi = copylen; elemi < newlen; ++elemi)
        {
            switch (oldse.sz)
            {
            case 1:
                (cast(char*)s)[cast(size_t)(indxlo + elemi)] = cast(char)defaultValue;
                break;
            case 2:
                (cast(utf16_t*)s)[cast(size_t)(indxlo + elemi)] = cast(utf16_t)defaultValue;
                break;
            case 4:
                (cast(utf32_t*)s)[cast(size_t)(indxlo + elemi)] = cast(utf32_t)defaultValue;
                break;
            default:
                assert(0);
            }
        }
        emplaceExp!(StringExp)(&ue, loc, s, newlen);
        StringExp se = cast(StringExp)ue.exp();
        se.type = arrayType;
        se.sz = oldse.sz;
        se.committed = oldse.committed;
        se.ownedByCtfe = OWNEDctfe;
    }
    else
    {
        if (oldlen != 0)
        {
            assert(oldval.op == TOKarrayliteral);
            ArrayLiteralExp ae = cast(ArrayLiteralExp)oldval;
            for (size_t i = 0; i < copylen; i++)
                (*elements)[i] = (*ae.elements)[indxlo + i];
        }
        if (elemType.ty == Tstruct || elemType.ty == Tsarray)
        {
            /* If it is an aggregate literal representing a value type,
             * we need to create a unique copy for each element
             */
            for (size_t i = copylen; i < newlen; i++)
                (*elements)[i] = copyLiteral(defaultElem).copy();
        }
        else
        {
            for (size_t i = copylen; i < newlen; i++)
                (*elements)[i] = defaultElem;
        }
        emplaceExp!(ArrayLiteralExp)(&ue, loc, elements);
        ArrayLiteralExp aae = cast(ArrayLiteralExp)ue.exp();
        aae.type = arrayType;
        aae.ownedByCtfe = OWNEDctfe;
    }
    return ue;
}

/*************************** CTFE Sanity Checks ***************************/
extern (C++) bool isCtfeValueValid(Expression newval)
{
    Type tb = newval.type.toBasetype();
    if (newval.op == TOKint64 || newval.op == TOKfloat64 || newval.op == TOKchar || newval.op == TOKcomplex80)
    {
        return tb.isscalar();
    }
    if (newval.op == TOKnull)
    {
        return tb.ty == Tnull || tb.ty == Tpointer || tb.ty == Tarray || tb.ty == Taarray || tb.ty == Tclass;
    }
    if (newval.op == TOKstring)
        return true; // CTFE would directly use the StringExp in AST.
    if (newval.op == TOKarrayliteral)
        return true; //((ArrayLiteralExp *)newval)->ownedByCtfe;
    if (newval.op == TOKassocarrayliteral)
        return true; //((AssocArrayLiteralExp *)newval)->ownedByCtfe;
    if (newval.op == TOKstructliteral)
        return true; //((StructLiteralExp *)newval)->ownedByCtfe;
    if (newval.op == TOKclassreference)
        return true;
    if (newval.op == TOKvector)
        return true; // vector literal
    if (newval.op == TOKfunction)
        return true; // function literal or delegate literal
    if (newval.op == TOKdelegate)
    {
        // &struct.func or &clasinst.func
        // &nestedfunc
        Expression ethis = (cast(DelegateExp)newval).e1;
        return (ethis.op == TOKstructliteral || ethis.op == TOKclassreference || ethis.op == TOKvar && (cast(VarExp)ethis).var == (cast(DelegateExp)newval).func);
    }
    if (newval.op == TOKsymoff)
    {
        // function pointer, or pointer to static variable
        Declaration d = (cast(SymOffExp)newval).var;
        return d.isFuncDeclaration() || d.isDataseg();
    }
    if (newval.op == TOKtypeid)
    {
        // always valid
        return true;
    }
    if (newval.op == TOKaddress)
    {
        // e1 should be a CTFE reference
        Expression e1 = (cast(AddrExp)newval).e1;
        return tb.ty == Tpointer && (e1.op == TOKstructliteral && isCtfeValueValid(e1) || e1.op == TOKvar || e1.op == TOKdotvar && isCtfeReferenceValid(e1) || e1.op == TOKindex && isCtfeReferenceValid(e1) || e1.op == TOKslice && e1.type.toBasetype().ty == Tsarray);
    }
    if (newval.op == TOKslice)
    {
        // e1 should be an array aggregate
        SliceExp se = cast(SliceExp)newval;
        assert(se.lwr && se.lwr.op == TOKint64);
        assert(se.upr && se.upr.op == TOKint64);
        return (tb.ty == Tarray || tb.ty == Tsarray) && (se.e1.op == TOKstring || se.e1.op == TOKarrayliteral);
    }
    if (newval.op == TOKvoid)
        return true; // uninitialized value
    newval.error("CTFE internal error: illegal CTFE value %s", newval.toChars());
    return false;
}

extern (C++) bool isCtfeReferenceValid(Expression newval)
{
    if (newval.op == TOKthis)
        return true;
    if (newval.op == TOKvar)
    {
        VarDeclaration v = (cast(VarExp)newval).var.isVarDeclaration();
        assert(v);
        // Must not be a reference to a reference
        return true;
    }
    if (newval.op == TOKindex)
    {
        Expression eagg = (cast(IndexExp)newval).e1;
        return eagg.op == TOKstring || eagg.op == TOKarrayliteral || eagg.op == TOKassocarrayliteral;
    }
    if (newval.op == TOKdotvar)
    {
        Expression eagg = (cast(DotVarExp)newval).e1;
        return (eagg.op == TOKstructliteral || eagg.op == TOKclassreference) && isCtfeValueValid(eagg);
    }
    // Internally a ref variable may directly point a stack memory.
    // e.g. ref int v = 1;
    return isCtfeValueValid(newval);
}

// Used for debugging only
extern (C++) void showCtfeExpr(Expression e, int level = 0)
{
    for (int i = level; i > 0; --i)
        printf(" ");
    Expressions* elements = null;
    // We need the struct definition to detect block assignment
    StructDeclaration sd = null;
    ClassDeclaration cd = null;
    if (e.op == TOKstructliteral)
    {
        elements = (cast(StructLiteralExp)e).elements;
        sd = (cast(StructLiteralExp)e).sd;
        printf("STRUCT type = %s %p:\n", e.type.toChars(), e);
    }
    else if (e.op == TOKclassreference)
    {
        elements = (cast(ClassReferenceExp)e).value.elements;
        cd = (cast(ClassReferenceExp)e).originalClass();
        printf("CLASS type = %s %p:\n", e.type.toChars(), (cast(ClassReferenceExp)e).value);
    }
    else if (e.op == TOKarrayliteral)
    {
        elements = (cast(ArrayLiteralExp)e).elements;
        printf("ARRAY LITERAL type=%s %p:\n", e.type.toChars(), e);
    }
    else if (e.op == TOKassocarrayliteral)
    {
        printf("AA LITERAL type=%s %p:\n", e.type.toChars(), e);
    }
    else if (e.op == TOKstring)
    {
        printf("STRING %s %p\n", e.toChars(), (cast(StringExp)e).string);
    }
    else if (e.op == TOKslice)
    {
        printf("SLICE %p: %s\n", e, e.toChars());
        showCtfeExpr((cast(SliceExp)e).e1, level + 1);
    }
    else if (e.op == TOKvar)
    {
        printf("VAR %p %s\n", e, e.toChars());
        VarDeclaration v = (cast(VarExp)e).var.isVarDeclaration();
        if (v && getValue(v))
            showCtfeExpr(getValue(v), level + 1);
    }
    else if (e.op == TOKaddress)
    {
        // This is potentially recursive. We mustn't try to print the thing we're pointing to.
        printf("POINTER %p to %p: %s\n", e, (cast(AddrExp)e).e1, e.toChars());
    }
    else
        printf("VALUE %p: %s\n", e, e.toChars());
    if (elements)
    {
        size_t fieldsSoFar = 0;
        for (size_t i = 0; i < elements.dim; i++)
        {
            Expression z = null;
            VarDeclaration v = null;
            if (i > 15)
            {
                printf("...(total %d elements)\n", cast(int)elements.dim);
                return;
            }
            if (sd)
            {
                v = sd.fields[i];
                z = (*elements)[i];
            }
            else if (cd)
            {
                while (i - fieldsSoFar >= cd.fields.dim)
                {
                    fieldsSoFar += cd.fields.dim;
                    cd = cd.baseClass;
                    for (int j = level; j > 0; --j)
                        printf(" ");
                    printf(" BASE CLASS: %s\n", cd.toChars());
                }
                v = cd.fields[i - fieldsSoFar];
                assert((elements.dim + i) >= (fieldsSoFar + cd.fields.dim));
                size_t indx = (elements.dim - fieldsSoFar) - cd.fields.dim + i;
                assert(indx < elements.dim);
                z = (*elements)[indx];
            }
            if (!z)
            {
                for (int j = level; j > 0; --j)
                    printf(" ");
                printf(" void\n");
                continue;
            }
            if (v)
            {
                // If it is a void assignment, use the default initializer
                if ((v.type.ty != z.type.ty) && v.type.ty == Tsarray)
                {
                    for (int j = level; --j;)
                        printf(" ");
                    printf(" field: block initalized static array\n");
                    continue;
                }
            }
            showCtfeExpr(z, level + 1);
        }
    }
}

/*************************** Void initialization ***************************/
extern (C++) UnionExp voidInitLiteral(Type t, VarDeclaration var)
{
    UnionExp ue;
    if (t.ty == Tsarray)
    {
        TypeSArray tsa = cast(TypeSArray)t;
        Expression elem = voidInitLiteral(tsa.next, var).copy();
        // For aggregate value types (structs, static arrays) we must
        // create an a separate copy for each element.
        bool mustCopy = (elem.op == TOKarrayliteral || elem.op == TOKstructliteral);
        auto elements = new Expressions();
        size_t d = cast(size_t)tsa.dim.toInteger();
        elements.setDim(d);
        for (size_t i = 0; i < d; i++)
        {
            if (mustCopy && i > 0)
                elem = copyLiteral(elem).copy();
            (*elements)[i] = elem;
        }
        emplaceExp!(ArrayLiteralExp)(&ue, var.loc, elements);
        ArrayLiteralExp ae = cast(ArrayLiteralExp)ue.exp();
        ae.type = tsa;
        ae.ownedByCtfe = OWNEDctfe;
    }
    else if (t.ty == Tstruct)
    {
        TypeStruct ts = cast(TypeStruct)t;
        auto exps = new Expressions();
        exps.setDim(ts.sym.fields.dim);
        for (size_t i = 0; i < ts.sym.fields.dim; i++)
        {
            (*exps)[i] = voidInitLiteral(ts.sym.fields[i].type, ts.sym.fields[i]).copy();
        }
        emplaceExp!(StructLiteralExp)(&ue, var.loc, ts.sym, exps);
        StructLiteralExp se = cast(StructLiteralExp)ue.exp();
        se.type = ts;
        se.ownedByCtfe = OWNEDctfe;
    }
    else
        emplaceExp!(VoidInitExp)(&ue, var, t);
    return ue;
}
