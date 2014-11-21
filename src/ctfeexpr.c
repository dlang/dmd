
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/ctfeexpr.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // mem{cpy|set}()
#include <new>

#include "rmem.h"

#include "expression.h"
#include "declaration.h"
#include "aggregate.h"
// for AssocArray
#include "id.h"
#include "template.h"
#include "ctfe.h"
#include "target.h"

int RealEquals(real_t x1, real_t x2);

/************** ClassReferenceExp ********************************************/

ClassReferenceExp::ClassReferenceExp(Loc loc, StructLiteralExp *lit, Type *type)
    : Expression(loc, TOKclassreference, sizeof(ClassReferenceExp))
{
    assert(lit && lit->sd && lit->sd->isClassDeclaration());
    this->value = lit;
    this->type = type;
}

ClassDeclaration *ClassReferenceExp::originalClass()
{
    return value->sd->isClassDeclaration();
}

VarDeclaration *ClassReferenceExp::getFieldAt(unsigned index)
{
    ClassDeclaration *cd = originalClass();
    unsigned fieldsSoFar = 0;
    while (index - fieldsSoFar >= cd->fields.dim)
    {
        fieldsSoFar += cd->fields.dim;
        cd = cd->baseClass;
    }
    return cd->fields[index - fieldsSoFar];
}

// Return index of the field, or -1 if not found
int ClassReferenceExp::getFieldIndex(Type *fieldtype, unsigned fieldoffset)
{
    ClassDeclaration *cd = originalClass();
    unsigned fieldsSoFar = 0;
    for (size_t j = 0; j < value->elements->dim; j++)
    {
        while (j - fieldsSoFar >= cd->fields.dim)
        {
            fieldsSoFar += cd->fields.dim;
            cd = cd->baseClass;
        }
        VarDeclaration *v2 = cd->fields[j - fieldsSoFar];
        if (fieldoffset == v2->offset &&
            fieldtype->size() == v2->type->size())
        {
            return (int)(value->elements->dim - fieldsSoFar - cd->fields.dim + (j-fieldsSoFar));
        }
    }
    return -1;
}

// Return index of the field, or -1 if not found
// Same as getFieldIndex, but checks for a direct match with the VarDeclaration
int ClassReferenceExp::findFieldIndexByName(VarDeclaration *v)
{
    ClassDeclaration *cd = originalClass();
    size_t fieldsSoFar = 0;
    for (size_t j = 0; j < value->elements->dim; j++)
    {
        while (j - fieldsSoFar >= cd->fields.dim)
        {
            fieldsSoFar += cd->fields.dim;
            cd = cd->baseClass;
        }
        VarDeclaration *v2 = cd->fields[j - fieldsSoFar];
        if (v == v2)
        {
            return (int)(value->elements->dim - fieldsSoFar - cd->fields.dim + (j-fieldsSoFar));
        }
    }
    return -1;
}

/************** VoidInitExp ********************************************/

VoidInitExp::VoidInitExp(VarDeclaration *var, Type *type)
    : Expression(var->loc, TOKvoid, sizeof(VoidInitExp))
{
    this->var = var;
    this->type = var->type;
}

char *VoidInitExp::toChars()
{
    return (char *)"void";
}

// Return index of the field, or -1 if not found
// Same as getFieldIndex, but checks for a direct match with the VarDeclaration
int findFieldIndexByName(StructDeclaration *sd, VarDeclaration *v)
{
    for (size_t i = 0; i < sd->fields.dim; ++i)
    {
        if (sd->fields[i] == v)
            return (int)i;
    }
    return -1;
}

/************** ThrownExceptionExp ********************************************/

ThrownExceptionExp::ThrownExceptionExp(Loc loc, ClassReferenceExp *victim) : Expression(loc, TOKthrownexception, sizeof(ThrownExceptionExp))
{
    this->thrown = victim;
    this->type = victim->type;
}

char *ThrownExceptionExp::toChars()
{
    return (char *)"CTFE ThrownException";
}

// Generate an error message when this exception is not caught
void ThrownExceptionExp::generateUncaughtError()
{
    Expression *e = (*thrown->value->elements)[0];
    StringExp *se = e->toStringExp();
    thrown->error("Uncaught CTFE exception %s(%s)", thrown->type->toChars(), se ? se->toChars() : e->toChars());

    /* Also give the line where the throw statement was. We won't have it
     * in the case where the ThrowStatement is generated internally
     * (eg, in ScopeStatement)
     */
    if (loc.filename && !loc.equals(thrown->loc))
        errorSupplemental(loc, "thrown from here");
}


// True if 'e' is CTFEExp::cantexp, or an exception
bool exceptionOrCantInterpret(Expression *e)
{
    return e && (e->op == TOKcantexp || e->op == TOKthrownexception);
}

/********************** CTFEExp ******************************************/

CTFEExp *CTFEExp::cantexp;
CTFEExp *CTFEExp::voidexp;
CTFEExp *CTFEExp::breakexp;
CTFEExp *CTFEExp::continueexp;
CTFEExp *CTFEExp::gotoexp;

CTFEExp::CTFEExp(TOK tok)
    : Expression(Loc(), tok, sizeof(CTFEExp))
{
    type = Type::tvoid;
}

/************** Aggregate literals (AA/string/array/struct) ******************/

// Given expr, which evaluates to an array/AA/string literal,
// return true if it needs to be copied
bool needToCopyLiteral(Expression *expr)
{
    for (;;)
    {
       switch (expr->op)
       {
            case TOKarrayliteral:
                return !((ArrayLiteralExp *)expr)->ownedByCtfe;
            case TOKassocarrayliteral:
                return !((AssocArrayLiteralExp *)expr)->ownedByCtfe;
            case TOKstructliteral:
                return !((StructLiteralExp *)expr)->ownedByCtfe;
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
                expr = ((UnaExp *)expr)->e1;
                continue;
            case TOKcat:
                return needToCopyLiteral(((BinExp *)expr)->e1) ||
                    needToCopyLiteral(((BinExp *)expr)->e2);
            case TOKcatass:
                expr = ((BinExp *)expr)->e2;
                continue;
            default:
                return false;
        }
    }
}

Expressions *copyLiteralArray(Expressions *oldelems)
{
    if (!oldelems)
        return oldelems;
    CtfeStatus::numArrayAllocs++;
    Expressions *newelems = new Expressions();
    newelems->setDim(oldelems->dim);
    for (size_t i = 0; i < oldelems->dim; i++)
        (*newelems)[i] = copyLiteral((*oldelems)[i]);
    return newelems;
}

// Make a copy of the ArrayLiteral, AALiteral, String, or StructLiteral.
// This value will be used for in-place modification.
Expression *copyLiteral(Expression *e)
{
    if (e->op == TOKstring) // syntaxCopy doesn't make a copy for StringExp!
    {
        StringExp *se = (StringExp *)e;
        utf8_t *s = (utf8_t *)mem.calloc(se->len + 1, se->sz);
        memcpy(s, se->string, se->len * se->sz);
        StringExp *se2 = new StringExp(se->loc, s, se->len);
        se2->committed = se->committed;
        se2->postfix = se->postfix;
        se2->type = se->type;
        se2->sz = se->sz;
        se2->ownedByCtfe = true;
        return se2;
    }
    if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ae = (ArrayLiteralExp *)e;
        ArrayLiteralExp *r = new ArrayLiteralExp(e->loc,
            copyLiteralArray(ae->elements));
        r->type = e->type;
        r->ownedByCtfe = true;
        return r;
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)e;
        AssocArrayLiteralExp *r = new AssocArrayLiteralExp(e->loc,
            copyLiteralArray(aae->keys), copyLiteralArray(aae->values));
        r->type = e->type;
        r->ownedByCtfe = true;
        return r;
    }
    if (e->op == TOKstructliteral)
    {
        /* syntaxCopy doesn't work for struct literals, because of a nasty special
         * case: block assignment is permitted inside struct literals, eg,
         * an int[4] array can be initialized with a single int.
         */
        StructLiteralExp *se = (StructLiteralExp *)e;
        Expressions *oldelems = se->elements;
        Expressions * newelems = new Expressions();
        newelems->setDim(oldelems->dim);
        for (size_t i = 0; i < newelems->dim; i++)
        {
            Expression *m = (*oldelems)[i];
            // We need the struct definition to detect block assignment
            AggregateDeclaration *sd = se->sd;
            VarDeclaration *v = sd->fields[i];
            // If it is a void assignment, use the default initializer
            if (!m)
                m = voidInitLiteral(v->type, v).copy();
            if ((v->type->ty != m->type->ty) && v->type->ty == Tsarray)
            {
                // Block assignment from inside struct literals
                TypeSArray *tsa = (TypeSArray *)v->type;
                uinteger_t length = tsa->dim->toInteger();
                m = createBlockDuplicatedArrayLiteral(e->loc, v->type, m, (size_t)length);
            }
            else if (v->type->ty != Tarray && v->type->ty!=Taarray) // NOTE: do not copy array references
                m = copyLiteral(m);
            (*newelems)[i] = m;
        }
        StructLiteralExp *r = new StructLiteralExp(e->loc, se->sd, newelems, se->stype);
        r->type = e->type;
        r->ownedByCtfe = true;
        r->origin = ((StructLiteralExp *)e)->origin;
        return r;
    }
    if (e->op == TOKfunction || e->op == TOKdelegate ||
        e->op == TOKsymoff || e->op == TOKnull ||
        e->op == TOKvar || e->op == TOKdotvar ||
        e->op == TOKint64 || e->op == TOKfloat64 ||
        e->op == TOKchar || e->op == TOKcomplex80 ||
        e->op == TOKvoid || e->op == TOKvector)
    {
        // Simple value types
        Expression *r = e->copy();  // keep e1 for DelegateExp and DotVarExp
        r->type = e->type;
        return r;
    }
    if (isPointer(e->type))
    {
        // For pointers, we only do a shallow copy.
        Expression *r;
        if (e->op == TOKaddress)
            r = new AddrExp(e->loc, ((AddrExp *)e)->e1);
        else if (e->op == TOKindex)
            r = new IndexExp(e->loc, ((IndexExp *)e)->e1, ((IndexExp *)e)->e2);
        else if (e->op == TOKdotvar)
        {
            r = new DotVarExp(e->loc, ((DotVarExp *)e)->e1,
                ((DotVarExp *)e)->var, ((DotVarExp *)e)->hasOverloads);
        }
        else
            assert(0);
        r->type = e->type;
        return r;
    }
    if (e->op == TOKslice)
    {
        // Array slices only do a shallow copy
        Expression *r = new SliceExp(e->loc, ((SliceExp *)e)->e1,
            ((SliceExp *)e)->lwr, ((SliceExp *)e)->upr);
        r->type = e->type;
        return r;
    }
    if (e->op == TOKclassreference)
        return new ClassReferenceExp(e->loc, ((ClassReferenceExp *)e)->value, e->type);
    if (e->op == TOKerror)
        return e;

    e->error("Internal Compiler Error: CTFE literal %s", e->toChars());
    assert(0);
    return e;
}

/* Deal with type painting.
 * Type painting is a major nuisance: we can't just set
 * e->type = type, because that would change the original literal.
 * But, we can't simply copy the literal either, because that would change
 * the values of any pointers.
 */
Expression *paintTypeOntoLiteral(Type *type, Expression *lit)
{
    if (lit->type->equals(type))
        return lit;

    // If it is a cast to inout, retain the original type of the referenced part.
    if (type->hasWild() && type->hasPointers())
    {
        lit = lit->copy();
        lit->type = type;
        return lit;
    }

    Expression *e;
    if (lit->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)lit;
        e = new SliceExp(lit->loc, se->e1, se->lwr, se->upr);
    }
    else if (lit->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)lit;
        e = new IndexExp(lit->loc, ie->e1, ie->e2);
    }
    else if (lit->op == TOKarrayliteral)
    {
        e = new SliceExp(lit->loc, lit,
            new IntegerExp(Loc(), 0, Type::tsize_t), ArrayLength(Type::tsize_t, lit).copy());
    }
    else if (lit->op == TOKstring)
    {
        // For strings, we need to introduce another level of indirection
        e = new SliceExp(lit->loc, lit,
            new IntegerExp(Loc(), 0, Type::tsize_t), ArrayLength(Type::tsize_t, lit).copy());
    }
    else if (lit->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *aae = (AssocArrayLiteralExp *)lit;
        // TODO: we should be creating a reference to this AAExp, not
        // just a ref to the keys and values.
        bool wasOwned = aae->ownedByCtfe;
        aae = new AssocArrayLiteralExp(lit->loc, aae->keys, aae->values);
        aae->ownedByCtfe = wasOwned;
        e = aae;
    }
    else
    {
        // Can't type paint from struct to struct*; this needs another
        // level of indirection
        if (lit->op == TOKstructliteral && isPointer(type))
            lit->error("CTFE internal error painting %s", type->toChars());
        e = copyLiteral(lit);
    }
    e->type = type;
    return e;
}

Expression *resolveSlice(Expression *e)
{
    assert(e->op == TOKslice);
    SliceExp *se = (SliceExp *)e;
    if (se->e1->op == TOKnull)
        return se->e1;
    return Slice(e->type, se->e1, se->lwr, se->upr).copy();
}

/* Determine the array length, without interpreting it.
 * e must be an array literal, or a slice
 * It's very wasteful to resolve the slice when we only
 * need the length.
 */
uinteger_t resolveArrayLength(Expression *e)
{
    if (e->op == TOKnull)
        return 0;
    if (e->op == TOKslice)
    {
        uinteger_t ilo = ((SliceExp *)e)->lwr->toInteger();
        uinteger_t iup = ((SliceExp *)e)->upr->toInteger();
        return iup - ilo;
    }
    if (e->op == TOKstring)
    {
        return ((StringExp *)e)->len;
    }
    if (e->op == TOKarrayliteral)
    {
        ArrayLiteralExp *ale = (ArrayLiteralExp *)e;
        return ale->elements ? ale->elements->dim : 0;
    }
    if (e->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *ale = (AssocArrayLiteralExp *)e;
        return ale->keys->dim;
    }
    assert(0);
    return 0;
}

/******************************
 * Helper for NewExp
 * Create an array literal consisting of 'elem' duplicated 'dim' times.
 */
ArrayLiteralExp *createBlockDuplicatedArrayLiteral(Loc loc, Type *type,
        Expression *elem, size_t dim)
{
    Expressions *elements = new Expressions();
    elements->setDim(dim);
    if (type->ty == Tsarray && type->nextOf()->ty == Tsarray &&
        elem->type->ty != Tsarray)
    {
        // If it is a multidimensional array literal, do it recursively
        elem = createBlockDuplicatedArrayLiteral(loc, type->nextOf(), elem,
            (size_t)((TypeSArray *)type->nextOf())->dim->toInteger());
    }
    bool mustCopy = needToCopyLiteral(elem);
    for (size_t i = 0; i < dim; i++)
    {
        if (mustCopy)
            elem  = copyLiteral(elem);
        (*elements)[i] = elem;
    }
    ArrayLiteralExp *ae = new ArrayLiteralExp(loc, elements);
    ae->type = type;
    ae->ownedByCtfe = true;
    return ae;
}

/******************************
 * Helper for NewExp
 * Create a string literal consisting of 'value' duplicated 'dim' times.
 */
StringExp *createBlockDuplicatedStringLiteral(Loc loc, Type *type,
        unsigned value, size_t dim, unsigned char sz)
{
    utf8_t *s = (utf8_t *)mem.calloc(dim + 1, sz);
    for (size_t elemi = 0; elemi < dim; ++elemi)
    {
        switch (sz)
        {
            case 1:     s[elemi] = (utf8_t)value; break;
            case 2:     ((unsigned short *)s)[elemi] = (unsigned short)value; break;
            case 4:     ((unsigned *)s)[elemi] = value; break;
            default:    assert(0);
        }
    }
    StringExp *se = new StringExp(loc, s, dim);
    se->type = type;
    se->sz = sz;
    se->committed = true;
    se->ownedByCtfe = true;
    return se;
}

// Return true if t is an AA
bool isAssocArray(Type *t)
{
    t = t->toBasetype();
    if (t->ty == Taarray)
        return true;
    return false;
}

// Given a template AA type, extract the corresponding built-in AA type
TypeAArray *toBuiltinAAType(Type *t)
{
    t = t->toBasetype();
    if (t->ty == Taarray)
        return (TypeAArray *)t;
    assert(0);
    return NULL;
}

/************** TypeInfo operations ************************************/

// Return true if type is TypeInfo_Class
bool isTypeInfo_Class(Type *type)
{
    return type->ty == Tclass &&
        (Type::dtypeinfo == ((TypeClass *)type)->sym ||
         Type::dtypeinfo->isBaseOf(((TypeClass *)type)->sym, NULL));
}

/************** Pointer operations ************************************/

// Return true if t is a pointer (not a function pointer)
bool isPointer(Type *t)
{
    Type * tb = t->toBasetype();
    return tb->ty == Tpointer && tb->nextOf()->ty != Tfunction;
}

// For CTFE only. Returns true if 'e' is true or a non-null pointer.
int isTrueBool(Expression *e)
{
    return e->isBool(true) ||
           ((e->type->ty == Tpointer || e->type->ty == Tclass) && e->op != TOKnull);
}

/* Is it safe to convert from srcPointee* to destPointee* ?
 * srcPointee is the genuine type (never void).
 * destPointee may be void.
 */
bool isSafePointerCast(Type *srcPointee, Type *destPointee)
{
    // It's safe to cast S** to D** if it's OK to cast S* to D*
    while (srcPointee->ty == Tpointer && destPointee->ty == Tpointer)
    {
        srcPointee = srcPointee->nextOf();
        destPointee = destPointee->nextOf();
    }

    // It's OK if both are the same (modulo const)
    if (srcPointee->constConv(destPointee))
        return true;

    // It's OK if function pointers differ only in safe/pure/nothrow
    if (srcPointee->ty == Tfunction && destPointee->ty == Tfunction)
        return srcPointee->covariant(destPointee) == 1;

    // it's OK to cast to void*
    if (destPointee->ty == Tvoid)
        return true;

    // It's OK to cast from V[K] to void*
    if (srcPointee->ty == Taarray && destPointee == Type::tvoidptr)
        return true;

    // It's OK if they are the same size (static array of) integers, eg:
    //     int*     --> uint*
    //     int[5][] --> uint[5][]
    return srcPointee->baseElemOf()->isintegral() &&
           destPointee->baseElemOf()->isintegral() &&
           srcPointee->size() == destPointee->size();
}

Expression *getAggregateFromPointer(Expression *e, dinteger_t *ofs)
{
    *ofs = 0;
    if (e->op == TOKaddress)
        e = ((AddrExp *)e)->e1;
    if (e->op == TOKsymoff)
        *ofs = ((SymOffExp *)e)->offset;
    if (e->op == TOKdotvar)
    {
        Expression *ex = ((DotVarExp *)e)->e1;
        VarDeclaration *v = ((DotVarExp *)e)->var->isVarDeclaration();
        assert(v);
        StructLiteralExp *se = ex->op == TOKclassreference ? ((ClassReferenceExp *)ex)->value : (StructLiteralExp *)ex;
        // We can't use getField, because it makes a copy
        unsigned i;
        if (ex->op == TOKclassreference)
            i = ((ClassReferenceExp *)ex)->getFieldIndex(e->type, v->offset);
        else
            i = se->getFieldIndex(e->type, v->offset);
        e = (*se->elements)[i];
    }
    if (e->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)e;
        // Note that each AA element is part of its own memory block
        if ((ie->e1->type->ty == Tarray || ie->e1->type->ty == Tsarray ||
             ie->e1->op == TOKstring || ie->e1->op==TOKarrayliteral) &&
            ie->e2->op == TOKint64)
        {
            *ofs = ie->e2->toInteger();
            return ie->e1;
        }
    }
    return e;
}

/** Return true if agg1 and agg2 are pointers to the same memory block
*/
bool pointToSameMemoryBlock(Expression *agg1, Expression *agg2)
{
    if (agg1 == agg2)
        return true;

    // For integers cast to pointers, we regard them as non-comparable
    // unless they are identical. (This may be overly strict).
    if (agg1->op == TOKint64 && agg2->op == TOKint64 &&
        agg1->toInteger() == agg2->toInteger())
    {
        return true;
    }

    // Note that type painting can occur with VarExp, so we
    // must compare the variables being pointed to.
    if (agg1->op == TOKvar && agg2->op == TOKvar &&
        ((VarExp *)agg1)->var == ((VarExp *)agg2)->var)
    {
        return true;
    }
    if (agg1->op == TOKsymoff && agg2->op == TOKsymoff &&
        ((SymOffExp *)agg1)->var == ((SymOffExp *)agg2)->var)
    {
        return true;
    }

    return false;
}

// return e1 - e2 as an integer, or error if not possible
Expression *pointerDifference(Loc loc, Type *type, Expression *e1, Expression *e2)
{
    dinteger_t ofs1, ofs2;
    Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
    Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
    if (agg1 == agg2)
    {
        Type *pointee = ((TypePointer *)agg1->type)->next;
        dinteger_t sz = pointee->size();
        return new IntegerExp(loc, (ofs1 - ofs2) * sz, type);
    }
    if (agg1->op == TOKstring && agg2->op == TOKstring)
    {
        if (((StringExp *)agg1)->string == ((StringExp *)agg2)->string)
        {
            Type *pointee = ((TypePointer *)agg1->type)->next;
            dinteger_t sz = pointee->size();
            return new IntegerExp(loc, (ofs1 - ofs2) * sz, type);
        }
    }
    else if (agg1->op == TOKsymoff && agg2->op == TOKsymoff &&
             ((SymOffExp *)agg1)->var == ((SymOffExp *)agg2)->var)
    {
        return new IntegerExp(loc, ofs1 - ofs2, type);
    }
    error(loc, "%s - %s cannot be interpreted at compile time: cannot subtract "
        "pointers to two different memory blocks",
        e1->toChars(), e2->toChars());
    return CTFEExp::cantexp;
}

// Return eptr op e2, where eptr is a pointer, e2 is an integer,
// and op is TOKadd or TOKmin
Expression *pointerArithmetic(Loc loc, TOK op, Type *type,
    Expression *eptr, Expression *e2)
{
    if (eptr->type->nextOf()->ty == Tvoid)
    {
        error(loc, "cannot perform arithmetic on void* pointers at compile time");
        return CTFEExp::cantexp;
    }
    dinteger_t ofs1, ofs2;
    if (eptr->op == TOKaddress)
        eptr = ((AddrExp *)eptr)->e1;
    Expression *agg1 = getAggregateFromPointer(eptr, &ofs1);
    if (agg1->op == TOKsymoff)
    {
        if (((SymOffExp *)agg1)->var->type->ty != Tsarray)
        {
            error(loc, "cannot perform pointer arithmetic on arrays of unknown length at compile time");
            return CTFEExp::cantexp;
        }
    }
    else if (agg1->op != TOKstring && agg1->op != TOKarrayliteral)
    {
        error(loc, "cannot perform pointer arithmetic on non-arrays at compile time");
        return CTFEExp::cantexp;
    }
    ofs2 = e2->toInteger();
    Type *pointee = ((TypePointer *)agg1->type)->next;
    sinteger_t indx = ofs1;
    dinteger_t sz = pointee->size();
    Expression *dollar;
    if (agg1->op == TOKsymoff)
    {
        dollar = ((TypeSArray *)(((SymOffExp *)agg1)->var->type))->dim;
        indx = ofs1/sz;
    }
    else
    {
        dollar = ArrayLength(Type::tsize_t, agg1).copy();
        assert(!CTFEExp::isCantExp(dollar));
    }
    dinteger_t len = dollar->toInteger();

    if (op == TOKadd || op == TOKaddass || op == TOKplusplus)
        indx = indx + ofs2/sz;
    else if (op == TOKmin || op == TOKminass || op == TOKminusminus)
        indx -= ofs2/sz;
    else
    {
        error(loc, "CTFE Internal compiler error: bad pointer operation");
        return CTFEExp::cantexp;
    }

    if (indx < 0 || indx > len)
    {
        error(loc, "cannot assign pointer to index %lld inside memory block [0..%lld]", indx, len);
        return CTFEExp::cantexp;
    }

    if (agg1->op == TOKsymoff)
    {
        SymOffExp *se = new SymOffExp(loc, ((SymOffExp *)agg1)->var, indx*sz);
        se->type = type;
        return se;
    }

    Expression *val = agg1;
    if (val->op != TOKarrayliteral && val->op != TOKstring)
    {
        error(loc, "CTFE Internal compiler error: pointer arithmetic %s", val->toChars());
        return CTFEExp::cantexp;
    }

    IntegerExp *ofs = new IntegerExp(loc, indx, Type::tsize_t);
    IndexExp *ie = new IndexExp(loc, val, ofs);
    ie->type = type;
    return ie;
}

// Return 1 if true, 0 if false
// -1 if comparison is illegal because they point to non-comparable memory blocks
int comparePointers(Loc loc, TOK op, Type *type, Expression *agg1, dinteger_t ofs1,
        Expression *agg2, dinteger_t ofs2)
{
    if (pointToSameMemoryBlock(agg1, agg2))
    {
        int n;
        switch (op)
        {
        case TOKlt:          n = (ofs1 <  ofs2); break;
        case TOKle:          n = (ofs1 <= ofs2); break;
        case TOKgt:          n = (ofs1 >  ofs2); break;
        case TOKge:          n = (ofs1 >= ofs2); break;
        case TOKidentity:
        case TOKequal:       n = (ofs1 == ofs2); break;
        case TOKnotidentity:
        case TOKnotequal:    n = (ofs1 != ofs2); break;
        default:
            assert(0);
        }
        return n;
    }
    bool null1 = (agg1->op == TOKnull);
    bool null2 = (agg2->op == TOKnull);

    int cmp;
    if (null1 || null2)
    {
        switch (op)
        {
        case TOKlt:   cmp =  null1 && !null2;   break;
        case TOKgt:   cmp = !null1 &&  null2;   break;
        case TOKle:   cmp = null1;              break;
        case TOKge:   cmp = null2;              break;
        case TOKidentity:
        case TOKequal:
        case TOKnotidentity: // 'cmp' gets inverted below
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
        case TOKnotidentity: // 'cmp' gets inverted below
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
bool isFloatIntPaint(Type *to, Type *from)
{
    return from->size() == to->size() &&
           (from->isintegral() && to->isfloating() ||
            from->isfloating() && to->isintegral());
}

// Reinterpret float/int value 'fromVal' as a float/integer of type 'to'.
Expression *paintFloatInt(Expression *fromVal, Type *to)
{
    if (exceptionOrCantInterpret(fromVal))
        return fromVal;

    assert(to->size() == 4 || to->size() == 8);
    return Target::paintAsType(fromVal, to);
}


/***********************************************
      Primitive integer operations
***********************************************/

/**   e = OP e
*/
void intUnary(TOK op, IntegerExp *e)
{
    switch (op)
    {
    case TOKneg:
        e->setInteger(-e->getInteger());
        break;
    case TOKtilde:
        e->setInteger(~e->getInteger());
        break;
    default:
        assert(0);
        break;
    }
}

/** dest = e1 OP e2;
*/
void intBinary(TOK op, IntegerExp *dest, Type *type, IntegerExp *e1, IntegerExp *e2)
{
    dinteger_t result;
    switch (op)
    {
    case TOKand:
        result = e1->getInteger() & e2->getInteger();
        break;
    case TOKor:
        result = e1->getInteger() | e2->getInteger();
        break;
    case TOKxor:
        result = e1->getInteger() ^ e2->getInteger();
        break;
    case TOKadd:
        result = e1->getInteger() + e2->getInteger();
        break;
    case TOKmin:
        result = e1->getInteger() - e2->getInteger();
        break;
    case TOKmul:
        result = e1->getInteger() * e2->getInteger();
        break;
    case TOKdiv:
    {
        sinteger_t n1 = e1->getInteger();
        sinteger_t n2 = e2->getInteger();

        if (n2 == 0)
        {
            e2->error("divide by 0");
            result = 1;
        }
        else if (e1->type->isunsigned() || e2->type->isunsigned())
            result = ((d_uns64) n1) / ((d_uns64) n2);
        else
            result = n1 / n2;
        break;
    }
    case TOKmod:
    {
        sinteger_t n1 = e1->getInteger();
        sinteger_t n2 = e2->getInteger();

        if (n2 == 0)
        {
            e2->error("divide by 0");
            n2 = 1;
        }
        if (n2 == -1 && !type->isunsigned())
        {
            // Check for int.min % -1
            if (n1 == 0xFFFFFFFF80000000ULL && type->toBasetype()->ty != Tint64)
            {
                e2->error("integer overflow: int.min % -1");
                n2 = 1;
            }
            else if (n1 == 0x8000000000000000LL) // long.min % -1
            {
                e2->error("integer overflow: long.min % -1");
                n2 = 1;
            }
        }
        if (e1->type->isunsigned() || e2->type->isunsigned())
            result = ((d_uns64) n1) % ((d_uns64) n2);
        else
            result = n1 % n2;
        break;
    }
    case TOKpow:
    {
        dinteger_t n = e2->getInteger();
        if (!e2->type->isunsigned() && (sinteger_t)n < 0)
        {
            e2->error("integer ^^ -integer: total loss of precision");
            n = 1;
        }
        uinteger_t r = e1->getInteger();
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
        result = e1->getInteger() << e2->getInteger();
        break;
    case TOKshr:
    {
        dinteger_t value = e1->getInteger();
        dinteger_t dcount = e2->getInteger();
        assert(dcount <= 0xFFFFFFFF);
        unsigned count = (unsigned)dcount;
        switch (e1->type->toBasetype()->ty)
        {
            case Tint8:
                result = (d_int8)(value) >> count;
                break;

            case Tuns8:
            case Tchar:
                result = (d_uns8)(value) >> count;
                break;

            case Tint16:
                result = (d_int16)(value) >> count;
                break;

            case Tuns16:
            case Twchar:
                result = (d_uns16)(value) >> count;
                break;

            case Tint32:
                result = (d_int32)(value) >> count;
                break;

            case Tuns32:
            case Tdchar:
                result = (d_uns32)(value) >> count;
                break;

            case Tint64:
                result = (d_int64)(value) >> count;
                break;

            case Tuns64:
                result = (d_uns64)(value) >> count;
                break;
            default:
                assert(0);
        }
        break;
    }
    case TOKushr:
    {
        dinteger_t value = e1->getInteger();
        dinteger_t dcount = e2->getInteger();
        assert(dcount <= 0xFFFFFFFF);
        unsigned count = (unsigned)dcount;
        switch (e1->type->toBasetype()->ty)
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
                result = (d_uns64)(value) >> count;
                break;

            default:
                assert(0);
        }
        break;
    }
    case TOKequal:
    case TOKidentity:
        result = (e1->getInteger() == e2->getInteger());
        break;
    case TOKnotequal:
    case TOKnotidentity:
        result = (e1->getInteger() != e2->getInteger());
        break;
    default:
        assert(0);
    }
    dest->setInteger(result);
    dest->type = type;
}


/******** Constant folding, with support for CTFE ***************************/

/// Return true if non-pointer expression e can be compared
/// with >,is, ==, etc, using ctfeCmp, ctfeEqual, ctfeIdentity
bool isCtfeComparable(Expression *e)
{
    Expression *x = e;
    if (x->op == TOKslice)
        x = ((SliceExp *)e)->e1;

    if (x->isConst() != 1 &&
        x->op != TOKnull &&
        x->op != TOKstring &&
        x->op != TOKfunction &&
        x->op != TOKdelegate &&
        x->op != TOKarrayliteral &&
        x->op != TOKstructliteral &&
        x->op != TOKassocarrayliteral &&
        x->op != TOKclassreference)
    {
        return false;
    }
    return true;
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
int intUnsignedCmp(TOK op, d_uns64 n1, d_uns64 n2)
{
    int n;
    switch (op)
    {
        case TOKlt:     n = n1 <  n2;   break;
        case TOKle:     n = n1 <= n2;   break;
        case TOKgt:     n = n1 >  n2;   break;
        case TOKge:     n = n1 >= n2;   break;

        case TOKleg:    n = 1;          break;
        case TOKlg:     n = n1 != n2;   break;
        case TOKunord:  n = 0;          break;
        case TOKue:     n = n1 == n2;   break;
        case TOKug:     n = n1 >  n2;   break;
        case TOKuge:    n = n1 >= n2;   break;
        case TOKul:     n = n1 <  n2;   break;
        case TOKule:    n = n1 <= n2;   break;

        default:
            assert(0);
    }
    return n;
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
int intSignedCmp(TOK op, sinteger_t n1, sinteger_t n2)
{
    int n;
    switch (op)
    {
        case TOKlt:     n = n1 <  n2;   break;
        case TOKle:     n = n1 <= n2;   break;
        case TOKgt:     n = n1 >  n2;   break;
        case TOKge:     n = n1 >= n2;   break;

        case TOKleg:    n = 1;          break;
        case TOKlg:     n = n1 != n2;   break;
        case TOKunord:  n = 0;          break;
        case TOKue:     n = n1 == n2;   break;
        case TOKug:     n = n1 >  n2;   break;
        case TOKuge:    n = n1 >= n2;   break;
        case TOKul:     n = n1 <  n2;   break;
        case TOKule:    n = n1 <= n2;   break;

        default:
            assert(0);
    }
    return n;
}

/// Returns e1 OP e2; where OP is ==, !=, <, >=, etc. Result is 0 or 1
int realCmp(TOK op, real_t r1, real_t r2)
{
    int n;

    // Don't rely on compiler, handle NAN arguments separately
    if (Port::isNan(r1) || Port::isNan(r2)) // if unordered
    {
        switch (op)
        {
            case TOKlt:     n = 0;  break;
            case TOKle:     n = 0;  break;
            case TOKgt:     n = 0;  break;
            case TOKge:     n = 0;  break;

            case TOKleg:    n = 0;  break;
            case TOKlg:     n = 0;  break;
            case TOKunord:  n = 1;  break;
            case TOKue:     n = 1;  break;
            case TOKug:     n = 1;  break;
            case TOKuge:    n = 1;  break;
            case TOKul:     n = 1;  break;
            case TOKule:    n = 1;  break;

            default:
                assert(0);
        }
    }
    else
    {
        switch (op)
        {
            case TOKlt:     n = r1 <  r2;   break;
            case TOKle:     n = r1 <= r2;   break;
            case TOKgt:     n = r1 >  r2;   break;
            case TOKge:     n = r1 >= r2;   break;

            case TOKleg:    n = 1;          break;
            case TOKlg:     n = r1 != r2;   break;
            case TOKunord:  n = 0;          break;
            case TOKue:     n = r1 == r2;   break;
            case TOKug:     n = r1 >  r2;   break;
            case TOKuge:    n = r1 >= r2;   break;
            case TOKul:     n = r1 <  r2;   break;
            case TOKule:    n = r1 <= r2;   break;

            default:
                assert(0);
        }
    }
    return n;
}

int ctfeRawCmp(Loc loc, Expression *e1, Expression *e2);

/* Conceptually the same as memcmp(e1, e2).
 * e1 and e2 may be strings, arrayliterals, or slices.
 * For string types, return <0 if e1 < e2, 0 if e1==e2, >0 if e1 > e2.
 * For all other types, return 0 if e1 == e2, !=0 if e1 != e2.
 */
int ctfeCmpArrays(Loc loc, Expression *e1, Expression *e2, uinteger_t len)
{
    // Resolve slices, if necessary
    uinteger_t lo1 = 0;
    uinteger_t lo2 = 0;

    Expression *x = e1;
    if (x->op == TOKslice)
    {
        lo1 = ((SliceExp *)x)->lwr->toInteger();
        x = ((SliceExp *)x)->e1;
    }
    StringExp *se1 = (x->op == TOKstring) ? (StringExp *)x : NULL;
    ArrayLiteralExp *ae1 = (x->op == TOKarrayliteral) ? (ArrayLiteralExp *)x : NULL;

    x = e2;
    if (x->op == TOKslice)
    {
        lo2 = ((SliceExp *)x)->lwr->toInteger();
        x = ((SliceExp *)x)->e1;
    }
    StringExp *se2 = (x->op == TOKstring) ? (StringExp *)x : NULL;
    ArrayLiteralExp *ae2 = (x->op == TOKarrayliteral) ? (ArrayLiteralExp *)x : NULL;

    // Now both must be either TOKarrayliteral or TOKstring
    if (se1 && se2)
        return sliceCmpStringWithString(se1, se2, (size_t)lo1, (size_t)lo2, (size_t)len);
    if (se1 && ae2)
        return sliceCmpStringWithArray(se1, ae2, (size_t)lo1, (size_t)lo2, (size_t)len);
    if (se2 && ae1)
        return -sliceCmpStringWithArray(se2, ae1, (size_t)lo2, (size_t)lo1, (size_t)len);

    assert (ae1 && ae2);
    // Comparing two array literals. This case is potentially recursive.
    // If they aren't strings, we just need an equality check rather than
    // a full cmp.
    bool needCmp = ae1->type->nextOf()->isintegral();
    for (size_t i = 0; i < len; i++)
    {
        Expression *ee1 = (*ae1->elements)[(size_t)(lo1 + i)];
        Expression *ee2 = (*ae2->elements)[(size_t)(lo2 + i)];
        if (needCmp)
        {
            sinteger_t c = ee1->toInteger() - ee2->toInteger();
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
FuncDeclaration *funcptrOf(Expression *e)
{
    assert(e->type->ty == Tdelegate);

    if (e->op == TOKdelegate)
        return ((DelegateExp *)e)->func;
    if (e->op == TOKfunction)
        return ((FuncExp *)e)->fd;
    assert(e->op == TOKnull);
    return NULL;
}

bool isArray(Expression *e)
{
    return e->op == TOKarrayliteral || e->op == TOKstring ||
           e->op == TOKslice || e->op == TOKnull;
}

/* For strings, return <0 if e1 < e2, 0 if e1==e2, >0 if e1 > e2.
 * For all other types, return 0 if e1 == e2, !=0 if e1 != e2.
 */
int ctfeRawCmp(Loc loc, Expression *e1, Expression *e2)
{
    if (e1->op == TOKclassreference || e2->op == TOKclassreference)
    {
        if (e1->op == TOKclassreference && e2->op == TOKclassreference &&
            ((ClassReferenceExp *)e1)->value == ((ClassReferenceExp *)e2)->value)
            return 0;
        return 1;
    }

    // null == null, regardless of type

    if (e1->op == TOKnull && e2->op == TOKnull)
        return 0;

    if (e1->type->ty == Tpointer && e2->type->ty == Tpointer)
    {
        // Can only be an equality test.

        dinteger_t ofs1, ofs2;
        Expression *agg1 = getAggregateFromPointer(e1, &ofs1);
        Expression *agg2 = getAggregateFromPointer(e2, &ofs2);
        if ((agg1 == agg2) || (agg1->op == TOKvar && agg2->op == TOKvar &&
            ((VarExp *)agg1)->var == ((VarExp *)agg2)->var))
        {
            if (ofs1 == ofs2)
                return 0;
        }
        return 1;
    }
    if (e1->type->ty == Tdelegate && e2->type->ty == Tdelegate)
    {
        // If .funcptr isn't the same, they are not equal

        if (funcptrOf(e1) != funcptrOf(e2))
            return 1;

        // If both are delegate literals, assume they have the
        // same closure pointer. TODO: We don't support closures yet!
        if (e1->op == TOKfunction && e2->op == TOKfunction)
            return 0;
        assert(e1->op == TOKdelegate && e2->op == TOKdelegate);

        // Same .funcptr. Do they have the same .ptr?
        Expression * ptr1 = ((DelegateExp *)e1)->e1;
        Expression * ptr2 = ((DelegateExp *)e2)->e1;

        dinteger_t ofs1, ofs2;
        Expression *agg1 = getAggregateFromPointer(ptr1, &ofs1);
        Expression *agg2 = getAggregateFromPointer(ptr2, &ofs2);
        // If they are TOKvar, it means they are FuncDeclarations
        if ((agg1 == agg2 && ofs1 == ofs2) ||
            (agg1->op == TOKvar && agg2->op == TOKvar &&
             ((VarExp *)agg1)->var == ((VarExp *)agg2)->var))
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
        return (int)(len1 - len2);
    }
    if (e1->type->isintegral())
    {
        return e1->toInteger() != e2->toInteger();
    }
    real_t r1;
    real_t r2;
    if (e1->type->isreal())
    {
        r1 = e1->toReal();
        r2 = e2->toReal();
        goto L1;
    }
    else if (e1->type->isimaginary())
    {
        r1 = e1->toImaginary();
        r2 = e2->toImaginary();
     L1:
        if (Port::isNan(r1) || Port::isNan(r2)) // if unordered
        {
            return 1;
        }
        else
        {
            return (r1 != r2);
        }
    }
    else if (e1->type->iscomplex())
    {
        return e1->toComplex() != e2->toComplex();
    }

    if (e1->op == TOKstructliteral && e2->op == TOKstructliteral)
    {
        StructLiteralExp *es1 = (StructLiteralExp *)e1;
        StructLiteralExp *es2 = (StructLiteralExp *)e2;
        // For structs, we only need to return 0 or 1 (< and > aren't legal).

        if (es1->sd != es2->sd)
            return 1;
        else if ((!es1->elements || !es1->elements->dim) &&
            (!es2->elements || !es2->elements->dim))
            return 0;            // both arrays are empty
        else if (!es1->elements || !es2->elements)
            return 1;
        else if (es1->elements->dim != es2->elements->dim)
            return 1;
        else
        {
            for (size_t i = 0; i < es1->elements->dim; i++)
            {
                Expression *ee1 = (*es1->elements)[i];
                Expression *ee2 = (*es2->elements)[i];

                if (ee1 == ee2)
                    continue;
                if (!ee1 || !ee2)
                   return 1;
                int cmp = ctfeRawCmp(loc, ee1, ee2);
                if (cmp)
                    return 1;
            }
            return 0;   // All elements are equal
        }
    }
    if (e1->op == TOKassocarrayliteral && e2->op == TOKassocarrayliteral)
    {
        AssocArrayLiteralExp *es1 = (AssocArrayLiteralExp *)e1;
        AssocArrayLiteralExp *es2 = (AssocArrayLiteralExp *)e2;

        size_t dim = es1->keys->dim;
        if (es2->keys->dim != dim)
            return 1;

        bool *used = (bool *)mem.malloc(sizeof(bool) * dim);
        memset(used, 0, sizeof(bool) * dim);

        for (size_t i = 0; i < dim; ++i)
        {
            Expression *k1 = (*es1->keys)[i];
            Expression *v1 = (*es1->values)[i];

            for (size_t j = 0; j < dim; ++j)
            {
                if (used[j])
                    continue;
                Expression *k2 = (*es2->keys)[j];
                Expression *v2 = (*es2->values)[j];

                if (ctfeRawCmp(loc, k1, k2))
                    continue;
                used[j] = true;
                if (ctfeRawCmp(loc, v1, v2))
                {
                    mem.free(used);
                    return 1;
                }
            }
        }
        mem.free(used);
        return 0;
    }
    error(loc, "CTFE internal error: bad compare");
    assert(0);
    return 0;
}


/// Evaluate ==, !=.  Resolves slices before comparing. Returns 0 or 1
int ctfeEqual(Loc loc, TOK op, Expression *e1, Expression *e2)
{
    int cmp = !ctfeRawCmp(loc, e1, e2);
    if (op == TOKnotequal)
        cmp ^= 1;
    return cmp;
}


/// Evaluate is, !is.  Resolves slices before comparing. Returns 0 or 1
int ctfeIdentity(Loc loc, TOK op, Expression *e1, Expression *e2)
{
    int cmp;
    if (e1->op == TOKnull)
    {
        cmp = (e2->op == TOKnull);
    }
    else if (e2->op == TOKnull)
    {
        cmp = 0;
    }
    else if (e1->op == TOKsymoff && e2->op == TOKsymoff)
    {
        SymOffExp *es1 = (SymOffExp *)e1;
        SymOffExp *es2 = (SymOffExp *)e2;
        cmp = (es1->var == es2->var && es1->offset == es2->offset);
    }
    else if (e1->type->isreal())
        cmp = RealEquals(e1->toReal(), e2->toReal());
    else if (e1->type->isimaginary())
        cmp = RealEquals(e1->toImaginary(), e2->toImaginary());
    else if (e1->type->iscomplex())
    {
        complex_t v1 = e1->toComplex();
        complex_t v2 = e2->toComplex();
        cmp = RealEquals(creall(v1), creall(v2)) &&
                 RealEquals(cimagl(v1), cimagl(v1));
    }
    else
        cmp = !ctfeRawCmp(loc, e1, e2);

    if (op == TOKnotidentity || op == TOKnotequal)
        cmp ^= 1;
    return cmp;
}


/// Evaluate >,<=, etc. Resolves slices before comparing. Returns 0 or 1
int ctfeCmp(Loc loc, TOK op, Expression *e1, Expression *e2)
{
    int n;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (t1->isString() && t2->isString())
    {
        int cmp = ctfeRawCmp(loc, e1, e2);
        switch (op)
        {
            case TOKlt: n = cmp <  0;   break;
            case TOKle: n = cmp <= 0;   break;
            case TOKgt: n = cmp >  0;   break;
            case TOKge: n = cmp >= 0;   break;

            case TOKleg:   n = 1;               break;
            case TOKlg:    n = cmp != 0;        break;
            case TOKunord: n = 0;               break;
            case TOKue:    n = cmp == 0;        break;
            case TOKug:    n = cmp >  0;        break;
            case TOKuge:   n = cmp >= 0;        break;
            case TOKul:    n = cmp <  0;        break;
            case TOKule:   n = cmp <= 0;        break;

            default:
                assert(0);
        }
    }
    else if (t1->isreal())
    {
        n = realCmp(op, e1->toReal(), e2->toReal());
    }
    else if (t1->isimaginary())
    {
        n = realCmp(op, e1->toImaginary(), e2->toImaginary());
    }
    else if (t1->isunsigned() || t2->isunsigned())
    {
        n = intUnsignedCmp(op, e1->toInteger(), e2->toInteger());
    }
    else
    {
        n = intSignedCmp(op, e1->toInteger(), e2->toInteger());
    }
    return n;
}


UnionExp ctfeCat(Type *type, Expression *e1, Expression *e2)
{
    Loc loc = e1->loc;
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    Expression *e;
    UnionExp ue;
    if (e2->op == TOKstring && e1->op == TOKarrayliteral &&
        t1->nextOf()->isintegral())
    {
        // [chars] ~ string => string (only valid for CTFE)
        StringExp *es1 = (StringExp *)e2;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e1;
        size_t len = es1->len + es2->elements->dim;
        unsigned char sz = es1->sz;

        void *s = mem.malloc((len + 1) * sz);
        memcpy((char *)s + sz * es2->elements->dim, es1->string, es1->len * sz);
        for (size_t i = 0; i < es2->elements->dim; i++)
        {
            Expression *es2e = (*es2->elements)[i];
            if (es2e->op != TOKint64)
            {
                new(&ue) CTFEExp(TOKcantexp);
                return ue;
            }
            dinteger_t v = es2e->toInteger();
            memcpy((utf8_t *)s + i * sz, &v, sz);
        }

        // Add terminating 0
        memset((utf8_t *)s + len * sz, 0, sz);

        StringExp *es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = 0;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKstring && e2->op == TOKarrayliteral &&
        t2->nextOf()->isintegral())
    {
        // string ~ [chars] => string (only valid for CTFE)
        // Concatenate the strings
        StringExp *es1 = (StringExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;
        size_t len = es1->len + es2->elements->dim;
        unsigned char sz = es1->sz;

        void *s = mem.malloc((len + 1) * sz);
        memcpy(s, es1->string, es1->len * sz);
        for (size_t i = 0; i < es2->elements->dim; i++)
        {
            Expression *es2e = (*es2->elements)[i];
            if (es2e->op != TOKint64)
            {
                new(&ue) CTFEExp(TOKcantexp);
                return ue;
            }
            dinteger_t v = es2e->toInteger();
            memcpy((utf8_t *)s + (es1->len + i) * sz, &v, sz);
        }

        // Add terminating 0
        memset((utf8_t *)s + len * sz, 0, sz);

        StringExp *es = new StringExp(loc, s, len);
        es->sz = sz;
        es->committed = 0; //es1->committed;
        es->type = type;
        e = es;
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKarrayliteral &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        //  [ e1 ] ~ [ e2 ] ---> [ e1, e2 ]
        ArrayLiteralExp *es1 = (ArrayLiteralExp *)e1;
        ArrayLiteralExp *es2 = (ArrayLiteralExp *)e2;

        es1 = new ArrayLiteralExp(es1->loc, copyLiteralArray(es1->elements));
        es1->elements->insert(es1->elements->dim, copyLiteralArray(es2->elements));
        e = es1;
        e->type = type;
    }
    else if (e1->op == TOKarrayliteral && e2->op == TOKnull &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        //  [ e1 ] ~ null ----> [ e1 ].dup
        e = paintTypeOntoLiteral(type, copyLiteral(e1));
    }
    else if (e1->op == TOKnull && e2->op == TOKarrayliteral &&
        t1->nextOf()->equals(t2->nextOf()))
    {
        //  null ~ [ e2 ] ----> [ e2 ].dup
        e = paintTypeOntoLiteral(type, copyLiteral(e2));
    }
    else
    {
        ue = Cat(type, e1, e2);
        return ue;
    }
    memcpy(&ue, e, e->size);
    return ue;
}

/*  Given an AA literal 'ae', and a key 'e2':
 *  Return ae[e2] if present, or NULL if not found.
 */
Expression *findKeyInAA(Loc loc, AssocArrayLiteralExp *ae, Expression *e2)
{
    /* Search the keys backwards, in case there are duplicate keys
     */
    for (size_t i = ae->keys->dim; i;)
    {
        i--;
        Expression *ekey = (*ae->keys)[i];
        int eq = ctfeEqual(loc, TOKequal, ekey, e2);
        if (eq)
        {
            return (*ae->values)[i];
        }
    }
    return NULL;
}

/* Same as for constfold.Index, except that it only works for static arrays,
 * dynamic arrays, and strings. We know that e1 is an
 * interpreted CTFE expression, so it cannot have side-effects.
 */
Expression *ctfeIndex(Loc loc, Type *type, Expression *e1, uinteger_t indx)
{
    //printf("ctfeIndex(e1 = %s)\n", e1->toChars());
    assert(e1->type);
    if (e1->op == TOKstring)
    {
        StringExp *es1 = (StringExp *)e1;
        if (indx >= es1->len)
        {
            error(loc, "string index %llu is out of bounds [0 .. %llu]", indx, (ulonglong)es1->len);
            return CTFEExp::cantexp;
        }
        else
            return new IntegerExp(loc, es1->charAt(indx), type);
    }
    assert(e1->op == TOKarrayliteral);
    ArrayLiteralExp *ale = (ArrayLiteralExp *)e1;
    if (indx >= ale->elements->dim)
    {
        error(loc, "array index %llu is out of bounds %s[0 .. %llu]", indx, e1->toChars(), (ulonglong)ale->elements->dim);
        return CTFEExp::cantexp;
    }
    Expression *e = (*ale->elements)[(size_t)indx];
    return paintTypeOntoLiteral(type, e);
}

Expression *ctfeCast(Loc loc, Type *type, Type *to, Expression *e)
{
    if (e->op == TOKnull)
        return paintTypeOntoLiteral(to, e);
    if (e->op == TOKclassreference)
    {
        // Disallow reinterpreting class casts. Do this by ensuring that
        // the original class can implicitly convert to the target class
        ClassDeclaration *originalClass = ((ClassReferenceExp *)e)->originalClass();
        if (originalClass->type->implicitConvTo(to->mutableOf()))
            return paintTypeOntoLiteral(to, e);
        else
            return new NullExp(loc, to);
    }
    // Allow TypeInfo type painting
    if (isTypeInfo_Class(e->type) && e->type->implicitConvTo(to))
        return paintTypeOntoLiteral(to, e);
    // Allow casting away const for struct literals
    if (e->op == TOKstructliteral &&
        e->type->toBasetype()->castMod(0) == to->toBasetype()->castMod(0))
        return paintTypeOntoLiteral(to, e);
    Expression *r;
    if (e->type->equals(type) && type->equals(to))
        r = e;          // necessary not to change e's address for pointer comparisons
    else
        r = Cast(type, to, e).copy();
    if (CTFEExp::isCantExp(r))
        error(loc, "cannot cast %s to %s at compile time", e->toChars(), to->toChars());
    if (e->op == TOKarrayliteral)
        ((ArrayLiteralExp *)e)->ownedByCtfe = true;
    if (e->op == TOKstring)
        ((StringExp *)e)->ownedByCtfe = true;
    return r;
}

/******** Assignment helper functions ***************************/

/* Set dest = src, where both dest and src are container value literals
 * (ie, struct literals, or static arrays (can be an array literal or a string)
 * Assignment is recursively in-place.
 * Purpose: any reference to a member of 'dest' will remain valid after the
 * assignment.
 */
void assignInPlace(Expression *dest, Expression *src)
{
    assert(dest->op == TOKstructliteral || dest->op == TOKarrayliteral ||
        dest->op == TOKstring);
    Expressions *oldelems;
    Expressions *newelems;
    if (dest->op == TOKstructliteral)
    {
        assert(dest->op == src->op);
        oldelems = ((StructLiteralExp *)dest)->elements;
        newelems = ((StructLiteralExp *)src)->elements;
        if (((StructLiteralExp *)dest)->sd->isNested() && oldelems->dim == newelems->dim - 1)
            oldelems->push(NULL);
    }
    else if (dest->op == TOKarrayliteral && src->op==TOKarrayliteral)
    {
        oldelems = ((ArrayLiteralExp *)dest)->elements;
        newelems = ((ArrayLiteralExp *)src)->elements;
    }
    else if (dest->op == TOKstring && src->op == TOKstring)
    {
        sliceAssignStringFromString((StringExp *)dest, (StringExp *)src, 0);
        return;
    }
    else if (dest->op == TOKarrayliteral && src->op == TOKstring)
    {
        sliceAssignArrayLiteralFromString((ArrayLiteralExp *)dest, (StringExp *)src, 0);
        return;
    }
    else if (src->op == TOKarrayliteral && dest->op == TOKstring)
    {
        sliceAssignStringFromArrayLiteral((StringExp *)dest, (ArrayLiteralExp *)src, 0);
        return;
    }
    else assert(0);

    assert(oldelems->dim == newelems->dim);

    for (size_t i= 0; i < oldelems->dim; ++i)
    {
        Expression *e = (*newelems)[i];
        Expression *o = (*oldelems)[i];
        if (e->op == TOKstructliteral)
        {
            assert(o->op == e->op);
            assignInPlace(o, e);
        }
        else if (e->type->ty == Tsarray && o->type->ty == Tsarray && e->op != TOKvoid)
        {
            assignInPlace(o, e);
        }
        else
        {
            (*oldelems)[i] = (*newelems)[i];
        }
    }
}

void recursiveBlockAssign(ArrayLiteralExp *ae, Expression *val, bool wantRef)
{
    assert( ae->type->ty == Tsarray || ae->type->ty == Tarray);
    Type *desttype = ((TypeArray *)ae->type)->next->toBasetype()->castMod(0);
    bool directblk = (val->type->toBasetype()->castMod(0))->equals(desttype);

    bool cow = val->op != TOKstructliteral &&
               val->op != TOKarrayliteral &&
               val->op != TOKstring;

    for (size_t k = 0; k < ae->elements->dim; k++)
    {
        if (!directblk && (*ae->elements)[k]->op == TOKarrayliteral)
        {
            recursiveBlockAssign((ArrayLiteralExp *)(*ae->elements)[k], val, wantRef);
        }
        else
        {
            if (wantRef || cow)
                (*ae->elements)[k] = val;
            else
                assignInPlace((*ae->elements)[k], val);
        }
    }
}

// Duplicate the elements array, then set field 'indexToChange' = newelem.
Expressions *changeOneElement(Expressions *oldelems, size_t indexToChange, Expression *newelem)
{
    Expressions *expsx = new Expressions();
    ++CtfeStatus::numArrayAllocs;
    expsx->setDim(oldelems->dim);
    for (size_t j = 0; j < expsx->dim; j++)
    {
        if (j == indexToChange)
            (*expsx)[j] = newelem;
        else
            (*expsx)[j] = (*oldelems)[j];
    }
    return expsx;
}

// Create a new struct literal, which is the same as se except that se.field[offset] = elem
Expression * modifyStructField(Type *type, StructLiteralExp *se, size_t offset, Expression *newval)
{
    int fieldi = se->getFieldIndex(newval->type, (unsigned)offset);
    if (fieldi == -1)
        return CTFEExp::cantexp;
    /* Create new struct literal reflecting updated fieldi
    */
    Expressions *expsx = changeOneElement(se->elements, fieldi, newval);
    StructLiteralExp * ee = new StructLiteralExp(se->loc, se->sd, expsx);
    ee->type = se->type;
    ee->ownedByCtfe = 1;
    return ee;
}

// Given an AA literal aae,  set arr[index] = newval and return the new array.
Expression *assignAssocArrayElement(Loc loc, AssocArrayLiteralExp *aae,
    Expression *index, Expression *newval)
{
    /* Create new associative array literal reflecting updated key/value
     */
    Expressions *keysx = aae->keys;
    Expressions *valuesx = aae->values;
    int updated = 0;
    for (size_t j = valuesx->dim; j; )
    {
        j--;
        Expression *ekey = (*aae->keys)[j];
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
        valuesx->push(newval);
        keysx->push(index);
    }
    return newval;
}

/// Given array literal oldval of type ArrayLiteralExp or StringExp, of length
/// oldlen, change its length to newlen. If the newlen is longer than oldlen,
/// all new elements will be set to the default initializer for the element type.
Expression *changeArrayLiteralLength(Loc loc, TypeArray *arrayType,
    Expression *oldval,  size_t oldlen, size_t newlen)
{
    Type *elemType = arrayType->next;
    assert(elemType);
    Expression *defaultElem = elemType->defaultInitLiteral(loc);
    Expressions *elements = new Expressions();
    elements->setDim(newlen);

    // Resolve slices
    size_t indxlo = 0;
    if (oldval->op == TOKslice)
    {
        indxlo = (size_t)((SliceExp *)oldval)->lwr->toInteger();
        oldval = ((SliceExp *)oldval)->e1;
    }
    size_t copylen = oldlen < newlen ? oldlen : newlen;
    if (oldval->op == TOKstring)
    {
        StringExp *oldse = (StringExp *)oldval;
        utf8_t *s = (utf8_t *)mem.calloc(newlen + 1, oldse->sz);
        memcpy(s, oldse->string, copylen * oldse->sz);
        unsigned defaultValue = (unsigned)(defaultElem->toInteger());
        for (size_t elemi = copylen; elemi < newlen; ++elemi)
        {
            switch (oldse->sz)
            {
                case 1:     s[(size_t)(indxlo + elemi)] = (utf8_t)defaultValue; break;
                case 2:     ((unsigned short *)s)[(size_t)(indxlo + elemi)] = (unsigned short)defaultValue; break;
                case 4:     ((unsigned *)s)[(size_t)(indxlo + elemi)] = defaultValue; break;
                default:    assert(0);
            }
        }
        StringExp *se = new StringExp(loc, s, newlen);
        se->type = arrayType;
        se->sz = oldse->sz;
        se->committed = oldse->committed;
        se->ownedByCtfe = true;
        return se;
    }
    else
    {
        if (oldlen !=0)
            assert(oldval->op == TOKarrayliteral);
        ArrayLiteralExp *ae = (ArrayLiteralExp *)oldval;
        for (size_t i = 0; i < copylen; i++)
            (*elements)[i] = (*ae->elements)[indxlo + i];
        if (elemType->ty == Tstruct || elemType->ty == Tsarray)
        {
            /* If it is an aggregate literal representing a value type,
             * we need to create a unique copy for each element
             */
            for (size_t i = copylen; i < newlen; i++)
                (*elements)[i] = copyLiteral(defaultElem);
        }
        else
        {
            for (size_t i = copylen; i < newlen; i++)
                (*elements)[i] = defaultElem;
        }
        ArrayLiteralExp *aae = new ArrayLiteralExp(loc, elements);
        aae->type = arrayType;
        aae->ownedByCtfe = true;
        return aae;
    }
}


/*************************** CTFE Sanity Checks ***************************/


bool isCtfeValueValid(Expression *newval)
{
    if (newval->type->ty == Tnull || isPointer(newval->type))
    {
        if (newval->op == TOKaddress || newval->op == TOKnull ||
            newval->op == TOKstring)
            return true;
        if (newval->op == TOKindex)
        {
            Expression *g = ((IndexExp *)newval)->e1;
            if (g->op == TOKarrayliteral || g->op == TOKstring ||
                g->op == TOKassocarrayliteral)
            return true;
        }
        if (newval->op == TOKvar)
            return true;
        if (newval->type->nextOf()->ty == Tarray && newval->op == TOKslice)
            return true;
        if (newval->op == TOKint64)
            return true; // Result of a cast, but cannot be dereferenced
        // else it must be a reference
    }
    if (newval->op == TOKclassreference || (newval->op == TOKnull && newval->type->ty == Tclass))
        return true;
    if (newval->op == TOKvar)
    {
        VarExp *ve = (VarExp *)newval;
        VarDeclaration *vv = ve->var->isVarDeclaration();
        // Must not be a reference to a reference
        if (!(vv && getValue(vv) && getValue(vv)->op == TOKvar))
            return true;
    }
    if (newval->op == TOKdotvar)
    {
        if (((DotVarExp *)newval)->e1->op == TOKstructliteral)
        {
            assert(((StructLiteralExp *)((DotVarExp *)newval)->e1)->ownedByCtfe);
            return true;
        }
    }
    if (newval->op == TOKindex)
    {
        IndexExp *ie = (IndexExp *)newval;
        if (ie->e2->op == TOKint64)
        {
            if (ie->e1->op == TOKarrayliteral || ie->e1->op == TOKstring)
                return true;
        }
        if (ie->e1->op == TOKassocarrayliteral)
            return true;
        // BUG: Happens ONLY in ref foreach. Should tighten this.
        if (ie->e2->op == TOKvar)
            return true;
    }

    if (newval->op == TOKfunction)
        return true; // function literal or delegate literal

    if (newval->op == TOKvector)
        return true; // vector literal

    if (newval->op == TOKdelegate)
    {
        Expression *dge = ((DelegateExp *)newval)->e1;
        if (dge->op == TOKvar && ((VarExp *)dge)->var->isFuncDeclaration())
            return true;        // &nestedfunc

        if (dge->op == TOKstructliteral || dge->op == TOKclassreference)
            return true;       // &struct.func or &clasinst.func
    }
    if (newval->op == TOKsymoff)  // function pointer
    {
        if (((SymOffExp *)newval)->var->isFuncDeclaration())
            return true;
        if (((SymOffExp *)newval)->var->isDataseg())
            return true;    // pointer to static variable
    }

    if (newval->op == TOKint64 || newval->op == TOKfloat64 ||
        newval->op == TOKchar || newval->op == TOKcomplex80)
        return true;

    // References

    if (newval->op == TOKstructliteral)
        assert(((StructLiteralExp *)newval)->ownedByCtfe);
    if (newval->op == TOKarrayliteral)
        assert(((ArrayLiteralExp *)newval)->ownedByCtfe);
    if (newval->op == TOKassocarrayliteral)
        assert(((AssocArrayLiteralExp *)newval)->ownedByCtfe);

    if (newval->op == TOKarrayliteral || newval->op == TOKstructliteral ||
        newval->op == TOKstring || newval->op == TOKassocarrayliteral ||
        newval->op == TOKnull)
    {
        return true;
    }
    // Dynamic arrays passed by ref may be null. When this happens
    // they may originate from an index or dotvar expression.
    if (newval->type->ty == Tarray || newval->type->ty == Taarray)
    {
        if (newval->op == TOKdotvar || newval->op == TOKindex)
            return true; // actually must be null
    }
    if (newval->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)newval;
        assert(se->lwr && se->lwr->op == TOKint64);
        assert(se->upr && se->upr->op == TOKint64);
        assert(se->e1->op == TOKarrayliteral || se->e1->op == TOKstring);
        return true;
    }
    if (newval->op == TOKvoid)
    {
        return true;
    }
    newval->error("CTFE internal error: illegal value %s", newval->toChars());
    return false;
}

// Used for debugging only
void showCtfeExpr(Expression *e, int level)
{
    for (int i = level; i>0; --i) printf(" ");
    Expressions *elements = NULL;
    // We need the struct definition to detect block assignment
    StructDeclaration *sd = NULL;
    ClassDeclaration *cd = NULL;
    if (e->op == TOKstructliteral)
    {
        elements = ((StructLiteralExp *)e)->elements;
        sd = ((StructLiteralExp *)e)->sd;
        printf("STRUCT type = %s %p:\n", e->type->toChars(),
            e);
    }
    else if (e->op == TOKclassreference)
    {
        elements = ((ClassReferenceExp *)e)->value->elements;
        cd = ((ClassReferenceExp *)e)->originalClass();
        printf("CLASS type = %s %p:\n", e->type->toChars(),
            ((ClassReferenceExp *)e)->value);
    }
    else if (e->op == TOKarrayliteral)
    {
        elements = ((ArrayLiteralExp *)e)->elements;
        printf("ARRAY LITERAL type=%s %p:\n", e->type->toChars(),
            e);
    }
    else if (e->op == TOKassocarrayliteral)
    {
        printf("AA LITERAL type=%s %p:\n", e->type->toChars(),
            e);
    }
    else if (e->op == TOKstring)
    {
        printf("STRING %s %p\n", e->toChars(),
            ((StringExp *)e)->string);
    }
    else if (e->op == TOKslice)
    {
        printf("SLICE %p: %s\n", e, e->toChars());
        showCtfeExpr(((SliceExp *)e)->e1, level + 1);
    }
    else if (e->op == TOKvar)
    {
        printf("VAR %p %s\n", e, e->toChars());
        VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
        if (v && getValue(v))
            showCtfeExpr(getValue(v), level + 1);
    }
    else if (isPointer(e->type))
    {
        // This is potentially recursive. We mustn't try to print the thing we're pointing to.
        if (e->op == TOKindex)
            printf("POINTER %p into %p [%s]\n", e, ((IndexExp *)e)->e1, ((IndexExp *)e)->e2->toChars());
        else if (e->op == TOKdotvar)
            printf("POINTER %p to %p .%s\n", e, ((DotVarExp *)e)->e1, ((DotVarExp *)e)->var->toChars());
        else
            printf("POINTER %p: %s\n", e, e->toChars());
    }
    else
        printf("VALUE %p: %s\n", e, e->toChars());

    if (elements)
    {
        size_t fieldsSoFar = 0;
        for (size_t i = 0; i < elements->dim; i++)
        {
            Expression *z = NULL;
            VarDeclaration *v = NULL;
            if (i > 15)
            {
                printf("...(total %d elements)\n", (int)elements->dim);
                return;
            }
            if (sd)
            {
                v = sd->fields[i];
                z = (*elements)[i];
            }
            else if (cd)
            {
                while (i - fieldsSoFar >= cd->fields.dim)
                {
                    fieldsSoFar += cd->fields.dim;
                    cd = cd->baseClass;
                    for (int j = level; j>0; --j) printf(" ");
                    printf(" BASE CLASS: %s\n", cd->toChars());
                }
                v = cd->fields[i - fieldsSoFar];
                assert((elements->dim + i) >= (fieldsSoFar + cd->fields.dim));
                size_t indx = (elements->dim - fieldsSoFar)- cd->fields.dim + i;
                assert(indx < elements->dim);
                z = (*elements)[indx];
            }
            if (!z)
            {
                for (int j = level; j>0; --j) printf(" ");
                printf(" void\n");
                continue;
            }

            if (v)
            {
                // If it is a void assignment, use the default initializer
                if ((v->type->ty != z->type->ty) && v->type->ty == Tsarray)
                {
                    for (int j = level; --j;) printf(" ");
                    printf(" field: block initalized static array\n");
                    continue;
                }
            }
            showCtfeExpr(z, level + 1);
        }
    }
}

/*************************** Void initialization ***************************/

UnionExp voidInitLiteral(Type *t, VarDeclaration *var)
{
    UnionExp ue;
    if (t->ty == Tsarray)
    {
        TypeSArray *tsa = (TypeSArray *)t;
        Expression *elem = voidInitLiteral(tsa->next, var).copy();

        // For aggregate value types (structs, static arrays) we must
        // create an a separate copy for each element.
        bool mustCopy = (elem->op == TOKarrayliteral || elem->op == TOKstructliteral);

        Expressions *elements = new Expressions();
        size_t d = (size_t)tsa->dim->toInteger();
        elements->setDim(d);
        for (size_t i = 0; i < d; i++)
        {
            if (mustCopy && i > 0)
                elem  = copyLiteral(elem);
            (*elements)[i] = elem;
        }
        new(&ue) ArrayLiteralExp(var->loc, elements);
        ArrayLiteralExp *ae = (ArrayLiteralExp *)ue.exp();
        ae->type = tsa;
        ae->ownedByCtfe = true;
    }
    else if (t->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)t;
        Expressions *exps = new Expressions();
        exps->setDim(ts->sym->fields.dim);
        for (size_t i = 0; i < ts->sym->fields.dim; i++)
        {
            (*exps)[i] = voidInitLiteral(ts->sym->fields[i]->type, ts->sym->fields[i]).copy();
        }
        new(&ue) StructLiteralExp(var->loc, ts->sym, exps);
        StructLiteralExp *se = (StructLiteralExp *)ue.exp();
        se->type = ts;
        se->ownedByCtfe = true;
    }
    else
        new(&ue) VoidInitExp(var, t);
    return ue;
}
