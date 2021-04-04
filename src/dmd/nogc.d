/**
 * Checks that a function marked `@nogc` does not invoke the Garbage Collector.
 *
 * Specification: $(LINK2 https://dlang.org/spec/function.html#nogc-functions, No-GC Functions)
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/nogc.d, _nogc.d)
 * Documentation:  https://dlang.org/phobos/dmd_nogc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/nogc.d
 */

module dmd.nogc;

import dmd.aggregate;
import dmd.apply : walkPostorder;
import dmd.declaration;
import dmd.dscope;
import dmd.expression;
import dmd.func;
import dmd.globals;
import dmd.init;
import dmd.mtype;
import dmd.sapply : walkPostorder;
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
    bool err;
    bool traceInference; /// Tracing violations that prohibit @nogc inference
    bool ignored;        /// Exceeded recursion limit with `traceInference`
    ubyte depth;         /// Current recursion depth

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
        {
            // The function declaration might be wrapped in a VarExp as e1 for certain lowerings
            if (traceInference && e.e1)
            {
                auto ve = e.e1.isVarExp();
                if (ve && ve.var)
                    check(e, ve.var.isFuncDeclaration());
            }
            return;
        }

        auto fd = stripHookTraceImpl(e.f);
        if (fd.ident == Id._d_arraysetlengthT)
        {
            if (f.setGC())
            {
                e.error("setting `length` in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            printGCUsage(e, "setting `length` may cause a GC allocation");
        }
        else if (traceInference)
            check(e, e.f);
    }

    /// Search fd for violations of `@nogc`
    private void enter(CallExp e, FuncDeclaration fd)
    {
        import dmd.errors;

        // Don't spam the user with too many errors at once
        if (depth > 5 && !global.params.verbose)
        {
            ignored = true;
            return;
        }

        // Skip functions without attribute inference
        if ((fd.inferenceTraced & 1) || !fd.isInstantiated() && !fd.isFuncLiteralDeclaration() && !(fd.storage_class & STC.inference))
            return;

        fd.inferenceTraced |= 1;

        fd.loc.error("|"); // N.B.: Temporary spacing, remove later
        fd.loc.errorSupplemental("%-*s  inferred non-`@nogc` for `%s` because:", 2 * depth, "".ptr, fd.toPrettyChars());

        depth++;
        walkPostorder(fd.fbody, this);
        depth--;

        fd.loc.error("|"); // N.B.: Temporary spacing, remove later
    }

    /// Checks whether calling fd causes a @nogc violation
    private void check(CallExp e, FuncDeclaration fd)
    {
        // Doesn't violate @nogc
        if (!fd || fd.type.isTypeFunction().isnogc)
            return;

        // Detect foreach lowerings including autodecoding
        // Analyze them as if the delegate was part of the current function
        if (fd.ident && fd.ident.startsWith("_aApply"))
        {
            assert(e.arguments);
            assert(e.arguments.length == 2);

            auto fe = (*e.arguments)[1].isFuncExp();
            assert(fe);

            walkPostorder(fe.fd.fbody, this);
            return;
        }

        e.errorSupplemental("%-*s- calling %s `%s` may cause a GC allocation", 2 * depth, "".ptr, fd.kind(), fd.toPrettyChars());
        enter(e, fd);
    }

    override void visit(ArrayLiteralExp e)
    {
        if (e.type.ty != Tarray || !e.elements || !e.elements.dim)
            return;
        if (f.setGC())
        {
            e.error("array literal in `@nogc` %s `%s` may cause a GC allocation",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "array literal may cause a GC allocation");
    }

    override void visit(AssocArrayLiteralExp e)
    {
        if (!e.keys.dim)
            return;
        if (f.setGC())
        {
            e.error("associative array literal in `@nogc` %s `%s` may cause a GC allocation",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "associative array literal may cause a GC allocation");
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
        if (global.params.ehnogc && e.thrownew)
            return;                     // separate allocator is called for this, not the GC
        if (f.setGC())
        {
            e.error("cannot use `new` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "`new` causes a GC allocation");
    }

    override void visit(DeleteExp e)
    {
        if (e.e1.op == TOK.variable)
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

        if (f.setGC())
        {
            e.error("cannot use `delete` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "`delete` requires the GC");
    }

    override void visit(IndexExp e)
    {
        Type t1b = e.e1.type.toBasetype();
        if (t1b.ty == Taarray)
        {
            if (f.setGC())
            {
                e.error("indexing an associative array in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            printGCUsage(e, "indexing an associative array may cause a GC allocation");
        }
    }

    override void visit(AssignExp e)
    {
        if (e.e1.op == TOK.arrayLength)
        {
            if (f.setGC())
            {
                e.error("setting `length` in `@nogc` %s `%s` may cause a GC allocation",
                    f.kind(), f.toPrettyChars());
                err = true;
                return;
            }
            printGCUsage(e, "setting `length` may cause a GC allocation");
        }
    }

    override void visit(CatAssignExp e)
    {
        if (f.setGC())
        {
            e.error("cannot use operator `~=` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "operator `~=` may cause a GC allocation");
    }

    override void visit(CatExp e)
    {
        if (f.setGC())
        {
            e.error("cannot use operator `~` in `@nogc` %s `%s`",
                f.kind(), f.toPrettyChars());
            err = true;
            return;
        }
        printGCUsage(e, "operator `~` may cause a GC allocation");
    }

    /**
     * Prints a hint regarding GC usage
     *
     * Params:
     *   e   = expression triggering this message
     *   msg = the hint
     */
    private void printGCUsage(Expression e, const char* msg)
    {
        if (traceInference)
            e.errorSupplemental("%-*s- %s", 2 * depth, "".ptr, msg);
        else
            f.printGCUsage(e.loc, msg);
    }

    import dmd.statement : ExpStatement, ReturnStatement, Statement;

    // Ignore other statements
    override void visit(Statement cs) {}

    // Check actual expressions
    override void visit(ExpStatement s)
    {
        walkPostorder(s.exp, this);
    }

    // Check expressions in return statements
    override void visit(ReturnStatement s)
    {
        s.exp.accept(this);
    }
}

Expression checkGC(Scope* sc, Expression e)
{
    FuncDeclaration f = sc.func;
    if (e && e.op != TOK.error && f && sc.intypeof != 1 && !(sc.flags & SCOPE.ctfe) &&
           (f.type.ty == Tfunction &&
            (cast(TypeFunction)f.type).isnogc || (f.flags & FUNCFLAG.nogcInprocess) || global.params.vgc) &&
           !(sc.flags & SCOPE.debug_))
    {
        scope NOGCVisitor gcv = new NOGCVisitor(f);
        walkPostorder(e, gcv);
        if (gcv.err)
            return ErrorExp.get();
    }
    return e;
}

/**
 * Prints supplemental messages indicating why `f` was inferred as non-@nogc.
 *
 * Params:
 *   e = expression where f was used
 *   f = function to check
 */
void notifyGcStatements(Expression e, FuncDeclaration f)
{
    if (!f || !f.fbody || global.gag)
        return;

    scope NOGCVisitor gcv = new NOGCVisitor(f);
    gcv.traceInference = true;
    gcv.enter(e.isCallExp(), f);

    if (gcv.ignored && !global.params.verbose)
        e.errorSupplemental("  (use `-v` to print remaining errors)");
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
