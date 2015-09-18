// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.arrayop;

import ddmd.arraytypes;
import ddmd.declaration;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.aav;
import ddmd.root.outbuffer;
import ddmd.statement;
import ddmd.tokens;
import ddmd.visitor;

/**************************************
 * Hash table of array op functions already generated or known about.
 */
extern (C++) __gshared AA* arrayfuncs;

/**************************************
 * Structure to contain information needed to insert an array op call
 */
extern (C++) FuncDeclaration buildArrayOp(Identifier ident, BinExp exp, Scope* sc, Loc loc)
{
    auto fparams = new Parameters();
    Expression loopbody = buildArrayLoop(exp, fparams);
    /* Construct the function body:
     *  foreach (i; 0 .. p.length)    for (size_t i = 0; i < p.length; i++)
     *      loopbody;
     *  return p;
     */
    Parameter p = (*fparams)[0];
    // foreach (i; 0 .. p.length)
    Statement s1 = new ForeachRangeStatement(Loc(), TOKforeach, new Parameter(0, null, Id.p, null), new IntegerExp(Loc(), 0, Type.tsize_t), new ArrayLengthExp(Loc(), new IdentifierExp(Loc(), p.ident)), new ExpStatement(Loc(), loopbody), Loc());
    //printf("%s\n", s1->toChars());
    Statement s2 = new ReturnStatement(Loc(), new IdentifierExp(Loc(), p.ident));
    //printf("s2: %s\n", s2->toChars());
    Statement fbody = new CompoundStatement(Loc(), s1, s2);
    // Built-in array ops should be @trusted, pure, nothrow and nogc
    StorageClass stc = STCtrusted | STCpure | STCnothrow | STCnogc;
    /* Construct the function
     */
    auto ftype = new TypeFunction(fparams, exp.type, 0, LINKc, stc);
    //printf("fd: %s %s\n", ident->toChars(), ftype->toChars());
    auto fd = new FuncDeclaration(Loc(), Loc(), ident, STCundefined, ftype);
    fd.fbody = fbody;
    fd.protection = Prot(PROTpublic);
    fd.linkage = LINKc;
    fd.isArrayOp = 1;
    sc._module.importedFrom.members.push(fd);
    sc = sc.push();
    sc.parent = sc._module.importedFrom;
    sc.stc = 0;
    sc.linkage = LINKc;
    fd.semantic(sc);
    fd.semantic2(sc);
    uint errors = global.startGagging();
    fd.semantic3(sc);
    if (global.endGagging(errors))
    {
        fd.type = Type.terror;
        fd.errors = true;
        fd.fbody = null;
    }
    sc.pop();
    return fd;
}

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
        e.error("array operation %s without destination memory not allowed%s", e.toChars(), s);
        return true;
    }
    return false;
}

/***********************************
 * Construct the array operation expression.
 */
extern (C++) Expression arrayOp(BinExp e, Scope* sc)
{
    //printf("BinExp::arrayOp() %s\n", toChars());
    Type tb = e.type.toBasetype();
    assert(tb.ty == Tarray || tb.ty == Tsarray);
    Type tbn = tb.nextOf().toBasetype();
    if (tbn.ty == Tvoid)
    {
        e.error("cannot perform array operations on void[] arrays");
        return new ErrorExp();
    }
    if (!isArrayOpValid(e))
    {
        e.error("invalid array operation %s (possible missing [])", e.toChars());
        return new ErrorExp();
    }
    auto arguments = new Expressions();
    /* The expression to generate an array operation for is mangled
     * into a name to use as the array operation function name.
     * Mangle in the operands and operators in RPN order, and type.
     */
    OutBuffer buf;
    buf.writestring("_array");
    buildArrayIdent(e, &buf, arguments);
    buf.writeByte('_');
    /* Append deco of array element type
     */
    buf.writestring(e.type.toBasetype().nextOf().toBasetype().mutableOf().deco);
    char* name = buf.peekString();
    Identifier ident = Identifier.idPool(name);
    FuncDeclaration* pFd = cast(FuncDeclaration*)dmd_aaGet(&arrayfuncs, cast(void*)ident);
    FuncDeclaration fd = *pFd;
    if (!fd)
        fd = buildArrayOp(ident, e, sc, e.loc);
    if (fd && fd.errors)
    {
        const(char)* fmt;
        if (tbn.ty == Tstruct || tbn.ty == Tclass)
            fmt = "invalid array operation '%s' because %s doesn't support necessary arithmetic operations";
        else if (!tbn.isscalar())
            fmt = "invalid array operation '%s' because %s is not a scalar type";
        else
            fmt = "invalid array operation '%s' for element type %s";
        e.error(fmt, e.toChars(), tbn.toChars());
        return new ErrorExp();
    }
    *pFd = fd;
    Expression ev = new VarExp(e.loc, fd);
    Expression ec = new CallExp(e.loc, ev, arguments);
    return ec.semantic(sc);
}

extern (C++) Expression arrayOp(BinAssignExp e, Scope* sc)
{
    //printf("BinAssignExp::arrayOp() %s\n", toChars());
    /* Check that the elements of e1 can be assigned to
     */
    Type tn = e.e1.type.toBasetype().nextOf();
    if (tn && (!tn.isMutable() || !tn.isAssignable()))
    {
        e.error("slice %s is not mutable", e.e1.toChars());
        return new ErrorExp();
    }
    if (e.e1.op == TOKarrayliteral)
    {
        return e.e1.modifiableLvalue(sc, e.e1);
    }
    return arrayOp(cast(BinExp)e, sc);
}

/******************************************
 * Construct the identifier for the array operation function,
 * and build the argument list to pass to it.
 */
extern (C++) void buildArrayIdent(Expression e, OutBuffer* buf, Expressions* arguments)
{
    extern (C++) final class BuildArrayIdentVisitor : Visitor
    {
        alias visit = super.visit;
        OutBuffer* buf;
        Expressions* arguments;

    public:
        extern (D) this(OutBuffer* buf, Expressions* arguments)
        {
            this.buf = buf;
            this.arguments = arguments;
        }

        override void visit(Expression e)
        {
            buf.writestring("Exp");
            arguments.shift(e);
        }

        override void visit(CastExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tarray || tb.ty == Tsarray)
            {
                e.e1.accept(this);
            }
            else
                visit(cast(Expression)e);
        }

        override void visit(ArrayLiteralExp e)
        {
            buf.writestring("Slice");
            arguments.shift(e);
        }

        override void visit(SliceExp e)
        {
            buf.writestring("Slice");
            arguments.shift(e);
        }

        override void visit(AssignExp e)
        {
            /* Evaluate assign expressions right to left
             */
            e.e2.accept(this);
            e.e1.accept(this);
            buf.writestring("Assign");
        }

        override void visit(BinAssignExp e)
        {
            /* Evaluate assign expressions right to left
             */
            e.e2.accept(this);
            e.e1.accept(this);
            const(char)* s;
            switch (e.op)
            {
            case TOKaddass:
                s = "Addass";
                break;
            case TOKminass:
                s = "Subass";
                break;
            case TOKmulass:
                s = "Mulass";
                break;
            case TOKdivass:
                s = "Divass";
                break;
            case TOKmodass:
                s = "Modass";
                break;
            case TOKxorass:
                s = "Xorass";
                break;
            case TOKandass:
                s = "Andass";
                break;
            case TOKorass:
                s = "Orass";
                break;
            case TOKpowass:
                s = "Powass";
                break;
            default:
                assert(0);
            }
            buf.writestring(s);
        }

        override void visit(NegExp e)
        {
            e.e1.accept(this);
            buf.writestring("Neg");
        }

        override void visit(ComExp e)
        {
            e.e1.accept(this);
            buf.writestring("Com");
        }

        override void visit(BinExp e)
        {
            /* Evaluate assign expressions left to right
             */
            const(char)* s = null;
            switch (e.op)
            {
            case TOKadd:
                s = "Add";
                break;
            case TOKmin:
                s = "Sub";
                break;
            case TOKmul:
                s = "Mul";
                break;
            case TOKdiv:
                s = "Div";
                break;
            case TOKmod:
                s = "Mod";
                break;
            case TOKxor:
                s = "Xor";
                break;
            case TOKand:
                s = "And";
                break;
            case TOKor:
                s = "Or";
                break;
            case TOKpow:
                s = "Pow";
                break;
            default:
                break;
            }
            if (s)
            {
                Type tb = e.type.toBasetype();
                Type t1 = e.e1.type.toBasetype();
                Type t2 = e.e2.type.toBasetype();
                e.e1.accept(this);
                if (t1.ty == Tarray && (t2.ty == Tarray && !t1.equivalent(tb) || t2.ty != Tarray && !t1.nextOf().equivalent(e.e2.type)))
                {
                    // Bugzilla 12780: if A is narrower than B
                    //  A[] op B[]
                    //  A[] op B
                    buf.writestring("Of");
                    buf.writestring(t1.nextOf().mutableOf().deco);
                }
                e.e2.accept(this);
                if (t2.ty == Tarray && (t1.ty == Tarray && !t2.equivalent(tb) || t1.ty != Tarray && !t2.nextOf().equivalent(e.e1.type)))
                {
                    // Bugzilla 12780: if B is narrower than A:
                    //  A[] op B[]
                    //  A op B[]
                    buf.writestring("Of");
                    buf.writestring(t2.nextOf().mutableOf().deco);
                }
                buf.writestring(s);
            }
            else
                visit(cast(Expression)e);
        }
    }

    scope BuildArrayIdentVisitor v = new BuildArrayIdentVisitor(buf, arguments);
    e.accept(v);
}

/******************************************
 * Construct the inner loop for the array operation function,
 * and build the parameter list.
 */
extern (C++) Expression buildArrayLoop(Expression e, Parameters* fparams)
{
    extern (C++) final class BuildArrayLoopVisitor : Visitor
    {
        alias visit = super.visit;
        Parameters* fparams;
        Expression result;

    public:
        extern (D) this(Parameters* fparams)
        {
            this.fparams = fparams;
            this.result = null;
        }

        override void visit(Expression e)
        {
            Identifier id = Identifier.generateId("c", fparams.dim);
            auto param = new Parameter(0, e.type, id, null);
            fparams.shift(param);
            result = new IdentifierExp(Loc(), id);
        }

        override void visit(CastExp e)
        {
            Type tb = e.type.toBasetype();
            if (tb.ty == Tarray || tb.ty == Tsarray)
            {
                e.e1.accept(this);
            }
            else
                visit(cast(Expression)e);
        }

        override void visit(ArrayLiteralExp e)
        {
            Identifier id = Identifier.generateId("p", fparams.dim);
            auto param = new Parameter(STCconst, e.type, id, null);
            fparams.shift(param);
            Expression ie = new IdentifierExp(Loc(), id);
            Expression index = new IdentifierExp(Loc(), Id.p);
            result = new ArrayExp(Loc(), ie, index);
        }

        override void visit(SliceExp e)
        {
            Identifier id = Identifier.generateId("p", fparams.dim);
            auto param = new Parameter(STCconst, e.type, id, null);
            fparams.shift(param);
            Expression ie = new IdentifierExp(Loc(), id);
            Expression index = new IdentifierExp(Loc(), Id.p);
            result = new ArrayExp(Loc(), ie, index);
        }

        override void visit(AssignExp e)
        {
            /* Evaluate assign expressions right to left
             */
            Expression ex2 = buildArrayLoop(e.e2);
            /* Need the cast because:
             *   b = c + p[i];
             * where b is a byte fails because (c + p[i]) is an int
             * which cannot be implicitly cast to byte.
             */
            ex2 = new CastExp(Loc(), ex2, e.e1.type.nextOf());
            Expression ex1 = buildArrayLoop(e.e1);
            Parameter param = (*fparams)[0];
            param.storageClass = 0;
            result = new AssignExp(Loc(), ex1, ex2);
        }

        override void visit(BinAssignExp e)
        {
            /* Evaluate assign expressions right to left
             */
            Expression ex2 = buildArrayLoop(e.e2);
            Expression ex1 = buildArrayLoop(e.e1);
            Parameter param = (*fparams)[0];
            param.storageClass = 0;
            switch (e.op)
            {
            case TOKaddass:
                result = new AddAssignExp(e.loc, ex1, ex2);
                return;
            case TOKminass:
                result = new MinAssignExp(e.loc, ex1, ex2);
                return;
            case TOKmulass:
                result = new MulAssignExp(e.loc, ex1, ex2);
                return;
            case TOKdivass:
                result = new DivAssignExp(e.loc, ex1, ex2);
                return;
            case TOKmodass:
                result = new ModAssignExp(e.loc, ex1, ex2);
                return;
            case TOKxorass:
                result = new XorAssignExp(e.loc, ex1, ex2);
                return;
            case TOKandass:
                result = new AndAssignExp(e.loc, ex1, ex2);
                return;
            case TOKorass:
                result = new OrAssignExp(e.loc, ex1, ex2);
                return;
            case TOKpowass:
                result = new PowAssignExp(e.loc, ex1, ex2);
                return;
            default:
                assert(0);
            }
        }

        override void visit(NegExp e)
        {
            Expression ex1 = buildArrayLoop(e.e1);
            result = new NegExp(Loc(), ex1);
        }

        override void visit(ComExp e)
        {
            Expression ex1 = buildArrayLoop(e.e1);
            result = new ComExp(Loc(), ex1);
        }

        override void visit(BinExp e)
        {
            if (isBinArrayOp(e.op))
            {
                /* Evaluate assign expressions left to right
                 */
                BinExp be = cast(BinExp)e.copy();
                be.e1 = buildArrayLoop(be.e1);
                be.e2 = buildArrayLoop(be.e2);
                be.type = null;
                result = be;
                return;
            }
            else
            {
                visit(cast(Expression)e);
                return;
            }
        }

        Expression buildArrayLoop(Expression e)
        {
            e.accept(this);
            return result;
        }
    }

    scope BuildArrayLoopVisitor v = new BuildArrayLoopVisitor(fparams);
    return v.buildArrayLoop(e);
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
    //printf("Expression::isArrayOpOperand() %s\n", e->toChars());
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
        return (isUnaArrayOp(e.op) || isBinArrayOp(e.op) || isBinAssignArrayOp(e.op) || e.op == TOKassign);
    }
    return false;
}
