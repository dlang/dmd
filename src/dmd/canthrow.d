/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/canthrow.d, _canthrow.d)
 * Documentation:  https://dlang.org/phobos/dmd_canthrow.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/canthrow.d
 */

module dmd.canthrow;

import dmd.aggregate;
import dmd.apply;
import dmd.arraytypes;
import dmd.attrib;
import dmd.declaration;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.init;
import dmd.mtype;
import dmd.root.rootobject;
import dmd.tokens;
import dmd.visitor;

/********************************************
 * Returns true if the expression may throw exceptions.
 * If 'mustNotThrow' is true, generate an error if it throws
 */
extern (C++) bool canThrow(Expression e, FuncDeclaration func, bool mustNotThrow)
{
    //printf("Expression::canThrow(%d) %s\n", mustNotThrow, toChars());
    // stop walking if we determine this expression can throw
    extern (C++) final class CanThrow : StoppableVisitor
    {
        alias visit = typeof(super).visit;
        FuncDeclaration func;
        bool mustNotThrow;

    public:
        extern (D) this(FuncDeclaration func, bool mustNotThrow)
        {
            this.func = func;
            this.mustNotThrow = mustNotThrow;
        }

        override void visit(Expression)
        {
        }

        override void visit(DeclarationExp de)
        {
            stop = Dsymbol_canThrow(de.declaration, func, mustNotThrow);
        }

        override void visit(CallExp ce)
        {
            if (global.errors && !ce.e1.type)
                return; // error recovery
            /* If calling a function or delegate that is typed as nothrow,
             * then this expression cannot throw.
             * Note that pure functions can throw.
             */
            if (ce.f && ce.f == func)
                return;
            Type t = ce.e1.type.toBasetype();
            auto tf = t.isTypeFunction();
            if (tf && tf.isnothrow)
                return;
            else
            {
                auto td = t.isTypeDelegate();
                if (td && td.nextOf().isTypeFunction().isnothrow)
                    return;
            }

            if (mustNotThrow)
            {
                if (ce.f)
                {
                    ce.error("%s `%s` is not `nothrow`",
                        ce.f.kind(), ce.f.toPrettyChars());
                }
                else
                {
                    auto e1 = ce.e1;
                    if (auto pe = e1.isPtrExp())   // print 'fp' if e1 is (*fp)
                        e1 = pe.e1;
                    ce.error("`%s` is not `nothrow`", e1.toChars());
                }
            }
            stop = true;
        }

        override void visit(NewExp ne)
        {
            if (ne.member)
            {
                if (ne.allocator)
                {
                    // https://issues.dlang.org/show_bug.cgi?id=14407
                    auto tf = ne.allocator.type.toBasetype().isTypeFunction();
                    if (tf && !tf.isnothrow)
                    {
                        if (mustNotThrow)
                        {
                            ne.error("%s `%s` is not `nothrow`",
                                ne.allocator.kind(), ne.allocator.toPrettyChars());
                        }
                        stop = true;
                    }
                }
                // See if constructor call can throw
                auto tf = ne.member.type.toBasetype().isTypeFunction();
                if (tf && !tf.isnothrow)
                {
                    if (mustNotThrow)
                    {
                        ne.error("%s `%s` is not `nothrow`",
                            ne.member.kind(), ne.member.toPrettyChars());
                    }
                    stop = true;
                }
            }
            // regard storage allocation failures as not recoverable
        }

        override void visit(DeleteExp de)
        {
            Type tb = de.e1.type.toBasetype();
            AggregateDeclaration ad = null;
            switch (tb.ty)
            {
            case Tclass:
                ad = tb.isTypeClass().sym;
                break;

            case Tpointer:
            case Tarray:
                auto ts = tb.nextOf().baseElemOf().isTypeStruct();
                if (!ts)
                    return;
                ad = ts.sym;
                break;

            default:
                assert(0);  // error should have been detected by semantic()
            }

            if (ad.dtor)
            {
                auto tf = ad.dtor.type.toBasetype().isTypeFunction();
                if (tf && !tf.isnothrow)
                {
                    if (mustNotThrow)
                    {
                        de.error("%s `%s` is not `nothrow`",
                            ad.dtor.kind(), ad.dtor.toPrettyChars());
                    }
                    stop = true;
                }
            }

            if (ad.aggDelete && tb.ty != Tarray)
            {
                auto tf = ad.aggDelete.type.isTypeFunction();
                if (tf && !tf.isnothrow)
                {
                    if (mustNotThrow)
                    {
                        de.error("%s `%s` is not `nothrow`",
                            ad.aggDelete.kind(), ad.aggDelete.toPrettyChars());
                    }
                    stop = true;
                }
            }
        }

        override void visit(AssignExp ae)
        {
            // blit-init cannot throw
            if (ae.op == TOK.blit)
                return;
            /* Element-wise assignment could invoke postblits.
             */
            Type t;
            if (ae.type.toBasetype().ty == Tsarray)
            {
                if (!ae.e2.isLvalue())
                    return;
                t = ae.type;
            }
            else if (auto se = ae.e1.isSliceExp())
                t = se.e1.type;
            else
                return;

            auto ts = t.baseElemOf().isTypeStruct();
            if (!ts)
                return;
            StructDeclaration sd = ts.sym;
            if (!sd.postblit)
                return;

            auto tf = sd.postblit.type.isTypeFunction();
            if (!tf || tf.isnothrow)
            {
            }
            else
            {
                if (mustNotThrow)
                {
                    ae.error("%s `%s` is not `nothrow`",
                        sd.postblit.kind(), sd.postblit.toPrettyChars());
                }
                stop = true;
            }
        }

        override void visit(NewAnonClassExp)
        {
            assert(0); // should have been lowered by semantic()
        }
    }

    scope CanThrow ct = new CanThrow(func, mustNotThrow);
    return walkPostorder(e, ct);
}

/**************************************
 * Does symbol, when initialized, throw?
 * Mirrors logic in Dsymbol_toElem().
 */
private bool Dsymbol_canThrow(Dsymbol s, FuncDeclaration func, bool mustNotThrow)
{
    int symbolDg(Dsymbol s)
    {
        return Dsymbol_canThrow(s, func, mustNotThrow);
    }

    //printf("Dsymbol_toElem() %s\n", s.toChars());
    if (auto vd = s.isVarDeclaration())
    {
        s = s.toAlias();
        if (s != vd)
            return Dsymbol_canThrow(s, func, mustNotThrow);
        if (vd.storage_class & STC.manifest)
        {
        }
        else if (vd.isStatic() || vd.storage_class & (STC.extern_ | STC.tls | STC.gshared))
        {
        }
        else
        {
            if (vd._init)
            {
                if (auto ie = vd._init.isExpInitializer())
                    if (canThrow(ie.exp, func, mustNotThrow))
                        return true;
            }
            if (vd.needsScopeDtor())
                return canThrow(vd.edtor, func, mustNotThrow);
        }
    }
    else if (auto ad = s.isAttribDeclaration())
    {
        return ad.include(null).foreachDsymbol(&symbolDg) != 0;
    }
    else if (auto tm = s.isTemplateMixin())
    {
        return tm.members.foreachDsymbol(&symbolDg) != 0;
    }
    else if (auto td = s.isTupleDeclaration())
    {
        for (size_t i = 0; i < td.objects.dim; i++)
        {
            RootObject o = (*td.objects)[i];
            if (o.dyncast() == DYNCAST.expression)
            {
                Expression eo = cast(Expression)o;
                if (auto se = eo.isDsymbolExp())
                {
                    if (Dsymbol_canThrow(se.s, func, mustNotThrow))
                        return true;
                }
            }
        }
    }
    return false;
}
