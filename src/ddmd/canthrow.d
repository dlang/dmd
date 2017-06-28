/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _canthrow.d)
 */

module ddmd.canthrow;

import ddmd.aggregate;
import ddmd.apply;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.init;
import ddmd.mtype;
import ddmd.root.rootobject;
import ddmd.tokens;
import ddmd.visitor;

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
        alias visit = super.visit;
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
            Type t = ce.e1.type.toBasetype();
            if (ce.f && ce.f == func)
                return;
            if (t.ty == Tfunction && (cast(TypeFunction)t).isnothrow)
                return;
            if (t.ty == Tdelegate && (cast(TypeFunction)(cast(TypeDelegate)t).next).isnothrow)
                return;

            if (mustNotThrow)
            {
                if (ce.f)
                {
                    ce.error("%s `%s` is not nothrow",
                        ce.f.kind(), ce.f.toPrettyChars());
                }
                else
                {
                    auto e1 = ce.e1;
                    if (e1.op == TOKstar)   // print 'fp' if e1 is (*fp)
                        e1 = (cast(PtrExp)e1).e1;
                    ce.error("`%s` is not nothrow", e1.toChars());
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
                    Type t = ne.allocator.type.toBasetype();
                    if (t.ty == Tfunction && !(cast(TypeFunction)t).isnothrow)
                    {
                        if (mustNotThrow)
                        {
                            ne.error("%s `%s` is not nothrow",
                                ne.allocator.kind(), ne.allocator.toPrettyChars());
                        }
                        stop = true;
                    }
                }
                // See if constructor call can throw
                Type t = ne.member.type.toBasetype();
                if (t.ty == Tfunction && !(cast(TypeFunction)t).isnothrow)
                {
                    if (mustNotThrow)
                    {
                        ne.error("%s `%s` is not nothrow",
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
                ad = (cast(TypeClass)tb).sym;
                break;

            case Tpointer:
                tb = (cast(TypePointer)tb).next.toBasetype();
                if (tb.ty == Tstruct)
                    ad = (cast(TypeStruct)tb).sym;
                break;

            case Tarray:
                Type tv = tb.nextOf().baseElemOf();
                if (tv.ty == Tstruct)
                    ad = (cast(TypeStruct)tv).sym;
                break;

            default:
                break;
            }
            if (!ad)
                return;

            if (ad.dtor)
            {
                Type t = ad.dtor.type.toBasetype();
                if (t.ty == Tfunction && !(cast(TypeFunction)t).isnothrow)
                {
                    if (mustNotThrow)
                    {
                        de.error("%s `%s` is not nothrow",
                            ad.dtor.kind(), ad.dtor.toPrettyChars());
                    }
                    stop = true;
                }
            }
            if (ad.aggDelete && tb.ty != Tarray)
            {
                Type t = ad.aggDelete.type;
                if (t.ty == Tfunction && !(cast(TypeFunction)t).isnothrow)
                {
                    if (mustNotThrow)
                    {
                        de.error("%s `%s` is not nothrow",
                            ad.aggDelete.kind(), ad.aggDelete.toPrettyChars());
                    }
                    stop = true;
                }
            }
        }

        override void visit(AssignExp ae)
        {
            // blit-init cannot throw
            if (ae.op == TOKblit)
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
            else if (ae.e1.op == TOKslice)
                t = (cast(SliceExp)ae.e1).e1.type;
            else
                return;
            Type tv = t.baseElemOf();
            if (tv.ty != Tstruct)
                return;
            StructDeclaration sd = (cast(TypeStruct)tv).sym;
            if (!sd.postblit || sd.postblit.type.ty != Tfunction)
                return;
            if ((cast(TypeFunction)sd.postblit.type).isnothrow)
            {
            }
            else
            {
                if (mustNotThrow)
                {
                    ae.error("%s `%s` is not nothrow",
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
extern (C++) bool Dsymbol_canThrow(Dsymbol s, FuncDeclaration func, bool mustNotThrow)
{
    AttribDeclaration ad;
    VarDeclaration vd;
    TemplateMixin tm;
    TupleDeclaration td;
    //printf("Dsymbol_toElem() %s\n", s.toChars());
    ad = s.isAttribDeclaration();
    if (ad)
    {
        Dsymbols* decl = ad.include(null, null);
        if (decl && decl.dim)
        {
            for (size_t i = 0; i < decl.dim; i++)
            {
                s = (*decl)[i];
                if (Dsymbol_canThrow(s, func, mustNotThrow))
                    return true;
            }
        }
    }
    else if ((vd = s.isVarDeclaration()) !is null)
    {
        s = s.toAlias();
        if (s != vd)
            return Dsymbol_canThrow(s, func, mustNotThrow);
        if (vd.storage_class & STCmanifest)
        {
        }
        else if (vd.isStatic() || vd.storage_class & (STCextern | STCtls | STCgshared))
        {
        }
        else
        {
            if (vd._init)
            {
                ExpInitializer ie = vd._init.isExpInitializer();
                if (ie && canThrow(ie.exp, func, mustNotThrow))
                    return true;
            }
            if (vd.needsScopeDtor())
                return canThrow(vd.edtor, func, mustNotThrow);
        }
    }
    else if ((tm = s.isTemplateMixin()) !is null)
    {
        //printf("%s\n", tm.toChars());
        if (tm.members)
        {
            for (size_t i = 0; i < tm.members.dim; i++)
            {
                Dsymbol sm = (*tm.members)[i];
                if (Dsymbol_canThrow(sm, func, mustNotThrow))
                    return true;
            }
        }
    }
    else if ((td = s.isTupleDeclaration()) !is null)
    {
        for (size_t i = 0; i < td.objects.dim; i++)
        {
            RootObject o = (*td.objects)[i];
            if (o.dyncast() == DYNCAST.expression)
            {
                Expression eo = cast(Expression)o;
                if (eo.op == TOKdsymbol)
                {
                    DsymbolExp se = cast(DsymbolExp)eo;
                    if (Dsymbol_canThrow(se.s, func, mustNotThrow))
                        return true;
                }
            }
        }
    }
    return false;
}
