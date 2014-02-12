
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>
#include <string.h>                     // mem{set|cpy}()

#include "rmem.h"

#include "expression.h"
#include "mtype.h"
#include "utf.h"
#include "declaration.h"
#include "aggregate.h"
#include "template.h"
#include "scope.h"
#include "id.h"

bool isCommutative(Expression *e);

/* ==================== implicitCast ====================== */

/**************************************
 * Do an implicit cast.
 * Issue error if it can't be done.
 */


Expression *implicitCastTo(Expression *e, Scope *sc, Type *t)
{
    class ImplicitCastTo : public Visitor
    {
    public:
        Type *t;
        Scope *sc;
        Expression *result;

        ImplicitCastTo(Scope *sc, Type *t)
            : sc(sc), t(t)
        {
            result = NULL;
        }

        void visit(Expression *e)
        {
            //printf("Expression::implicitCastTo(%s of type %s) => %s\n", e->toChars(), e->type->toChars(), t->toChars());

            MATCH match = e->implicitConvTo(t);
            if (match)
            {
                if (match == MATCHconst && e->type->constConv(t))
                {
                    result = e->copy();
                    result->type = t;
                    return;
                }
                result = e->castTo(sc, t);
                return;
            }

            result = e->optimize(WANTflags | WANTvalue);
            if (result != e)
            {
                result->accept(this);
                return;
            }

            if (t->ty != Terror && e->type->ty != Terror)
            {
                if (!t->deco)
                {
                    /* Can happen with:
                     *    enum E { One }
                     *    class A
                     *    { static void fork(EDG dg) { dg(E.One); }
                     *      alias void delegate(E) EDG;
                     *    }
                     * Should eventually make it work.
                     */
                    e->error("forward reference to type %s", t->toChars());
                }
                else if (t->reliesOnTident())
                    e->error("forward reference to type %s", t->reliesOnTident()->toChars());

                //printf("type %p ty %d deco %p\n", type, type->ty, type->deco);
                //type = type->semantic(loc, sc);
                //printf("type %s t %s\n", type->deco, t->deco);
                e->error("cannot implicitly convert expression (%s) of type %s to %s",
                    e->toChars(), e->type->toChars(), t->toChars());
            }
            result = new ErrorExp();
        }

        void visit(StringExp *e)
        {
            //printf("StringExp::implicitCastTo(%s of type %s) => %s\n", e->toChars(), e->type->toChars(), t->toChars());
            unsigned char committed = e->committed;
            visit((Expression *)e);
            if (result->op == TOKstring)
            {
                // Retain polysemous nature if it started out that way
                ((StringExp *)result)->committed = e->committed;
            }
        }

        void visit(ErrorExp *e)
        {
            result = e;
        }

        void visit(FuncExp *e)
        {
            //printf("FuncExp::implicitCastTo type = %p %s, t = %s\n", e->type, e->type ? e->type->toChars() : NULL, t->toChars());
            visit((Expression *)e->inferType(t));
        }
    };

    ImplicitCastTo v(sc, t);
    e->accept(&v);
    return v.result;
}

/*******************************************
 * Return !=0 if we can implicitly convert this to type t.
 * Don't do the actual cast.
 */

MATCH implicitConvTo(Expression *e, Type *t)
{
    class ImplicitConvTo : public Visitor
    {
    public:
        Type *t;
        MATCH result;

        ImplicitConvTo(Type *t)
            : t(t)
        {
            result = MATCHnomatch;
        }

        void visit(Expression *e)
        {
        #if 0
            printf("Expression::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            //static int nest; if (++nest == 10) halt();
            if (t == Type::terror)
                return;
            if (!e->type)
            {
                e->error("%s is not an expression", e->toChars());
                e->type = Type::terror;
            }
            Expression *ex = e->optimize(WANTvalue | WANTflags);
            if (ex->type->equals(t))
            {
                result = MATCHexact;
                return;
            }
            if (ex != e)
            {
                //printf("\toptimized to %s of type %s\n", e->toChars(), e->type->toChars());
                result = ex->implicitConvTo(t);
                return;
            }
            MATCH match = e->type->implicitConvTo(t);
            if (match != MATCHnomatch)
            {
                result = match;
                return;
            }

            /* See if we can do integral narrowing conversions
             */
            if (e->type->isintegral() && t->isintegral() &&
                e->type->isTypeBasic() && t->isTypeBasic())
            {
                IntRange src = getIntRange(e);
                IntRange target = IntRange::fromType(t);
                if (target.contains(src))
                {
                    result = MATCHconvert;
                    return;
                }
            }
        }

        void visit(IntegerExp *e)
        {
        #if 0
            printf("IntegerExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            MATCH m = e->type->implicitConvTo(t);
            if (m >= MATCHconst)
            {
                result = m;
                return;
            }

            TY ty = e->type->toBasetype()->ty;
            TY toty = t->toBasetype()->ty;
            TY oldty = ty;

            if (m == MATCHnomatch && t->ty == Tenum)
                return;

            if (t->ty == Tvector)
            {
                TypeVector *tv = (TypeVector *)t;
                TypeBasic *tb = tv->elementType();
                if (tb->ty == Tvoid)
                    return;
                toty = tb->ty;
            }

            switch (ty)
            {
                case Tbool:
                    e->value &= 1;
                    ty = Tint32;
                    break;

                case Tint8:
                    e->value = (signed char)e->value;
                    ty = Tint32;
                    break;

                case Tchar:
                case Tuns8:
                    e->value &= 0xFF;
                    ty = Tint32;
                    break;

                case Tint16:
                    e->value = (short)e->value;
                    ty = Tint32;
                    break;

                case Tuns16:
                case Twchar:
                    e->value &= 0xFFFF;
                    ty = Tint32;
                    break;

                case Tint32:
                    e->value = (int)e->value;
                    break;

                case Tuns32:
                case Tdchar:
                    e->value &= 0xFFFFFFFF;
                    ty = Tuns32;
                    break;

                default:
                    break;
            }

            // Only allow conversion if no change in value
            switch (toty)
            {
                case Tbool:
                    if ((e->value & 1) != e->value)
                        return;
                    break;

                case Tint8:
                    if (ty == Tuns64 && e->value & ~0x7FUL)
                        return;
                    else if ((signed char)e->value != e->value)
                        return;
                    break;

                case Tchar:
                    if ((oldty == Twchar || oldty == Tdchar) && e->value > 0x7F)
                        return;
                case Tuns8:
                    //printf("value = %llu %llu\n", (dinteger_t)(unsigned char)e->value, e->value);
                    if ((unsigned char)e->value != e->value)
                        return;
                    break;

                case Tint16:
                    if (ty == Tuns64 && e->value & ~0x7FFFUL)
                        return;
                    else if ((short)e->value != e->value)
                        return;
                    break;

                case Twchar:
                    if (oldty == Tdchar && e->value > 0xD7FF && e->value < 0xE000)
                        return;
                case Tuns16:
                    if ((unsigned short)e->value != e->value)
                        return;
                    break;

                case Tint32:
                    if (ty == Tuns32)
                    {
                    }
                    else if (ty == Tuns64 && e->value & ~0x7FFFFFFFUL)
                        return;
                    else if ((int)e->value != e->value)
                        return;
                    break;

                case Tuns32:
                    if (ty == Tint32)
                    {
                    }
                    else if ((unsigned)e->value != e->value)
                        return;
                    break;

                case Tdchar:
                    if (e->value > 0x10FFFFUL)
                        return;
                    break;

                case Tfloat32:
                {
                    volatile float f;
                    if (e->type->isunsigned())
                    {
                        f = (float)e->value;
                        if (f != e->value)
                            return;
                    }
                    else
                    {
                        f = (float)(sinteger_t)e->value;
                        if (f != (sinteger_t)e->value)
                            return;
                    }
                    break;
                }

                case Tfloat64:
                {
                    volatile double f;
                    if (e->type->isunsigned())
                    {
                        f = (double)e->value;
                        if (f != e->value)
                            return;
                    }
                    else
                    {
                        f = (double)(sinteger_t)e->value;
                        if (f != (sinteger_t)e->value)
                            return;
                    }
                    break;
                }

                case Tfloat80:
                {
                    volatile_longdouble f;
                    if (e->type->isunsigned())
                    {
                        f = ldouble(e->value);
                        if (f != e->value) // isn't this a noop, because the compiler prefers ld
                            return;
                    }
                    else
                    {
                        f = ldouble((sinteger_t)e->value);
                        if (f != (sinteger_t)e->value)
                            return;
                    }
                    break;
                }

                case Tpointer:
                    //printf("type = %s\n", type->toBasetype()->toChars());
                    //printf("t = %s\n", t->toBasetype()->toChars());
                    if (ty == Tpointer &&
                        e->type->toBasetype()->nextOf()->ty == t->toBasetype()->nextOf()->ty)
                    {
                        /* Allow things like:
                         *      const char* P = cast(char *)3;
                         *      char* q = P;
                         */
                        break;
                    }

                default:
                    visit((Expression *)e);
                return;
            }

            //printf("MATCHconvert\n");
            result = MATCHconvert;
        }

        void visit(ErrorExp *e)
        {
            // no match
        }

        void visit(NullExp *e)
        {
        #if 0
            printf("NullExp::implicitConvTo(this=%s, type=%s, t=%s, committed = %d)\n",
                e->toChars(), e->type->toChars(), t->toChars(), e->committed);
        #endif
            if (e->type->equals(t))
            {
                result = MATCHexact;
                return;
            }

            /* Allow implicit conversions from immutable to mutable|const,
             * and mutable to immutable. It works because, after all, a null
             * doesn't actually point to anything.
             */
            if (t->immutableOf()->equals(e->type->immutableOf()))
            {
                result = MATCHconst;
                return;
            }

            visit((Expression *)e);
        }

        void visit(StructLiteralExp *e)
        {
        #if 0
            printf("StructLiteralExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            visit((Expression *)e);
            if (result != MATCHnomatch)
                return;
            if (e->type->ty == t->ty && e->type->ty == Tstruct &&
                ((TypeStruct *)e->type)->sym == ((TypeStruct *)t)->sym)
            {
                result = MATCHconst;
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    Expression *el = (*e->elements)[i];
                    if (!el)
                        continue;
                    Type *te = el->type;
                    te = e->sd->fields[i]->type->addMod(t->mod);
                    MATCH m2 = el->implicitConvTo(te);
                    //printf("\t%s => %s, match = %d\n", el->toChars(), te->toChars(), m2);
                    if (m2 < result)
                        result = m2;
                }
            }
        }

        void visit(StringExp *e)
        {
        #if 0
            printf("StringExp::implicitConvTo(this=%s, committed=%d, type=%s, t=%s)\n",
                e->toChars(), e->committed, e->type->toChars(), t->toChars());
        #endif
            if (!e->committed && t->ty == Tpointer && t->nextOf()->ty == Tvoid)
                return;

            if (e->type->ty == Tsarray || e->type->ty == Tarray || e->type->ty == Tpointer)
            {
                TY tyn = e->type->nextOf()->ty;
                if (tyn == Tchar || tyn == Twchar || tyn == Tdchar)
                {
                    switch (t->ty)
                    {
                        case Tsarray:
                            if (e->type->ty == Tsarray)
                            {
                                if (((TypeSArray *)e->type)->dim->toInteger() !=
                                    ((TypeSArray *)t)->dim->toInteger())
                                    return;
                                TY tynto = t->nextOf()->ty;
                                if (tynto == tyn)
                                {
                                    result = MATCHexact;
                                    return;
                                }
                                if (!e->committed && (tynto == Tchar || tynto == Twchar || tynto == Tdchar))
                                {
                                    result = MATCHexact;
                                    return;
                                }
                            }
                            else if (e->type->ty == Tarray)
                            {
                                if (e->length() >
                                    ((TypeSArray *)t)->dim->toInteger())
                                    return;
                                TY tynto = t->nextOf()->ty;
                                if (tynto == tyn)
                                {
                                    result = MATCHexact;
                                    return;
                                }
                                if (!e->committed && (tynto == Tchar || tynto == Twchar || tynto == Tdchar))
                                {
                                    result = MATCHexact;
                                    return;
                                }
                            }
                        case Tarray:
                        case Tpointer:
                            Type *tn = t->nextOf();
                            MATCH m = MATCHexact;
                            if (e->type->nextOf()->mod != tn->mod)
                            {
                                if (!tn->isConst())
                                    return;
                                m = MATCHconst;
                            }
                            if (!e->committed)
                            {
                                switch (tn->ty)
                                {
                                    case Tchar:
                                        if (e->postfix == 'w' || e->postfix == 'd')
                                            m = MATCHconvert;
                                        result = m;
                                        return;
                                    case Twchar:
                                        if (e->postfix != 'w')
                                            m = MATCHconvert;
                                        result = m;
                                        return;
                                    case Tdchar:
                                        if (e->postfix != 'd')
                                            m = MATCHconvert;
                                        result = m;
                                        return;
                                }
                            }
                            break;
                    }
                }
            }
            
            visit((Expression *)e);
        }

        void visit(ArrayLiteralExp *e)
        {
        #if 0
            printf("ArrayLiteralExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();
            if ((tb->ty == Tarray || tb->ty == Tsarray) &&
                (typeb->ty == Tarray || typeb->ty == Tsarray))
            {
                result = MATCHexact;
                Type *typen = typeb->nextOf()->toBasetype();

                if (tb->ty == Tsarray)
                {
                    TypeSArray *tsa = (TypeSArray *)tb;
                    if (e->elements->dim != tsa->dim->toInteger())
                        result = MATCHnomatch;
                }

                Type *telement = tb->nextOf();
                if (!e->elements->dim)
                {
                    if (typen->ty != Tvoid)
                        result = typen->implicitConvTo(telement);
                }
                else
                {
                    for (size_t i = 0; i < e->elements->dim; i++)
                    {
                        Expression *el = (*e->elements)[i];
                        if (result == MATCHnomatch)
                            break;                          // no need to check for worse
                        MATCH m = el->implicitConvTo(telement);
                        if (m < result)
                            result = m;                     // remember worst match
                    }
                }

                if (!result)
                    result = e->type->implicitConvTo(t);

                return;
            }
            else if (tb->ty == Tvector &&
                (typeb->ty == Tarray || typeb->ty == Tsarray))
            {
                result = MATCHexact;
                // Convert array literal to vector type
                TypeVector *tv = (TypeVector *)tb;
                TypeSArray *tbase = (TypeSArray *)tv->basetype;
                assert(tbase->ty == Tsarray);
                if (e->elements->dim != tbase->dim->toInteger())
                {
                    result = MATCHnomatch;
                    return;
                }

                Type *telement = tv->elementType();
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    Expression *el = (*e->elements)[i];
                    MATCH m = el->implicitConvTo(telement);
                    if (m < result)
                        result = m;                     // remember worst match
                    if (result == MATCHnomatch)
                        break;                          // no need to check for worse
                }
                return;
            }

            visit((Expression *)e);
        }

        void visit(AssocArrayLiteralExp *e)
        {
            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();
            if (tb->ty == Taarray && typeb->ty == Taarray)
            {
                result = MATCHexact;
                for (size_t i = 0; i < e->keys->dim; i++)
                {
                    Expression *el = (*e->keys)[i];
                    MATCH m = el->implicitConvTo(((TypeAArray *)tb)->index);
                    if (m < result)
                        result = m;                     // remember worst match
                    if (result == MATCHnomatch)
                        break;                          // no need to check for worse
                    el = (*e->values)[i];
                    m = el->implicitConvTo(tb->nextOf());
                    if (m < result)
                        result = m;                     // remember worst match
                    if (result == MATCHnomatch)
                        break;                          // no need to check for worse
                }
                return;
            }
            else
                visit((Expression *)e);
        }

        void visit(CallExp *e)
        {
        #if 0
            printf("CalLExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif

            visit((Expression *)e);
            if (result)
                return;

            /* Allow the result of strongly pure functions to
             * convert to immutable
             */
            if (e->f && e->f->isolateReturn())
            {
                result = e->type->immutableOf()->implicitConvTo(t);
                return;
            }

            /* The result of arr.dup and arr.idup can be unique essentially.
             * So deal with this case specially.
             */
            if (!e->f && e->e1->op == TOKvar && ((VarExp *)e->e1)->var->ident == Id::adDup &&
                t->toBasetype()->ty == Tarray)
            {
                assert(e->type->toBasetype()->ty == Tarray);
                assert(e->arguments->dim == 2);
                Expression *eorg = (*e->arguments)[1];
                Type *tn = t->nextOf();
                if (e->type->nextOf()->implicitConvTo(tn) < MATCHconst)
                {
                    /* If the operand is an unique array literal, then allow conversion.
                     */
                    if (eorg->op != TOKarrayliteral)
                        return;
                    Expressions *elements = ((ArrayLiteralExp *)eorg)->elements;
                    for (size_t i = 0; i < elements->dim; i++)
                    {
                        if (!(*elements)[i]->implicitConvTo(tn))
                            return;
                    }
                }
                result = e->type->immutableOf()->implicitConvTo(t);
                return;
            }
        }

        void visit(AddrExp *e)
        {
        #if 0
            printf("AddrExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            result = e->type->implicitConvTo(t);
            //printf("\tresult = %d\n", result);

            if (result != MATCHnomatch)
                return;

            // Look for pointers to functions where the functions are overloaded.

            t = t->toBasetype();

            if (e->e1->op == TOKoverloadset &&
                (t->ty == Tpointer || t->ty == Tdelegate) && t->nextOf()->ty == Tfunction)
            {
                OverExp *eo = (OverExp *)e->e1;
                FuncDeclaration *f = NULL;
                for (size_t i = 0; i < eo->vars->a.dim; i++)
                {
                    Dsymbol *s = eo->vars->a[i];
                    FuncDeclaration *f2 = s->isFuncDeclaration();
                    assert(f2);
                    if (f2->overloadExactMatch(t->nextOf()))
                    {
                        if (f)
                        {
                            /* Error if match in more than one overload set,
                             * even if one is a 'better' match than the other.
                             */
                            ScopeDsymbol::multiplyDefined(e->loc, f, f2);
                        }
                        else
                            f = f2;
                        result = MATCHexact;
                    }
                }
            }

            if (e->type->ty == Tpointer && e->type->nextOf()->ty == Tfunction &&
                t->ty == Tpointer && t->nextOf()->ty == Tfunction &&
                e->e1->op == TOKvar)
            {
                /* I don't think this can ever happen -
                 * it should have been
                 * converted to a SymOffExp.
                 */
                assert(0);
            }

            //printf("\tresult = %d\n", result);
        }

        void visit(SymOffExp *e)
        {
        #if 0
            printf("SymOffExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            result = e->type->implicitConvTo(t);
            //printf("\tresult = %d\n", result);
            if (result != MATCHnomatch)
                return;

            // Look for pointers to functions where the functions are overloaded.
            t = t->toBasetype();
            if (e->type->ty == Tpointer && e->type->nextOf()->ty == Tfunction &&
                (t->ty == Tpointer || t->ty == Tdelegate) && t->nextOf()->ty == Tfunction)
            {
                if (FuncDeclaration *f = e->var->isFuncDeclaration())
                {
                    f = f->overloadExactMatch(t->nextOf());
                    if (f)
                    {
                        if ((t->ty == Tdelegate && (f->needThis() || f->isNested())) ||
                            (t->ty == Tpointer && !(f->needThis() || f->isNested())))
                        {
                            result = MATCHexact;
                        }
                    }
                }
            }
            //printf("\tresult = %d\n", result);
        }

        void visit(DelegateExp *e)
        {
        #if 0
            printf("DelegateExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            result = e->type->implicitConvTo(t);
            if (result != MATCHnomatch)
                return;

            // Look for pointers to functions where the functions are overloaded.
            t = t->toBasetype();
            if (e->type->ty == Tdelegate &&
                t->ty == Tdelegate)
            {
                if (e->func && e->func->overloadExactMatch(t->nextOf()))
                    result = MATCHexact;
            }
        }

        void visit(FuncExp *e)
        {
            //printf("FuncExp::implicitConvTo type = %p %s, t = %s\n", e->type, e->type ? e->type->toChars() : NULL, t->toChars());
            Expression *ex = e->inferType(t, 1);
            if (ex &&
                (t->ty == Tdelegate ||
                 t->ty == Tpointer && t->nextOf()->ty == Tfunction))
            {
                if (ex != e)
                {
                    result = ex->implicitConvTo(t);
                    return;
                }

                /* MATCHconst:   Conversion from implicit to explicit function pointer
                 * MATCHconvert: Conversion from impliict funciton pointer to delegate
                 */
                // fbody doesn't have a frame pointer
                if (e->fd->tok == TOKreserved &&
                    (e->type->equals(t) || e->type->nextOf()->covariant(t->nextOf()) == 1))
                {
                    result = t->ty == Tpointer ? MATCHconst : MATCHconvert;
                    return;
                }
            }
            visit((Expression *)e);
        }

        void visit(OrExp *e)
        {
            visit((Expression *)e);
            if (result != MATCHnomatch)
                return;

            MATCH m1 = e->e1->implicitConvTo(t);
            MATCH m2 = e->e2->implicitConvTo(t);

            // Pick the worst match
            result = (m1 < m2) ? m1 : m2;
        }

        void visit(XorExp *e)
        {
            visit((Expression *)e);
            if (result != MATCHnomatch)
                return;

            MATCH m1 = e->e1->implicitConvTo(t);
            MATCH m2 = e->e2->implicitConvTo(t);

            // Pick the worst match
            result = (m1 < m2) ? m1 : m2;
        }

        void visit(CondExp *e)
        {
            MATCH m1 = e->e1->implicitConvTo(t);
            MATCH m2 = e->e2->implicitConvTo(t);
            //printf("CondExp: m1 %d m2 %d\n", m1, m2);

            // Pick the worst match
            result = (m1 < m2) ? m1 : m2;
        }

        void visit(CommaExp *e)
        {
            e->e2->accept(this);
        }

        void visit(CastExp *e)
        {
        #if 0
            printf("CastExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            result = e->type->implicitConvTo(t);
            if (result != MATCHnomatch)
                return;

            if (t->isintegral() &&
                e->e1->type->isintegral() &&
                e->e1->implicitConvTo(t) != MATCHnomatch)
                result = MATCHconvert;
            else
                visit((Expression *)e);
        }

        void visit(NewExp *e)
        {
        #if 0
            printf("NewExp::implicitConvTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            visit((Expression *)e);
            if (result != MATCHnomatch)
                return;

            /* The return from new() is special in that it might be a unique pointer.
             * If we can prove it is, allow the following implicit conversions:
             *  mutable => immutable
             *  non-shared => shared
             *  shared => non-shared
             */

            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();

            if (tb->ty == Tclass)
            {
                //printf("%s => %s\n", type->castMod(0)->toChars(), t->castMod(0)->toChars());
                MATCH match = e->type->castMod(0)->implicitConvTo(t->castMod(0));
                if (!match)
                    return;

                // Regardless, don't allow immutable to be implicitly converted to mutable
                if (tb->isMutable() && !typeb->isMutable())
                    return;

                // All the fields must be convertible as well
                ClassDeclaration *cd = ((TypeClass *)tb)->sym;

                cd->size(e->loc);          // resolve any forward references

                /* The following is excessively conservative, but be very
                 * careful in loosening them up.
                 */
                if (cd->isNested() ||
                    cd->isInterfaceDeclaration() ||
                    cd->ctor ||
                    cd->baseClass != ClassDeclaration::object)
                    return;

                for (size_t i = 0; i < cd->fields.dim; i++)
                {
                    Declaration *d = cd->fields[i];
                    if (d->storage_class & STCref || d->hasPointers())
                        return;
                }
                result = (match == MATCHexact) ? MATCHconst : match;
            }
            else if ((tb->ty == Tpointer || tb->ty == Tarray) &&
                     (typeb->ty == Tpointer || typeb->ty == Tarray))
            {
                Type *typen = e->type->nextOf()->toBasetype();
                Type *tn = tb->nextOf()->toBasetype();

                //printf("%s => %s\n", typen->castMod(0)->toChars(), tn->castMod(0)->toChars());

                /* Determine if the match failure was solely due to a difference
                 * in the mod bits, by rebuilding type and t without mod bits and
                 * retrying the implicit conversion.
                 */
                Type *tn2 = tn->castMod(0);         // cast off mod bits
                Type *typen2 = typen->castMod(0);
                Type *t2 = (tb->ty == Tpointer) ? tn2->pointerTo() : tn2->arrayOf();
                Type *type2 = (typeb->ty == Tpointer) ? typen2->pointerTo() : typen2->arrayOf();
                MATCH match = type2->implicitConvTo(t2);
                if (!match)
                    return;

                // Regardless, don't allow immutable to be implicitly converted to mutable
                if (tn->isMutable() && !typen->isMutable())
                    return;

                if (tn->isTypeBasic())
                    ;
                else if (tn->ty == Tstruct)
                {
                    // All the fields must be convertible as well
                    StructDeclaration *sd = ((TypeStruct *)tn)->sym;

                    sd->size(e->loc);              // resolve any forward references

                    /* The following is excessively conservative, but be very
                     * careful in loosening them up.
                     */

                    if (sd->isNested() ||
                        sd->ctor)
                        return;

                    for (size_t i = 0; i < sd->fields.dim; i++)
                    {
                        Declaration *d = sd->fields[i];
                        if (d->storage_class & STCref || d->hasPointers())
                            return;
                    }
                }
                else
                {
                    /* More fruit left on the table, such as pointers to immutable.
                     */
                    return;
                }

                result = (match == MATCHexact) ? MATCHconst : match;
            }
        }

        void visit(SliceExp *e)
        {
            visit((Expression *)e);
            if (result != MATCHnomatch)
                return;

            Type *tb = t->toBasetype();
            Type *typeb = e->type->toBasetype();
            if (tb->ty == Tsarray && typeb->ty == Tarray &&
                e->lwr && e->upr)
            {
                typeb = e->toStaticArrayType();
                if (typeb)
                    result = typeb->implicitConvTo(t);
            }
        }
    };

    ImplicitConvTo v(t);
    e->accept(&v);
    return v.result;
}

Type *SliceExp::toStaticArrayType()
{
    if (lwr && upr)
    {
        Expression *lwr = this->lwr->optimize(WANTvalue);
        Expression *upr = this->upr->optimize(WANTvalue);
        if (lwr->isConst() && upr->isConst())
        {
            size_t len = (size_t)(upr->toUInteger() - lwr->toUInteger());
            return type->toBasetype()->nextOf()->sarrayOf(len);
        }
    }
    return NULL;
}

/* ==================== castTo ====================== */

/**************************************
 * Do an explicit cast.
 * Assume that the 'this' expression does not have any indirections.
 */

Expression *castTo(Expression *e, Scope *sc, Type *t)
{

    class CastTo : public Visitor
    {
    public:
        Type *t;
        Scope *sc;
        Expression *result;

        CastTo(Scope *sc, Type *t)
            : sc(sc), t(t)
        {
            result = NULL;
        }

        void visit(Expression *e)
        {
            //printf("Expression::castTo(this=%s, t=%s)\n", e->toChars(), t->toChars());
        #if 0
            printf("Expression::castTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            if (e->type->equals(t))
            {
                result = e;
                return;
            }
            if (e->op == TOKvar)
            {
                VarDeclaration *v = ((VarExp *)e)->var->isVarDeclaration();
                if (v && v->storage_class & STCmanifest)
                {
                    result = e->ctfeInterpret();
                    result = result->castTo(sc, t);
                    return;
                }
            }
            result = e;
            Type *tb = t->toBasetype();
            Type *typeb = e->type->toBasetype();
            if (!tb->equals(typeb))
            {
                // Do (type *) cast of (type [dim])
                if (tb->ty == Tpointer &&
                    typeb->ty == Tsarray)
                {
                    //printf("Converting [dim] to *\n");
                    result = new AddrExp(e->loc, result);
                }
                else
                {
                    if (typeb->ty == Tstruct)
                    {
                        TypeStruct *ts = (TypeStruct *)typeb;
                        if (!(tb->ty == Tstruct && ts->sym == ((TypeStruct *)tb)->sym) &&
                            ts->sym->aliasthis)
                        {
                            /* Forward the cast to our alias this member, rewrite to:
                             *   cast(to)e1.aliasthis
                             */
                            Expression *ex = resolveAliasThis(sc, e);
                            result = ex->castTo(sc, t);
                            return;
                        }
                    }
                    else if (typeb->ty == Tclass)
                    {
                        TypeClass *ts = (TypeClass *)typeb;
                        if (ts->sym->aliasthis)
                        {
                            if (tb->ty == Tclass)
                            {
                                ClassDeclaration *cdfrom = typeb->isClassHandle();
                                ClassDeclaration *cdto   = tb->isClassHandle();
                                int offset;
                                if (cdto->isBaseOf(cdfrom, &offset))
                                     goto L1;
                            }
                            /* Forward the cast to our alias this member, rewrite to:
                             *   cast(to)e1.aliasthis
                             */
                            Expression *e1 = resolveAliasThis(sc, e);
                            Expression *e2 = new CastExp(e->loc, e1, tb);
                            e2 = e2->semantic(sc);
                            result = e2;
                            return;
                        }
                    }
                    else if (tb->ty == Tvector && typeb->ty != Tvector)
                    {
                        //printf("test1 e = %s, e->type = %s, tb = %s\n", e->toChars(), e->type->toChars(), tb->toChars());
                        TypeVector *tv = (TypeVector *)tb;
                        result = new CastExp(e->loc, result, tv->elementType());
                        result = new VectorExp(e->loc, result, tb);
                        result = result->semantic(sc);
                        return;
                    }
                    else if (typeb->implicitConvTo(tb) == MATCHconst && t->equals(e->type->constOf()))
                    {
                        result = e->copy();
                        result->type = t;
                        return;
                    }
                L1:
                    result = new CastExp(e->loc, result, tb);
                }
            }
            else
            {
                result = result->copy();  // because of COW for assignment to e->type
            }
            assert(result != e);
            result->type = t;
            //printf("Returning: %s\n", result->toChars());
        }

        void visit(ErrorExp *e)
        {
            result = e;
        }

        void visit(RealExp *e)
        {
            if (!e->type->equals(t))
            {
                if ((e->type->isreal() && t->isreal()) ||
                    (e->type->isimaginary() && t->isimaginary())
                   )
                {
                    result = e->copy();
                    result->type = t;
                }
                else
                    visit((Expression *)e);
                return;
            }
            result = e;
        }

        void visit(ComplexExp *e)
        {
            if (!e->type->equals(t))
            {
                if (e->type->iscomplex() && t->iscomplex())
                {
                    result = e->copy();
                    result->type = t;
                }
                else
                    visit((Expression *)e);
                return;
            }
            result = e;
        }

        void visit(NullExp *e)
        {
            //printf("NullExp::castTo(t = %s) %s\n", t->toChars(), toChars());
            if (e->type->equals(t))
            {
                e->committed = 1;
                result = e;
                return;
            }

            NullExp *ex = (NullExp *)e->copy();
            ex->committed = 1;
            Type *tb = t->toBasetype();

            if (tb->ty == Tvoid)
            {
                ex->type = e->type->toBasetype();
                visit((Expression *)ex);
                return;
            }
            if (tb->ty == Tsarray || tb->ty == Tstruct)
            {
                e->error("cannot cast null to %s", t->toChars());
            }
            ex->type = t;
            result = ex;
        }

        void visit(StructLiteralExp *e)
        {
            visit((Expression *)e);
            if (result->op == TOKstructliteral)
                ((StructLiteralExp *)result)->stype = t; // commit type
        }

        void visit(StringExp *e)
        {
            /* This follows copy-on-write; any changes to 'this'
             * will result in a copy.
             * The this->string member is considered immutable.
             */
            int copied = 0;

            //printf("StringExp::castTo(t = %s), '%s' committed = %d\n", t->toChars(), e->toChars(), e->committed);

            if (!e->committed && t->ty == Tpointer && t->nextOf()->ty == Tvoid)
            {
                e->error("cannot convert string literal to void*");
                result = new ErrorExp();
                return;
            }

            StringExp *se = e;
            if (!e->committed)
            {
                se = (StringExp *)e->copy();
                se->committed = 1;
                copied = 1;
            }

            if (e->type->equals(t))
            {
                result = se;
                return;
            }

            Type *tb = t->toBasetype();
            //printf("\ttype = %s\n", e->type->toChars());
            if (tb->ty == Tdelegate && e->type->toBasetype()->ty != Tdelegate)
            {
                visit((Expression *)e);
                return;
            }

            Type *typeb = e->type->toBasetype();
            if (typeb->equals(tb))
            {
                if (!copied)
                {
                    se = (StringExp *)e->copy();
                    copied = 1;
                }
                se->type = t;
                result = se;
                return;
            }

            if (e->committed && tb->ty == Tsarray && typeb->ty == Tarray)
            {
                se = (StringExp *)e->copy();
                d_uns64 szx = tb->nextOf()->size();
                assert(szx <= 255);
                se->sz = (unsigned char)szx;
                se->len = (e->len * e->sz) / se->sz;
                se->committed = 1;
                se->type = t;

                /* Assure space for terminating 0
                 */
                if ((se->len + 1) * se->sz > (e->len + 1) * e->sz)
                {
                    void *s = (void *)mem.malloc((se->len + 1) * se->sz);
                    memcpy(s, se->string, se->len * se->sz);
                    memset((char *)s + se->len * se->sz, 0, se->sz);
                    se->string = s;
                }
                result = se;
                return;
            }

            if (tb->ty != Tsarray && tb->ty != Tarray && tb->ty != Tpointer)
            {
                if (!copied)
                {
                    se = (StringExp *)e->copy();
                    copied = 1;
                }
                goto Lcast;
            }
            if (typeb->ty != Tsarray && typeb->ty != Tarray && typeb->ty != Tpointer)
            {
                if (!copied)
                {
                    se = (StringExp *)e->copy();
                    copied = 1;
                }
                goto Lcast;
            }

            if (typeb->nextOf()->size() == tb->nextOf()->size())
            {
                if (!copied)
                {
                    se = (StringExp *)e->copy();
                    copied = 1;
                }
                if (tb->ty == Tsarray)
                    goto L2;    // handle possible change in static array dimension
                se->type = t;
                result = se;
                return;
            }

            if (e->committed)
                goto Lcast;

        #define X(tf,tt)        ((int)(tf) * 256 + (int)(tt))
            {
            OutBuffer buffer;
            size_t newlen = 0;
            int tfty = typeb->nextOf()->toBasetype()->ty;
            int ttty = tb->nextOf()->toBasetype()->ty;
            switch (X(tfty, ttty))
            {
                case X(Tchar, Tchar):
                case X(Twchar,Twchar):
                case X(Tdchar,Tdchar):
                    break;

                case X(Tchar, Twchar):
                    for (size_t u = 0; u < e->len;)
                    {
                        unsigned c;
                        const char *p = utf_decodeChar((utf8_t *)se->string, e->len, &u, &c);
                        if (p)
                            e->error("%s", p);
                        else
                            buffer.writeUTF16(c);
                    }
                    newlen = buffer.offset / 2;
                    buffer.writeUTF16(0);
                    goto L1;

                case X(Tchar, Tdchar):
                    for (size_t u = 0; u < e->len;)
                    {
                        unsigned c;
                        const char *p = utf_decodeChar((utf8_t *)se->string, e->len, &u, &c);
                        if (p)
                            e->error("%s", p);
                        buffer.write4(c);
                        newlen++;
                    }
                    buffer.write4(0);
                    goto L1;

                case X(Twchar,Tchar):
                    for (size_t u = 0; u < e->len;)
                    {
                        unsigned c;
                        const char *p = utf_decodeWchar((unsigned short *)se->string, e->len, &u, &c);
                        if (p)
                            e->error("%s", p);
                        else
                            buffer.writeUTF8(c);
                    }
                    newlen = buffer.offset;
                    buffer.writeUTF8(0);
                    goto L1;

                case X(Twchar,Tdchar):
                    for (size_t u = 0; u < e->len;)
                    {
                        unsigned c;
                        const char *p = utf_decodeWchar((unsigned short *)se->string, e->len, &u, &c);
                        if (p)
                            e->error("%s", p);
                        buffer.write4(c);
                        newlen++;
                    }
                    buffer.write4(0);
                    goto L1;

                case X(Tdchar,Tchar):
                    for (size_t u = 0; u < e->len; u++)
                    {
                        unsigned c = ((unsigned *)se->string)[u];
                        if (!utf_isValidDchar(c))
                            e->error("invalid UCS-32 char \\U%08x", c);
                        else
                            buffer.writeUTF8(c);
                        newlen++;
                    }
                    newlen = buffer.offset;
                    buffer.writeUTF8(0);
                    goto L1;

                case X(Tdchar,Twchar):
                    for (size_t u = 0; u < e->len; u++)
                    {
                        unsigned c = ((unsigned *)se->string)[u];
                        if (!utf_isValidDchar(c))
                            e->error("invalid UCS-32 char \\U%08x", c);
                        else
                            buffer.writeUTF16(c);
                        newlen++;
                    }
                    newlen = buffer.offset / 2;
                    buffer.writeUTF16(0);
                    goto L1;

                L1:
                    if (!copied)
                    {
                        se = (StringExp *)e->copy();
                        copied = 1;
                    }
                    se->string = buffer.extractData();
                    se->len = newlen;

                    {
                        d_uns64 szx = tb->nextOf()->size();
                        assert(szx <= 255);
                        se->sz = (unsigned char)szx;
                    }
                    break;

                default:
                    assert(typeb->nextOf()->size() != tb->nextOf()->size());
                    goto Lcast;
            }
            }
        #undef X
        L2:
            assert(copied);

            // See if need to truncate or extend the literal
            if (tb->ty == Tsarray)
            {
                size_t dim2 = (size_t)((TypeSArray *)tb)->dim->toInteger();

                //printf("dim from = %d, to = %d\n", (int)se->len, (int)dim2);

                // Changing dimensions
                if (dim2 != se->len)
                {
                    // Copy when changing the string literal
                    size_t newsz = se->sz;
                    size_t d = (dim2 < se->len) ? dim2 : se->len;
                    void *s = (void *)mem.malloc((dim2 + 1) * newsz);
                    memcpy(s, se->string, d * newsz);
                    // Extend with 0, add terminating 0
                    memset((char *)s + d * newsz, 0, (dim2 + 1 - d) * newsz);
                    se->string = s;
                    se->len = dim2;
                }
            }
            se->type = t;
            result = se;
            return;

        Lcast:
            result = new CastExp(e->loc, se, t);
            result->type = t;        // so semantic() won't be run on e
        }

        void visit(AddrExp *e)
        {
            Type *tb;

        #if 0
            printf("AddrExp::castTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            result = e;

            tb = t->toBasetype();
            e->type = e->type->toBasetype();
            if (!tb->equals(e->type))
            {
                // Look for pointers to functions where the functions are overloaded.

                if (e->e1->op == TOKoverloadset &&
                    (t->ty == Tpointer || t->ty == Tdelegate) && t->nextOf()->ty == Tfunction)
                {
                    OverExp *eo = (OverExp *)e->e1;
                    FuncDeclaration *f = NULL;
                    for (size_t i = 0; i < eo->vars->a.dim; i++)
                    {
                        Dsymbol *s = eo->vars->a[i];
                        FuncDeclaration *f2 = s->isFuncDeclaration();
                        assert(f2);
                        if (f2->overloadExactMatch(t->nextOf()))
                        {
                            if (f)
                            {
                                /* Error if match in more than one overload set,
                                 * even if one is a 'better' match than the other.
                                 */
                                ScopeDsymbol::multiplyDefined(e->loc, f, f2);
                            }
                            else
                                f = f2;
                        }
                    }
                    if (f)
                    {
                        f->tookAddressOf++;
                        SymOffExp *se = new SymOffExp(e->loc, f, 0, 0);
                        se->semantic(sc);
                        // Let SymOffExp::castTo() do the heavy lifting
                        visit(se);
                        return;
                    }
                }

                if (e->type->ty == Tpointer && e->type->nextOf()->ty == Tfunction &&
                    tb->ty == Tpointer && tb->nextOf()->ty == Tfunction &&
                    e->e1->op == TOKvar)
                {
                    VarExp *ve = (VarExp *)e->e1;
                    FuncDeclaration *f = ve->var->isFuncDeclaration();
                    if (f)
                    {
                        assert(0);      // should be SymOffExp instead
                        f = f->overloadExactMatch(tb->nextOf());
                        if (f)
                        {
                            result = new VarExp(e->loc, f);
                            result->type = f->type;
                            result = new AddrExp(e->loc, result);
                            result->type = t;
                            return;
                        }
                    }
                }
                visit((Expression *)e);
            }
            result->type = t;
        }

        void visit(TupleExp *e)
        {
            if (e->type->equals(t))
            {
                result = e;
                return;
            }

            TupleExp *te = (TupleExp *)e->copy();
            te->e0 = e->e0 ? e->e0->copy() : NULL;
            te->exps = (Expressions *)e->exps->copy();
            for (size_t i = 0; i < te->exps->dim; i++)
            {
                Expression *ex = (*te->exps)[i];
                ex = ex->castTo(sc, t);
                (*te->exps)[i] = ex;
            }
            result = te;
        }

        void visit(ArrayLiteralExp *e)
        {
        #if 0
            printf("ArrayLiteralExp::castTo(this=%s, type=%s, => %s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            if (e->type == t)
            {
                result = e;
                return;
            }
            ArrayLiteralExp *ae = e;
            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();
            if ((tb->ty == Tarray || tb->ty == Tsarray) &&
                (typeb->ty == Tarray || typeb->ty == Tsarray))
            {
                if (tb->nextOf()->toBasetype()->ty == Tvoid && typeb->nextOf()->toBasetype()->ty != Tvoid)
                {
                    // Don't do anything to cast non-void[] to void[]
                }
                else if (typeb->ty == Tsarray && typeb->nextOf()->toBasetype()->ty == Tvoid)
                {
                    // Don't do anything for casting void[n] to others
                }
                else
                {
                    if (tb->ty == Tsarray)
                    {
                        TypeSArray *tsa = (TypeSArray *)tb;
                        if (e->elements->dim != tsa->dim->toInteger())
                            goto L1;
                    }

                    ae = (ArrayLiteralExp *)e->copy();
                    ae->elements = e->elements->copy();
                    for (size_t i = 0; i < e->elements->dim; i++)
                    {
                        Expression *ex = (*e->elements)[i];
                        ex = ex->castTo(sc, tb->nextOf());
                        (*ae->elements)[i] = ex;
                    }
                    ae->type = t;
                    result = ae;
                    return;
                }
            }
            else if (tb->ty == Tpointer && typeb->ty == Tsarray)
            {
                Type *tp = typeb->nextOf()->pointerTo();
                if (!tp->equals(ae->type))
                {
                    ae = (ArrayLiteralExp *)e->copy();
                    ae->type = tp;
                }
            }
            else if (tb->ty == Tvector &&
                (typeb->ty == Tarray || typeb->ty == Tsarray))
            {
                // Convert array literal to vector type
                TypeVector *tv = (TypeVector *)tb;
                TypeSArray *tbase = (TypeSArray *)tv->basetype;
                assert(tbase->ty == Tsarray);
                if (e->elements->dim != tbase->dim->toInteger())
                    goto L1;

                ae = (ArrayLiteralExp *)e->copy();
                ae->elements = e->elements->copy();
                Type *telement = tv->elementType();
                for (size_t i = 0; i < e->elements->dim; i++)
                {
                    Expression *ex = (*e->elements)[i];
                    ex = ex->castTo(sc, telement);
                    (*ae->elements)[i] = ex;
                }
                Expression *ev = new VectorExp(e->loc, ae, tb);
                ev = ev->semantic(sc);
                result = ev;
                return;
            }
        L1:
            visit((Expression *)ae);
        }

        void visit(AssocArrayLiteralExp *e)
        {
            if (e->type == t)
            {
                result = e;
                return;
            }
            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();
            if (tb->ty == Taarray && typeb->ty == Taarray &&
                tb->nextOf()->toBasetype()->ty != Tvoid)
            {
                AssocArrayLiteralExp *ae = (AssocArrayLiteralExp *)e->copy();
                ae->keys = e->keys->copy();
                ae->values = e->values->copy();
                assert(e->keys->dim == e->values->dim);
                for (size_t i = 0; i < e->keys->dim; i++)
                {
                    Expression *ex = (*e->values)[i];
                    ex = ex->castTo(sc, tb->nextOf());
                    (*ae->values)[i] = ex;

                    ex = (*e->keys)[i];
                    ex = ex->castTo(sc, ((TypeAArray *)tb)->index);
                    (*ae->keys)[i] = ex;
                }
                ae->type = t;
                result = ae;
                return;
            }
            visit((Expression *)e);
        }

        void visit(SymOffExp *e)
        {
        #if 0
            printf("SymOffExp::castTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            if (e->type == t && !e->hasOverloads)
            {
                result = e;
                return;
            }
            Type *tb = t->toBasetype();
            Type *typeb = e->type->toBasetype();
            
            if (tb->equals(typeb))
            {
                result = e->copy();
                result->type = t;
                ((SymOffExp *)result)->hasOverloads = false;
                return;
            }

            // Look for pointers to functions where the functions are overloaded.
            if (e->hasOverloads &&
                typeb->ty == Tpointer && typeb->nextOf()->ty == Tfunction &&
                (tb->ty == Tpointer || tb->ty == Tdelegate) && tb->nextOf()->ty == Tfunction)
            {
                FuncDeclaration *f = e->var->isFuncDeclaration();
                f = f ? f->overloadExactMatch(tb->nextOf()) : NULL;
                if (f)
                {
                    if (tb->ty == Tdelegate)
                    {
                        if (f->needThis() && hasThis(sc))
                        {
                            result = new DelegateExp(e->loc, new ThisExp(e->loc), f);
                            result = result->semantic(sc);
                        }
                        else if (f->isNested())
                        {
                            result = new DelegateExp(e->loc, new IntegerExp(0), f);
                            result = result->semantic(sc);
                        }
                        else if (f->needThis())
                        {
                            e->error("no 'this' to create delegate for %s", f->toChars());
                            result = new ErrorExp();
                            return;
                        }
                        else
                        {
                            e->error("cannot cast from function pointer to delegate");
                            result = new ErrorExp();
                            return;
                        }
                    }
                    else
                    {
                        result = new SymOffExp(e->loc, f, 0);
                        result->type = t;
                    }
                    f->tookAddressOf++;
                    return;
                }
            }
            visit((Expression *)e);
        }

        void visit(DelegateExp *e)
        {
        #if 0
            printf("DelegateExp::castTo(this=%s, type=%s, t=%s)\n",
                e->toChars(), e->type->toChars(), t->toChars());
        #endif
            static const char msg[] = "cannot form delegate due to covariant return type";

            Type *tb = t->toBasetype();
            Type *typeb = e->type->toBasetype();
            if (!tb->equals(typeb) || e->hasOverloads)
            {
                // Look for delegates to functions where the functions are overloaded.
                if (typeb->ty == Tdelegate &&
                    tb->ty == Tdelegate)
                {
                    if (e->func)
                    {
                        FuncDeclaration *f = e->func->overloadExactMatch(tb->nextOf());
                        if (f)
                        {
                            int offset;
                            if (f->tintro && f->tintro->nextOf()->isBaseOf(f->type->nextOf(), &offset) && offset)
                                e->error("%s", msg);
                            f->tookAddressOf++;
                            result = new DelegateExp(e->loc, e->e1, f);
                            result->type = t;
                            return;
                        }
                        if (e->func->tintro)
                            e->error("%s", msg);
                    }
                }
                visit((Expression *)e);
            }
            else
            {
                int offset;
                e->func->tookAddressOf++;
                if (e->func->tintro && e->func->tintro->nextOf()->isBaseOf(e->func->type->nextOf(), &offset) && offset)
                    e->error("%s", msg);
                result = e->copy();
                result->type = t;
            }
        }

        void visit(FuncExp *e)
        {
            //printf("FuncExp::castTo type = %s, t = %s\n", type->toChars(), t->toChars());
            result = e->inferType(t, 1);
            if (result)
            {
                if (result != e)
                {
                    result->accept(this);
                    return;
                }
                if (!result->type->equals(t) && result->type->implicitConvTo(t))
                {
                    // Bugzilla 9928
                    assert(t->ty == Tpointer && t->nextOf()->ty == Tvoid ||
                           result->type->nextOf()->covariant(t->nextOf()) == 1);
                    result = result->copy();
                    result->type = t;
                    return;
                }
            }
            visit((Expression *)e);
        }

        void visit(CondExp *e)
        {
            if (!e->type->equals(t))
            {
                result = new CondExp(e->loc, e->econd, e->e1->castTo(sc, t), e->e2->castTo(sc, t));
                result->type = t;
                return;
            }
            result = e;
        }

        void visit(CommaExp *e)
        {
            Expression *e2c = e->e2->castTo(sc, t);

            if (e2c != e->e2)
            {
                result = new CommaExp(e->loc, e->e1, e2c);
                result->type = e2c->type;
            }
            else
            {
                result = e;
                result->type = e->e2->type;
            }
        }

        void visit(SliceExp *e)
        {
            Type *typeb = e->type->toBasetype();
            Type *tb = t->toBasetype();

            if (typeb->ty == Tarray && tb->ty == Tsarray)
            {
                /* If a SliceExp has Tsarray, it will become lvalue.
                 * That's handled in SliceExp::isLvalue and toLvalue
                 */
                result = e->copy();
                result->type = t;
            }
            else if (typeb->ty == Tarray && tb->ty == Tarray &&
                     typeb->nextOf()->constConv(tb->nextOf()) == MATCHconst)
            {
                // immutable(T)[] to const(T)[]
                //           T [] to const(T)[]
                result = e->copy();
                result->type = t;
            }
            else
            {
                visit((Expression *)e);
            }
        }
    };

    CastTo v(sc, t);
    e->accept(&v);
    return v.result;
}

/* ==================== inferType ====================== */

/****************************************
 * Set type inference target
 *      t       Target type
 *      flag    1: don't put an error when inference fails
 *      sc      it is used for the semantic of t, when != NULL
 *      tparams template parameters should be inferred
 */

Expression *Expression::inferType(Type *t, int flag, Scope *sc, TemplateParameters *tparams)
{
    return this;
}

Expression *ArrayLiteralExp::inferType(Type *t, int flag, Scope *sc, TemplateParameters *tparams)
{
    if (t)
    {
        t = t->toBasetype();
        if (t->ty == Tarray || t->ty == Tsarray)
        {
            Type *tn = t->nextOf();
            for (size_t i = 0; i < elements->dim; i++)
            {   Expression *e = (*elements)[i];
                if (e)
                {   e = e->inferType(tn, flag, sc, tparams);
                    (*elements)[i] = e;
                }
            }
        }
    }
    return this;
}

Expression *AssocArrayLiteralExp::inferType(Type *t, int flag, Scope *sc, TemplateParameters *tparams)
{
    if (t)
    {
        t = t->toBasetype();
        if (t->ty == Taarray)
        {   TypeAArray *taa = (TypeAArray *)t;
            Type *ti = taa->index;
            Type *tv = taa->nextOf();
            for (size_t i = 0; i < keys->dim; i++)
            {   Expression *e = (*keys)[i];
                if (e)
                {   e = e->inferType(ti, flag, sc, tparams);
                    (*keys)[i] = e;
                }
            }
            for (size_t i = 0; i < values->dim; i++)
            {   Expression *e = (*values)[i];
                if (e)
                {   e = e->inferType(tv, flag, sc, tparams);
                    (*values)[i] = e;
                }
            }
        }
    }
    return this;
}

Expression *FuncExp::inferType(Type *to, int flag, Scope *sc, TemplateParameters *tparams)
{
    if (!to)
        return this;

    //printf("FuncExp::interType('%s'), to=%s\n", type?type->toChars():"null", to->toChars());

    if (!type)  // semantic is not yet done
    {
        if (to->ty == Tdelegate ||
            to->ty == Tpointer && to->nextOf()->ty == Tfunction)
        {
            fd->treq = to;
        }
        return this;
    }

    Expression *e = NULL;

    Type *t = to;
    if (t->ty == Tdelegate)
    {   if (tok == TOKfunction)
            goto L1;
        t = t->nextOf();
    }
    else if (t->ty == Tpointer && t->nextOf()->ty == Tfunction)
    {   if (tok == TOKdelegate)
            goto L1;
        t = t->nextOf();
    }

    if (td)
    {
        // Parameter types inference from 'to'
        assert(td->scope);
        if (t->ty == Tfunction)
        {
            TypeFunction *tfv = (TypeFunction *)t;
            TypeFunction *tfl = (TypeFunction *)fd->type;
            //printf("\ttfv = %s\n", tfv->toChars());
            //printf("\ttfl = %s\n", tfl->toChars());
            size_t dim = Parameter::dim(tfl->parameters);

            if (Parameter::dim(tfv->parameters) == dim &&
                tfv->varargs == tfl->varargs)
            {
                Objects *tiargs = new Objects();
                tiargs->reserve(td->parameters->dim);

                for (size_t i = 0; i < td->parameters->dim; i++)
                {
                    TemplateParameter *tp = (*td->parameters)[i];
                    for (size_t u = 0; u < dim; u++)
                    {
                        Parameter *p = Parameter::getNth(tfl->parameters, u);
                        if (p->type->ty == Tident &&
                            ((TypeIdentifier *)p->type)->ident == tp->ident)
                        {
                            p = Parameter::getNth(tfv->parameters, u);
                            Type *tprm = p->type;
                            if (tprm->reliesOnTident(tparams))
                                goto L1;
                            if (sc)
                                tprm = tprm->semantic(loc, sc);
                            if (tprm->ty == Terror)
                                goto L1;
                            tiargs->push(tprm);
                            u = dim;    // break inner loop
                        }
                    }
                }

                // Set target of return type inference
                assert(td->onemember);
                FuncLiteralDeclaration *fld = td->onemember->isFuncLiteralDeclaration();
                assert(fld);
                if (!fld->type->nextOf() && tfv->next)
                    fld->treq = to;

                TemplateInstance *ti = new TemplateInstance(loc, td, tiargs);
                e = (new ScopeExp(loc, ti))->semantic(td->scope);

                // Reset inference target for the later re-semantic
                fld->treq = NULL;

                if (e->op == TOKfunction)
                {
                    FuncExp *fe = (FuncExp *)e;
                    assert(fe->td == NULL);
                    e = fe->inferType(to, flag);
                }
            }
        }
    }
    else if (type)
    {
        assert(type != Type::tvoid);   // semantic is already done

        // Allow conversion from implicit function pointer to delegate
        if (tok == TOKreserved && type->ty == Tpointer &&
            to->ty == Tdelegate)
        {
            Type *typen = type->nextOf();
            if (typen->deco)
            {
                FuncExp *fe = (FuncExp *)copy();
                fe->tok = TOKdelegate;
                fe->type = (new TypeDelegate(typen))->merge();
                e = fe;
            }
        }
        else
            e = this;
    }
L1:
    if (!flag && !e)
    {
        error("cannot infer function literal type from %s", to->toChars());
        e = new ErrorExp();
    }
    return e;
}

Expression *CondExp::inferType(Type *t, int flag, Scope *sc, TemplateParameters *tparams)
{
    if (t)
    {
        t = t->toBasetype();
        e1 = e1->inferType(t, flag, sc, tparams);
        e2 = e2->inferType(t, flag, sc, tparams);
    }
    return this;
}

/* ==================== ====================== */

/****************************************
 * Scale addition/subtraction to/from pointer.
 */

Expression *BinExp::scaleFactor(Scope *sc)
{
    d_uns64 stride;
    Type *t1b = e1->type->toBasetype();
    Type *t2b = e2->type->toBasetype();
    Expression *eoff;

    if (t1b->ty == Tpointer && t2b->isintegral())
    {   // Need to adjust operator by the stride
        // Replace (ptr + int) with (ptr + (int * stride))
        Type *t = Type::tptrdiff_t;

        stride = t1b->nextOf()->size(loc);
        if (!t->equals(t2b))
            e2 = e2->castTo(sc, t);
        eoff = e2;
        e2 = new MulExp(loc, e2, new IntegerExp(Loc(), stride, t));
        e2->type = t;
        type = e1->type;
    }
    else if (t2b->ty == Tpointer && t1b->isintegral())
    {   // Need to adjust operator by the stride
        // Replace (int + ptr) with (ptr + (int * stride))
        Type *t = Type::tptrdiff_t;
        Expression *e;

        stride = t2b->nextOf()->size(loc);
        if (!t->equals(t1b))
            e = e1->castTo(sc, t);
        else
            e = e1;
        eoff = e;
        e = new MulExp(loc, e, new IntegerExp(Loc(), stride, t));
        e->type = t;
        type = e2->type;
        e1 = e2;
        e2 = e;
    }
    else
        assert(0);

    if (sc->func && !sc->intypeof)
    {
        eoff = eoff->optimize(WANTvalue);
        if (eoff->op == TOKint64 && eoff->toInteger() == 0)
            ;
        else if (sc->func->setUnsafe())
        {
            error("pointer arithmetic not allowed in @safe functions");
            return new ErrorExp();
        }
    }

    return this;
}

/**************************************
 * Return true if e is an empty array literal with dimensionality
 * equal to or less than type of other array.
 * [], [[]], [[[]]], etc.
 * I.e., make sure that [1,2] is compatible with [],
 * [[1,2]] is compatible with [[]], etc.
 */
bool isVoidArrayLiteral(Expression *e, Type *other)
{
    while (e->op == TOKarrayliteral && e->type->ty == Tarray
        && (((ArrayLiteralExp *)e)->elements->dim == 1))
    {
        e = (*((ArrayLiteralExp *)e)->elements)[0];
        if (other->ty == Tsarray || other->ty == Tarray)
            other = other->nextOf();
        else
            return false;
    }
    if (other->ty != Tsarray && other->ty != Tarray)
        return false;
    Type *t = e->type;
    return (e->op == TOKarrayliteral && t->ty == Tarray &&
        t->nextOf()->ty == Tvoid &&
        ((ArrayLiteralExp *)e)->elements->dim == 0);
}


/**************************************
 * Combine types.
 * Output:
 *      *pt     merged type, if *pt is not NULL
 *      *pe1    rewritten e1
 *      *pe2    rewritten e2
 * Returns:
 *      !=0     success
 *      0       failed
 */

int typeMerge(Scope *sc, Expression *e, Type **pt, Expression **pe1, Expression **pe2)
{
    //printf("typeMerge() %s op %s\n", (*pe1)->toChars(), (*pe2)->toChars());
    //e->print();

    MATCH m;
    Expression *e1 = *pe1;
    Expression *e2 = *pe2;
    Type *t1b = e1->type->toBasetype();
    Type *t2b = e2->type->toBasetype();

    if (e->op != TOKquestion ||
        t1b->ty != t2b->ty && (t1b->isTypeBasic() && t2b->isTypeBasic()))
    {
        e1 = integralPromotions(e1, sc);
        e2 = integralPromotions(e2, sc);
    }

    Type *t1 = e1->type;
    Type *t2 = e2->type;
    assert(t1);
    Type *t = t1;

    /* The start type of alias this type recursion.
     * In following case, we should save A, and stop recursion
     * if it appears again.
     *      X -> Y -> [A] -> B -> A -> B -> ...
     */
    Type *att1 = NULL;
    Type *att2 = NULL;

    //if (t1) printf("\tt1 = %s\n", t1->toChars());
    //if (t2) printf("\tt2 = %s\n", t2->toChars());
#ifdef DEBUG
    if (!t2) printf("\te2 = '%s'\n", e2->toChars());
#endif
    assert(t2);

Lagain:
    t1b = t1->toBasetype();
    t2b = t2->toBasetype();

    TY ty = (TY)Type::impcnvResult[t1b->ty][t2b->ty];
    if (ty != Terror)
    {
        TY ty1 = (TY)Type::impcnvType1[t1b->ty][t2b->ty];
        TY ty2 = (TY)Type::impcnvType2[t1b->ty][t2b->ty];

        if (t1b->ty == ty1)     // if no promotions
        {
            if (t1->equals(t2))
            {
                t = t1;
                goto Lret;
            }

            if (t1b->equals(t2b))
            {
                t = t1b;
                goto Lret;
            }
        }

        t = Type::basic[ty];

        t1 = Type::basic[ty1];
        t2 = Type::basic[ty2];
        e1 = e1->castTo(sc, t1);
        e2 = e2->castTo(sc, t2);
        //printf("after typeCombine():\n");
        //print();
        //printf("ty = %d, ty1 = %d, ty2 = %d\n", ty, ty1, ty2);
        goto Lret;
    }

    t1 = t1b;
    t2 = t2b;

    if (t1->ty == Ttuple || t2->ty == Ttuple)
        goto Lincompatible;

    if (t1->equals(t2))
    {
        // merging can not result in new enum type
        if (t->ty == Tenum)
            t = t1b;
    }
    else if ((t1->ty == Tpointer && t2->ty == Tpointer) ||
             (t1->ty == Tdelegate && t2->ty == Tdelegate))
    {
        // Bring pointers to compatible type
        Type *t1n = t1->nextOf();
        Type *t2n = t2->nextOf();

        if (t1n->equals(t2n))
            ;
        else if (t1n->ty == Tvoid)      // pointers to void are always compatible
            t = t2;
        else if (t2n->ty == Tvoid)
            ;
        else if (t1->implicitConvTo(t2))
        {
            goto Lt2;
        }
        else if (t2->implicitConvTo(t1))
        {
            goto Lt1;
        }
        else if (t1n->ty == Tfunction && t2n->ty == Tfunction)
        {
            TypeFunction *tf1 = (TypeFunction *)t1n;
            TypeFunction *tf2 = (TypeFunction *)t2n;
            TypeFunction *d = (TypeFunction *)tf1->syntaxCopy();

            if (tf1->purity != tf2->purity)
                d->purity = PUREimpure;
            assert(d->purity != PUREfwdref);

            d->isnothrow = (tf1->isnothrow && tf2->isnothrow);

            if (tf1->trust == tf2->trust)
                d->trust = tf1->trust;
            else if (tf1->trust <= TRUSTsystem || tf2->trust <= TRUSTsystem)
                d->trust = TRUSTsystem;
            else
                d->trust = TRUSTtrusted;

            Type *tx = NULL;
            if (t1->ty == Tdelegate)
            {
                tx = new TypeDelegate(d);
            }
            else
                tx = d->pointerTo();

            tx = tx->semantic(e1->loc, sc);

            if (t1->implicitConvTo(tx) && t2->implicitConvTo(tx))
            {
                t = tx;
                e1 = e1->castTo(sc, t);
                e2 = e2->castTo(sc, t);
                goto Lret;
            }
            goto Lincompatible;
        }
        else if (t1n->mod != t2n->mod)
        {
            if (!t1n->isImmutable() && !t2n->isImmutable() && t1n->isShared() != t2n->isShared())
                goto Lincompatible;
            unsigned char mod = MODmerge(t1n->mod, t2n->mod);
            t1 = t1n->castMod(mod)->pointerTo();
            t2 = t2n->castMod(mod)->pointerTo();
            t = t1;
            goto Lagain;
        }
        else if (t1n->ty == Tclass && t2n->ty == Tclass)
        {   ClassDeclaration *cd1 = t1n->isClassHandle();
            ClassDeclaration *cd2 = t2n->isClassHandle();
            int offset;

            if (cd1->isBaseOf(cd2, &offset))
            {
                if (offset)
                    e2 = e2->castTo(sc, t);
            }
            else if (cd2->isBaseOf(cd1, &offset))
            {
                t = t2;
                if (offset)
                    e1 = e1->castTo(sc, t);
            }
            else
                goto Lincompatible;
        }
        else
        {
            t1 = t1n->constOf()->pointerTo();
            t2 = t2n->constOf()->pointerTo();
            if (t1->implicitConvTo(t2))
            {
                goto Lt2;
            }
            else if (t2->implicitConvTo(t1))
            {
                goto Lt1;
            }
            goto Lincompatible;
        }
    }
    else if ((t1->ty == Tsarray || t1->ty == Tarray) &&
             (e2->op == TOKnull && t2->ty == Tpointer && t2->nextOf()->ty == Tvoid ||
              // if e2 is void[]
              e2->op == TOKarrayliteral && t2->ty == Tsarray && t2->nextOf()->ty == Tvoid && ((TypeSArray *)t2)->dim->toInteger() == 0 ||
              isVoidArrayLiteral(e2, t1))
            )
    {   /*  (T[n] op void*)   => T[]
         *  (T[]  op void*)   => T[]
         *  (T[n] op void[0]) => T[]
         *  (T[]  op void[0]) => T[]
         *  (T[n] op void[])  => T[]
         *  (T[]  op void[])  => T[]
         */
        goto Lx1;
    }
    else if ((t2->ty == Tsarray || t2->ty == Tarray) &&
             (e1->op == TOKnull && t1->ty == Tpointer && t1->nextOf()->ty == Tvoid ||
              e1->op == TOKarrayliteral && t1->ty == Tsarray && t1->nextOf()->ty == Tvoid && ((TypeSArray *)t1)->dim->toInteger() == 0 ||
              isVoidArrayLiteral(e1, t2))
            )
    {   /*  (void*   op T[n]) => T[]
         *  (void*   op T[])  => T[]
         *  (void[0] op T[n]) => T[]
         *  (void[0] op T[])  => T[]
         *  (void[]  op T[n]) => T[]
         *  (void[]  op T[])  => T[]
         */
        goto Lx2;
    }
    else if ((t1->ty == Tsarray || t1->ty == Tarray) &&
             (m = t1->implicitConvTo(t2)) != MATCHnomatch)
    {
        if (t1->ty == Tsarray && e2->op == TOKarrayliteral)
            goto Lt1;
        if (m == MATCHconst &&
            (e->op == TOKaddass || e->op == TOKminass || e->op == TOKmulass ||
             e->op == TOKdivass || e->op == TOKmodass || e->op == TOKpowass ||
             e->op == TOKandass || e->op == TOKorass  || e->op == TOKxorass)
           )
        {   // Don't make the lvalue const
            t = t2;
            goto Lret;
        }
        goto Lt2;
    }
    else if ((t2->ty == Tsarray || t2->ty == Tarray) && t2->implicitConvTo(t1))
    {
        if (t2->ty == Tsarray && e1->op == TOKarrayliteral)
            goto Lt2;
        goto Lt1;
    }
    /* If one is mutable and the other invariant, then retry
     * with both of them as const
     */
    else if ((t1->ty == Tsarray || t1->ty == Tarray || t1->ty == Tpointer) &&
             (t2->ty == Tsarray || t2->ty == Tarray || t2->ty == Tpointer) &&
             t1->nextOf()->mod != t2->nextOf()->mod
            )
    {
        Type *t1n = t1->nextOf();
        Type *t2n = t2->nextOf();
        unsigned char mod;
        if (e1->op == TOKnull && e2->op != TOKnull)
            mod = t2n->mod;
        else if (e1->op != TOKnull && e2->op == TOKnull)
            mod = t1n->mod;
        else if (!t1n->isImmutable() && !t2n->isImmutable() && t1n->isShared() != t2n->isShared())
            goto Lincompatible;
        else
            mod = MODmerge(t1n->mod, t2n->mod);

        if (t1->ty == Tpointer)
            t1 = t1n->castMod(mod)->pointerTo();
        else
            t1 = t1n->castMod(mod)->arrayOf();

        if (t2->ty == Tpointer)
            t2 = t2n->castMod(mod)->pointerTo();
        else
            t2 = t2n->castMod(mod)->arrayOf();
        t = t1;
        goto Lagain;
    }
    else if (t1->ty == Tclass && t2->ty == Tclass)
    {
        if (t1->mod != t2->mod)
        {
            unsigned char mod;
            if (e1->op == TOKnull && e2->op != TOKnull)
                mod = t2->mod;
            else if (e1->op != TOKnull && e2->op == TOKnull)
                mod = t1->mod;
            else if (!t1->isImmutable() && !t2->isImmutable() && t1->isShared() != t2->isShared())
                goto Lincompatible;
            else
                mod = MODmerge(t1->mod, t2->mod);
            t1 = t1->castMod(mod);
            t2 = t2->castMod(mod);
            t = t1;
            goto Lagain;
        }
        goto Lcc;
    }
    else if (t1->ty == Tclass || t2->ty == Tclass)
    {
Lcc:
        while (1)
        {
            MATCH i1 = e2->implicitConvTo(t1);
            MATCH i2 = e1->implicitConvTo(t2);

            if (i1 && i2)
            {
                // We have the case of class vs. void*, so pick class
                if (t1->ty == Tpointer)
                    i1 = MATCHnomatch;
                else if (t2->ty == Tpointer)
                    i2 = MATCHnomatch;
            }

            if (i2)
            {
                goto Lt2;
            }
            else if (i1)
            {
                goto Lt1;
            }
            else if (t1->ty == Tclass && t2->ty == Tclass)
            {   TypeClass *tc1 = (TypeClass *)t1;
                TypeClass *tc2 = (TypeClass *)t2;

                /* Pick 'tightest' type
                 */
                ClassDeclaration *cd1 = tc1->sym->baseClass;
                ClassDeclaration *cd2 = tc2->sym->baseClass;

                if (cd1 && cd2)
                {   t1 = cd1->type;
                    t2 = cd2->type;
                }
                else if (cd1)
                    t1 = cd1->type;
                else if (cd2)
                    t2 = cd2->type;
                else
                    goto Lincompatible;
            }
            else if (t1->ty == Tstruct && ((TypeStruct *)t1)->sym->aliasthis)
            {
                if (att1 && e1->type == att1)
                    goto Lincompatible;
                if (!att1 && e1->type->checkAliasThisRec())
                    att1 = e1->type;
                //printf("att tmerge(c || c) e1 = %s\n", e1->type->toChars());
                e1 = resolveAliasThis(sc, e1);
                t1 = e1->type;
                continue;
            }
            else if (t2->ty == Tstruct && ((TypeStruct *)t2)->sym->aliasthis)
            {
                if (att2 && e2->type == att2)
                    goto Lincompatible;
                if (!att2 && e2->type->checkAliasThisRec())
                    att2 = e2->type;
                //printf("att tmerge(c || c) e2 = %s\n", e2->type->toChars());
                e2 = resolveAliasThis(sc, e2);
                t2 = e2->type;
                continue;
            }
            else
                goto Lincompatible;
        }
    }
    else if (t1->ty == Tstruct && t2->ty == Tstruct)
    {
        if (t1->mod != t2->mod)
        {
            if (!t1->isImmutable() && !t2->isImmutable() && t1->isShared() != t2->isShared())
                goto Lincompatible;
            unsigned char mod = MODmerge(t1->mod, t2->mod);
            t1 = t1->castMod(mod);
            t2 = t2->castMod(mod);
            t = t1;
            goto Lagain;
        }

        TypeStruct *ts1 = (TypeStruct *)t1;
        TypeStruct *ts2 = (TypeStruct *)t2;
        if (ts1->sym != ts2->sym)
        {
            if (!ts1->sym->aliasthis && !ts2->sym->aliasthis)
                goto Lincompatible;

            MATCH i1 = MATCHnomatch;
            MATCH i2 = MATCHnomatch;

            Expression *e1b = NULL;
            Expression *e2b = NULL;
            if (ts2->sym->aliasthis)
            {
                if (att2 && e2->type == att2)
                    goto Lincompatible;
                if (!att2 && e2->type->checkAliasThisRec())
                    att2 = e2->type;
                //printf("att tmerge(s && s) e2 = %s\n", e2->type->toChars());
                e2b = resolveAliasThis(sc, e2);
                i1 = e2b->implicitConvTo(t1);
            }
            if (ts1->sym->aliasthis)
            {
                if (att1 && e1->type == att1)
                    goto Lincompatible;
                if (!att1 && e1->type->checkAliasThisRec())
                    att1 = e1->type;
                //printf("att tmerge(s && s) e1 = %s\n", e1->type->toChars());
                e1b = resolveAliasThis(sc, e1);
                i2 = e1b->implicitConvTo(t2);
            }
            if (i1 && i2)
                goto Lincompatible;

            if (i1)
                goto Lt1;
            else if (i2)
                goto Lt2;

            if (e1b)
            {   e1 = e1b;
                t1 = e1b->type->toBasetype();
            }
            if (e2b)
            {   e2 = e2b;
                t2 = e2b->type->toBasetype();
            }
            t = t1;
            goto Lagain;
        }
    }
    else if (t1->ty == Tstruct || t2->ty == Tstruct)
    {
        if (t1->ty == Tstruct && ((TypeStruct *)t1)->sym->aliasthis)
        {
            if (att1 && e1->type == att1)
                goto Lincompatible;
            if (!att1 && e1->type->checkAliasThisRec())
                att1 = e1->type;
            //printf("att tmerge(s || s) e1 = %s\n", e1->type->toChars());
            e1 = resolveAliasThis(sc, e1);
            t1 = e1->type;
            t = t1;
            goto Lagain;
        }
        if (t2->ty == Tstruct && ((TypeStruct *)t2)->sym->aliasthis)
        {
            if (att2 && e2->type == att2)
                goto Lincompatible;
            if (!att2 && e2->type->checkAliasThisRec())
                att2 = e2->type;
            //printf("att tmerge(s || s) e2 = %s\n", e2->type->toChars());
            e2 = resolveAliasThis(sc, e2);
            t2 = e2->type;
            t = t2;
            goto Lagain;
        }
        goto Lincompatible;
    }
    else if ((e1->op == TOKstring || e1->op == TOKnull) && e1->implicitConvTo(t2))
    {
        goto Lt2;
    }
    else if ((e2->op == TOKstring || e2->op == TOKnull) && e2->implicitConvTo(t1))
    {
        goto Lt1;
    }
    else if (t1->ty == Tsarray && t2->ty == Tsarray &&
             e2->implicitConvTo(t1->nextOf()->arrayOf()))
    {
     Lx1:
        t = t1->nextOf()->arrayOf();    // T[]
        e1 = e1->castTo(sc, t);
        e2 = e2->castTo(sc, t);
    }
    else if (t1->ty == Tsarray && t2->ty == Tsarray &&
             e1->implicitConvTo(t2->nextOf()->arrayOf()))
    {
     Lx2:
        t = t2->nextOf()->arrayOf();
        e1 = e1->castTo(sc, t);
        e2 = e2->castTo(sc, t);
    }
    else if (t1->ty == Tvector && t2->ty != Tvector &&
             e2->implicitConvTo(t1))
    {
        e2 = e2->castTo(sc, t1);
        t2 = t1;
        t = t1;
        goto Lagain;
    }
    else if (t2->ty == Tvector && t1->ty != Tvector &&
             e1->implicitConvTo(t2))
    {
        e1 = e1->castTo(sc, t2);
        t1 = t2;
        t = t1;
        goto Lagain;
    }
    else if (t1->isintegral() && t2->isintegral())
    {
        if (t1->ty != t2->ty)
        {
            e1 = integralPromotions(e1, sc);
            e2 = integralPromotions(e2, sc);
            t1 = e1->type;  t1b = t1->toBasetype();
            t2 = e2->type;  t2b = t2->toBasetype();
        }
        assert(t1->ty == t2->ty);
        if (!t1->isImmutable() && !t2->isImmutable() && t1->isShared() != t2->isShared())
            goto Lincompatible;
        unsigned char mod = MODmerge(t1->mod, t2->mod);

        t1 = t1->castMod(mod);
        t2 = t2->castMod(mod);
        t = t1;
        e1 = e1->castTo(sc, t);
        e2 = e2->castTo(sc, t);
        goto Lagain;
    }
    else if (t1->ty == Tnull && t2->ty == Tnull)
    {
        unsigned char mod = MODmerge(t1->mod, t2->mod);

        t = t1->castMod(mod);
        e1 = e1->castTo(sc, t);
        e2 = e2->castTo(sc, t);
        goto Lret;
    }
    else if (t2->ty == Tnull &&
        (t1->ty == Tpointer || t1->ty == Taarray || t1->ty == Tarray))
    {
        goto Lt1;
    }
    else if (t1->ty == Tnull &&
        (t2->ty == Tpointer || t2->ty == Taarray || t2->ty == Tarray))
    {
        goto Lt2;
    }
    else if (isArrayOperand(e1) && t1->ty == Tarray &&
             e2->implicitConvTo(t1->nextOf()))
    {   // T[] op T
        e2 = e2->castTo(sc, t1->nextOf());
        t = t1->nextOf()->arrayOf();
    }
    else if (isArrayOperand(e2) && t2->ty == Tarray &&
             e1->implicitConvTo(t2->nextOf()))
    {   // T op T[]
        e1 = e1->castTo(sc, t2->nextOf());
        t = t2->nextOf()->arrayOf();

        //printf("test %s\n", e->toChars());
        e1 = e1->optimize(WANTvalue);
        if (e && isCommutative(e) && e1->isConst())
        {   /* Swap operands to minimize number of functions generated
             */
            //printf("swap %s\n", e->toChars());
            Expression *tmp = e1;
            e1 = e2;
            e2 = tmp;
        }
    }
    else
    {
     Lincompatible:
        return 0;
    }
Lret:
    if (!*pt)
        *pt = t;
    *pe1 = e1;
    *pe2 = e2;
#if 0
    printf("-typeMerge() %s op %s\n", e1->toChars(), e2->toChars());
    if (e1->type) printf("\tt1 = %s\n", e1->type->toChars());
    if (e2->type) printf("\tt2 = %s\n", e2->type->toChars());
    printf("\ttype = %s\n", t->toChars());
#endif
    //print();
    return 1;


Lt1:
    e2 = e2->castTo(sc, t1);
    t = t1;
    goto Lret;

Lt2:
    e1 = e1->castTo(sc, t2);
    t = t2;
    goto Lret;
}

/************************************
 * Bring leaves to common type.
 */

Expression *BinExp::typeCombine(Scope *sc)
{
    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();

    if (op == TOKmin || op == TOKadd)
    {
        // struct+struct, and class+class are errors
        if (t1->ty == Tstruct && t2->ty == Tstruct)
            goto Lerror;
        else if (t1->ty == Tclass && t2->ty == Tclass)
            goto Lerror;
        else if (t1->ty == Taarray && t2->ty == Taarray)
            goto Lerror;
    }

    if (!typeMerge(sc, this, &type, &e1, &e2))
        goto Lerror;
    // If the types have no value, return an error
    if (e1->op == TOKerror)
        return e1;
    if (e2->op == TOKerror)
        return e2;
    return this;

Lerror:
    incompatibleTypes();
    type = Type::terror;
    e1 = new ErrorExp();
    e2 = new ErrorExp();
    return new ErrorExp();
}

/***********************************
 * Do integral promotions (convertchk).
 * Don't convert <array of> to <pointer to>
 */

Expression *integralPromotions(Expression *e, Scope *sc)
{
    //printf("integralPromotions %s %s\n", e->toChars(), e->type->toChars());
    switch (e->type->toBasetype()->ty)
    {
        case Tvoid:
            e->error("void has no value");
            return new ErrorExp();

        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:
        case Tbool:
        case Tchar:
        case Twchar:
            e = e->castTo(sc, Type::tint32);
            break;

        case Tdchar:
            e = e->castTo(sc, Type::tuns32);
            break;
        default:
            break;
    }
    return e;
}

/***********************************
 * See if both types are arrays that can be compared
 * for equality. Return !=0 if so.
 * If they are arrays, but incompatible, issue error.
 * This is to enable comparing things like an immutable
 * array with a mutable one.
 */

int arrayTypeCompatible(Loc loc, Type *t1, Type *t2)
{
    t1 = t1->toBasetype()->merge2();
    t2 = t2->toBasetype()->merge2();

    if ((t1->ty == Tarray || t1->ty == Tsarray || t1->ty == Tpointer) &&
        (t2->ty == Tarray || t2->ty == Tsarray || t2->ty == Tpointer))
    {
        if (t1->nextOf()->implicitConvTo(t2->nextOf()) < MATCHconst &&
            t2->nextOf()->implicitConvTo(t1->nextOf()) < MATCHconst &&
            (t1->nextOf()->ty != Tvoid && t2->nextOf()->ty != Tvoid))
        {
            error(loc, "array equality comparison type mismatch, %s vs %s", t1->toChars(), t2->toChars());
        }
        return 1;
    }
    return 0;
}

/***********************************
 * See if both types are arrays that can be compared
 * for equality without any casting. Return !=0 if so.
 * This is to enable comparing things like an immutable
 * array with a mutable one.
 */
int arrayTypeCompatibleWithoutCasting(Loc loc, Type *t1, Type *t2)
{
    t1 = t1->toBasetype();
    t2 = t2->toBasetype();

    if ((t1->ty == Tarray || t1->ty == Tsarray || t1->ty == Tpointer) &&
        t2->ty == t1->ty)
    {
        if (t1->nextOf()->implicitConvTo(t2->nextOf()) >= MATCHconst ||
            t2->nextOf()->implicitConvTo(t1->nextOf()) >= MATCHconst)
            return 1;
    }
    return 0;
}

/******************************************************************/

/* Determine the integral ranges of an expression.
 * This is used to determine if implicit narrowing conversions will
 * be allowed.
 */

IntRange getIntRange(Expression *e)
{
    class IntRangeVisitor : public Visitor
    {
    private:
        static uinteger_t getMask(uinteger_t v)
        {
            // Ref: http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
            v |= v >> 1;
            v |= v >> 2;
            v |= v >> 4;
            v |= v >> 8;
            v |= v >> 16;
            v |= v >> 32;
            return v;
        }

        // The algorithms for &, |, ^ are not yet the best! Sometimes they will produce
        //  not the tightest bound. See
        //      https://github.com/D-Programming-Language/dmd/pull/116
        //  for detail.
        static IntRange unsignedBitwiseAnd(const IntRange& a, const IntRange& b)
        {
            // the DiffMasks stores the mask of bits which are variable in the range.
            uinteger_t aDiffMask = getMask(a.imin.value ^ a.imax.value);
            uinteger_t bDiffMask = getMask(b.imin.value ^ b.imax.value);
            // Since '&' computes the digitwise-minimum, the we could set all varying
            //  digits to 0 to get a lower bound, and set all varying digits to 1 to get
            //  an upper bound.
            IntRange result;
            result.imin.value = (a.imin.value & ~aDiffMask) & (b.imin.value & ~bDiffMask);
            result.imax.value = (a.imax.value | aDiffMask) & (b.imax.value | bDiffMask);
            // Sometimes the upper bound is overestimated. The upper bound will never
            //  exceed the input.
            if (result.imax.value > a.imax.value)
                result.imax.value = a.imax.value;
            if (result.imax.value > b.imax.value)
                result.imax.value = b.imax.value;
            result.imin.negative = result.imax.negative = a.imin.negative && b.imin.negative;
            return result;
        }
        static IntRange unsignedBitwiseOr(const IntRange& a, const IntRange& b)
        {
            // the DiffMasks stores the mask of bits which are variable in the range.
            uinteger_t aDiffMask = getMask(a.imin.value ^ a.imax.value);
            uinteger_t bDiffMask = getMask(b.imin.value ^ b.imax.value);
            // The imax algorithm by Adam D. Ruppe.
            // http://www.digitalmars.com/pnews/read.php?server=news.digitalmars.com&group=digitalmars.D&artnum=108796
            IntRange result;
            result.imin.value = (a.imin.value & ~aDiffMask) | (b.imin.value & ~bDiffMask);
            result.imax.value = a.imax.value | b.imax.value | getMask(a.imax.value & b.imax.value);
            // Sometimes the lower bound is underestimated. The lower bound will never
            //  less than the input.
            if (result.imin.value < a.imin.value)
                result.imin.value = a.imin.value;
            if (result.imin.value < b.imin.value)
                result.imin.value = b.imin.value;
            result.imin.negative = result.imax.negative = a.imin.negative || b.imin.negative;
            return result;
        }
        static IntRange unsignedBitwiseXor(const IntRange& a, const IntRange& b)
        {
            // the DiffMasks stores the mask of bits which are variable in the range.
            uinteger_t aDiffMask = getMask(a.imin.value ^ a.imax.value);
            uinteger_t bDiffMask = getMask(b.imin.value ^ b.imax.value);
            IntRange result;
            result.imin.value = (a.imin.value ^ b.imin.value) & ~(aDiffMask | bDiffMask);
            result.imax.value = (a.imax.value ^ b.imax.value) | (aDiffMask | bDiffMask);
            result.imin.negative = result.imax.negative = a.imin.negative != b.imin.negative;
            return result;
        }

    public:
        IntRange range;

        void visit(Expression *e)
        {
            range = IntRange::fromType(e->type);
        }

        void visit(IntegerExp *e)
        {
            range = IntRange(SignExtendedNumber(e->value)).cast(e->type);
        }

        void visit(CastExp *e)
        {
            range = getIntRange(e->e1).cast(e->type);
        }

        void visit(AddExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);
            range = IntRange(ir1.imin + ir2.imin, ir1.imax + ir2.imax).cast(e->type);
        }

        void visit(MinExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);
            range = IntRange(ir1.imin - ir2.imax, ir1.imax - ir2.imin).cast(e->type);
        }

        void visit(DivExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            // Should we ignore the possibility of div-by-0???
            if (ir2.containsZero())
            {
                visit((Expression *)e);
                return;
            }

            // [a,b] / [c,d] = [min (a/c, a/d, b/c, b/d), max (a/c, a/d, b/c, b/d)]
            SignExtendedNumber bdy[4];
            bdy[0] = ir1.imin / ir2.imin;
            bdy[1] = ir1.imin / ir2.imax;
            bdy[2] = ir1.imax / ir2.imin;
            bdy[3] = ir1.imax / ir2.imax;
            range = IntRange::fromNumbers4(bdy).cast(e->type);
        }

        void visit(MulExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            // [a,b] * [c,d] = [min (ac, ad, bc, bd), max (ac, ad, bc, bd)]
            SignExtendedNumber bdy[4];
            bdy[0] = ir1.imin * ir2.imin;
            bdy[1] = ir1.imin * ir2.imax;
            bdy[2] = ir1.imax * ir2.imin;
            bdy[3] = ir1.imax * ir2.imax;
            range = IntRange::fromNumbers4(bdy).cast(e->type);
        }

        void visit(ModExp *e)
        {
            IntRange irNum = getIntRange(e->e1);
            IntRange irDen = getIntRange(e->e2).absNeg();

            /*
            due to the rules of D (C)'s % operator, we need to consider the cases
            separately in different range of signs.

                case 1. [500, 1700] % [7, 23] (numerator is always positive)
                    = [0, 22]
                case 2. [-500, 1700] % [7, 23] (numerator can be negative)
                    = [-22, 22]
                case 3. [-1700, -500] % [7, 23] (numerator is always negative)
                    = [-22, 0]

            the number 22 is the maximum absolute value in the denomator's range. We
            don't care about divide by zero.
            */

            // Modding on 0 is invalid anyway.
            if (!irDen.imin.negative)
            {
                visit((Expression *)e);
                return;
            }

            ++ irDen.imin;
            irDen.imax = -irDen.imin;

            if (!irNum.imin.negative)
                irNum.imin.value = 0;
            else if (irNum.imin < irDen.imin)
                irNum.imin = irDen.imin;

            if (irNum.imax.negative)
            {
                irNum.imax.negative = false;
                irNum.imax.value = 0;
            }
            else if (irNum.imax > irDen.imax)
                irNum.imax = irDen.imax;

            range = irNum.cast(e->type);
        }

        void visit(AndExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            IntRange ir1neg, ir1pos, ir2neg, ir2pos;
            bool has1neg, has1pos, has2neg, has2pos;

            ir1.splitBySign(ir1neg, has1neg, ir1pos, has1pos);
            ir2.splitBySign(ir2neg, has2neg, ir2pos, has2pos);

            IntRange result;
            bool hasResult = false;
            if (has1pos && has2pos)
                result.unionOrAssign(unsignedBitwiseAnd(ir1pos, ir2pos), hasResult);
            if (has1pos && has2neg)
                result.unionOrAssign(unsignedBitwiseAnd(ir1pos, ir2neg), hasResult);
            if (has1neg && has2pos)
                result.unionOrAssign(unsignedBitwiseAnd(ir1neg, ir2pos), hasResult);
            if (has1neg && has2neg)
                result.unionOrAssign(unsignedBitwiseAnd(ir1neg, ir2neg), hasResult);
            assert(hasResult);
            range = result.cast(e->type);
        }

        void visit(OrExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            IntRange ir1neg, ir1pos, ir2neg, ir2pos;
            bool has1neg, has1pos, has2neg, has2pos;

            ir1.splitBySign(ir1neg, has1neg, ir1pos, has1pos);
            ir2.splitBySign(ir2neg, has2neg, ir2pos, has2pos);

            IntRange result;
            bool hasResult = false;
            if (has1pos && has2pos)
                result.unionOrAssign(unsignedBitwiseOr(ir1pos, ir2pos), hasResult);
            if (has1pos && has2neg)
                result.unionOrAssign(unsignedBitwiseOr(ir1pos, ir2neg), hasResult);
            if (has1neg && has2pos)
                result.unionOrAssign(unsignedBitwiseOr(ir1neg, ir2pos), hasResult);
            if (has1neg && has2neg)
                result.unionOrAssign(unsignedBitwiseOr(ir1neg, ir2neg), hasResult);

            assert(hasResult);
            range = result.cast(e->type);
        }

        void visit(XorExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            IntRange ir1neg, ir1pos, ir2neg, ir2pos;
            bool has1neg, has1pos, has2neg, has2pos;

            ir1.splitBySign(ir1neg, has1neg, ir1pos, has1pos);
            ir2.splitBySign(ir2neg, has2neg, ir2pos, has2pos);

            IntRange result;
            bool hasResult = false;
            if (has1pos && has2pos)
                result.unionOrAssign(unsignedBitwiseXor(ir1pos, ir2pos), hasResult);
            if (has1pos && has2neg)
                result.unionOrAssign(unsignedBitwiseXor(ir1pos, ir2neg), hasResult);
            if (has1neg && has2pos)
                result.unionOrAssign(unsignedBitwiseXor(ir1neg, ir2pos), hasResult);
            if (has1neg && has2neg)
                result.unionOrAssign(unsignedBitwiseXor(ir1neg, ir2neg), hasResult);

            assert(hasResult);
            range = result.cast(e->type);
        }

        void visit(ShlExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            if (ir2.imin.negative)
                ir2 = IntRange(SignExtendedNumber(0), SignExtendedNumber(64));

            SignExtendedNumber lower = ir1.imin << (ir1.imin.negative ? ir2.imax : ir2.imin);
            SignExtendedNumber upper = ir1.imax << (ir1.imax.negative ? ir2.imin : ir2.imax);

            range = IntRange(lower, upper).cast(e->type);
        }

        void visit(ShrExp *e)
        {
            IntRange ir1 = getIntRange(e->e1);
            IntRange ir2 = getIntRange(e->e2);

            if (ir2.imin.negative)
                ir2 = IntRange(SignExtendedNumber(0), SignExtendedNumber(64));

            SignExtendedNumber lower = ir1.imin >> (ir1.imin.negative ? ir2.imin : ir2.imax);
            SignExtendedNumber upper = ir1.imax >> (ir1.imax.negative ? ir2.imax : ir2.imin);

            range = IntRange(lower, upper).cast(e->type);
        }

        void visit(UshrExp *e)
        {
            IntRange ir1 = getIntRange(e->e1).castUnsigned(e->e1->type);
            IntRange ir2 = getIntRange(e->e2);

            if (ir2.imin.negative)
                ir2 = IntRange(SignExtendedNumber(0), SignExtendedNumber(64));

            range = IntRange(ir1.imin >> ir2.imax, ir1.imax >> ir2.imin).cast(e->type);

        }

        void visit(CommaExp *e)
        {
            e->e2->accept(this);
        }

        void visit(ComExp *e)
        {
            IntRange ir = getIntRange(e->e1);
            range = IntRange(SignExtendedNumber(~ir.imax.value, !ir.imax.negative),
                            SignExtendedNumber(~ir.imin.value, !ir.imin.negative)).cast(e->type);
        }

        void visit(NegExp *e)
        {
            IntRange ir = getIntRange(e->e1);
            range = IntRange(-ir.imax, -ir.imin).cast(e->type);
        }
    };

    IntRangeVisitor v;
    e->accept(&v);
    return v.range;
}
