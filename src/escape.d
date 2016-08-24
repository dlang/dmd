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
import ddmd.arraytypes;

/****************************************
 * Given an AssignExp, determine if the lvalue will cause
 * the contents of the rvalue to escape.
 * Print error messages when these are detected.
 * Infer 'scope' for the lvalue where possible, in order
 * to eliminate the error.
 * Params:
 *      sc = used to determine current function and module
 *      ae = AssignExp to check for any pointers to the stack
 *      gag = do not print error messages
 * Returns:
 *      true if pointers to the stack can escape via assignment
 */
bool checkAssignEscape(Scope* sc, Expression e, bool gag)
{
    //printf("checkAssignEscape(e: %s)\n", e.toChars());
    if (e.op != TOKassign && e.op != TOKblit && e.op != TOKconstruct)
        return false;
    auto ae = cast(AssignExp)e;
    Expression e1 = ae.e1;
    Expression e2 = ae.e2;
    //printf("type = %s, %d\n", e1.type.toChars(), e1.type.hasPointers());

    if (!e1.type.hasPointers())
        return false;

    if (e1.op == TOKslice)
        return false;

    EscapeByResults er;

    escapeByValue(e2, &er);

    if (!er.byref.dim && !er.byvalue.dim && !er.byfunc.dim && !er.byexp.dim)
        return false;

    VarDeclaration va;
    while (e1.op == TOKdotvar)
        e1 = (cast(DotVarExp)e1).e1;
    if (e1.op == TOKvar)
        va = (cast(VarExp)e1).var.isVarDeclaration();
    else if (e1.op == TOKthis)
        va = (cast(ThisExp)e1).var.isVarDeclaration();

    bool inferScope = false;
    if (sc.func && sc.func.type && sc.func.type.ty == Tfunction)
        inferScope = (cast(TypeFunction)sc.func.type).trust != TRUSTsystem;

    bool result = false;
    foreach (VarDeclaration v; er.byvalue)
    {
        if (v.isDataseg())
            continue;

        Dsymbol p = v.toParent2();

        if (v.isScope())
        {
            if (va && !va.isDataseg())
            {
                if (!va.isScope() && inferScope)
                    va.storage_class |= STCscope;
                continue;
            }
            if (sc.func.setUnsafe())
            {
                if (!gag)
                    error(ae.loc, "scope variable %s assigned to non-scope %s", v.toChars(), e1.toChars());
                result = true;
            }
        }
        else if (v.storage_class & STCvariadic && p == sc.func)
        {
            Type tb = v.type.toBasetype();
            if (tb.ty == Tarray || tb.ty == Tsarray)
            {
                if (va && !va.isDataseg())
                {
                    if (!va.isScope() && inferScope)
                        va.storage_class |= STCscope;
                    continue;
                }
                if (sc.func.setUnsafe())
                {
                    if (!gag)
                        error(ae.loc, "variadic variable %s assigned to non-scope %s", v.toChars(), e1.toChars());
                    result = true;
                }
            }
        }
    }

    foreach (VarDeclaration v; er.byref)
    {
        if (v.isDataseg())
            continue;

        Dsymbol p = v.toParent2();

        if ((v.storage_class & (STCref | STCout)) == 0 && p == sc.func)
        {
            if (va && !va.isDataseg())
            {
                if (!va.isScope() && inferScope &&
                    va.type.toBasetype().ty != Tclass)  // scope classes are special
                    va.storage_class |= STCscope;
                continue;
            }
            if (sc.func.setUnsafe())
            {
                if (!gag)
                    error(ae.loc, "reference to local variable %s assigned to non-scope %s", v.toChars(), e1.toChars());
                result = true;
            }
            continue;
        }
    }

    foreach (FuncDeclaration fd; er.byfunc)
    {
        //printf("fd = %s, %d\n", fd.toChars(), fd.tookAddressOf);
        VarDeclarations vars;
        findAllOuterAccessedVariables(fd, &vars);

        foreach (v; vars)
        {
            //printf("v = %s\n", v.toChars());
            if (v.isDataseg())
                continue;

            Dsymbol p = v.toParent2();

            if ((v.storage_class & (STCref | STCout | STCscope)) && p == sc.func)
            {
                if (va && !va.isDataseg())
                {
                    /* Don't infer STCscope for va, because then a closure
                     * won't be generated for sc.func.
                     */
                    //if (!va.isScope() && inferScope)
                        //va.storage_class |= STCscope;
                    continue;
                }
                if (sc.func.setUnsafe())
                {
                    if (!gag)
                        error(ae.loc, "reference to local %s assigned to non-scope %s in @safe code", v.toChars(), e1.toChars());
                    result = true;
                }
                continue;
            }
        }
    }

    foreach (Expression ee; er.byexp)
    {
        if (va && !va.isDataseg())
        {
            if (!va.isScope() && inferScope)
                va.storage_class |= STCscope;
            continue;
        }
        if (sc.func.setUnsafe())
        {
            if (!gag)
                error(ee.loc, "reference to stack allocated value returned by %s assigned to non-scope %s",
                    ee.toChars(), e1.toChars());
            result = true;
        }
    }

    return false;
}

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
    return checkEscapeImpl(sc, e, false, gag);
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

    return checkEscapeImpl(sc, e, true, gag);
}

private bool checkEscapeImpl(Scope* sc, Expression e, bool refs, bool gag)
{
    EscapeByResults er;

    if (refs)
        escapeByRef(e, &er);
    else
        escapeByValue(e, &er);

    if (!er.byref.dim && !er.byvalue.dim && !er.byexp.dim)
        return false;

    bool result = false;
    foreach (VarDeclaration v; er.byvalue)
    {
        if (v.isDataseg())
            continue;

        Dsymbol p = v.toParent2();

        if (v.isScope())
        {
            if (v.storage_class & STCreturn)
                continue;

            if (v.isParameter())
            {
                if (sc.func.flags & FUNCFLAGreturnInprocess && p == sc.func)
                {
                    inferReturn(sc.func, v);        // infer addition of 'return'
                    continue;
                }
            }
            if (sc._module && sc._module.isRoot())
            {
                // Only look for errors if in module listed on command line

                if (!gag)
                    error(e.loc, "scope variable %s may not be returned", v.toChars());
                result = true;
                continue;
            }
        }
        else if (v.storage_class & STCvariadic && p == sc.func)
        {
            Type tb = v.type.toBasetype();
            if (tb.ty == Tarray || tb.ty == Tsarray)
            {
                if (!gag)
                    error(e.loc, "escaping reference to variadic parameter %s", v.toChars());
                result = false;
            }
        }
    }

    foreach (VarDeclaration v; er.byref)
    {
        if (v.isDataseg())
            continue;

        Dsymbol p = v.toParent2();

        if ((v.storage_class & (STCref | STCout)) == 0 && p == sc.func)
        {
            if (!gag)
                error(e.loc, "escaping reference to local variable %s", v.toChars());
            result = true;
            continue;
        }

        /* Check for returning a ref variable by 'ref', but should be 'return ref'
         * Infer the addition of 'return', or set result to be the offending expression.
         */
        if (global.params.useDIP25 &&
            (v.storage_class & (STCref | STCout)) &&
            !(v.storage_class & (STCreturn | STCforeach)))
        {
            if (sc.func.flags & FUNCFLAGreturnInprocess && p == sc.func)
            {
                inferReturn(sc.func, v);        // infer addition of 'return'
            }
            else if (sc._module && sc._module.isRoot())
            {
                // Only look for errors if in module listed on command line

                if (p == sc.func)
                {
                    //printf("escaping reference to local ref variable %s\n", v.toChars());
                    //printf("storage class = x%llx\n", v.storage_class);
                    if (!gag)
                        error(e.loc, "escaping reference to local variable %s", v.toChars());
                    result = true;
                    continue;
                }
                // Don't need to be concerned if v's parent does not return a ref
                FuncDeclaration fd = p.isFuncDeclaration();
                if (fd && fd.type && fd.type.ty == Tfunction)
                {
                    TypeFunction tf = cast(TypeFunction)fd.type;
                    if (tf.isref)
                    {
                        if (!gag)
                            error(e.loc, "escaping reference to outer local variable %s", v.toChars());
                        result = true;
                        continue;
                    }
                }

            }
        }
    }

    foreach (Expression ee; er.byexp)
    {
        if (!gag)
            error(ee.loc, "escaping reference to stack allocated value returned by %s", ee.toChars());
        result = true;
    }

    return result;
}


/*************************************
 * Variable v needs to have 'return' inferred for it.
 * Params:
 *      fd = function that v is a parameter to
 *      v = parameter that needs to be STCreturn
 */

private void inferReturn(FuncDeclaration fd, VarDeclaration v)
{
    // v is a local in the current function

    //printf("inferring 'return' for variable '%s'\n", v.toChars());
    v.storage_class |= STCreturn;

    TypeFunction tf = cast(TypeFunction)fd.type;
    if (v == fd.vthis)
    {
        /* v is the 'this' reference, so mark the function
         */
        fd.storage_class |= STCreturn;
        if (tf.ty == Tfunction)
        {
            //printf("'this' too %p %s\n", tf, sc.func.toChars());
            tf.isreturn = true;
        }
    }
    else
    {
        // Perform 'return' inference on parameter
        if (tf.ty == Tfunction && tf.parameters)
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


/****************************************
 * e is an expression to be returned by value, and that value contains pointers.
 * Walk e to determine which variables are possibly being
 * returned by value, such as:
 *      int* function(int* p) { return p; }
 * If e is a form of &p, determine which variables have content
 * which is being returned as ref, such as:
 *      int* function(int i) { return &i; }
 * Multiple variables can be inserted, because of expressions like this:
 *      int function(bool b, int i, int* p) { return b ? &i : p; }
 *
 * No side effects.
 *
 * Params:
 *      e = expression to be returned by value
 *      er = where to place collected data
 */
private void escapeByValue(Expression e, EscapeByResults* er)
{
    //printf("[%s] checkEscape, e = %s\n", e.loc.toChars(), e.toChars());
    extern (C++) final class EscapeVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        EscapeByResults* er;

        extern (D) this(EscapeByResults* er)
        {
            this.er = er;
        }

        override void visit(Expression e)
        {
        }

        override void visit(AddrExp e)
        {
            escapeByRef(e.e1, er);
        }

        override void visit(SymOffExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
                er.byref.push(v);
        }

        override void visit(VarExp e)
        {
            VarDeclaration v = e.var.isVarDeclaration();
            if (v)
                er.byvalue.push(v);
        }

        override void visit(DelegateExp e)
        {
            er.byfunc.push(e.func);
        }

        override void visit(FuncExp e)
        {
            if (e.fd.tok == TOKdelegate)
                er.byfunc.push(e.fd);
        }

        override void visit(TupleExp e)
        {
            if (e.exps.dim)
            {
                (*e.exps)[e.exps.dim - 1].accept(this); // last one only
            }
        }

        override void visit(ArrayLiteralExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tsarray || tb.ty == Tarray)
            {
                if (e.basis)
                    e.basis.accept(this);
                foreach (el; *e.elements)
                {
                    if (el)
                        el.accept(this);
                }
            }
        }

        override void visit(StructLiteralExp e)
        {
            if (e.elements)
            {
                foreach (ex; *e.elements)
                {
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
                foreach (ex; *e.arguments)
                {
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
                escapeByRef(e.e1, er);
            }
            else
                e.e1.accept(this);
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
                        er.byvalue.push(v);
                        return;
                    }
                }
            }
            Type t1b = e.e1.type.toBasetype();
            if (t1b.ty == Tsarray)
                escapeByRef(e.e1, er);
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

        override void visit(CallExp e)
        {
            /* Check each argument that is
             * passed as 'return scope'.
             */
            Type t1 = e.e1.type.toBasetype();
            TypeFunction tf;
            if (t1.ty == Tdelegate)
                tf = cast(TypeFunction)(cast(TypeDelegate)t1).next;
            else if (t1.ty == Tfunction)
                tf = cast(TypeFunction)t1;
            else
                return;

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
                        if ((p.storageClass & (STCscope)) && (p.storageClass & STCreturn))
                            arg.accept(this);
                    }
                }
            }
            // If 'this' is returned, check it too
            if (e.e1.op == TOKdotvar && t1.ty == Tfunction)
            {
                DotVarExp dve = cast(DotVarExp)e.e1;
                if (dve.var.storage_class & STCreturn || tf.isreturn)
                    dve.e1.accept(this);
            }
        }
    }

    scope EscapeVisitor v = new EscapeVisitor(er);
    e.accept(v);
}


/****************************************
 * e is an expression to be returned by 'ref'.
 * Walk e to determine which variables are possibly being
 * returned by ref, such as:
 *      ref int function(int i) { return i; }
 * If e is a form of *p, determine which variables have content
 * which is being returned as ref, such as:
 *      ref int function(int* p) { return *p; }
 * Multiple variables can be inserted, because of expressions like this:
 *      ref int function(bool b, int i, int* p) { return b ? i : *p; }
 *
 * No side effects.
 *
 * Params:
 *      e = expression to be returned by 'ref'
 *      er = where to place collected data
 */
private void escapeByRef(Expression e, EscapeByResults* er)
{
    extern (C++) final class EscapeRefVisitor : Visitor
    {
        alias visit = super.visit;
    public:
        EscapeByResults* er;

        extern (D) this(EscapeByResults* er)
        {
            this.er = er;
        }

        override void visit(Expression e)
        {
        }

        override void visit(VarExp e)
        {
            auto v = e.var.isVarDeclaration();
            if (v)
            {
                if (v.storage_class & STCref && v.storage_class & (STCforeach | STCtemp) && v._init)
                {
                    /* If compiler generated ref temporary
                     *   (ref v = ex; ex)
                     * look at the initializer instead
                     */
                    if (ExpInitializer ez = v._init.isExpInitializer())
                    {
                        assert(ez.exp && ez.exp.op == TOKconstruct);
                        Expression ex = (cast(ConstructExp)ez.exp).e2;
                        ex.accept(this);
                    }
                }
                else
                    er.byref.push(v);
            }
        }

        override void visit(ThisExp e)
        {
            auto v = e.var.isVarDeclaration();
            if (v)
                er.byref.push(v);
        }

        override void visit(PtrExp e)
        {
            escapeByValue(e.e1, er);
        }

        override void visit(IndexExp e)
        {
            Type tb = e.e1.type.toBasetype();
            if (e.e1.op == TOKvar)
            {
                VarDeclaration v = (cast(VarExp)e.e1).var.isVarDeclaration();
                if (tb.ty == Tarray || tb.ty == Tsarray)
                {
                    if (v && v.storage_class & STCvariadic)
                    {
                        er.byref.push(v);
                        return;
                    }
                }
            }
            if (tb.ty == Tsarray)
            {
                e.e1.accept(this);
            }
            else if (tb.ty == Tarray)
            {
                escapeByValue(e.e1, er);
            }
        }

        override void visit(DotVarExp e)
        {
            Type t1b = e.e1.type.toBasetype();
            if (t1b.ty == Tclass)
                escapeByValue(e.e1, er);
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
                            else if ((p.storageClass & STCscope) && (p.storageClass & STCreturn))
                            {
                                if (arg.op == TOKdelegate)
                                {
                                    DelegateExp de = cast(DelegateExp)arg;
                                    if (de.func.isNested())
                                        er.byexp.push(de);
                                }
                                else
                                    escapeByValue(arg, er);
                            }
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
                // If it's a delegate, check it too
                if (e.e1.op == TOKvar && t1.ty == Tdelegate)
                {
                    escapeByValue(e.e1, er);
                }
            }
            else
                er.byexp.push(e);
        }
    }

    scope EscapeRefVisitor v = new EscapeRefVisitor(er);
    e.accept(v);
}


/************************************
 * Aggregate the data collected by the escapeBy??() functions.
 */
private struct EscapeByResults
{
    VarDeclarations byref;      // array into which variables being returned by ref are inserted
    VarDeclarations byvalue;    // array into which variables with values containing pointers are inserted
    FuncDeclarations byfunc;    // nested functions that are turned into delegates
    Expressions byexp;          // array into which temporaries being returned by ref are inserted
}

/*************************
 * Find all variables accessed by this delegate that are
 * in functions enclosing it.
 * Params:
 *      fd = function
 *      vars = array to append found variables to
 */
void findAllOuterAccessedVariables(FuncDeclaration fd, VarDeclarations* vars)
{
    for (auto p = fd.parent; p; p = p.parent)
    {
        auto fdp = p.isFuncDeclaration();
        if (fdp)
        {
            foreach (v; fdp.closureVars)
            {
                foreach (const fdv; v.nestedrefs)
                {
                    if (fdv == fd)
                    {
                        //printf("accessed: %s, type %s\n", v.toChars(), v.type.toChars());
                        vars.push(v);
                    }
                }
            }
        }
    }
}
