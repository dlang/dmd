// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.sideeffect;

import ddmd.apply, ddmd.declaration, ddmd.expression, ddmd.func, ddmd.globals, ddmd.mtype, ddmd.tokens, ddmd.visitor;

/**************************************************
 * Front-end expression rewriting should create temporary variables for
 * non trivial sub-expressions in order to:
 *  1. save evaluation order
 *  2. prevent sharing of sub-expression in AST
 */
extern (C++) bool isTrivialExp(Expression e)
{
    extern (C++) final class IsTrivialExp : StoppableVisitor
    {
        alias visit = super.visit;
    public:
        extern (D) this()
        {
        }

        void visit(Expression e)
        {
            /* Bugzilla 11201: CallExp is always non trivial expression,
             * especially for inlining.
             */
            if (e.op == TOKcall)
            {
                stop = true;
                return;
            }
            // stop walking if we determine this expression has side effects
            stop = lambdaHasSideEffect(e);
        }
    }

    scope IsTrivialExp v = new IsTrivialExp();
    return walkPostorder(e, v) == false;
}

/********************************************
 * Determine if Expression has any side effects.
 */
extern (C++) bool hasSideEffect(Expression e)
{
    extern (C++) final class LambdaHasSideEffect : StoppableVisitor
    {
        alias visit = super.visit;
    public:
        extern (D) this()
        {
        }

        void visit(Expression e)
        {
            // stop walking if we determine this expression has side effects
            stop = lambdaHasSideEffect(e);
        }
    }

    scope LambdaHasSideEffect v = new LambdaHasSideEffect();
    return walkPostorder(e, v);
}

/********************************************
 * Determine if the call of f, or function type or delegate type t1, has any side effects.
 * Returns:
 *      0   has any side effects
 *      1   nothrow + constant purity
 *      2   nothrow + strong purity
 */
extern (C++) int callSideEffectLevel(FuncDeclaration f)
{
    /* Bugzilla 12760: ctor call always has side effects.
     */
    if (f.isCtorDeclaration())
        return 0;
    assert(f.type.ty == Tfunction);
    TypeFunction tf = cast(TypeFunction)f.type;
    if (tf.isnothrow)
    {
        PURE purity = f.isPure();
        if (purity == PUREstrong)
            return 2;
        if (purity == PUREconst)
            return 1;
    }
    return 0;
}

extern (C++) int callSideEffectLevel(Type t)
{
    t = t.toBasetype();
    TypeFunction tf;
    if (t.ty == Tdelegate)
        tf = cast(TypeFunction)(cast(TypeDelegate)t).next;
    else
    {
        assert(t.ty == Tfunction);
        tf = cast(TypeFunction)t;
    }
    tf.purityLevel();
    PURE purity = tf.purity;
    if (t.ty == Tdelegate && purity > PUREweak)
    {
        if (tf.isMutable())
            purity = PUREweak;
        else if (!tf.isImmutable())
            purity = PUREconst;
    }
    if (tf.isnothrow)
    {
        if (purity == PUREstrong)
            return 2;
        if (purity == PUREconst)
            return 1;
    }
    return 0;
}

extern (C++) bool lambdaHasSideEffect(Expression e)
{
    switch (e.op)
    {
        // Sort the cases by most frequently used first
    case TOKassign:
    case TOKplusplus:
    case TOKminusminus:
    case TOKdeclaration:
    case TOKconstruct:
    case TOKblit:
    case TOKaddass:
    case TOKminass:
    case TOKcatass:
    case TOKmulass:
    case TOKdivass:
    case TOKmodass:
    case TOKshlass:
    case TOKshrass:
    case TOKushrass:
    case TOKandass:
    case TOKorass:
    case TOKxorass:
    case TOKpowass:
    case TOKin:
    case TOKremove:
    case TOKassert:
    case TOKhalt:
    case TOKdelete:
    case TOKnew:
    case TOKnewanonclass:
        return true;
    case TOKcall:
        {
            CallExp ce = cast(CallExp)e;
            /* Calling a function or delegate that is pure nothrow
             * has no side effects.
             */
            if (ce.e1.type)
            {
                Type t = ce.e1.type.toBasetype();
                if (t.ty == Tdelegate)
                    t = (cast(TypeDelegate)t).next;
                if (t.ty == Tfunction && (ce.f ? callSideEffectLevel(ce.f) : callSideEffectLevel(ce.e1.type)) > 0)
                {
                }
                else
                    return true;
            }
            break;
        }
    case TOKcast:
        {
            CastExp ce = cast(CastExp)e;
            /* if:
             *  cast(classtype)func()  // because it may throw
             */
            if (ce.to.ty == Tclass && ce.e1.op == TOKcall && ce.e1.type.ty == Tclass)
                return true;
            break;
        }
    default:
        break;
    }
    return false;
}

/***********************************
 * The result of this expression will be discarded.
 * Complain if the operation has no side effects (and hence is meaningless).
 */
extern (C++) void discardValue(Expression e)
{
    if (lambdaHasSideEffect(e)) // check side-effect shallowly
        return;
    switch (e.op)
    {
    case TOKcast:
        {
            CastExp ce = cast(CastExp)e;
            if (ce.to.equals(Type.tvoid))
            {
                /*
                 * Don't complain about an expression with no effect if it was cast to void
                 */
                return;
            }
            break;
            // complain
        }
    case TOKerror:
        return;
    case TOKvar:
        {
            VarDeclaration v = (cast(VarExp)e).var.isVarDeclaration();
            if (v && (v.storage_class & STCtemp))
            {
                // Bugzilla 5810: Don't complain about an internal generated variable.
                return;
            }
            break;
        }
    case TOKcall:
        /* Issue 3882: */
        if (global.params.warnings && !global.gag)
        {
            CallExp ce = cast(CallExp)e;
            if (e.type.ty == Tvoid)
            {
                /* Don't complain about calling void-returning functions with no side-effect,
                 * because purity and nothrow are inferred, and because some of the
                 * runtime library depends on it. Needs more investigation.
                 *
                 * One possible solution is to restrict this message to only be called in hierarchies that
                 * never call assert (and or not called from inside unittest blocks)
                 */
            }
            else if (ce.e1.type)
            {
                Type t = ce.e1.type.toBasetype();
                if (t.ty == Tdelegate)
                    t = (cast(TypeDelegate)t).next;
                if (t.ty == Tfunction && (ce.f ? callSideEffectLevel(ce.f) : callSideEffectLevel(ce.e1.type)) > 0)
                {
                    const(char)* s;
                    if (ce.f)
                        s = ce.f.toPrettyChars();
                    else if (ce.e1.op == TOKstar)
                    {
                        // print 'fp' if ce->e1 is (*fp)
                        s = (cast(PtrExp)ce.e1).e1.toChars();
                    }
                    else
                        s = ce.e1.toChars();
                    e.warning("calling %s without side effects discards return value of type %s, prepend a cast(void) if intentional", s, e.type.toChars());
                }
            }
        }
        return;
    case TOKimport:
        e.error("%s has no effect", e.toChars());
        return;
    case TOKandand:
        {
            AndAndExp aae = cast(AndAndExp)e;
            discardValue(aae.e2);
            return;
        }
    case TOKoror:
        {
            OrOrExp ooe = cast(OrOrExp)e;
            discardValue(ooe.e2);
            return;
        }
    case TOKquestion:
        {
            CondExp ce = cast(CondExp)e;
            /* Bugzilla 6178 & 14089: Either CondExp::e1 or e2 may have
             * redundant expression to make those types common. For example:
             *
             *  struct S { this(int n); int v; alias v this; }
             *  S[int] aa;
             *  aa[1] = 0;
             *
             * The last assignment statement will be rewitten to:
             *
             *  1 in aa ? aa[1].value = 0 : (aa[1] = 0, aa[1].this(0)).value;
             *
             * The last DotVarExp is necessary to take assigned value.
             *
             *  int value = (aa[1] = 0);    // value = aa[1].value
             *
             * To avoid false error, discardValue() should be called only when
             * the both tops of e1 and e2 have actually no side effects.
             */
            if (!lambdaHasSideEffect(ce.e1) && !lambdaHasSideEffect(ce.e2))
            {
                discardValue(ce.e1);
                discardValue(ce.e2);
            }
            return;
        }
    case TOKcomma:
        {
            CommaExp ce = cast(CommaExp)e;
            /* Check for compiler-generated code of the form  auto __tmp, e, __tmp;
             * In such cases, only check e for side effect (it's OK for __tmp to have
             * no side effect).
             * See Bugzilla 4231 for discussion
             */
            CommaExp firstComma = ce;
            while (firstComma.e1.op == TOKcomma)
                firstComma = cast(CommaExp)firstComma.e1;
            if (firstComma.e1.op == TOKdeclaration && ce.e2.op == TOKvar && (cast(DeclarationExp)firstComma.e1).declaration == (cast(VarExp)ce.e2).var)
            {
                return;
            }
            // Don't check e1 until we cast(void) the a,b code generation
            //discardValue(ce->e1);
            discardValue(ce.e2);
            return;
        }
    case TOKtuple:
        /* Pass without complaint if any of the tuple elements have side effects.
         * Ideally any tuple elements with no side effects should raise an error,
         * this needs more investigation as to what is the right thing to do.
         */
        if (!hasSideEffect(e))
            break;
        return;
    default:
        break;
    }
    e.error("%s has no effect in expression (%s)", Token.toChars(e.op), e.toChars());
}
