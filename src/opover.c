
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <string.h>                     // memset()

#ifdef __APPLE__
#define integer_t dmd_integer_t
#endif

#include "rmem.h"

//#include "port.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"
#include "statement.h"
#include "scope.h"
#include "id.h"
#include "declaration.h"
#include "aggregate.h"
#include "template.h"

static Dsymbol *inferApplyArgTypesX(Expression *ethis, FuncDeclaration *fstart, Parameters *arguments);
static void inferApplyArgTypesZ(TemplateDeclaration *tstart, Parameters *arguments);
static int inferApplyArgTypesY(TypeFunction *tf, Parameters *arguments, int flags = 0);

/******************************** Expression **************************/


/***********************************
 * Determine if operands of binary op can be reversed
 * to fit operator overload.
 */

int Expression::isCommutative()
{
    return false;       // default is no reverse
}

/***********************************
 * Get Identifier for operator overload.
 */

Identifier *Expression::opId()
{
    assert(0);
    return NULL;
}

/***********************************
 * Get Identifier for reverse operator overload,
 * NULL if not supported for this operator.
 */

Identifier *Expression::opId_r()
{
    return NULL;
}

/************************* Operators *****************************/

Identifier *UAddExp::opId()   { return Id::uadd; }

Identifier *NegExp::opId()   { return Id::neg; }

Identifier *ComExp::opId()   { return Id::com; }

Identifier *CastExp::opId()   { return Id::cast; }

Identifier *InExp::opId()     { return Id::opIn; }
Identifier *InExp::opId_r()     { return Id::opIn_r; }

Identifier *PostExp::opId() { return (op == TOKplusplus)
                                ? Id::postinc
                                : Id::postdec; }

int AddExp::isCommutative()  { return true; }
Identifier *AddExp::opId()   { return Id::add; }
Identifier *AddExp::opId_r() { return Id::add_r; }

Identifier *MinExp::opId()   { return Id::sub; }
Identifier *MinExp::opId_r() { return Id::sub_r; }

int MulExp::isCommutative()  { return true; }
Identifier *MulExp::opId()   { return Id::mul; }
Identifier *MulExp::opId_r() { return Id::mul_r; }

Identifier *DivExp::opId()   { return Id::div; }
Identifier *DivExp::opId_r() { return Id::div_r; }

Identifier *ModExp::opId()   { return Id::mod; }
Identifier *ModExp::opId_r() { return Id::mod_r; }

Identifier *PowExp::opId()   { return Id::pow; }
Identifier *PowExp::opId_r() { return Id::pow_r; }

Identifier *ShlExp::opId()   { return Id::shl; }
Identifier *ShlExp::opId_r() { return Id::shl_r; }

Identifier *ShrExp::opId()   { return Id::shr; }
Identifier *ShrExp::opId_r() { return Id::shr_r; }

Identifier *UshrExp::opId()   { return Id::ushr; }
Identifier *UshrExp::opId_r() { return Id::ushr_r; }

int AndExp::isCommutative()  { return true; }
Identifier *AndExp::opId()   { return Id::iand; }
Identifier *AndExp::opId_r() { return Id::iand_r; }

int OrExp::isCommutative()  { return true; }
Identifier *OrExp::opId()   { return Id::ior; }
Identifier *OrExp::opId_r() { return Id::ior_r; }

int XorExp::isCommutative()  { return true; }
Identifier *XorExp::opId()   { return Id::ixor; }
Identifier *XorExp::opId_r() { return Id::ixor_r; }

Identifier *CatExp::opId()   { return Id::cat; }
Identifier *CatExp::opId_r() { return Id::cat_r; }

Identifier *    AssignExp::opId()  { return Id::assign;  }
Identifier * AddAssignExp::opId()  { return Id::addass;  }
Identifier * MinAssignExp::opId()  { return Id::subass;  }
Identifier * MulAssignExp::opId()  { return Id::mulass;  }
Identifier * DivAssignExp::opId()  { return Id::divass;  }
Identifier * ModAssignExp::opId()  { return Id::modass;  }
Identifier * AndAssignExp::opId()  { return Id::andass;  }
Identifier *  OrAssignExp::opId()  { return Id::orass;   }
Identifier * XorAssignExp::opId()  { return Id::xorass;  }
Identifier * ShlAssignExp::opId()  { return Id::shlass;  }
Identifier * ShrAssignExp::opId()  { return Id::shrass;  }
Identifier *UshrAssignExp::opId()  { return Id::ushrass; }
Identifier * CatAssignExp::opId()  { return Id::catass;  }
Identifier * PowAssignExp::opId()  { return Id::powass;  }

int EqualExp::isCommutative()  { return true; }
Identifier *EqualExp::opId()   { return Id::eq; }

int CmpExp::isCommutative()  { return true; }
Identifier *CmpExp::opId()   { return Id::cmp; }

Identifier *ArrayExp::opId()    { return Id::index; }
Identifier *PtrExp::opId()      { return Id::opStar; }

/************************************
 * If type is a class or struct, return the symbol for it,
 * else NULL
 */
AggregateDeclaration *isAggregate(Type *t)
{
    t = t->toBasetype();
    if (t->ty == Tclass)
    {
        return ((TypeClass *)t)->sym;
    }
    else if (t->ty == Tstruct)
    {
        return ((TypeStruct *)t)->sym;
    }
    return NULL;
}

/*******************************************
 * Helper function to turn operator into template argument list
 */
Objects *opToArg(Scope *sc, TOK op)
{
    /* Remove the = from op=
     */
    switch (op)
    {
        case TOKaddass: op = TOKadd; break;
        case TOKminass: op = TOKmin; break;
        case TOKmulass: op = TOKmul; break;
        case TOKdivass: op = TOKdiv; break;
        case TOKmodass: op = TOKmod; break;
        case TOKandass: op = TOKand; break;
        case TOKorass:  op = TOKor;  break;
        case TOKxorass: op = TOKxor; break;
        case TOKshlass: op = TOKshl; break;
        case TOKshrass: op = TOKshr; break;
        case TOKushrass: op = TOKushr; break;
        case TOKcatass: op = TOKcat; break;
        case TOKpowass: op = TOKpow; break;
    }
    Expression *e = new StringExp(Loc(), (char *)Token::toChars(op));
    e = e->semantic(sc);
    Objects *tiargs = new Objects();
    tiargs->push(e);
    return tiargs;
}

/************************************
 * Operator overload.
 * Check for operator overload, if so, replace
 * with function call.
 * Return NULL if not an operator overload.
 */

Expression *UnaExp::op_overload(Scope *sc)
{
    //printf("UnaExp::op_overload() (%s)\n", toChars());

    if (e1->op == TOKarray)
    {
        ArrayExp *ae = (ArrayExp *)e1;
        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);

        AggregateDeclaration *ad = isAggregate(ae->e1->type);
        if (ad)
        {
            /* Rewrite as:
             *  a.opIndexUnary!("+")(args);
             */
            Dsymbol *fd = search_function(ad, Id::opIndexUnary);
            if (fd)
            {
                Expression *e0 = resolveOpDollar(sc, ae);
                Objects *tiargs = opToArg(sc, op);
                Expression *e = new DotTemplateInstanceExp(loc, ae->e1, fd->ident, tiargs);
                e = new CallExp(loc, e, ae->arguments);
                e = combine(e0, e);
                e = e->semantic(sc);
                return e;
            }

            // Didn't find it. Forward to aliasthis
            if (ad->aliasthis && ae->e1->type != att1)
            {
                /* Rewrite op(a[arguments]) as:
                 *      op(a.aliasthis[arguments])
                 */
                Expression *e1 = ae->copy();
                ((ArrayExp *)e1)->e1 = new DotIdExp(loc, ae->e1, ad->aliasthis->ident);
                UnaExp *ue = (UnaExp *)copy();
                if (!ue->att1 && ae->e1->type->checkAliasThisRec())
                    ue->att1 = ae->e1->type;
                ue->e1 = e1;
                if (Expression *e = ue->trySemantic(sc))
                    return e;
            }
            att1 = NULL;
        }
    }
    else if (e1->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)e1;
        se->e1 = se->e1->semantic(sc);
        se->e1 = resolveProperties(sc, se->e1);

        AggregateDeclaration *ad = isAggregate(se->e1->type);
        if (ad)
        {
            /* Rewrite as:
             *  a.opSliceUnary!("+")(lwr, upr);
             */
            Dsymbol *fd = search_function(ad, Id::opSliceUnary);
            if (fd)
            {
                Expression *e0 = resolveOpDollar(sc, se);
                Expressions *a = new Expressions();
                assert(!se->lwr || se->upr);
                if (se->lwr)
                {
                    a->push(se->lwr);
                    a->push(se->upr);
                }
                Objects *tiargs = opToArg(sc, op);
                Expression *e = new DotTemplateInstanceExp(loc, se->e1, fd->ident, tiargs);
                e = new CallExp(loc, e, a);
                e = combine(e0, e);
                e = e->semantic(sc);
                return e;
            }

            // Didn't find it. Forward to aliasthis
            if (ad->aliasthis && se->e1->type != att1)
            {
                /* Rewrite op(a[lwr..upr]) as:
                 *      op(a.aliasthis[lwr..upr])
                 */
                Expression *e1 = se->copy();
                ((SliceExp *)e1)->e1 = new DotIdExp(loc, se->e1, ad->aliasthis->ident);
                UnaExp *ue = (UnaExp *)copy();
                if (!ue->att1 && se->e1->type->checkAliasThisRec())
                    ue->att1 = se->e1->type;
                ue->e1 = e1;
                if (Expression *e = ue->trySemantic(sc))
                    return e;
            }
            att1 = NULL;
        }
    }

    e1 = e1->semantic(sc);
    e1 = resolveProperties(sc, e1);

    AggregateDeclaration *ad = isAggregate(e1->type);
    if (ad)
    {
        Dsymbol *fd = NULL;
#if 1 // Old way, kept for compatibility with D1
        if (op != TOKpreplusplus && op != TOKpreminusminus)
        {   fd = search_function(ad, opId());
            if (fd)
            {
                if (op == TOKarray)
                {
                    /* Rewrite op e1[arguments] as:
                     *    e1.fd(arguments)
                     */
                    Expression *e = new DotIdExp(loc, e1, fd->ident);
                    ArrayExp *ae = (ArrayExp *)this;
                    e = new CallExp(loc, e, ae->arguments);
                    e = e->semantic(sc);
                    return e;
                }
                else
                {
                    // Rewrite +e1 as e1.add()
                    return build_overload(loc, sc, e1, NULL, fd);
                }
            }
        }
#endif

        /* Rewrite as:
         *      e1.opUnary!("+")();
         */
        fd = search_function(ad, Id::opUnary);
        if (fd)
        {
            Objects *tiargs = opToArg(sc, op);
            Expression *e = new DotTemplateInstanceExp(loc, e1, fd->ident, tiargs);
            e = new CallExp(loc, e);
            e = e->semantic(sc);
            return e;
        }

        // Didn't find it. Forward to aliasthis
        if (ad->aliasthis && this->e1->type != att1)
        {
            /* Rewrite op(e1) as:
             *  op(e1.aliasthis)
             */
            //printf("att una %s e1 = %s\n", Token::toChars(op), this->e1->type->toChars());
            Expression *e1 = new DotIdExp(loc, this->e1, ad->aliasthis->ident);
            UnaExp *ue = (UnaExp *)copy();
            if (!ue->att1 && this->e1->type->checkAliasThisRec())
                ue->att1 = this->e1->type;
            ue->e1 = e1;
            return ue->trySemantic(sc);
        }
    }
    return NULL;
}

Expression *ArrayExp::op_overload(Scope *sc)
{
    //printf("ArrayExp::op_overload() (%s)\n", toChars());
    AggregateDeclaration *ad = isAggregate(e1->type);
    if (ad)
    {
        Dsymbol *fd = search_function(ad, opId());
        if (fd)
        {
            /* Rewrite op e1[arguments] as:
             *    e1.opIndex(arguments)
             */
            Expression *e0 = resolveOpDollar(sc, this);
            Expression *e = new DotIdExp(loc, e1, fd->ident);
            e = new CallExp(loc, e, arguments);
            e = combine(e0, e);
            e = e->semantic(sc);
            return e;
        }

        // Didn't find it. Forward to aliasthis
        if (ad->aliasthis && this->e1->type != att1)
        {
            /* Rewrite op(e1) as:
             *  op(e1.aliasthis)
             */
            //printf("att arr e1 = %s\n", this->e1->type->toChars());
            Expression *e1 = new DotIdExp(loc, this->e1, ad->aliasthis->ident);
            UnaExp *ue = (UnaExp *)copy();
            if (!ue->att1 && this->e1->type->checkAliasThisRec())
                ue->att1 = this->e1->type;
            ue->e1 = e1;
            return ue->trySemantic(sc);
        }
    }
    return NULL;
}

/***********************************************
 * This is mostly the same as UnaryExp::op_overload(), but has
 * a different rewrite.
 */
Expression *CastExp::op_overload(Scope *sc)
{
    //printf("CastExp::op_overload() (%s)\n", toChars());
    AggregateDeclaration *ad = isAggregate(e1->type);
    if (ad)
    {
        Dsymbol *fd = NULL;
        /* Rewrite as:
         *      e1.opCast!(T)();
         */
        fd = search_function(ad, Id::cast);
        if (fd)
        {
#if 1 // Backwards compatibility with D1 if opCast is a function, not a template
            if (fd->isFuncDeclaration())
            {   // Rewrite as:  e1.opCast()
                return build_overload(loc, sc, e1, NULL, fd);
            }
#endif
            Objects *tiargs = new Objects();
            tiargs->push(to);
            Expression *e = new DotTemplateInstanceExp(loc, e1, fd->ident, tiargs);
            e = new CallExp(loc, e);
            e = e->semantic(sc);
            return e;
        }

        // Didn't find it. Forward to aliasthis
        if (ad->aliasthis)
        {
            /* Rewrite op(e1) as:
             *  op(e1.aliasthis)
             */
            Expression *e1 = new DotIdExp(loc, this->e1, ad->aliasthis->ident);
            Expression *e = copy();
            ((UnaExp *)e)->e1 = e1;
            e = e->trySemantic(sc);
            return e;
        }
    }
    return NULL;
}

Expression *BinExp::op_overload(Scope *sc)
{
    //printf("BinExp::op_overload() (%s)\n", toChars());

    Identifier *id = opId();
    Identifier *id_r = opId_r();

    Expressions args1;
    Expressions args2;
    int argsset = 0;

    AggregateDeclaration *ad1 = isAggregate(e1->type);
    AggregateDeclaration *ad2 = isAggregate(e2->type);

    if (op == TOKassign && ad1 == ad2)
    {
        StructDeclaration *sd = ad1->isStructDeclaration();
        if (sd && !sd->hasIdentityAssign)
        {   /* This is bitwise struct assignment. */
            return NULL;
        }
    }

    Dsymbol *s = NULL;
    Dsymbol *s_r = NULL;

#if 1 // the old D1 scheme
    if (ad1 && id)
    {
        s = search_function(ad1, id);
    }
    if (ad2 && id_r)
    {
        s_r = search_function(ad2, id_r);
    }
#endif

    Objects *tiargs = NULL;
    if (op == TOKplusplus || op == TOKminusminus)
    {   // Bug4099 fix
        if (ad1 && search_function(ad1, Id::opUnary))
            return NULL;
    }
    if (!s && !s_r && op != TOKequal && op != TOKnotequal && op != TOKassign &&
        op != TOKplusplus && op != TOKminusminus)
    {
        /* Try the new D2 scheme, opBinary and opBinaryRight
         */
        if (ad1)
        {
            s = search_function(ad1, Id::opBinary);
            if (s && !s->isTemplateDeclaration())
            {   e1->error("%s.opBinary isn't a template", e1->toChars());
                return new ErrorExp();
            }
        }
        if (ad2)
        {
            s_r = search_function(ad2, Id::opBinaryRight);
            if (s_r && !s_r->isTemplateDeclaration())
            {   e2->error("%s.opBinaryRight isn't a template", e2->toChars());
                return new ErrorExp();
            }
        }

        // Set tiargs, the template argument list, which will be the operator string
        if (s || s_r)
        {
            id = Id::opBinary;
            id_r = Id::opBinaryRight;
            tiargs = opToArg(sc, op);
        }
    }

    if (s || s_r)
    {
        /* Try:
         *      a.opfunc(b)
         *      b.opfunc_r(a)
         * and see which is better.
         */

        args1.setDim(1);
        args1[0] = e1;
        expandTuples(&args1);
        args2.setDim(1);
        args2[0] = e2;
        expandTuples(&args2);
        argsset = 1;

        Match m;
        memset(&m, 0, sizeof(m));
        m.last = MATCHnomatch;

        if (s)
            functionResolve(&m, s, loc, sc, tiargs, e1->type, &args2);

        FuncDeclaration *lastf = m.lastf;

        if (s_r)
            functionResolve(&m, s_r, loc, sc, tiargs, e2->type, &args1);

        if (m.count > 1)
        {
            // Error, ambiguous
            error("overloads %s and %s both match argument list for %s",
                    m.lastf->type->toChars(),
                    m.nextf->type->toChars(),
                    m.lastf->toChars());
        }
        else if (m.last == MATCHnomatch)
        {
            m.lastf = m.anyf;
            if (tiargs)
                goto L1;
        }

        Expression *e;
        if (op == TOKplusplus || op == TOKminusminus)
            // Kludge because operator overloading regards e++ and e--
            // as unary, but it's implemented as a binary.
            // Rewrite (e1 ++ e2) as e1.postinc()
            // Rewrite (e1 -- e2) as e1.postdec()
            e = build_overload(loc, sc, e1, NULL, m.lastf ? m.lastf : s);
        else if (lastf && m.lastf == lastf || !s_r && m.last == MATCHnomatch)
            // Rewrite (e1 op e2) as e1.opfunc(e2)
            e = build_overload(loc, sc, e1, e2, m.lastf ? m.lastf : s);
        else
            // Rewrite (e1 op e2) as e2.opfunc_r(e1)
            e = build_overload(loc, sc, e2, e1, m.lastf ? m.lastf : s_r);
        return e;
    }

L1:
#if 1 // Retained for D1 compatibility
    if (isCommutative() && !tiargs)
    {
        s = NULL;
        s_r = NULL;
        if (ad1 && id_r)
        {
            s_r = search_function(ad1, id_r);
        }
        if (ad2 && id)
        {
            s = search_function(ad2, id);
        }

        if (s || s_r)
        {
            /* Try:
             *  a.opfunc_r(b)
             *  b.opfunc(a)
             * and see which is better.
             */

            if (!argsset)
            {
                args1.setDim(1);
                args1[0] = e1;
                expandTuples(&args1);
                args2.setDim(1);
                args2[0] = e2;
                expandTuples(&args2);
            }

            Match m;
            memset(&m, 0, sizeof(m));
            m.last = MATCHnomatch;

            if (s_r)
                functionResolve(&m, s_r, loc, sc, tiargs, e1->type, &args2);

            FuncDeclaration *lastf = m.lastf;

            if (s)
                functionResolve(&m, s, loc, sc, tiargs, e2->type, &args1);

            if (m.count > 1)
            {
                // Error, ambiguous
                error("overloads %s and %s both match argument list for %s",
                        m.lastf->type->toChars(),
                        m.nextf->type->toChars(),
                        m.lastf->toChars());
            }
            else if (m.last == MATCHnomatch)
            {
                m.lastf = m.anyf;
            }

            Expression *e;
            if (lastf && m.lastf == lastf || !s && m.last == MATCHnomatch)
                // Rewrite (e1 op e2) as e1.opfunc_r(e2)
                e = build_overload(loc, sc, e1, e2, m.lastf ? m.lastf : s_r);
            else
                // Rewrite (e1 op e2) as e2.opfunc(e1)
                e = build_overload(loc, sc, e2, e1, m.lastf ? m.lastf : s);

            // When reversing operands of comparison operators,
            // need to reverse the sense of the op
            switch (op)
            {
                case TOKlt:     op = TOKgt;     break;
                case TOKgt:     op = TOKlt;     break;
                case TOKle:     op = TOKge;     break;
                case TOKge:     op = TOKle;     break;

                // Floating point compares
                case TOKule:    op = TOKuge;     break;
                case TOKul:     op = TOKug;      break;
                case TOKuge:    op = TOKule;     break;
                case TOKug:     op = TOKul;      break;

                // These are symmetric
                case TOKunord:
                case TOKlg:
                case TOKleg:
                case TOKue:
                    break;
            }

            return e;
        }
    }
#endif

    // Try alias this on first operand
    if (ad1 && ad1->aliasthis &&
        !(op == TOKassign && ad2 && ad1 == ad2))   // See Bugzilla 2943
    {
        /* Rewrite (e1 op e2) as:
         *      (e1.aliasthis op e2)
         */
        if (att1 && this->e1->type == att1)
            return NULL;
        //printf("att bin e1 = %s\n", this->e1->type->toChars());
        Expression *e1 = new DotIdExp(loc, this->e1, ad1->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att1 && this->e1->type->checkAliasThisRec())
            be->att1 = this->e1->type;
        be->e1 = e1;
        return be->trySemantic(sc);
    }

    // Try alias this on second operand
    if (ad2 && ad2->aliasthis &&
        /* Bugzilla 2943: make sure that when we're copying the struct, we don't
         * just copy the alias this member
         */
        !(op == TOKassign && ad1 && ad1 == ad2))
    {
        /* Rewrite (e1 op e2) as:
         *      (e1 op e2.aliasthis)
         */
        if (att2 && this->e2->type == att2)
            return NULL;
        //printf("att bin e2 = %s\n", this->e2->type->toChars());
        Expression *e2 = new DotIdExp(loc, this->e2, ad2->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att2 && this->e2->type->checkAliasThisRec())
            be->att2 = this->e2->type;
        be->e2 = e2;
        return be->trySemantic(sc);
    }
    return NULL;
}

/******************************************
 * Common code for overloading of EqualExp and CmpExp
 */
Expression *BinExp::compare_overload(Scope *sc, Identifier *id)
{
    //printf("BinExp::compare_overload(id = %s) %s\n", id->toChars(), toChars());

    AggregateDeclaration *ad1 = isAggregate(e1->type);
    AggregateDeclaration *ad2 = isAggregate(e2->type);

    Dsymbol *s = NULL;
    Dsymbol *s_r = NULL;

    if (ad1)
    {
        s = search_function(ad1, id);
    }
    if (ad2)
    {
        s_r = search_function(ad2, id);
        if (s == s_r)
            s_r = NULL;
    }

    Objects *tiargs = NULL;

    if (s || s_r)
    {
        /* Try:
         *      a.opEquals(b)
         *      b.opEquals(a)
         * and see which is better.
         */

        Expressions args1;
        Expressions args2;

        args1.setDim(1);
        args1[0] = e1;
        expandTuples(&args1);
        args2.setDim(1);
        args2[0] = e2;
        expandTuples(&args2);

        Match m;
        memset(&m, 0, sizeof(m));
        m.last = MATCHnomatch;

        if (0 && s && s_r)
        {
            printf("s  : %s\n", s->toPrettyChars());
            printf("s_r: %s\n", s_r->toPrettyChars());
        }

        if (s)
            functionResolve(&m, s, loc, sc, tiargs, e1->type, &args2);

        FuncDeclaration *lastf = m.lastf;
        int count = m.count;

        if (s_r)
            functionResolve(&m, s_r, loc, sc, tiargs, e2->type, &args1);

        if (m.count > 1)
        {
            /* The following if says "not ambiguous" if there's one match
             * from s and one from s_r, in which case we pick s.
             * This doesn't follow the spec, but is a workaround for the case
             * where opEquals was generated from templates and we cannot figure
             * out if both s and s_r came from the same declaration or not.
             * The test case is:
             *   import std.typecons;
             *   void main() {
             *    assert(tuple("has a", 2u) == tuple("has a", 1));
             *   }
             */
            if (!(m.lastf == lastf && m.count == 2 && count == 1))
            {
                // Error, ambiguous
                error("overloads %s and %s both match argument list for %s",
                    m.lastf->type->toChars(),
                    m.nextf->type->toChars(),
                    m.lastf->toChars());
            }
        }
        else if (m.last == MATCHnomatch)
        {
            m.lastf = m.anyf;
        }

        Expression *e;
        if (lastf && m.lastf == lastf || !s_r && m.last == MATCHnomatch)
            // Rewrite (e1 op e2) as e1.opfunc(e2)
            e = build_overload(loc, sc, e1, e2, m.lastf ? m.lastf : s);
        else
        {   // Rewrite (e1 op e2) as e2.opfunc_r(e1)
            e = build_overload(loc, sc, e2, e1, m.lastf ? m.lastf : s_r);

            // When reversing operands of comparison operators,
            // need to reverse the sense of the op
            switch (op)
            {
                case TOKlt:     op = TOKgt;     break;
                case TOKgt:     op = TOKlt;     break;
                case TOKle:     op = TOKge;     break;
                case TOKge:     op = TOKle;     break;

                // Floating point compares
                case TOKule:    op = TOKuge;     break;
                case TOKul:     op = TOKug;      break;
                case TOKuge:    op = TOKule;     break;
                case TOKug:     op = TOKul;      break;

                // The rest are symmetric
                default:
                    break;
            }
        }

        return e;
    }

    // Try alias this on first operand
    if (ad1 && ad1->aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1.aliasthis op e2)
         */
        if (att1 && this->e1->type == att1)
            return NULL;
        //printf("att cmp_bin e1 = %s\n", this->e1->type->toChars());
        Expression *e1 = new DotIdExp(loc, this->e1, ad1->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att1 && this->e1->type->checkAliasThisRec())
            be->att1 = this->e1->type;
        be->e1 = e1;
        return be->trySemantic(sc);
    }

    // Try alias this on second operand
    if (ad2 && ad2->aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1 op e2.aliasthis)
         */
        if (att2 && this->e2->type == att2)
            return NULL;
        //printf("att cmp_bin e2 = %s\n", this->e2->type->toChars());
        Expression *e2 = new DotIdExp(loc, this->e2, ad2->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att2 && this->e2->type->checkAliasThisRec())
            be->att2 = this->e2->type;
        be->e2 = e2;
        return be->trySemantic(sc);
    }

    return NULL;
}

Expression *EqualExp::op_overload(Scope *sc)
{
    //printf("EqualExp::op_overload() (%s)\n", toChars());

    Type *t1 = e1->type->toBasetype();
    Type *t2 = e2->type->toBasetype();
    if (t1->ty == Tclass && t2->ty == Tclass)
    {   ClassDeclaration *cd1 = t1->isClassHandle();
        ClassDeclaration *cd2 = t2->isClassHandle();

        if (!(cd1->cpp || cd2->cpp))
        {
            /* Rewrite as:
             *      .object.opEquals(e1, e2)
             */
            Expression *e1x = e1;
            Expression *e2x = e2;

            /*
             * The explicit cast is necessary for interfaces,
             * see http://d.puremagic.com/issues/show_bug.cgi?id=4088
             */
            Type *to = ClassDeclaration::object->getType();
            if (cd1->isInterfaceDeclaration())
                e1x = new CastExp(loc, e1, t1->isMutable() ? to : to->constOf());
            if (cd2->isInterfaceDeclaration())
                e2x = new CastExp(loc, e2, t2->isMutable() ? to : to->constOf());

            Expression *e = new IdentifierExp(loc, Id::empty);
            e = new DotIdExp(loc, e, Id::object);
            e = new DotIdExp(loc, e, Id::eq);
            e = new CallExp(loc, e, e1x, e2x);
            e = e->semantic(sc);
            return e;
        }
    }

    return compare_overload(sc, Id::eq);
}

Expression *CmpExp::op_overload(Scope *sc)
{
    //printf("CmpExp::op_overload() (%s)\n", toChars());

    return compare_overload(sc, Id::cmp);
}

/*********************************
 * Operator overloading for op=
 */
Expression *BinAssignExp::op_overload(Scope *sc)
{
    //printf("BinAssignExp::op_overload() (%s)\n", toChars());

    if (e1->op == TOKarray)
    {
        ArrayExp *ae = (ArrayExp *)e1;
        ae->e1 = ae->e1->semantic(sc);
        ae->e1 = resolveProperties(sc, ae->e1);

        AggregateDeclaration *ad = isAggregate(ae->e1->type);
        if (ad)
        {
            /* Rewrite a[args]+=e2 as:
             *  a.opIndexOpAssign!("+")(e2, args);
             */
            Dsymbol *fd = search_function(ad, Id::opIndexOpAssign);
            if (fd)
            {
                Expression *e0 = resolveOpDollar(sc, ae);
                Expressions *a = (Expressions *)ae->arguments->copy();
                a->insert(0, e2);

                Objects *tiargs = opToArg(sc, op);
                Expression *e = new DotTemplateInstanceExp(loc, ae->e1, fd->ident, tiargs);
                e = new CallExp(loc, e, a);
                e = combine(e0, e);
                e = e->semantic(sc);
                return e;
            }

            // Didn't find it. Forward to aliasthis
            if (ad->aliasthis && ae->e1->type != att1)
            {
                /* Rewrite a[arguments] op= e2 as:
                 *      a.aliasthis[arguments] op= e2
                 */
                Expression *e1 = ae->copy();
                ((ArrayExp *)e1)->e1 = new DotIdExp(loc, ae->e1, ad->aliasthis->ident);
                BinExp *be = (BinExp *)copy();
                if (!be->att1 && ae->e1->type->checkAliasThisRec())
                    be->att1 = ae->e1->type;
                be->e1 = e1;
                if (Expression *e = be->trySemantic(sc))
                    return e;
            }
            att1 = NULL;
        }
    }
    else if (e1->op == TOKslice)
    {
        SliceExp *se = (SliceExp *)e1;
        se->e1 = se->e1->semantic(sc);
        se->e1 = resolveProperties(sc, se->e1);

        AggregateDeclaration *ad = isAggregate(se->e1->type);
        if (ad)
        {
            /* Rewrite a[lwr..upr]+=e2 as:
             *  a.opSliceOpAssign!("+")(e2, lwr, upr);
             */
            Dsymbol *fd = search_function(ad, Id::opSliceOpAssign);
            if (fd)
            {
                Expression *e0 = resolveOpDollar(sc, se);
                Expressions *a = new Expressions();
                a->push(e2);
                assert(!se->lwr || se->upr);
                if (se->lwr)
                {
                    a->push(se->lwr);
                    a->push(se->upr);
                }

                Objects *tiargs = opToArg(sc, op);
                Expression *e = new DotTemplateInstanceExp(loc, se->e1, fd->ident, tiargs);
                e = new CallExp(loc, e, a);
                e = combine(e0, e);
                e = e->semantic(sc);
                return e;
            }

            // Didn't find it. Forward to aliasthis
            if (ad->aliasthis && se->e1->type != att1)
            {
                /* Rewrite a[lwr..upr] op= e2 as:
                 *      a.aliasthis[lwr..upr] op= e2
                 */
                Expression *e1 = se->copy();
                ((SliceExp *)e1)->e1 = new DotIdExp(loc, se->e1, ad->aliasthis->ident);
                BinExp *be = (BinExp *)copy();
                if (!be->att1 && se->e1->type->checkAliasThisRec())
                    be->att1 = se->e1->type;
                be->e1 = e1;
                if (Expression *e = be->trySemantic(sc))
                    return e;
            }
            att1 = NULL;
        }
    }

    BinExp::semantic(sc);
    e1 = resolveProperties(sc, e1);
    e2 = resolveProperties(sc, e2);

    // Don't attempt 'alias this' if an error occured
    if (e1->type->ty == Terror || e2->type->ty == Terror)
        return new ErrorExp();

    Identifier *id = opId();

    Expressions args2;

    AggregateDeclaration *ad1 = isAggregate(e1->type);

    Dsymbol *s = NULL;

#if 1 // the old D1 scheme
    if (ad1 && id)
    {
        s = search_function(ad1, id);
    }
#endif

    Objects *tiargs = NULL;
    if (!s)
    {   /* Try the new D2 scheme, opOpAssign
         */
        if (ad1)
        {
            s = search_function(ad1, Id::opOpAssign);
            if (s && !s->isTemplateDeclaration())
            {   error("%s.opOpAssign isn't a template", e1->toChars());
                return new ErrorExp();
            }
        }

        // Set tiargs, the template argument list, which will be the operator string
        if (s)
        {
            id = Id::opOpAssign;
            tiargs = opToArg(sc, op);
        }
    }

    if (s)
    {
        /* Try:
         *      a.opOpAssign(b)
         */

        args2.setDim(1);
        args2[0] = e2;
        expandTuples(&args2);

        Match m;
        memset(&m, 0, sizeof(m));
        m.last = MATCHnomatch;

        if (s)
            functionResolve(&m, s, loc, sc, tiargs, e1->type, &args2);

        if (m.count > 1)
        {
            // Error, ambiguous
            error("overloads %s and %s both match argument list for %s",
                    m.lastf->type->toChars(),
                    m.nextf->type->toChars(),
                    m.lastf->toChars());
        }
        else if (m.last == MATCHnomatch)
        {
            m.lastf = m.anyf;
            if (tiargs)
                goto L1;
        }

        // Rewrite (e1 op e2) as e1.opOpAssign(e2)
        return build_overload(loc, sc, e1, e2, m.lastf ? m.lastf : s);
    }

L1:

    // Try alias this on first operand
    if (ad1 && ad1->aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1.aliasthis op e2)
         */
        if (att1 && this->e1->type == att1)
            return NULL;
        //printf("att %s e1 = %s\n", Token::toChars(op), this->e1->type->toChars());
        Expression *e1 = new DotIdExp(loc, this->e1, ad1->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att1 && this->e1->type->checkAliasThisRec())
            be->att1 = this->e1->type;
        be->e1 = e1;
        return be->trySemantic(sc);
    }

    // Try alias this on second operand
    AggregateDeclaration *ad2 = isAggregate(e2->type);
    if (ad2 && ad2->aliasthis)
    {
        /* Rewrite (e1 op e2) as:
         *      (e1 op e2.aliasthis)
         */
        if (att2 && this->e2->type == att2)
            return NULL;
        //printf("att %s e2 = %s\n", Token::toChars(op), this->e2->type->toChars());
        Expression *e2 = new DotIdExp(loc, this->e2, ad2->aliasthis->ident);
        BinExp *be = (BinExp *)copy();
        if (!be->att2 && this->e2->type->checkAliasThisRec())
            be->att2 = this->e2->type;
        be->e2 = e2;
        return be->trySemantic(sc);
    }
    return NULL;
}

/***********************************
 * Utility to build a function call out of this reference and argument.
 */

Expression *build_overload(Loc loc, Scope *sc, Expression *ethis, Expression *earg,
        Dsymbol *d)
{
    assert(d);
    Expression *e;

    //printf("build_overload(id = '%s')\n", id->toChars());
    //earg->print();
    //earg->type->print();
    Declaration *decl = d->isDeclaration();
    if (decl)
        e = new DotVarExp(loc, ethis, decl, 0);
    else
        e = new DotIdExp(loc, ethis, d->ident);
    e = new CallExp(loc, e, earg);

    e = e->semantic(sc);
    return e;
}

/***************************************
 * Search for function funcid in aggregate ad.
 */

Dsymbol *search_function(ScopeDsymbol *ad, Identifier *funcid)
{
    Dsymbol *s;
    FuncDeclaration *fd;
    TemplateDeclaration *td;

    s = ad->search(Loc(), funcid, 0);
    if (s)
    {   Dsymbol *s2;

        //printf("search_function: s = '%s'\n", s->kind());
        s2 = s->toAlias();
        //printf("search_function: s2 = '%s'\n", s2->kind());
        fd = s2->isFuncDeclaration();
        if (fd && fd->type->ty == Tfunction)
            return fd;

        td = s2->isTemplateDeclaration();
        if (td)
            return td;
    }
    return NULL;
}


int ForeachStatement::inferAggregate(Scope *sc, Dsymbol *&sapply)
{
    Identifier *idapply = (op == TOKforeach) ? Id::apply : Id::applyReverse;
    Identifier *idfront = (op == TOKforeach) ? Id::Ffront : Id::Fback;
    int sliced = 0;
    Type *tab;
    Type *att = NULL;
    Expression *org_aggr = aggr;
    AggregateDeclaration *ad;

    while (1)
    {
        aggr = aggr->semantic(sc);
        aggr = resolveProperties(sc, aggr);
        aggr = aggr->optimize(WANTvalue);
        if (!aggr->type)
            goto Lerr;

        tab = aggr->type->toBasetype();
        if (att == tab)
        {   aggr = org_aggr;
            goto Lerr;
        }
        switch (tab->ty)
        {
            case Tarray:
            case Tsarray:
            case Ttuple:
            case Taarray:
                break;

            case Tclass:
                ad = ((TypeClass *)tab)->sym;
                goto Laggr;

            case Tstruct:
                ad = ((TypeStruct *)tab)->sym;
                goto Laggr;

            Laggr:
                if (!sliced)
                {
                    sapply = search_function(ad, idapply);
                    if (sapply)
                    {   // opApply aggregate
                        break;
                    }

                    Dsymbol *s = search_function(ad, Id::slice);
                    if (s)
                    {   Expression *rinit = new SliceExp(aggr->loc, aggr, NULL, NULL);
                        rinit = rinit->trySemantic(sc);
                        if (rinit)                  // if application of [] succeeded
                        {   aggr = rinit;
                            sliced = 1;
                            continue;
                        }
                    }
                }

                if (Dsymbol *shead = ad->search(Loc(), idfront, 0))
                {   // range aggregate
                    break;
                }

                if (ad->aliasthis)
                {
                    if (!att && tab->checkAliasThisRec())
                        att = tab;
                    aggr = new DotIdExp(aggr->loc, aggr, ad->aliasthis->ident);
                    continue;
                }
                goto Lerr;

            case Tdelegate:
                if (aggr->op == TOKdelegate)
                {   DelegateExp *de = (DelegateExp *)aggr;
                    sapply = de->func->isFuncDeclaration();
                }
                break;

            case Terror:
                break;

            default:
                goto Lerr;
        }
        break;
    }
    return 1;

Lerr:
    return 0;
}

/*****************************************
 * Given array of arguments and an aggregate type,
 * if any of the argument types are missing, attempt to infer
 * them from the aggregate type.
 */

int ForeachStatement::inferApplyArgTypes(Scope *sc, Dsymbol *&sapply)
{
    if (!arguments || !arguments->dim)
        return 0;

    if (sapply)     // prefer opApply
    {
        for (size_t u = 0; u < arguments->dim; u++)
        {   Parameter *arg = (*arguments)[u];
            if (arg->type)
            {
                arg->type = arg->type->semantic(loc, sc);
                arg->type = arg->type->addStorageClass(arg->storageClass);
            }
        }

        Expression *ethis;
        Type *tab = aggr->type->toBasetype();
        if (tab->ty == Tclass || tab->ty == Tstruct)
            ethis = aggr;
        else
        {   assert(tab->ty == Tdelegate && aggr->op == TOKdelegate);
            ethis = ((DelegateExp *)aggr)->e1;
        }

        /* Look for like an
         *  int opApply(int delegate(ref Type [, ...]) dg);
         * overload
         */
        FuncDeclaration *fd = sapply->isFuncDeclaration();
        if (fd)
        {   sapply = inferApplyArgTypesX(ethis, fd, arguments);
        }
#if 0
        TemplateDeclaration *td = sapply->isTemplateDeclaration();
        if (td)
        {   inferApplyArgTypesZ(td, arguments);
        }
#endif
        return sapply ? 1 : 0;
    }

    /* Return if no arguments need types.
     */
    for (size_t u = 0; u < arguments->dim; u++)
    {   Parameter *arg = (*arguments)[u];
        if (!arg->type)
            break;
    }

    AggregateDeclaration *ad;

    Parameter *arg = (*arguments)[0];
    Type *taggr = aggr->type;
    assert(taggr);
    Type *tab = taggr->toBasetype();
    switch (tab->ty)
    {
        case Tarray:
        case Tsarray:
        case Ttuple:
            if (arguments->dim == 2)
            {
                if (!arg->type)
                {
                    arg->type = Type::tsize_t;  // key type
                    arg->type = arg->type->addStorageClass(arg->storageClass);
                }
                arg = (*arguments)[1];
            }
            if (!arg->type && tab->ty != Ttuple)
            {
                arg->type = tab->nextOf();      // value type
                arg->type = arg->type->addStorageClass(arg->storageClass);
            }
            break;

        case Taarray:
        {   TypeAArray *taa = (TypeAArray *)tab;

            if (arguments->dim == 2)
            {
                if (!arg->type)
                {
                    arg->type = taa->index;     // key type
                    arg->type = arg->type->addStorageClass(arg->storageClass);
                }
                arg = (*arguments)[1];
            }
            if (!arg->type)
            {
                arg->type = taa->next;          // value type
                arg->type = arg->type->addStorageClass(arg->storageClass);
            }
            break;
        }

        case Tclass:
            ad = ((TypeClass *)tab)->sym;
            goto Laggr;

        case Tstruct:
            ad = ((TypeStruct *)tab)->sym;
            goto Laggr;

        Laggr:
            if (arguments->dim == 1)
            {
                if (!arg->type)
                {
                    /* Look for a front() or back() overload
                     */
                    Identifier *id = (op == TOKforeach) ? Id::Ffront : Id::Fback;
                    Dsymbol *s = ad->search(Loc(), id, 0);
                    FuncDeclaration *fd = s ? s->isFuncDeclaration() : NULL;
                    if (fd)
                    {
                        // Resolve inout qualifier of front type
                        arg->type = fd->type->nextOf();
                        if (arg->type)
                        {
                            arg->type = arg->type->substWildTo(tab->mod);
                            arg->type = arg->type->addStorageClass(arg->storageClass);
                        }
                    }
                    else if (s && s->isTemplateDeclaration())
                        ;
                    else if (s && s->isDeclaration())
                        arg->type = ((Declaration *)s)->type;
                    else
                        break;
                }
                break;
            }
            break;

        case Tdelegate:
        {
            if (!inferApplyArgTypesY((TypeFunction *)tab->nextOf(), arguments))
                return 0;
            break;
        }

        default:
            break;              // ignore error, caught later
    }
    return 1;
}

static Dsymbol *inferApplyArgTypesX(Expression *ethis, FuncDeclaration *fstart, Parameters *arguments)
{
  struct ParamOpOver
  {
    Parameters *arguments;
    unsigned char mod;
    MATCH match;
    FuncDeclaration *fd_best;
    FuncDeclaration *fd_ambig;

    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f)
            return 0;
        ParamOpOver *p = (ParamOpOver *)param;
        TypeFunction *tf = (TypeFunction *)f->type;
        MATCH m = MATCHexact;

        if (f->isThis())
        {
            if (!MODimplicitConv(p->mod, tf->mod))
                m = MATCHnomatch;
            else if (p->mod != tf->mod)
                m = MATCHconst;
        }
        if (!inferApplyArgTypesY(tf, p->arguments, 1))
            m = MATCHnomatch;

        if (m > p->match)
        {
            p->fd_best = f;
            p->fd_ambig = NULL;
            p->match = m;
        }
        else if (m == p->match)
            p->fd_ambig = f;
        return 0;
    }
  };
    ParamOpOver p;
    p.arguments = arguments;
    p.mod = ethis->type->mod;
    p.match = MATCHnomatch;
    p.fd_best = NULL;
    p.fd_ambig = NULL;
    overloadApply(fstart, &p, &ParamOpOver::fp);
    if (p.fd_best)
    {
        inferApplyArgTypesY((TypeFunction *)p.fd_best->type, arguments);
        if (p.fd_ambig)
        {   ::error(ethis->loc, "%s.%s matches more than one declaration:\n\t%s(%d):%s\nand:\n\t%s(%d):%s",
                    ethis->toChars(), fstart->ident->toChars(),
                    p.fd_best ->loc.filename, p.fd_best ->loc.linnum, p.fd_best ->type->toChars(),
                    p.fd_ambig->loc.filename, p.fd_ambig->loc.linnum, p.fd_ambig->type->toChars());
            p.fd_best = NULL;
        }
    }
    return p.fd_best;
}

/******************************
 * Infer arguments from type of function.
 * Returns:
 *      1 match for this function
 *      0 no match for this function
 */

static int inferApplyArgTypesY(TypeFunction *tf, Parameters *arguments, int flags)
{   size_t nparams;
    Parameter *p;

    if (Parameter::dim(tf->parameters) != 1)
        goto Lnomatch;
    p = Parameter::getNth(tf->parameters, 0);
    if (p->type->ty != Tdelegate)
        goto Lnomatch;
    tf = (TypeFunction *)p->type->nextOf();
    assert(tf->ty == Tfunction);

    /* We now have tf, the type of the delegate. Match it against
     * the arguments, filling in missing argument types.
     */
    nparams = Parameter::dim(tf->parameters);
    if (nparams == 0 || tf->varargs)
        goto Lnomatch;          // not enough parameters
    if (arguments->dim != nparams)
        goto Lnomatch;          // not enough parameters

    for (size_t u = 0; u < nparams; u++)
    {
        Parameter *arg = (*arguments)[u];
        Parameter *param = Parameter::getNth(tf->parameters, u);
        if (arg->type)
        {   if (!arg->type->equals(param->type))
                goto Lnomatch;
        }
        else if (!flags)
        {
            arg->type = param->type;
            arg->type = arg->type->addStorageClass(arg->storageClass);
        }
    }
Lmatch:
    return 1;

Lnomatch:
    return 0;
}

/*******************************************
 * Infer foreach arg types from a template function opApply which looks like:
 *    int opApply(alias int func(ref uint))() { ... }
 */

#if 0
void inferApplyArgTypesZ(TemplateDeclaration *tstart, Parameters *arguments)
{
    for (TemplateDeclaration *td = tstart; td; td = td->overnext)
    {
        if (!td->scope)
        {
            error("forward reference to template %s", td->toChars());
            return;
        }
        if (!td->onemember || !td->onemember->toAlias()->isFuncDeclaration())
        {
            error("is not a function template");
            return;
        }
        if (!td->parameters || td->parameters->dim != 1)
            continue;
        TemplateParameter *tp = (*td->parameters)[0];
        TemplateAliasParameter *tap = tp->isTemplateAliasParameter();
        if (!tap || !tap->specType || tap->specType->ty != Tfunction)
            continue;
        TypeFunction *tf = (TypeFunction *)tap->specType;
        if (inferApplyArgTypesY(tf, arguments) == 0)    // found it
            return;
    }
}
#endif
