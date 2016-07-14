/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _escape.d)
 */

module ddmd.escape;

import core.stdc.stdio : printf;

import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.init;
import ddmd.mtype;
import ddmd.root.rootobject;
import ddmd.tokens;
import ddmd.visitor;

/************************************
 * Detect cases where pointers to the stack can 'escape' the
 * lifetime of the stack frame.
 * Print error messages when these are detected.
 * Params:
 *      sc = used to determine current function and module
 *      e = expression to check for any pointers to the stack
 *      gag = do not print error messages
 * Returns:
 *      true if pointers to the stack can escape
 */
bool checkEscape(Scope* sc, Expression e, bool gag)
{
    Expression er = escapeExpressionValue(sc, e);
    if (!er)
        return false;
    if (gag)
        return true;

    if (er.op == TOKvar)
    {
        VarDeclaration v = (cast(VarExp)er).var.isVarDeclaration();
        if (v.isScope())
        {
            error(er.loc, "scope variable %s may not be returned", v.toChars());
        }
        else if (v.storage_class & STCvariadic)
        {
            error(er.loc, "escaping reference to variadic parameter %s", v.toChars());
        }
        else
            assert(0);
    }
    else if (er.op == TOKsymoff)
    {
        VarDeclaration v = (cast(SymOffExp)er).var.isVarDeclaration();
        error(er.loc, "escaping reference to local %s", v.toChars());
    }
    else if (er.op == TOKaddress)
    {
        return checkEscapeRef(sc, (cast(AddrExp)er).e1, gag);
    }
    else if (er.op == TOKcast)
    {
        return checkEscapeRef(sc, (cast(CastExp)er).e1, gag);
    }
    else if (er.op == TOKslice)
    {
        return checkEscapeRef(sc, (cast(SliceExp)er).e1, gag);
    }
    else
    {
        error(er.loc, "escaping reference to stack allocated value returned by %s", er.toChars());
    }
    return true;
}

/************************************
 * Detect cases where returning 'e' by ref can result in a reference to the stack
 * being returned.
 * Print error messages when these are detected.
 * Params:
 *      sc = used to determine current function and module
 *      e = expression to check
 *      gag = do not print error messages
 * Returns:
 *      true if references to the stack can escape
 */
bool checkEscapeRef(Scope* sc, Expression e, bool gag)
{
    version (none)
    {
        printf("[%s] checkEscapeRef, e = %s\n", e.loc.toChars(), e.toChars());
        printf("current function %s\n", sc.func.toChars());
        printf("parent2 function %s\n", sc.func.toParent2().toChars());
    }

    Expression er = escapeExpressionRef(sc, e);
    if (!er)
        return false;
    if (gag)
        return true;

    if (er.op == TOKvar)
    {
        error(er.loc, "escaping reference to variable %s", er.toChars());
    }
    else if (er.op == TOKthis)
    {
        error(er.loc, "escaping reference to 'this'");
    }
    else if (er.op == TOKstar)
    {
        return checkEscape(sc, (cast(PtrExp)er).e1, gag);
    }
    else if (er.op == TOKdotvar)
    {
        return checkEscape(sc, (cast(DotVarExp)er).e1, gag);
    }
    else if (er.op == TOKcall)
    {
        error(er.loc, "escaping reference to stack allocated value returned by %s", er.toChars());
    }
    else
    {
        error(er.loc, "escaping reference to expression %s", er.toChars());
    }
    return true;
}


/****************************************
 * Walk e to determine which sub-expression contains the pointers
 * that form the foundation of the pointers in e,
 * if those pointers come with restrictions.
 * Params:
 *      sc = used to determine current function and module
 *      e = expression to check for any pointers to the stack
 * Returns:
 *      null means no pointers with restrictions, otherwise the sub-expression
 */
private Expression escapeExpressionValue(Scope* sc, Expression e)
{
    //printf("[%s] checkEscape, e = %s\n", e.loc.toChars(), e.toChars());
    extern (C++) final class EscapeVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        Expression result;

        extern (D) this(Scope* sc)
        {
            this.sc = sc;
        }

        override void visit(Expression e)
        {
        }

        override void visit(AddrExp e)
        {
            if (checkEscapeRef(sc, e.e1, true))
                result = e;
        }

        override void visit(SymOffExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v && v.toParent2() == sc.func)
            {
                if (v.isDataseg())
                    return;
                if ((v.storage_class & (STCref | STCout)) == 0)
                    result = e;
            }
        }

        override void visit(VarExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
            {
                if (v.isScope())
                {
                    result = e;
                }
                else if (v.storage_class & STCvariadic)
                {
                    Type tb = v.type.toBasetype();
                    if (tb.ty == Tarray || tb.ty == Tsarray)
                        result = e;
                }
            }
        }

        override void visit(TupleExp e)
        {
            for (size_t i = 0; i < e.exps.dim; i++)
            {
                (*e.exps)[i].accept(this);
            }
        }

        override void visit(ArrayLiteralExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tsarray || tb.ty == Tarray)
            {
                if (e.basis)
                    e.basis.accept(this);
                for (size_t i = 0; i < e.elements.dim; i++)
                {
                    auto el = (*e.elements)[i];
                    if (!el)
                        continue;
                    el.accept(this);
                }
            }
        }

        override void visit(StructLiteralExp e)
        {
            if (e.elements)
            {
                for (size_t i = 0; i < e.elements.dim; i++)
                {
                    Expression ex = (*e.elements)[i];
                    if (ex)
                        ex.accept(this);
                }
            }
        }

        override void visit(NewExp e)
        {
            Type tb = e.newtype.toBasetype();
            if (tb.ty == Tstruct && !e.member && e.arguments)
            {
                for (size_t i = 0; i < e.arguments.dim; i++)
                {
                    Expression ex = (*e.arguments)[i];
                    if (ex)
                        ex.accept(this);
                }
            }
        }

        override void visit(CastExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tarray && e.e1.type.toBasetype().ty == Tsarray)
            {
                if (checkEscapeRef(sc, e.e1, true))
                    result = e;
            }
        }

        override void visit(SliceExp e)
        {
            if (e.e1.op == TOKvar)
            {
                VarDeclaration v = (cast(VarExp)e.e1).var.isVarDeclaration();
                Type tb = e.type.toBasetype();
                if (v)
                {
                    if (tb.ty == Tsarray)
                        return;
                    if (v.storage_class & STCvariadic)
                    {
                        result = e.e1;
                        return;
                    }
                }
            }
            Type t1b = e.e1.type.toBasetype();
            if (t1b.ty == Tsarray)
            {
                if (checkEscapeRef(sc, e.e1, true))
                    result = e;
            }
            else
                e.e1.accept(this);
        }

        override void visit(BinExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tpointer)
            {
                e.e1.accept(this);
                e.e2.accept(this);
            }
        }

        override void visit(BinAssignExp e)
        {
            e.e2.accept(this);
        }

        override void visit(AssignExp e)
        {
            e.e2.accept(this);
        }

        override void visit(CommaExp e)
        {
            e.e2.accept(this);
        }

        override void visit(CondExp e)
        {
            e.e1.accept(this);
            e.e2.accept(this);
        }
    }

    scope EscapeVisitor v = new EscapeVisitor(sc);
    e.accept(v);
    return v.result;
}

/****************************************
 * Walk e to determine which sub-expression contains the refs
 * that form the foundation of the refs of e,
 * if those refs come with restrictions.
 * Do inference of 'return' storage class if possible.
 * Params:
 *      sc = used to determine current function and module
 *      e = expression to check for any refs
 * Returns:
 *      null means no refs with restrictions, otherwise the sub-expression
 */
private Expression escapeExpressionRef(Scope* sc, Expression e)
{
    extern (C++) final class EscapeRefVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        Expression result;

        extern (D) this(Scope* sc)
        {
            this.sc = sc;
        }

        void check(Expression e, Declaration d)
        {
            assert(d);
            VarDeclaration v = d.isVarDeclaration();
            if (!v)
                return;

            if (v.isDataseg())
                return;

            if ((v.storage_class & (STCref | STCout)) == 0 && v.toParent2() == sc.func)
            {
                // Returning a non-ref local by ref
                result = e;
                return;
            }

            /* Check for returning a ref variable by 'ref', but should be 'return ref'
             * Infer the addition of 'return', or set result to be the offending expression.
             */
            if (global.params.useDIP25 &&
                (v.storage_class & (STCref | STCout)) &&
                !(v.storage_class & (STCreturn | STCforeach)))
            {
                if (sc.func.flags & FUNCFLAGreturnInprocess && v.toParent2() == sc.func)
                {
                    // v is a local in the current function

                    //printf("inferring 'return' for variable '%s'\n", v.toChars());
                    v.storage_class |= STCreturn;

                    if (v == sc.func.vthis)
                    {
                        // Perform 'return' inference on function type
                        sc.func.storage_class |= STCreturn;
                        TypeFunction tf = cast(TypeFunction)sc.func.type;
                        if (tf.ty == Tfunction)
                        {
                            //printf("'this' too %p %s\n", tf, sc.func.toChars());
                            tf.isreturn = true;
                        }
                    }
                    else
                    {
                        // Perform 'return' inference on parameter
                        TypeFunction tf = cast(TypeFunction)sc.func.type;
                        if (tf.parameters)
                        {
                            const dim = Parameter.dim(tf.parameters);
                            foreach (const i; 0 .. dim)
                            {
                                Parameter p = Parameter.getNth(tf.parameters, i);
                                if (p.ident == v.ident)
                                {
                                    p.storageClass |= STCreturn;
                                    break;              // there can be only one
                                }
                            }
                        }
                    }
                }
                else if (sc._module && sc._module.isRoot())
                {
                    // Only look for errors if in module listed on command line

                    Dsymbol p = v.toParent2();
                    if (p == sc.func)
                    {
                        //printf("escaping reference to local ref variable %s\n", v.toChars());
                        //printf("storage class = x%llx\n", v.storage_class);
                        result = e;             // escaping ref to local variable
                        return;
                    }
                    // Don't need to be concerned if v's parent does not return a ref
                    FuncDeclaration fd = p.isFuncDeclaration();
                    if (fd && fd.type && fd.type.ty == Tfunction)
                    {
                        TypeFunction tf = cast(TypeFunction)fd.type;
                        if (tf.isref)
                            result = e;         // escaping ref to outer variable
                    }

                }
                return;
            }

            if (v.storage_class & STCref && v.storage_class & (STCforeach | STCtemp) && v._init)
            {
                // If compiler generated ref temporary
                // (ref v = ex; ex)
                if (ExpInitializer ez = v._init.isExpInitializer())
                {
                    assert(ez.exp && ez.exp.op == TOKconstruct);
                    Expression ex = (cast(ConstructExp)ez.exp).e2;
                    ex.accept(this);
                    return;
                }
            }
        }

        override void visit(Expression e)
        {
        }

        override void visit(VarExp e)
        {
            check(e, e.var);
        }

        override void visit(ThisExp e)
        {
            if (e.var)
                check(e, e.var);
        }

        override void visit(PtrExp e)
        {
            if (checkEscape(sc, e.e1, true))
                result = e;
        }

        override void visit(IndexExp e)
        {
            if (e.e1.op == TOKvar)
            {
                VarDeclaration v = (cast(VarExp)e.e1).var.isVarDeclaration();
                if (v && v.toParent2() == sc.func)
                {
                    Type tb = v.type.toBasetype();
                    if (tb.ty == Tarray || tb.ty == Tsarray)
                    {
                        if (v.storage_class & STCvariadic)
                        {
                            result = e.e1;
                            return;
                        }
                    }
                }
            }
            Type tb = e.e1.type.toBasetype();
            if (tb.ty == Tsarray)
            {
                e.e1.accept(this);
            }
        }

        override void visit(DotVarExp e)
        {
            Type t1b = e.e1.type.toBasetype();
            if (t1b.ty == Tclass)
            {
                if (checkEscape(sc, e.e1, true))
                   result = e;
            }
            else
                e.e1.accept(this);
        }

        override void visit(BinAssignExp e)
        {
            e.e1.accept(this);
        }

        override void visit(AssignExp e)
        {
            e.e1.accept(this);
        }

        override void visit(CommaExp e)
        {
            e.e2.accept(this);
        }

        override void visit(CondExp e)
        {
            e.e1.accept(this);
            e.e2.accept(this);
        }

        override void visit(CallExp e)
        {
            /* If the function returns by ref, check each argument that is
             * passed as 'return ref'.
             */
            Type t1 = e.e1.type.toBasetype();
            TypeFunction tf;
            if (t1.ty == Tdelegate)
                tf = cast(TypeFunction)(cast(TypeDelegate)t1).next;
            else if (t1.ty == Tfunction)
                tf = cast(TypeFunction)t1;
            else
                return;
            if (tf.isref)
            {
                if (e.arguments && e.arguments.dim)
                {
                    /* j=1 if _arguments[] is first argument,
                     * skip it because it is not passed by ref
                     */
                    int j = (tf.linkage == LINKd && tf.varargs == 1);
                    for (size_t i = j; i < e.arguments.dim; ++i)
                    {
                        Expression arg = (*e.arguments)[i];
                        size_t nparams = Parameter.dim(tf.parameters);
                        if (i - j < nparams && i >= j)
                        {
                            Parameter p = Parameter.getNth(tf.parameters, i - j);
                            if ((p.storageClass & (STCout | STCref)) && (p.storageClass & STCreturn))
                                arg.accept(this);
                        }
                    }
                }
                // If 'this' is returned by ref, check it too
                if (e.e1.op == TOKdotvar && t1.ty == Tfunction)
                {
                    DotVarExp dve = cast(DotVarExp)e.e1;
                    if (dve.var.storage_class & STCreturn || tf.isreturn)
                        dve.e1.accept(this);
                }
            }
            else
            {
                result = e;
            }
        }
    }

    scope EscapeRefVisitor v = new EscapeRefVisitor(sc);
    e.accept(v);
    return v.result;
}
