/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/arrayop.d, _arrayop.d)
 */

module ddmd.arrayop;

// Online documentation: https://dlang.org/phobos/ddmd_arrayop.html

import core.stdc.stdio;
import ddmd.arraytypes;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.expressionsem;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.statement;
import ddmd.tokens;
import ddmd.semantic;
import ddmd.visitor;

/**********************************************
 * Check that there are no uses of arrays without [].
 */
extern (C++) bool isArrayOpValid(Expression e)
{
    if (e.op == TOKslice)
        return true;
    if (e.op == TOKarrayliteral)
    {
        Type t = e.type.toBasetype();
        while (t.ty == Tarray || t.ty == Tsarray)
            t = t.nextOf().toBasetype();
        return (t.ty != Tvoid);
    }
    Type tb = e.type.toBasetype();
    if (tb.ty == Tarray || tb.ty == Tsarray)
    {
        if (isUnaArrayOp(e.op))
        {
            return isArrayOpValid((cast(UnaExp)e).e1);
        }
        if (isBinArrayOp(e.op) || isBinAssignArrayOp(e.op) || e.op == TOKassign)
        {
            BinExp be = cast(BinExp)e;
            return isArrayOpValid(be.e1) && isArrayOpValid(be.e2);
        }
        if (e.op == TOKconstruct)
        {
            BinExp be = cast(BinExp)e;
            return be.e1.op == TOKslice && isArrayOpValid(be.e2);
        }
        if (e.op == TOKcall)
        {
            return false; // TODO: Decide if [] is required after arrayop calls.
        }
        else
        {
            return false;
        }
    }
    return true;
}

extern (C++) bool isNonAssignmentArrayOp(Expression e)
{
    if (e.op == TOKslice)
        return isNonAssignmentArrayOp((cast(SliceExp)e).e1);

    Type tb = e.type.toBasetype();
    if (tb.ty == Tarray || tb.ty == Tsarray)
    {
        return (isUnaArrayOp(e.op) || isBinArrayOp(e.op));
    }
    return false;
}

extern (C++) bool checkNonAssignmentArrayOp(Expression e, bool suggestion = false)
{
    if (isNonAssignmentArrayOp(e))
    {
        const(char)* s = "";
        if (suggestion)
            s = " (possible missing [])";
        e.error("array operation `%s` without destination memory not allowed%s", e.toChars(), s);
        return true;
    }
    return false;
}

/***********************************
 * Construct the array operation expression, call object._arrayOp!(tiargs)(args).
 * Encode operand types and operations into tiargs using reverse polish notation (RPN) to preserve precedence.
 * Unary operations are prefixed with "u" (e.g. "u~").
 * Pass operand values (slices or scalars) as args.
 *
 * Scalar expression sub-trees of `e` are evaluated before calling
 * into druntime to hoist them out of the loop. This is a valid
 * evaluation order as the actual array operations have no
 * side-effect.
 */
extern (C++) Expression arrayOp(BinExp e, Scope* sc)
{
    //printf("BinExp.arrayOp() %s\n", toChars());
    Type tb = e.type.toBasetype();
    assert(tb.ty == Tarray || tb.ty == Tsarray);
    Type tbn = tb.nextOf().toBasetype();
    if (tbn.ty == Tvoid)
    {
        e.error("cannot perform array operations on `void[]` arrays");
        return new ErrorExp();
    }
    if (!isArrayOpValid(e))
        return arrayOpInvalidError(e);

    auto tiargs = new Objects();
    auto args = new Expressions();
    buildArrayOp(sc, e, tiargs, args);

    import ddmd.dtemplate : TemplateDeclaration;
    __gshared TemplateDeclaration arrayOp;
    if (arrayOp is null)
    {
        Expression id = new IdentifierExp(e.loc, Id.empty);
        id = new DotIdExp(e.loc, id, Id.object);
        id = new DotIdExp(e.loc, id, Identifier.idPool("_arrayOp"));
        id = id.expressionSemantic(sc);
        if (id.op != TOKtemplate)
            ObjectNotFound(Identifier.idPool("_arrayOp"));
        arrayOp = (cast(TemplateExp)id).td;
    }

    auto fd = resolveFuncCall(e.loc, sc, arrayOp, tiargs, null, args);
    if (!fd || fd.errors)
        return new ErrorExp();
    return new CallExp(e.loc, new VarExp(e.loc, fd, false), args).expressionSemantic(sc);
}

/// ditto
extern (C++) Expression arrayOp(BinAssignExp e, Scope* sc)
{
    //printf("BinAssignExp.arrayOp() %s\n", toChars());

    /* Check that the elements of e1 can be assigned to
     */
    Type tn = e.e1.type.toBasetype().nextOf();

    if (tn && (!tn.isMutable() || !tn.isAssignable()))
    {
        e.error("slice `%s` is not mutable", e.e1.toChars());
        return new ErrorExp();
    }
    if (e.e1.op == TOKarrayliteral)
    {
        return e.e1.modifiableLvalue(sc, e.e1);
    }

    return arrayOp(cast(BinExp)e, sc);
}

/******************************************
 * Convert the expression tree e to template and function arguments,
 * using reverse polish notation (RPN) to encode order of operations.
 * Encode operations as string arguments, using a "u" prefix for unary operations.
 */
extern (C++) void buildArrayOp(Scope* sc, Expression e, Objects* tiargs, Expressions* args)
{
    extern (C++) final class BuildArrayOpVisitor : Visitor
    {
        alias visit = super.visit;
        Scope* sc;
        Objects* tiargs;
        Expressions* args;

    public:
        extern (D) this(Scope* sc, Objects* tiargs, Expressions* args)
        {
            this.sc = sc;
            this.tiargs = tiargs;
            this.args = args;
        }

        override void visit(Expression e)
        {
            tiargs.push(e.type);
            args.push(e);
        }

        override void visit(SliceExp e)
        {
            visit(cast(Expression) e);
        }

        override void visit(CastExp e)
        {
            visit(cast(Expression) e);
        }

        override void visit(UnaExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty != Tarray && tb.ty != Tsarray) // hoist scalar expressions
            {
                visit(cast(Expression) e);
            }
            else
            {
                // RPN, prefix unary ops with u
                OutBuffer buf;
                buf.writestring("u");
                buf.writestring(Token.toString(e.op));
                e.e1.accept(this);
                tiargs.push(new StringExp(Loc(), buf.extractString()).expressionSemantic(sc));
            }
        }

        override void visit(BinExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty != Tarray && tb.ty != Tsarray) // hoist scalar expressions
            {
                visit(cast(Expression) e);
            }
            else
            {
                // RPN
                e.e1.accept(this);
                e.e2.accept(this);
                tiargs.push(new StringExp(Loc(), cast(char*) Token.toChars(e.op)).expressionSemantic(sc));
            }
        }
    }

    scope v = new BuildArrayOpVisitor(sc, tiargs, args);
    e.accept(v);
}

/***********************************************
 * Test if expression is a unary array op.
 */
extern (C++) bool isUnaArrayOp(TOK op)
{
    switch (op)
    {
    case TOKneg:
    case TOKtilde:
        return true;
    default:
        break;
    }
    return false;
}

/***********************************************
 * Test if expression is a binary array op.
 */
extern (C++) bool isBinArrayOp(TOK op)
{
    switch (op)
    {
    case TOKadd:
    case TOKmin:
    case TOKmul:
    case TOKdiv:
    case TOKmod:
    case TOKxor:
    case TOKand:
    case TOKor:
    case TOKpow:
        return true;
    default:
        break;
    }
    return false;
}

/***********************************************
 * Test if expression is a binary assignment array op.
 */
extern (C++) bool isBinAssignArrayOp(TOK op)
{
    switch (op)
    {
    case TOKaddass:
    case TOKminass:
    case TOKmulass:
    case TOKdivass:
    case TOKmodass:
    case TOKxorass:
    case TOKandass:
    case TOKorass:
    case TOKpowass:
        return true;
    default:
        break;
    }
    return false;
}

/***********************************************
 * Test if operand is a valid array op operand.
 */
extern (C++) bool isArrayOpOperand(Expression e)
{
    //printf("Expression.isArrayOpOperand() %s\n", e.toChars());
    if (e.op == TOKslice)
        return true;
    if (e.op == TOKarrayliteral)
    {
        Type t = e.type.toBasetype();
        while (t.ty == Tarray || t.ty == Tsarray)
            t = t.nextOf().toBasetype();
        return (t.ty != Tvoid);
    }
    Type tb = e.type.toBasetype();
    if (tb.ty == Tarray)
    {
        return (isUnaArrayOp(e.op) ||
                isBinArrayOp(e.op) ||
                isBinAssignArrayOp(e.op) ||
                e.op == TOKassign);
    }
    return false;
}


/***************************************************
 * Print error message about invalid array operation.
 * Params:
 *      e = expression with the invalid array operation
 * Returns:
 *      instance of ErrorExp
 */

ErrorExp arrayOpInvalidError(Expression e)
{
    e.error("invalid array operation `%s` (possible missing [])", e.toChars());
    return new ErrorExp();
}
