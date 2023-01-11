/**
 * Checks that a function marked `@nogc` does not invoke the Garbage Collector.
 *
 * Specification: $(LINK2 https://dlang.org/spec/function.html#nogc-functions, No-GC Functions)
 *
 * Copyright:   Copyright (C) 1999-2023 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/nogc.d, _nogc.d)
 * Documentation:  https://dlang.org/phobos/dmd_nogc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/nogc.d
 */

module dmd.nogc;

import dmd.aggregate;
import dmd.apply;
import dmd.astenums;
import dmd.declaration;
import dmd.dscope;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.init;
import dmd.mtype;
import dmd.tokens;
import dmd.visitor;

/**************************************
 * Look for GC-allocations
 */
extern (C++) final class NOGCVisitor : StoppableVisitor
{
    alias visit = typeof(super).visit;
public:
    FuncDeclaration f;
    bool checkOnly;     // don't print errors
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
        if (v && !(v.storage_class & STC.manifest) && !v.isDataseg() && v._init)
        {
            if (ExpInitializer ei = v._init.isExpInitializer())
            {
                doCond(ei.exp);
            }
        }
    }

    override void visit(CallExp e)
    {
        import dmd.id : Id;
        import core.stdc.stdio : printf;
        if (!e.f)
            return;

        // Treat lowered hook calls as their original expressions.
        auto fd = stripHookTraceImpl(e.f);
        if (fd.ident == Id._d_arraysetlengthT)
        {
            if (checkOnly)
            {
                err = true;
                return;
            }
            if (f.setGC())
            {
                e.error("setting `length` in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "setting `length` may cause a GC allocation");
        }
        else if (fd.ident == Id._d_arrayappendT || fd.ident == Id._d_arrayappendcTX)
        {
            if (checkOnly)
            {
                err = true;
                return;
            }
            if (f.setGC())
            {
                e.error("cannot use operator `~=` in `@nogc` %s `%s`",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "operator `~=` may cause a GC allocation");
        }
    }

    override void visit(ArrayLiteralExp e)
    {
        if (e.type.ty != Tarray || !e.elements || !e.elements.length || e.onstack)
            return;
        if (checkOnly)
        {
            err = true;
            return;
        }
        if (f.setGC())
        {
            with(e.origin) 
            {
                e.error("array literal `%s` in `@nogc` %s `%s` may cause a GC allocation",
                    (isPresent ? get : e).toChars(), f.kind(), f.toPrettyChars());
                if (isPresent)
                {
                    import dmd.dtemplate : isDsymbol;
                    import dmd.dsymbol;
                    if (auto from = get().isDsymbol())
                    {
                        import dmd.errors;
                        auto tmp = from.isVarDeclaration();
                        if (tmp && tmp.storage_class & STC.manifest)
                            errorSupplemental(from.loc, "Consider declaring the manifest constant `%s` `static immutable` to avoid the GC", from.toChars());
                    }
                }
            }
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "array literal may cause a GC allocation");
    }

    override void visit(AssocArrayLiteralExp e)
    {
        if (!e.keys.length)
            return;
        if (checkOnly)
        {
            err = true;
            return;
        }
        if (f.setGC())
        {
            e.error("associative array literal in `@nogc` %s `%s` may cause a GC allocation",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "associative array literal may cause a GC allocation");
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
        if (global.params.ehnogc && e.thrownew)
            return;                     // separate allocator is called for this, not the GC
        if (checkOnly)
        {
            err = true;
            return;
        }
        if (f.setGC())
        {
            e.error("cannot use `new` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "`new` causes a GC allocation");
    }

    override void visit(DeleteExp e)
    {
        if (VarExp ve = e.e1.isVarExp())
        {
            VarDeclaration v = ve.var.isVarDeclaration();
            if (v && v.onstack)
                return; // delete for scope allocated class object
        }

        // Semantic should have already handled this case.
        assert(0);
    }

    override void visit(IndexExp e)
    {
        Type t1b = e.e1.type.toBasetype();
        if (e.modifiable && t1b.ty == Taarray)
        {
            if (checkOnly)
            {
                err = true;
                return;
            }
            if (f.setGC())
            {
                e.error("assigning an associative array element in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "assigning an associative array element may cause a GC allocation");
        }
    }

    override void visit(AssignExp e)
    {
        if (e.e1.op == EXP.arrayLength)
        {
            if (checkOnly)
            {
                err = true;
                return;
            }
            if (f.setGC())
            {
                e.error("setting `length` in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            f.printGCUsage(e.loc, "setting `length` may cause a GC allocation");
        }
    }

    override void visit(CatAssignExp e)
    {
        /* CatAssignExp will exist in `__traits(compiles, ...)` and in the `.e1` branch of a `__ctfe ? :` CondExp.
         * The other branch will be `_d_arrayappendcTX(e1, 1), e1[$-1]=e2` which will generate the warning about
         * GC usage. See visit(CallExp).
         */
        if (checkOnly)
        {
            err = true;
            return;
        }
        if (f.setGC())
        {
            err = true;
            return;
        }
    }

    override void visit(CatExp e)
    {
        if (checkOnly)
        {
            err = true;
            return;
        }
        if (f.setGC())
        {
            e.error("cannot use operator `~` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        f.printGCUsage(e.loc, "operator `~` may cause a GC allocation");
    }
}

Expression checkGC(Scope* sc, Expression e)
{
    /* If betterC, allow GC to happen in non-CTFE code.
     * Just don't generate code for it.
     * Detect non-CTFE use of the GC in betterC code.
     */
    const betterC = global.params.betterC;
    FuncDeclaration f = sc.func;
    if (e && e.op != EXP.error && f && sc.intypeof != 1 &&
           (!(sc.flags & SCOPE.ctfe) || betterC) &&
           (f.type.ty == Tfunction &&
            (cast(TypeFunction)f.type).isnogc || f.nogcInprocess || global.params.vgc) &&
           !(sc.flags & SCOPE.debug_))
    {
        scope NOGCVisitor gcv = new NOGCVisitor(f);
        gcv.checkOnly = betterC;
        walkPostorder(e, gcv);
        if (gcv.err)
        {
            if (betterC)
            {
                /* Allow ctfe to use the gc code, but don't let it into the runtime
                 */
                f.skipCodegen = true;
            }
            else
                return ErrorExp.get();
        }
    }
    return e;
}

/**
 * Removes `_d_HookTraceImpl` if found from `fd`.
 * This is needed to be able to find hooks that are called though the hook's `*Trace` wrapper.
 * Parameters:
 *  fd = The function declaration to remove `_d_HookTraceImpl` from
 */
private FuncDeclaration stripHookTraceImpl(FuncDeclaration fd)
{
    import dmd.id : Id;
    import dmd.dsymbol : Dsymbol;
    import dmd.root.rootobject : RootObject, DYNCAST;

    if (fd.ident != Id._d_HookTraceImpl)
        return fd;

    // Get the Hook from the second template parameter
    auto templateInstance = fd.parent.isTemplateInstance;
    RootObject hook = (*templateInstance.tiargs)[1];
    assert(hook.dyncast() == DYNCAST.dsymbol, "Expected _d_HookTraceImpl's second template parameter to be an alias to the hook!");
    return (cast(Dsymbol)hook).isFuncDeclaration;
}
