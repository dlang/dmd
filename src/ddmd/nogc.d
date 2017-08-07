/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _nogc.d)
 */

module ddmd.nogc;

import ddmd.aggregate;
import ddmd.apply;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.init;
import ddmd.mtype;
import ddmd.tokens;
import ddmd.visitor;

/**************************************
 * Look for GC-allocations
 */
extern (C++) final class NOGCVisitor : StoppableVisitor
{
    alias visit = super.visit;
public:
    FuncDeclaration f;
    bool err;

    extern (D) this(FuncDeclaration f)
    {
        this.f = f;
    }

    void doCond(Expression exp)
    {
        if (exp)
            walkPostorder(exp, this);
    }

    override void visit(Expression e)
    {
    }

    override void visit(DeclarationExp e)
    {
        // Note that, walkPostorder does not support DeclarationExp today.
        VarDeclaration v = e.declaration.isVarDeclaration();
        if (v && !(v.storage_class & STCmanifest) && !v.isDataseg() && v._init)
        {
            if (ExpInitializer ei = v._init.isExpInitializer())
            {
                doCond(ei.exp);
            }
        }
    }

    override void visit(CallExp e)
    {
    }

    override void visit(ArrayLiteralExp e)
    {
        if (e.type.ty != Tarray || !e.elements || !e.elements.dim)
            return;
        if (f.setGC())
        {
            e.error("array literal in @nogc %s '%s' may cause GC allocation",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "array literal may cause GC allocation");
    }

    override void visit(AssocArrayLiteralExp e)
    {
        if (!e.keys.dim)
            return;
        if (f.setGC())
        {
            e.error("associative array literal in @nogc %s '%s' may cause GC allocation",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "associative array literal may cause GC allocation");
    }

    override void visit(NewExp e)
    {
        if (e.member && !e.member.isNogc() && f.setGC())
        {
            // @nogc-ness is already checked in NewExp::semantic
            return;
        }
        if (e.onstack)
            return;
        if (e.allocator)
            return;
        if (f.setGC())
        {
            e.error("cannot use 'new' in @nogc %s '%s'",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "'new' causes GC allocation");
    }

    override void visit(DeleteExp e)
    {
        if (e.e1.op == TOKvar)
        {
            VarDeclaration v = (cast(VarExp)e.e1).var.isVarDeclaration();
            if (v && v.onstack)
                return; // delete for scope allocated class object
        }

        Type tb = e.e1.type.toBasetype();
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

        default:
            break;
        }
        if (ad && ad.aggDelete)
            return;

        if (f.setGC())
        {
            e.error("cannot use 'delete' in @nogc %s '%s'",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "'delete' requires GC");
    }

    override void visit(IndexExp e)
    {
        Type t1b = e.e1.type.toBasetype();
        if (t1b.ty == Taarray)
        {
            if (f.setGC())
            {
                e.error("indexing an associative array in @nogc %s '%s' may cause GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "indexing an associative array may cause GC allocation");
        }
    }

    override void visit(AssignExp e)
    {
        if (e.e1.op == TOKarraylength)
        {
            if (f.setGC())
            {
                e.error("setting 'length' in @nogc %s '%s' may cause GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "setting 'length' may cause GC allocation");
        }
    }

    override void visit(CatAssignExp e)
    {
        if (f.setGC())
        {
            e.error("cannot use operator ~= in @nogc %s '%s'",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "operator ~= may cause GC allocation");
    }

    override void visit(CatExp e)
    {
        if (f.setGC())
        {
            e.error("cannot use operator ~ in @nogc %s '%s'",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "operator ~ may cause GC allocation");
    }
}

extern (C++) Expression checkGC(Scope* sc, Expression e)
{
    FuncDeclaration f = sc.func;
    if (e && e.op != TOKerror && f && sc.intypeof != 1 && !(sc.flags & SCOPEctfe) && (f.type.ty == Tfunction && (cast(TypeFunction)f.type).isnogc || (f.flags & FUNCFLAGnogcInprocess) || global.params.vgc))
    {
        scope NOGCVisitor gcv = new NOGCVisitor(f);
        walkPostorder(e, gcv);
        if (gcv.err)
            return new ErrorExp();
    }
    return e;
}
