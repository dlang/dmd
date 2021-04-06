/**
 * Implements reports for expressions/statements that affected attribute interference.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/attribute_diagnostic.d, _attribute_diagnostic.d)
 * Documentation:  https://dlang.org/phobos/dmd_attribute_diagnostic.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/attribute_diagnostic.d
 */

module dmd.attribute_diagnostic;

import core.stdc.stdio : printf, puts;

import dmd.apply : walkPostorder;
import dmd.declaration : STC;
import dmd.dsymbol : Dsymbol;
import dmd.errors : errorSupplemental;
import dmd.expression;
import dmd.func : FuncDeclaration;
import dmd.globals : global, Loc;
import dmd.sapply : walkPostorder;
import dmd.statement;
import dmd.visitor;

// debug = VIOLATIONS;

/**
 * Reports statements/expression that prohibited attribute inference.
 *
 * Params:
 *   f = function to check
 *   v = attribute violation
 */
void reportViolations(FuncDeclaration f, Violation v)
{
    if (!f || !f.fbody || global.gag)
        return;

    scope vv = new ViolationVisitor(v);
    vv.enter(f);
}

private:

/// Detects attribute violations
extern (C++) final class ViolationVisitor : StoppableVisitor
{
    const Violation filter; /// Selected attribute
    const char* message;    /// error message for matched nodes
    ubyte depth;            /// current recursion depth
    bool ignored;           /// whether certain nodes were skipped
    FuncDeclaration current;/// currently diagnosed function

    /// Initialize this visitor for the specified attribute
    this(Violation filter)
    {
        this.filter = filter;
        with (Violation)
        {
            if (filter == nogc)
                message = "@nogc";
            else if (filter == safe)
                message = "@safe";
            else if (filter == nothrow_)
                message = "nothrow";
            else if (filter == pure_)
                message = "pure";
            else
            {
                printf("Unknown violation: %x", filter);
                assert(false);
            }
        }
    }

    /// Returns: Whether `t` violates the attribute specified in `filter`
    private bool hasViolations(T)(T t) const pure /* nothrow */ @safe @nogc
    {
        if (t.violation & this.filter)
            return true;

        debug (VIOLATIONS) printf("Ignoring `%s`\n", t.toChars());
        return false;
    }

    /// Recursively check `fd` for attribute violations according to `filter`
    private void enter(FuncDeclaration fd)
    {
        // Don't spam the user with too many errors at once
        if (depth > 5 && !global.params.verbose)
        {
            ignored = true;
            return;
        }

        // Trace functions exactly once
        if (fd.inferenceTraced & this.filter)
        {
            // TODO: Maybe print a message here?
            debug (VIOLATIONS) printf("Skipping already visited `%s`\n", fd.toPrettyChars());
            return;
        }

        // Skip functions without attribute inference
        if (!fd.isInstantiated() && !fd.isFuncLiteralDeclaration() && !(fd.storage_class & STC.inference) || fd.ident.startsWith("_d_")) // Druntime hooks
            return;

        fd.inferenceTraced |= this.filter;

        fd.loc.errorSupplemental("%-*s  could not infer `%s` for `%s` because:", 2 * depth, "".ptr, message, fd.toPrettyChars());

        auto currentSave = current;
        current = fd;
        depth++;
        walkPostorder(fd.fbody, this);
        depth--;
        current = currentSave;
    }

    /// Checks whether calling `fd` causes attribute violation according to `filter`
    private void check(CallExp e, FuncDeclaration fd)
    {
        assert(e);
        assert(fd);
        assert(fd.ident);

        // Detect foreach lowerings including autodecoding
        // Analyse them as if the delegate was part of the current function
        if (fd.ident.startsWith("_aApply"))
        {
            assert(e.arguments);
            assert(e.arguments.length == 2);

            auto fe = (*e.arguments)[1].isFuncExp();
            assert(fe);

            walkPostorder(fe.fd.fbody, this);
        }
        else if (!hasViolations(cast(Expression) e))
        {
            // Ignore
        }
        else if (fd.ident.startsWith("_d_")) // Druntime hooks
        {
            // TODO: better messages for rewritten expression
            printExpressionViolation(e);
        }
        else
        {
            const loc = e.loc != Loc.initial ? e.loc : current.loc;
            loc.errorSupplemental("%-*s- calling `%s` which is not `%s`", 2 * depth, "".ptr, fd.toPrettyChars(), message);
            enter(fd);
        }
    }

    /// Prints a message for `t` violating `filter`
    private void printExpressionViolation(T)(T t) const
    {
        t.loc.errorSupplemental("%-*s- `%s` is not `%s`", 2 * depth, "".ptr, t.toChars(), message);
    }

    // Visitor implementation below

    alias visit = typeof(super).visit;

    /// Check expressions for violations
    override void visit(Expression e)
    {
        if (!hasViolations(e))
            return;

        // Special case certain statements for better diagnostic messages:
        if (auto ve = e.isVarExp())
        {
            e.errorSupplemental("%-*s- accessing `%s` is not `%s`", 2 * depth, "".ptr, ve.toChars(), message);
            return;
        }

        printExpressionViolation(e);
    }

    /// Check function calls for violations and potentially enter into the function body
    override void visit(CallExp e)
    {
        if (e.f)
        {
            check(e, e.f);
            return;
        }

        // The function declaration might be wrapped in a VarExp as e1 for certain lowerings
        if (auto ve = e.e1.isVarExp())
        {
            if (auto fd = ve.var.isFuncDeclaration())
                check(e, fd);
        }
    }

    /// Check statements for violations
    override void visit(Statement s)
    {
        if (!hasViolations(s))
            return;

        // Special case certain statements for better diagnostic messages:

        if (auto ts = s.isThrowStatement())
        {
            assert(this.filter & Violation.nothrow_);
            s.loc.errorSupplemental("%-*s- throwing `%s` here", 2 * depth, "".ptr, ts.exp.type.toChars());
            return;
        }

        printExpressionViolation(s);
    }

    /// Check the internal expressions
    override void visit(ExpStatement s)
    {
        walkPostorder(s.exp, this);
    }

    /// Check expressions in return statements
    override void visit(ReturnStatement s)
    {
        s.exp.accept(this);
    }

    /// Check symbols (aka VarDeclarations) for violations
    override void visit(Dsymbol s)
    {
        if (hasViolations(s))
            printExpressionViolation(s);
    }
}
