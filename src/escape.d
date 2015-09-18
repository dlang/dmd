// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.escape;

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
 * Params:
 *      gag     do not print error messages
 * Returns:
 *      true    errors occured
 */
extern (C++) bool checkEscape(Scope* sc, Expression e, bool gag)
{
    //printf("[%s] checkEscape, e = %s\n", e->loc.toChars(), e->toChars());
    extern (C++) final class EscapeVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        bool gag;
        bool result;

        extern (D) this(Scope* sc, bool gag)
        {
            this.sc = sc;
            this.gag = gag;
        }

        void error(Loc loc, const(char)* format, Dsymbol s)
        {
            if (!gag)
                .error(loc, format, s.toChars());
            result = true;
        }

        void check(Loc loc, Declaration d)
        {
            VarDeclaration v = d.isVarDeclaration();
            if (v && v.toParent2() == sc.func)
            {
                if (v.isDataseg())
                    return;
                if ((v.storage_class & (STCref | STCout)) == 0)
                    error(loc, "escaping reference to local %s", v);
            }
        }

        override void visit(Expression e)
        {
        }

        override void visit(AddrExp e)
        {
            result |= checkEscapeRef(sc, e.e1, gag);
        }

        override void visit(SymOffExp e)
        {
            check(e.loc, e.var);
        }

        override void visit(VarExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
            {
                Type tb = v.type.toBasetype();
                if (v.isScope())
                {
                    /* Today, scope attribute almost doesn't work for escape analysis.
                     * Until the semantics will be completed, it should be left as-is.
                     * See also: fail_compilation/fail_scope.d
                     */
                    if (tb.ty == Tarray || tb.ty == Tsarray || tb.ty == Tclass || tb.ty == Tdelegate)
                    {
                        if ((!v.noscope || tb.ty == Tclass))
                        {
                            error(e.loc, "escaping reference to scope local %s", v);
                            return;
                        }
                    }
                }
                if (v.storage_class & STCvariadic)
                {
                    if (tb.ty == Tarray || tb.ty == Tsarray)
                        error(e.loc, "escaping reference to variadic parameter %s", v);
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
                for (size_t i = 0; i < e.elements.dim; i++)
                {
                    (*e.elements)[i].accept(this);
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
                result |= checkEscapeRef(sc, e.e1, gag);
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
                        error(e.loc, "escaping reference to the payload of variadic parameter %s", v);
                        return;
                    }
                }
            }
            Type t1b = e.e1.type.toBasetype();
            if (t1b.ty == Tsarray)
                result |= checkEscapeRef(sc, e.e1, gag);
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

    scope EscapeVisitor v = new EscapeVisitor(sc, gag);
    e.accept(v);
    return v.result;
}

/************************************
 * Detect cases where returning 'e' by ref can result in a reference to the stack
 * being returned.
 * Params:
 *      gag     do not print error messages
 * Returns:
 *      true    errors occured
 */
extern (C++) bool checkEscapeRef(Scope* sc, Expression e, bool gag)
{
    //printf("[%s] checkEscapeRef, e = %s\n", e->loc.toChars(), e->toChars());
    extern (C++) final class EscapeRefVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        Scope* sc;
        bool gag;
        bool result;

        extern (D) this(Scope* sc, bool gag)
        {
            this.sc = sc;
            this.gag = gag;
        }

        void error(Loc loc, const(char)* format, RootObject o)
        {
            if (!gag)
                .error(loc, format, o.toChars());
            result = true;
        }

        void check(Loc loc, Declaration d)
        {
            assert(d);
            VarDeclaration v = d.isVarDeclaration();
            if (v && v.toParent2() == sc.func)
            {
                if (v.isDataseg())
                    return;
                if ((v.storage_class & (STCref | STCout)) == 0)
                {
                    error(loc, "escaping reference to local variable %s", v);
                    return;
                }
                if (global.params.useDIP25 && (v.storage_class & (STCref | STCout)) && !(v.storage_class & (STCreturn | STCforeach)))
                {
                    if (sc.func.flags & FUNCFLAGreturnInprocess)
                    {
                        //printf("inferring 'return' for variable '%s'\n", v->toChars());
                        v.storage_class |= STCreturn;
                        if (v == sc.func.vthis)
                        {
                            TypeFunction tf = cast(TypeFunction)sc.func.type;
                            if (tf.ty == Tfunction)
                            {
                                //printf("'this' too\n");
                                tf.isreturn = true;
                            }
                        }
                    }
                    else if (sc._module && sc._module.isRoot())
                    {
                        //printf("escaping reference to local ref variable %s\n", v->toChars());
                        //printf("storage class = x%llx\n", v->storage_class);
                        error(loc, "escaping reference to local ref variable %s", v);
                    }
                    return;
                }
                if (v.storage_class & STCref && v.storage_class & (STCforeach | STCtemp) && v._init)
                {
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
        }

        override void visit(Expression e)
        {
        }

        override void visit(VarExp e)
        {
            check(e.loc, e.var);
        }

        override void visit(ThisExp e)
        {
            if (e.var)
                check(e.loc, e.var);
        }

        override void visit(PtrExp e)
        {
            result |= checkEscape(sc, e.e1, gag);
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
                            error(e.loc, "escaping reference to the payload of variadic parameter %s", v);
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
                result |= checkEscape(sc, e.e1, gag);
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
                if (tf.isreturn && e.e1.op == TOKdotvar && t1.ty == Tfunction)
                {
                    DotVarExp dve = cast(DotVarExp)e.e1;
                    dve.e1.accept(this);
                }
            }
            else
            {
                error(e.loc, "escaping reference to stack allocated value returned by %s", e);
                return;
            }
        }
    }

    scope EscapeRefVisitor v = new EscapeRefVisitor(sc, gag);
    e.accept(v);
    return v.result;
}
