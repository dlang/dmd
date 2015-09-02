// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.canthrow;

import ddmd.apply, ddmd.arraytypes, ddmd.attrib, ddmd.declaration, ddmd.dstruct, ddmd.dsymbol, ddmd.dtemplate, ddmd.expression, ddmd.func, ddmd.globals, ddmd.init, ddmd.mtype, ddmd.root.rootobject, ddmd.tokens, ddmd.visitor;

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

        void visit(Expression)
        {
        }

        void visit(DeclarationExp de)
        {
            stop = Dsymbol_canThrow(de.declaration, func, mustNotThrow);
        }

        void visit(CallExp ce)
        {
            if (global.errors && !ce.e1.type)
                return; // error recovery
            /* If calling a function or delegate that is typed as nothrow,
             * then this expression cannot throw.
             * Note that pure functions can throw.
             */
            Type t = ce.e1.type.toBasetype();
            if (ce.f && ce.f == func)
            {
            }
            else if (t.ty == Tfunction && (cast(TypeFunction)t).isnothrow)
            {
            }
            else if (t.ty == Tdelegate && (cast(TypeFunction)(cast(TypeDelegate)t).next).isnothrow)
            {
            }
            else
            {
                if (mustNotThrow)
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
                    ce.error("'%s' is not nothrow", s);
                }
                stop = true;
            }
        }

        void visit(NewExp ne)
        {
            if (ne.member)
            {
                // See if constructor call can throw
                Type t = ne.member.type.toBasetype();
                if (t.ty == Tfunction && !(cast(TypeFunction)t).isnothrow)
                {
                    if (mustNotThrow)
                        ne.error("constructor %s is not nothrow", ne.member.toChars());
                    stop = true;
                }
            }
            // regard storage allocation failures as not recoverable
        }

        void visit(AssignExp ae)
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
                    ae.error("'%s' is not nothrow", sd.postblit.toPrettyChars());
                stop = true;
            }
        }

        void visit(NewAnonClassExp)
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
    //printf("Dsymbol_toElem() %s\n", s->toChars());
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
            if (vd.edtor && !vd.noscope)
                return canThrow(vd.edtor, func, mustNotThrow);
        }
    }
    else if ((tm = s.isTemplateMixin()) !is null)
    {
        //printf("%s\n", tm->toChars());
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
            if (o.dyncast() == DYNCAST_EXPRESSION)
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
