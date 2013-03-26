
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <ctype.h>
#include <assert.h>
#include <math.h>

#if __DMC__
#include <complex.h>
#endif

#include "lexer.h"
#include "mtype.h"
#include "expression.h"
#include "declaration.h"
#include "aggregate.h"
#include "init.h"


#ifdef IN_GCC
#include "d-gcc-real.h"
#endif

static real_t zero;     // work around DMC bug for now


/*************************************
 * If variable has a const initializer,
 * return that initializer.
 */

Expression *expandVar(int result, VarDeclaration *v)
{
    //printf("expandVar(result = %d, v = %p, %s)\n", result, v, v ? v->toChars() : "null");

    Expression *e = NULL;
    if (!v)
        return e;
    if (!v->originalType && v->scope)   // semantic() not yet run
        v->semantic (v->scope);

    if (v->isConst() || v->isImmutable() || v->storage_class & STCmanifest)
    {
        if (!v->type)
        {
            //error("ICE");
            return e;
        }
        Type *tb = v->type->toBasetype();
        if (result & WANTinterpret ||
            v->storage_class & STCmanifest ||
            v->type->toBasetype()->isscalar() ||
            ((result & WANTexpand) && (tb->ty != Tsarray && tb->ty != Tstruct))
           )
        {
            if (v->init)
            {
                if (v->inuse)
                {   if (v->storage_class & STCmanifest)
                        v->error("recursive initialization of constant");
                    goto L1;
                }
                if (v->scope)
                {
                    v->init->semantic(v->scope, v->type, INITinterpret);
                }
                Expression *ei = v->init->toExpression(v->type);
                if (!ei)
                {   if (v->storage_class & STCmanifest)
                        v->error("enum cannot be initialized with %s", v->init->toChars());
                    goto L1;
                }
                if (ei->op == TOKconstruct || ei->op == TOKblit)
                {   AssignExp *ae = (AssignExp *)ei;
                    ei = ae->e2;
                    if (result & WANTinterpret)
                    {
                        v->inuse++;
                        ei = ei->optimize(result);
                        v->inuse--;
                    }
                    else if (ei->isConst() != 1 && ei->op != TOKstring)
                        goto L1;

                    if (ei->type == v->type)
                    {   // const variable initialized with const expression
                    }
                    else if (ei->implicitConvTo(v->type) >= MATCHconst)
                    {   // const var initialized with non-const expression
                        ei = ei->implicitCastTo(0, v->type);
                        ei = ei->semantic(0);
                    }
                    else
                        goto L1;
                }
                if (v->scope)
                {
                    v->inuse++;
                    e = ei->syntaxCopy();
                    e = e->semantic(v->scope);
                    e = e->implicitCastTo(v->scope, v->type);
                    // enabling this line causes test22 in test suite to fail
                    //ei->type = e->type;
                    v->scope = NULL;
                    v->inuse--;
                }
                else if (!ei->type)
                {
                    goto L1;
                }
                else
                    // Should remove the copy() operation by
                    // making all mods to expressions copy-on-write
                    e = ei->copy();
            }
            else
            {
#if 1
                goto L1;
#else
                // BUG: what if const is initialized in constructor?
                e = v->type->defaultInit();
                e->loc = e1->loc;
#endif
            }
            if (e->type != v->type)
            {
                e = e->castTo(NULL, v->type);
            }
            v->inuse++;
            e = e->optimize(result);
            v->inuse--;
        }
    }
L1:
    //if (e) printf("\te = %p, %s, e->type = %d, %s\n", e, e->toChars(), e->type->ty, e->type->toChars());
    return e;
}


Expression *fromConstInitializer(int result, Expression *e1)
{
    //printf("fromConstInitializer(result = %x, %s)\n", result, e1->toChars());
    //static int xx; if (xx++ == 10) assert(0);
    Expression *e = e1;
    if (e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        e = expandVar(result, v);
        if (e)
        {
            // If it is a comma expression involving a declaration, we mustn't
            // perform a copy -- we'd get two declarations of the same variable.
            // See bugzilla 4465.
            if (e->op == TOKcomma && ((CommaExp *)e)->e1->op == TOKdeclaration)
                 e = e1;
            else

            if (e->type != e1->type && e1->type && e1->type->ty != Tident)
            {   // Type 'paint' operation
                e = e->copy();
                e->type = e1->type;
            }
            e->loc = e1->loc;
        }
        else
        {
            e = e1;
            /* If we needed to interpret, generate an error.
             * Don't give an error if it's a template parameter
             */
            if (v && (result & WANTinterpret) &&
                !(v->storage_class & STCtemplateparameter))
            {
                e1->error("variable %s cannot be read at compile time", v->toChars());
                e = e->copy();
                e->type = Type::terror;
            }
        }
    }
    return e;
}


Expression *Expression::optimize(int result, bool keepLvalue)
{
    //printf("Expression::optimize(result = x%x) %s\n", result, toChars());
    return this;
}

Expression *VarExp::optimize(int result, bool keepLvalue)
{
    return keepLvalue ? this : fromConstInitializer(result, this);
}

Expression *TupleExp::optimize(int result, bool keepLvalue)
{
    for (size_t i = 0; i < exps->dim; i++)
    {   Expression *e = (*exps)[i];

        e = e->optimize(WANTvalue | (result & WANTinterpret));
        (*exps)[i] = e;
    }
    return this;
}

Expression *ArrayLiteralExp::optimize(int result, bool keepLvalue)
{
    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {   Expression *e = (*elements)[i];

            e = e->optimize(WANTvalue | (result & (WANTinterpret | WANTexpand)));
            (*elements)[i] = e;
        }
    }
    return this;
}

Expression *AssocArrayLiteralExp::optimize(int result, bool keepLvalue)
{
    assert(keys->dim == values->dim);
    for (size_t i = 0; i < keys->dim; i++)
    {   Expression *e = (*keys)[i];

        e = e->optimize(WANTvalue | (result & (WANTinterpret | WANTexpand)));
        (*keys)[i] = e;

        e = (*values)[i];
        e = e->optimize(WANTvalue | (result & (WANTinterpret | WANTexpand)));
        (*values)[i] = e;
    }
    return this;
}

Expression *StructLiteralExp::optimize(int result, bool keepLvalue)
{
    if (elements)
    {
        for (size_t i = 0; i < elements->dim; i++)
        {   Expression *e = (*elements)[i];
            if (!e)
                continue;
            e = e->optimize(WANTvalue | (result & (WANTinterpret | WANTexpand)));
            (*elements)[i] = e;
        }
    }
    return this;
}

Expression *TypeExp::optimize(int result, bool keepLvalue)
{
    return this;
}

Expression *UnaExp::optimize(int result, bool keepLvalue)
{
    //printf("UnaExp::optimize() %s\n", toChars());
    e1 = e1->optimize(result);
    return this;
}

Expression *NegExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst() == 1)
    {
        e = Neg(type, e1);
    }
    else
        e = this;
    return e;
}

Expression *ComExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst() == 1)
    {
        e = Com(type, e1);
    }
    else
        e = this;
    return e;
}

Expression *NotExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst() == 1)
    {
        e = Not(type, e1);
    }
    else
        e = this;
    return e;
}

Expression *BoolExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    if (e1->isConst() == 1)
    {
        e = Bool(type, e1);
    }
    else
        e = this;
    return e;
}

Expression *AddrExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("AddrExp::optimize(result = %d) %s\n", result, toChars());

    /* Rewrite &(a,b) as (a,&b)
     */
    if (e1->op == TOKcomma)
    {   CommaExp *ce = (CommaExp *)e1;
        AddrExp *ae = new AddrExp(loc, ce->e2);
        ae->type = type;
        e = new CommaExp(ce->loc, ce->e1, ae);
        e->type = type;
        return e->optimize(result);
    }

    if (e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)e1;
        if (ve->var->storage_class & STCmanifest)
            e1 = e1->optimize(result);
    }
    else
        e1 = e1->optimize(result);

    // Convert &*ex to ex
    if (e1->op == TOKstar)
    {   Expression *ex;

        ex = ((PtrExp *)e1)->e1;
        if (type->equals(ex->type))
            e = ex;
        else
        {
            e = ex->copy();
            e->type = type;
        }
        return e;
    }
    if (e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)e1;
        if (!ve->var->isOut() && !ve->var->isRef() &&
            !ve->var->isImportedSymbol())
        {
            SymOffExp *se = new SymOffExp(loc, ve->var, 0, ve->hasOverloads);
            se->type = type;
            return se;
        }
    }
    if (e1->op == TOKindex)
    {   // Convert &array[n] to &array+n
        IndexExp *ae = (IndexExp *)e1;

        if (ae->e2->op == TOKint64 && ae->e1->op == TOKvar)
        {
            dinteger_t index = ae->e2->toInteger();
            VarExp *ve = (VarExp *)ae->e1;
            if (ve->type->ty == Tsarray
                && !ve->var->isImportedSymbol())
            {
                TypeSArray *ts = (TypeSArray *)ve->type;
                sinteger_t dim = ts->dim->toInteger();
                if (index < 0 || index >= dim)
                    error("array index %lld is out of bounds [0..%lld]", index, dim);
                e = new SymOffExp(loc, ve->var, index * ts->nextOf()->size());
                e->type = type;
                return e;
            }
        }
    }
    return this;
}

Expression *PtrExp::optimize(int result, bool keepLvalue)
{
    //printf("PtrExp::optimize(result = x%x) %s\n", result, toChars());
    e1 = e1->optimize(result);
    // Convert *&ex to ex
    if (e1->op == TOKaddress)
    {   Expression *e;
        Expression *ex;

        ex = ((AddrExp *)e1)->e1;
        if (type->equals(ex->type))
            e = ex;
        else
        {
            e = ex->copy();
            e->type = type;
        }
        return e;
    }
    if (keepLvalue)
        return this;

    // Constant fold *(&structliteral + offset)
    if (e1->op == TOKadd)
    {
        Expression *e;
        e = Ptr(type, e1);
        if (e != EXP_CANT_INTERPRET)
            return e;
    }

    if (e1->op == TOKsymoff)
    {   SymOffExp *se = (SymOffExp *)e1;
        VarDeclaration *v = se->var->isVarDeclaration();
        Expression *e = expandVar(result, v);
        if (e && e->op == TOKstructliteral)
        {   StructLiteralExp *sle = (StructLiteralExp *)e;
            e = sle->getField(type, se->offset);
            if (e && e != EXP_CANT_INTERPRET)
                return e;
        }
    }
    return this;
}

Expression *DotVarExp::optimize(int result, bool keepLvalue)
{
    //printf("DotVarExp::optimize(result = x%x) %s\n", result, toChars());
    e1 = e1->optimize(result);
    if (keepLvalue)
        return this;

    Expression *e = e1;

    if (e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)e1;
        VarDeclaration *v = ve->var->isVarDeclaration();
        e = expandVar(result, v);
    }

    if (e && e->op == TOKstructliteral)
    {   StructLiteralExp *sle = (StructLiteralExp *)e;
        VarDeclaration *vf = var->isVarDeclaration();
        if (vf)
        {
            Expression *e = sle->getField(type, vf->offset);
            if (e && e != EXP_CANT_INTERPRET)
                return e;
        }
    }

    return this;
}

Expression *NewExp::optimize(int result, bool keepLvalue)
{
    if (thisexp)
        thisexp = thisexp->optimize(WANTvalue);

    // Optimize parameters
    if (newargs)
    {
        for (size_t i = 0; i < newargs->dim; i++)
        {   Expression *e = (*newargs)[i];

            e = e->optimize(WANTvalue);
            (*newargs)[i] = e;
        }
    }

    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {   Expression *e = (*arguments)[i];

            e = e->optimize(WANTvalue);
            (*arguments)[i] = e;
        }
    }
    if (result & WANTinterpret)
    {
        error("cannot evaluate %s at compile time", toChars());
    }
    return this;
}

Expression *CallExp::optimize(int result, bool keepLvalue)
{
    //printf("CallExp::optimize(result = %d) %s\n", result, toChars());
    Expression *e = this;

    // Optimize parameters with keeping lvalue-ness
    if (arguments)
    {
        Type *t1 = e1->type->toBasetype();
        if (t1->ty == Tdelegate) t1 = t1->nextOf();
        assert(t1->ty == Tfunction);
        TypeFunction *tf = (TypeFunction *)t1;
        size_t pdim = Parameter::dim(tf->parameters) - (tf->varargs == 2 ? 1 : 0);
        for (size_t i = 0; i < arguments->dim; i++)
        {
            bool keepLvalue = false;
            if (i < pdim)
            {
                Parameter *p = Parameter::getNth(tf->parameters, i);
                keepLvalue = ((p->storageClass & (STCref | STCout)) != 0);
            }
            Expression *e = (*arguments)[i];
            e = e->optimize(WANTvalue, keepLvalue);
            (*arguments)[i] = e;
        }
    }

    e1 = e1->optimize(result);
    if (keepLvalue)
        return this;

#if 1
    if (result & WANTinterpret)
    {
        Expression *eresult = interpret(NULL);
        if (eresult == EXP_CANT_INTERPRET)
            return e;
        if (eresult && eresult != EXP_VOID_INTERPRET)
            e = eresult;
        else
            error("cannot evaluate %s at compile time", toChars());
    }
#else
    if (e1->op == TOKvar)
    {
        FuncDeclaration *fd = ((VarExp *)e1)->var->isFuncDeclaration();
        if (fd)
        {
            enum BUILTIN b = fd->isBuiltin();
            if (b)
            {
                e = eval_builtin(b, arguments);
                if (!e)                 // failed
                    e = this;           // evaluate at runtime
            }
            else if (result & WANTinterpret)
            {
                Expression *eresult = fd->interpret(NULL, arguments);
                if (eresult && eresult != EXP_VOID_INTERPRET)
                    e = eresult;
                else
                    error("cannot evaluate %s at compile time", toChars());
            }
        }
    }
    else if (e1->op == TOKdotvar && result & WANTinterpret)
    {   DotVarExp *dve = (DotVarExp *)e1;
        FuncDeclaration *fd = dve->var->isFuncDeclaration();
        if (fd)
        {
            Expression *eresult = fd->interpret(NULL, arguments, dve->e1);
            if (eresult && eresult != EXP_VOID_INTERPRET)
                e = eresult;
            else
                error("cannot evaluate %s at compile time", toChars());
        }
    }
#endif
    return e;
}


Expression *CastExp::optimize(int result, bool keepLvalue)
{
    //printf("CastExp::optimize(result = %d) %s\n", result, toChars());
    //printf("from %s to %s\n", type->toChars(), to->toChars());
    //printf("from %s\n", type->toChars());
    //printf("e1->type %s\n", e1->type->toChars());
    //printf("type = %p\n", type);
    assert(type);
    enum TOK op1 = e1->op;
#define X 0

    Expression *e1old = e1;
    e1 = e1->optimize(result);
    e1 = fromConstInitializer(result, e1);

    if (e1 == e1old &&
        e1->op == TOKarrayliteral &&
        type->toBasetype()->ty == Tpointer &&
        e1->type->toBasetype()->ty != Tsarray)
    {
        // Casting this will result in the same expression, and
        // infinite loop because of Expression::implicitCastTo()
        return this;            // no change
    }

    if ((e1->op == TOKstring || e1->op == TOKarrayliteral) &&
        (type->ty == Tpointer || type->ty == Tarray) &&
        e1->type->nextOf()->size() == type->nextOf()->size()
       )
    {
        Expression *e = e1->castTo(NULL, type);
        if (X) printf(" returning1 %s\n", e->toChars());
        return e;
    }

    if (e1->op == TOKstructliteral &&
        e1->type->implicitConvTo(type) >= MATCHconst)
    {
        if (X) printf(" returning2 %s\n", e1->toChars());
        goto L1;
    }

    /* The first test here is to prevent infinite loops
     */
    if (op1 != TOKarrayliteral && e1->op == TOKarrayliteral)
        return e1->castTo(NULL, to);
    if (e1->op == TOKnull &&
        (type->ty == Tpointer || type->ty == Tclass || type->ty == Tarray))
    {
        if (X) printf(" returning3 %s\n", e1->toChars());
        goto L1;
    }

    if (result & WANTflags && type->ty == Tclass && e1->type->ty == Tclass)
    {
        // See if we can remove an unnecessary cast
        ClassDeclaration *cdfrom;
        ClassDeclaration *cdto;
        int offset;

        cdfrom = e1->type->isClassHandle();
        cdto   = type->isClassHandle();
        if (cdto->isBaseOf(cdfrom, &offset) && offset == 0)
        {
            if (X) printf(" returning4 %s\n", e1->toChars());
            goto L1;
        }
    }

    // We can convert 'head const' to mutable
    if (to->mutableOf()->constOf()->equals(e1->type->mutableOf()->constOf()))
    {
        if (X) printf(" returning5 %s\n", e1->toChars());
        goto L1;
    }

    Expression *e;

    if (e1->isConst())
    {
        if (e1->op == TOKsymoff)
        {
            if (type->size() == e1->type->size() &&
                type->toBasetype()->ty != Tsarray)
            {
                goto L1;
            }
            return this;
        }
        if (to->toBasetype()->ty == Tvoid)
            e = this;
        else
            e = Cast(type, to, e1);
    }
    else
        e = this;
    if (X) printf(" returning6 %s\n", e->toChars());
    return e;
L1: // Returning e1 with changing its type
    e = (e1old == e1 ? e1->copy() : e1);
    e->type = type;
    return e;
#undef X
}

Expression *BinExp::optimize(int result, bool keepLvalue)
{
    //printf("BinExp::optimize(result = %d) %s\n", result, toChars());
    if (op != TOKconstruct && op != TOKblit)    // don't replace const variable with its initializer
        e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (op == TOKshlass || op == TOKshrass || op == TOKushrass)
    {
        if (e2->isConst() == 1)
        {
            sinteger_t i2 = e2->toInteger();
            d_uns64 sz = e1->type->size() * 8;
            if (i2 < 0 || i2 >= sz)
            {   error("shift assign by %lld is outside the range 0..%llu", i2, (ulonglong)sz - 1);
                e2 = new IntegerExp(0);
            }
        }
    }
    return this;
}

Expression *AddExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("AddExp::optimize(%s)\n", toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() && e2->isConst())
    {
        if (e1->op == TOKsymoff && e2->op == TOKsymoff)
            return this;
        e = Add(type, e1, e2);
    }
    else
        e = this;
    return e;
}

Expression *MinExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() && e2->isConst())
    {
        if (e2->op == TOKsymoff)
            return this;
        e = Min(type, e1, e2);
    }
    else
        e = this;
    return e;
}

Expression *MulExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("MulExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
    {
        e = Mul(type, e1, e2);
    }
    else
        e = this;
    return e;
}

Expression *DivExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("DivExp::optimize(%s)\n", toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
    {
        e = Div(type, e1, e2);
    }
    else
        e = this;
    return e;
}

Expression *ModExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
    {
        e = Mod(type, e1, e2);
    }
    else
        e = this;
    return e;
}

Expression *shift_optimize(int result, BinExp *e, Expression *(*shift)(Type *, Expression *, Expression *))
{   Expression *ex = e;

    e->e1 = e->e1->optimize(result);
    e->e2 = e->e2->optimize(result);
    if (e->e2->isConst() == 1)
    {
        sinteger_t i2 = e->e2->toInteger();
        d_uns64 sz = e->e1->type->size() * 8;
        if (i2 < 0 || i2 >= sz)
        {   e->error("shift by %lld is outside the range 0..%llu", i2, (ulonglong)sz - 1);
            e->e2 = new IntegerExp(0);
        }
        if (e->e1->isConst() == 1)
            ex = (*shift)(e->type, e->e1, e->e2);
    }
    return ex;
}

Expression *ShlExp::optimize(int result, bool keepLvalue)
{
    //printf("ShlExp::optimize(result = %d) %s\n", result, toChars());
    return shift_optimize(result, this, &Shl);
}

Expression *ShrExp::optimize(int result, bool keepLvalue)
{
    //printf("ShrExp::optimize(result = %d) %s\n", result, toChars());
    return shift_optimize(result, this, &Shr);
}

Expression *UshrExp::optimize(int result, bool keepLvalue)
{
    //printf("UshrExp::optimize(result = %d) %s\n", result, toChars());
    return shift_optimize(result, this, &Ushr);
}

Expression *AndExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
        e = And(type, e1, e2);
    else
        e = this;
    return e;
}

Expression *OrExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
        e = Or(type, e1, e2);
    else
        e = this;
    return e;
}

Expression *XorExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    if (e1->isConst() == 1 && e2->isConst() == 1)
        e = Xor(type, e1, e2);
    else
        e = this;
    return e;
}

Expression *PowExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(result);
    e2 = e2->optimize(result);

    // Replace 1 ^^ x or 1.0^^x by (x, 1)
    if ((e1->op == TOKint64 && e1->toInteger() == 1) ||
        (e1->op == TOKfloat64 && e1->toReal() == 1.0))
    {
        e = new CommaExp(loc, e2, e1);
    }
    // Replace -1 ^^ x by (x&1) ? -1 : 1, where x is integral
    else if (e2->type->isintegral() && e1->op == TOKint64 && (sinteger_t)e1->toInteger() == -1L)
    {
        Type* resultType = type;
        e = new AndExp(loc, e2, new IntegerExp(loc, 1, e2->type));
        e = new CondExp(loc, e, new IntegerExp(loc, -1L, resultType), new IntegerExp(loc, 1L, resultType));
    }
    // Replace x ^^ 0 or x^^0.0 by (x, 1)
    else if ((e2->op == TOKint64 && e2->toInteger() == 0) ||
             (e2->op == TOKfloat64 && e2->toReal() == 0.0))
    {
        if (e1->type->isintegral())
            e = new IntegerExp(loc, 1, e1->type);
        else
            e = new RealExp(loc, ldouble(1.0), e1->type);

        e = new CommaExp(loc, e1, e);
    }
    // Replace x ^^ 1 or x^^1.0 by (x)
    else if ((e2->op == TOKint64 && e2->toInteger() == 1) ||
             (e2->op == TOKfloat64 && e2->toReal() == 1.0))
    {
        e = e1;
    }
    // Replace x ^^ -1.0 by (1.0 / x)
    else if ((e2->op == TOKfloat64 && e2->toReal() == -1.0))
    {
        e = new DivExp(loc, new RealExp(loc, ldouble(1.0), e2->type), e1);
    }
    // All other negative integral powers are illegal
    else if ((e1->type->isintegral()) && (e2->op == TOKint64) && (sinteger_t)e2->toInteger() < 0)
    {
        error("cannot raise %s to a negative integer power. Did you mean (cast(real)%s)^^%s ?",
              e1->type->toBasetype()->toChars(), e1->toChars(), e2->toChars());
        e = new ErrorExp();
    }
    else
    {
        // If e2 *could* have been an integer, make it one.
        if (e2->op == TOKfloat64 && (e2->toReal() == (sinteger_t)(e2->toReal())))
            e2 = new IntegerExp(loc, e2->toInteger(), Type::tint64);

        if (e1->isConst() == 1 && e2->isConst() == 1)
        {
            e = Pow(type, e1, e2);
            if (e != EXP_CANT_INTERPRET)
                return e;
        }
        e = this;
    }
    return e;
}

Expression *CommaExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("CommaExp::optimize(result = %d) %s\n", result, toChars());
    // Comma needs special treatment, because it may
    // contain compiler-generated declarations. We can interpret them, but
    // otherwise we must NOT attempt to constant-fold them.
    // In particular, if the comma returns a temporary variable, it needs
    // to be an lvalue (this is particularly important for struct constructors)

    if (result & WANTinterpret)
    {   // Interpreting comma needs special treatment, because it may
        // contain compiler-generated declarations.
        e = interpret(NULL);
        return (e == EXP_CANT_INTERPRET) ?  this : e;
    }

    e1 = e1->optimize(result & WANTinterpret);
    e2 = e2->optimize(result, keepLvalue);
    if (!e1 || e1->op == TOKint64 || e1->op == TOKfloat64 || !e1->hasSideEffect())
    {
        e = e2;
        if (e)
            e->type = type;
    }
    else
        e = this;
    //printf("-CommaExp::optimize(result = %d) %s\n", result, e->toChars());
    return e;
}

Expression *ArrayLengthExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("ArrayLengthExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue | WANTexpand | (result & WANTinterpret));
    e = this;
    if (e1->op == TOKstring || e1->op == TOKarrayliteral || e1->op == TOKassocarrayliteral)
    {
        e = ArrayLength(type, e1);
    }
    return e;
}

Expression *EqualExp::optimize(int result, bool keepLvalue)
{
    //printf("EqualExp::optimize(result = %x) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue | (result & WANTinterpret));
    e2 = e2->optimize(WANTvalue | (result & WANTinterpret));

    Expression *e1 = fromConstInitializer(result, this->e1);
    Expression *e2 = fromConstInitializer(result, this->e2);

    Expression *e = Equal(op, type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        e = this;
    return e;
}

Expression *IdentityExp::optimize(int result, bool keepLvalue)
{
    //printf("IdentityExp::optimize(result = %d) %s\n", result, toChars());
    e1 = e1->optimize(WANTvalue | (result & WANTinterpret));
    e2 = e2->optimize(WANTvalue | (result & WANTinterpret));
    Expression *e = this;

    if ((this->e1->isConst()     && this->e2->isConst()) ||
        (this->e1->op == TOKnull && this->e2->op == TOKnull))
    {
        e = Identity(op, type, this->e1, this->e2);
        if (e == EXP_CANT_INTERPRET)
            e = this;
    }
    return e;
}

/* It is possible for constant folding to change an array expression of
 * unknown length, into one where the length is known.
 * If the expression 'arr' is a literal, set lengthVar to be its length.
 */
void setLengthVarIfKnown(VarDeclaration *lengthVar, Expression *arr)
{
    if (!lengthVar)
        return;
    if (lengthVar->init && !lengthVar->init->isVoidInitializer())
        return; // we have previously calculated the length
    size_t len;
    if (arr->op == TOKstring)
        len = ((StringExp *)arr)->len;
    else if (arr->op == TOKarrayliteral)
        len = ((ArrayLiteralExp *)arr)->elements->dim;
    else
    {
        Type *t = arr->type->toBasetype();
        if (t->ty == Tsarray)
            len = ((TypeSArray *)t)->dim->toInteger();
        else
            return; // we don't know the length yet
    }

    Expression *dollar = new IntegerExp(0, len, Type::tsize_t);
    lengthVar->init = new ExpInitializer(0, dollar);
    lengthVar->storage_class |= STCstatic | STCconst;
}


Expression *IndexExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("IndexExp::optimize(result = %d) %s\n", result, toChars());
    Expression *e1 = this->e1->optimize(
        WANTvalue | (result & (WANTinterpret| WANTexpand)));
    e1 = fromConstInitializer(result, e1);
    if (this->e1->op == TOKvar)
    {   VarExp *ve = (VarExp *)this->e1;
        if (ve->var->storage_class & STCmanifest)
        {   /* We generally don't want to have more than one copy of an
             * array literal, but if it's an enum we have to because the
             * enum isn't stored elsewhere. See Bugzilla 2559
             */
            this->e1 = e1;
        }
    }
    // We might know $ now
    setLengthVarIfKnown(lengthVar, e1);
    e2 = e2->optimize(WANTvalue | (result & WANTinterpret));
    if (keepLvalue)
        return this;
    e = Index(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        e = this;
    return e;
}


Expression *SliceExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("SliceExp::optimize(result = %d) %s\n", result, toChars());
    e = this;
    e1 = e1->optimize(WANTvalue | (result & (WANTinterpret|WANTexpand)));
    if (!lwr)
    {   if (e1->op == TOKstring)
        {   // Convert slice of string literal into dynamic array
            Type *t = e1->type->toBasetype();
            if (t->nextOf())
                e = e1->castTo(NULL, t->nextOf()->arrayOf());
        }
        return e;
    }
    e1 = fromConstInitializer(result, e1);
    // We might know $ now
    setLengthVarIfKnown(lengthVar, e1);
    lwr = lwr->optimize(WANTvalue | (result & WANTinterpret));
    upr = upr->optimize(WANTvalue | (result & WANTinterpret));
    e = Slice(type, e1, lwr, upr);
    if (e == EXP_CANT_INTERPRET)
        e = this;
    //printf("-SliceExp::optimize() %s\n", e->toChars());
    return e;
}

Expression *AndAndExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("AndAndExp::optimize(%d) %s\n", result, toChars());
    e1 = e1->optimize(WANTflags | (result & WANTinterpret));
    e = this;
    if (e1->isBool(FALSE))
    {
        if (type->toBasetype()->ty == Tvoid)
            e = e2;
        else
        {   e = new CommaExp(loc, e1, new IntegerExp(loc, 0, type));
            e->type = type;
        }
        e = e->optimize(result);
    }
    else
    {
        e2 = e2->optimize(WANTflags | (result & WANTinterpret));
        if (result && e2->type->toBasetype()->ty == Tvoid && !global.errors)
            error("void has no value");
        if (e1->isConst())
        {
            if (e2->isConst())
            {   int n1 = e1->isBool(1);
                int n2 = e2->isBool(1);

                e = new IntegerExp(loc, n1 && n2, type);
            }
            else if (e1->isBool(TRUE))
            {
                if (type->toBasetype()->ty == Tvoid)
                    e = e2;
                else e = new BoolExp(loc, e2, type);
            }
        }
    }
    return e;
}

Expression *OrOrExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    e1 = e1->optimize(WANTflags | (result & WANTinterpret));
    e = this;
    if (e1->isBool(TRUE))
    {   // Replace with (e1, 1)
        e = new CommaExp(loc, e1, new IntegerExp(loc, 1, type));
        e->type = type;
        e = e->optimize(result);
    }
    else
    {
        e2 = e2->optimize(WANTflags | (result & WANTinterpret));
        if (result && e2->type->toBasetype()->ty == Tvoid && !global.errors)
            error("void has no value");
        if (e1->isConst())
        {
            if (e2->isConst())
            {   int n1 = e1->isBool(1);
                int n2 = e2->isBool(1);

                e = new IntegerExp(loc, n1 || n2, type);
            }
            else if (e1->isBool(FALSE))
            {
                if (type->toBasetype()->ty == Tvoid)
                    e = e2;
                else
                    e = new BoolExp(loc, e2, type);
            }
        }
    }
    return e;
}

Expression *CmpExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("CmpExp::optimize() %s\n", toChars());
    e1 = e1->optimize(WANTvalue | (result & WANTinterpret));
    e2 = e2->optimize(WANTvalue | (result & WANTinterpret));

    Expression *e1 = fromConstInitializer(result, this->e1);
    Expression *e2 = fromConstInitializer(result, this->e2);

    e = Cmp(op, type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        e = this;
    return e;
}

Expression *CatExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    //printf("CatExp::optimize(%d) %s\n", result, toChars());
    e1 = e1->optimize(result);
    e2 = e2->optimize(result);
    e = Cat(type, e1, e2);
    if (e == EXP_CANT_INTERPRET)
        e = this;
    return e;
}


Expression *CondExp::optimize(int result, bool keepLvalue)
{   Expression *e;

    econd = econd->optimize(WANTflags | (result & WANTinterpret));
    if (econd->isBool(TRUE))
        e = e1->optimize(result, keepLvalue);
    else if (econd->isBool(FALSE))
        e = e2->optimize(result, keepLvalue);
    else
    {   e1 = e1->optimize(result, keepLvalue);
        e2 = e2->optimize(result, keepLvalue);
        e = this;
    }
    return e;
}


