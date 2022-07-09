// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.expr;

import vdc.util;
import vdc.lexer;
import vdc.semantic;
import vdc.interpret;

import vdc.ast.node;
import vdc.ast.decl;
import vdc.ast.misc;
import vdc.ast.tmpl;
import vdc.ast.aggr;
import vdc.ast.mod;
import vdc.ast.type;
import vdc.ast.writer;

import vdc.parser.engine;

import stdext.util;
import std.conv;
import std.string;

////////////////////////////////////////////////////////////////
// Operator precedence - greater values are higher precedence
enum PREC
{
    zero,
    expr,
    assign,
    cond,
    oror,
    andand,
    or,
    xor,
    and,
    equal,
    rel,
    shift,
    add,
    mul,
    pow,
    unary,
    primary,
}
shared static PREC[NumTokens] precedence;

shared static char[NumTokens] recursion;

////////////////////////////////////////////////////////////////
void writeExpr(CodeWriter writer, Expression expr, bool paren)
{
    if(paren)
        writer("(");
    writer(expr);
    if(paren)
        writer(")");
}

enum Spaces
{
    None = 0,
    Left = 1,
    Right = 2,
    LeftRight = Left | Right
}

void writeOperator(CodeWriter writer, TokenId op, int spaces)
{
    if(spaces & Spaces.Left)
        writer(" ");
    writer(op);
    if(spaces & Spaces.Right)
        writer(" ");
}

////////////////////////////////////////////////////////////////
//Expression:
class Expression : Node
{
    // semantic data
    Type type;

    mixin ForwardCtor!();

    abstract PREC getPrecedence();

    override Type calcType()
    {
        if(!type)
            return semanticErrorType(this, ".calcType not implemented");
        return type;
    }
}

//BinaryExpression:
//    [Expression Expression]
class BinaryExpression : Expression
{
    mixin ForwardCtor!();

    TokenId getOperator() { return id; }
    Expression getLeftExpr() { return getMember!Expression(0); }
    Expression getRightExpr() { return getMember!Expression(1); }

    override PREC getPrecedence() { return precedence[id]; }
    bool isAssign() { return false; }

    override void _semantic(Scope sc)
    {
        getLeftExpr().semantic(sc);
        getRightExpr().semantic(sc);
    }

    override void toD(CodeWriter writer)
    {
        Expression exprL = getLeftExpr();
        Expression exprR = getRightExpr();

        bool parenL = (exprL.getPrecedence() < getPrecedence() + (recursion[id] == 'L' ? 0 : 1));
        bool parenR = (exprR.getPrecedence() < getPrecedence() + (recursion[id] == 'R' ? 0 : 1));

        writeExpr(writer, exprL, parenL);
        writeOperator(writer, id, Spaces.LeftRight);
        writeExpr(writer, exprR, parenR);
    }

    override Type calcType()
    {
        if(!type)
        {
            Type typeL = getLeftExpr().calcType();
            Type typeR = getRightExpr().calcType();
            type = typeL.commonType(typeR);
        }
        return type;
    }

    override Value interpret(Context sc)
    {
        Value vL, vR;
        if(isAssign())
        {
            // right side evaluated first in assignments
            vR = getRightExpr().interpret(sc);
            vL = getLeftExpr().interpret(sc);
        }
        else
        {
            vL = getLeftExpr().interpret(sc);
            vR = getRightExpr().interpret(sc);
        }
version(all)
{
        auto btL = cast(BasicType) vL.getType();
        auto avR = cast(ArrayValueBase) vR;
        if(btL && avR)
            return vR.opBin_r(sc, id, vL);
        return vL.opBin(sc, id, vR);
}
else
        switch(id)
        {
            case TOK_equal:        return vL.opBinOp!"=="(vR);
            case TOK_notequal:  return vL.opBinOp!"!="(vR);
            case TOK_lt:        return vL.opBinOp!"<"(vR);
            case TOK_gt:        return vL.opBinOp!">"(vR);
            case TOK_le:        return vL.opBinOp!"<="(vR);
            case TOK_ge:        return vL.opBinOp!">="(vR);
            case TOK_unord:        return vL.opBinOp!"!<>="(vR);
            case TOK_ue:        return vL.opBinOp!"!<>"(vR);
            case TOK_lg:        return vL.opBinOp!"<>"(vR);
            case TOK_leg:        return vL.opBinOp!"<>="(vR);
            case TOK_ule:        return vL.opBinOp!"!>"(vR);
            case TOK_ul:        return vL.opBinOp!"!>="(vR);
            case TOK_uge:        return vL.opBinOp!"!<"(vR);
            case TOK_ug:        return vL.opBinOp!"!<="(vR);
            case TOK_is:        return vL.opBinOp!"is"(vR);
            case TOK_notcontains:return vL.opBinOp!"!in"(vR);
            case TOK_notidentity:return vL.opBinOp!"!is"(vR);

            case TOK_shl:        return vL.opBinOp!"<<"(vR);
            case TOK_shr:        return vL.opBinOp!">>"(vR);
            case TOK_ushr:        return vL.opBinOp!">>>"(vR);

            case TOK_add:        return vL.opBinOp!"+"(vR);
            case TOK_min:        return vL.opBinOp!"-"(vR);
            case TOK_mul:        return vL.opBinOp!"*"(vR);
            case TOK_pow:        return vL.opBinOp!"^^"(vR);

            case TOK_div:        return vL.opBinOp!"/"(vR);
            case TOK_mod:        return vL.opBinOp!"%"(vR);
    //[ "slice",            ".." ],
    //[ "dotdotdot",        "..." ],
            case TOK_xor:        return vL.opBinOp!"^"(vR);
            case TOK_and:        return vL.opBinOp!"&"(vR);
            case TOK_or:        return vL.opBinOp!"|"(vR);
            case TOK_tilde:        return vL.opBinOp!"~"(vR);
    //[ "plusplus",         "++" ],
    //[ "minusminus",       "--" ],
    //[ "question",         "?" ],
            case TOK_assign:    return vL.opassign!"="(vR);
            case TOK_addass:    return vL.opassign!"+="(vR);
            case TOK_minass:    return vL.opassign!"-="(vR);
            case TOK_mulass:    return vL.opassign!"*="(vR);
            case TOK_powass:    return vL.opassign!"^^="(vR);

            case TOK_shlass:    return vL.opassign!"<<="(vR);
            case TOK_shrass:    return vL.opassign!">>="(vR);
            case TOK_ushrass:    return vL.opassign!">>>="(vR);
            case TOK_xorass:    return vL.opassign!"^="(vR);
            case TOK_andass:    return vL.opassign!"&="(vR);
            case TOK_orass:        return vL.opassign!"|="(vR);
            case TOK_catass:    return vL.opassign!"~="(vR);

            case TOK_divass:    return vL.opassign!"/="(vR);
            case TOK_modass:    return vL.opassign!"%="(vR);

            default:
                return semanticErrorType("interpretation of binary operator ", tokenString(id), " not implemented");
        }
    }

};

mixin template BinaryExpr()
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
    }
}

class CommaExpression : BinaryExpression
{
    mixin BinaryExpr!();

    override Type calcType()
    {
        return getRightExpr().calcType();
    }
}

class AssignExpression : BinaryExpression
{
    override bool isAssign() { return true; }

    mixin BinaryExpr!();

    override Type calcType()
    {
        return getLeftExpr().calcType();
    }
}

//ConditionalExpression:
//    [Expression Expression Expression]
class ConditionalExpression : Expression
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
    }

    Expression getCondition() { return getMember!Expression(0); }
    Expression getThenExpr() { return getMember!Expression(1); }
    Expression getElseExpr() { return getMember!Expression(2); }

    override PREC getPrecedence() { return PREC.cond; }

    override void _semantic(Scope sc)
    {
        getCondition().semantic(sc);
        getThenExpr().semantic(sc);
        getElseExpr().semantic(sc);
    }

    override void toD(CodeWriter writer)
    {
        Expression condExpr = getCondition();
        Expression thenExpr = getThenExpr();
        Expression elseExpr = getElseExpr();

        bool condParen = (condExpr.getPrecedence() <= getPrecedence());
        bool thenParen = (thenExpr.getPrecedence() < PREC.expr);
        bool elseParen = (elseExpr.getPrecedence() < getPrecedence());

        writeExpr(writer, condExpr, condParen);
        writeOperator(writer, TOK_question, Spaces.LeftRight);
        writeExpr(writer, thenExpr, thenParen);
        writeOperator(writer, TOK_colon, Spaces.LeftRight);
        writeExpr(writer, elseExpr, elseParen);
    }

    override Type calcType()
    {
        if(!type)
        {
            Type typeL = getThenExpr().calcType();
            Type typeR = getElseExpr().calcType();
            type = typeL.commonType(typeR);
        }
        return type;
    }

    override Value interpret(Context sc)
    {
        Value cond = getCondition().interpret(sc);
        Expression e = (cond.toBool() ? getThenExpr() : getElseExpr());
        return e.interpret(sc); // TODO: cast to common type
    }
}

class OrOrExpression : BinaryExpression
{
    mixin BinaryExpr!();

    override Type calcType()
    {
        if(!type)
            type = createBasicType(TOK_bool);
        return type;
    }

    override Value interpret(Context sc)
    {
        Value vL = getLeftExpr().interpret(sc);
        if(vL.toBool())
            return Value.create(true);
        Value vR = getRightExpr().interpret(sc);
        return Value.create(vR.toBool());
    }
}

class AndAndExpression : BinaryExpression
{
    mixin BinaryExpr!();

    override Type calcType()
    {
        if(!type)
            type = createBasicType(TOK_bool);
        return type;
    }

    override Value interpret(Context sc)
    {
        Value vL = getLeftExpr().interpret(sc);
        if(!vL.toBool())
            return Value.create(false);
        Value vR = getRightExpr().interpret(sc);
        return Value.create(vR.toBool());
    }
}

class OrExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class XorExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class AndExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class CmpExpression : BinaryExpression
{
    mixin BinaryExpr!();

    void _checkIdentityLiterals()
    {
        if(id == TOK_is || id == TOK_notidentity)
        {
            if(auto litL = cast(IntegerLiteralExpression) getLeftExpr())
                litL.forceLargerType(getRightExpr().calcType());
            if(auto litR = cast(IntegerLiteralExpression) getRightExpr())
                litR.forceLargerType(getLeftExpr().calcType());
        }
    }

    override Type calcType()
    {
        if(!type)
        {
            _checkIdentityLiterals();
            if(id == TOK_in)
            {
                auto t = getRightExpr().calcType();
                if(auto ti = cast(TypeIndirection)t)
                {
                    auto tp = new TypePointer();
                    tp.setNextType(ti.getNextType());
                    type = tp;
                }
                else
                    type = semanticErrorType("cannot calculate type of operator in on ", t);
            }
            else
                type = createBasicType(TOK_bool);
        }
        return type;
    }

    override void _semantic(Scope sc)
    {
        _checkIdentityLiterals();
        getLeftExpr().semantic(sc);
        getRightExpr().semantic(sc);
    }
}

class ShiftExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class AddExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class MulExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

class PowExpression : BinaryExpression
{
    mixin BinaryExpr!();
}

//UnaryExpression:
//    id [Expression]
class UnaryExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.unary; }

    Expression getExpression() { return getMember!Expression(0); }

    override void _semantic(Scope sc)
    {
        getExpression().semantic(sc);
    }

    override Type calcType()
    {
        if(!type)
        {
            Type exprtype = getExpression().calcType();
            switch(id)
            {
                default:
                    type = exprtype;
                    break;
                case TOK_delete:
                    type = createBasicType(TOK_void);
                    break;
                case TOK_not:
                    type = createBasicType(TOK_bool);
                    break;
            }
        }
        return type;
    }

    override Value interpret(Context sc)
    {
        Value v = getExpression().interpret(sc);
version(all)
        switch(id)
        {
            case TOK_plusplus:
                return v.opBin(sc, TOK_addass, Value.create(cast(byte)1));
            case TOK_minusminus:
                return v.opBin(sc, TOK_minass, Value.create(cast(byte)1));
            case TOK_delete:
                // TODO: call destructor?
                v.opBin(sc, TOK_assign, v.getType().createValue(sc, null));
                return theVoidValue;
            default:
                return v.opUn(sc, id);
        }
else
        switch(id)
        {
            case TOK_and:        return v.opRefPointer();
            case TOK_mul:        return v.opDerefPointer();
            case TOK_plusplus:   return v.opUnOp!"++"();
            case TOK_minusminus: return v.opUnOp!"--"();
            case TOK_min:        return v.opUnOp!"-"();
            case TOK_add:        return v.opUnOp!"+"();
            case TOK_not:        return v.opUnOp!"!"();
            case TOK_tilde:      return v.opUnOp!"~"();
            default:
                return semanticErrorValue("interpretation of unary operator ", tokenString(id), " not implemented");
        }
    }

    override void toD(CodeWriter writer)
    {
        Expression expr = getExpression();
        bool paren = (expr.getPrecedence() < getPrecedence());

        writeOperator(writer, id, Spaces.Right);
        writeExpr(writer, expr, paren);
    }
}

//NewExpression:
//    NewArguments Type [ AssignExpression ]
//    NewArguments Type ( ArgumentList )
//    NewArguments Type
//    NewArguments ClassArguments BaseClassList_opt { DeclDefs }
class NewExpression : Expression
{
    bool hasNewArgs;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK_new, tok.span);
    }

    override NewExpression clone()
    {
        NewExpression n = static_cast!NewExpression(super.clone());
        n.hasNewArgs = hasNewArgs;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.hasNewArgs == hasNewArgs;
    }

    override PREC getPrecedence() { return PREC.unary; }

    ArgumentList getNewArguments() { return hasNewArgs ? getMember!ArgumentList(0) : null; }
    Type getType() { return getMember!Type(hasNewArgs ? 1 : 0); }
    ArgumentList getCtorArguments() { return members.length > (hasNewArgs ? 2 : 1) ? getMember!ArgumentList(members.length - 1) : null; }

    override void _semantic(Scope sc)
    {
        if(auto args = getNewArguments())
            args.semantic(sc);
        getType().semantic(sc);
        if(auto args = getCtorArguments())
            args.semantic(sc);
    }

    override Type calcType()
    {
        return getType().calcType();
    }

    override Value interpret(Context sc)
    {
        Value initVal;
        if(auto args = getCtorArguments())
            initVal = args.interpret(sc);
        else
            initVal = new TupleValue; // empty args force new instance
        return calcType().createValue(sc, initVal);
    }

    override void toD(CodeWriter writer)
    {
        if(ArgumentList nargs = getNewArguments())
            writer("new(", nargs, ") ");
        else
            writer("new ");
        writer(getType());
        if(ArgumentList cargs = getCtorArguments())
            writer("(", cargs, ")");
    }
}

class AnonymousClassType : Type
{
    mixin ForwardCtor!();

    ArgumentList getArguments() { return members.length > 1 ? getMember!ArgumentList(0) : null; }
    AnonymousClass getClass() { return getMember!AnonymousClass(members.length - 1); }

    override bool propertyNeedsParens() const { return true; }

    override void toD(CodeWriter writer)
    {
        if(ArgumentList args = getArguments())
            writer("class(", args, ") ");
        else
            writer("class ");
        writer(getClass());
    }

    override Type calcType()
    {
        return getClass().calcType();
    }

}

//CastExpression:
//    attr [Type_opt Expression]
class CastExpression : Expression
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK_cast, tok.span);
    }

    override PREC getPrecedence() { return PREC.unary; }

    Type getType() { return members.length > 1 ? getMember!Type(0) : null; }
    Expression getExpression() { return getMember!Expression(members.length - 1); }

    override void toD(CodeWriter writer)
    {
        writer("cast(");
        writer.writeAttributesAndAnnotations(attr, annotation);
        if(Type type = getType())
            writer(getType());
        writer(")");

        if(getExpression().getPrecedence() < getPrecedence())
            writer("(", getExpression(), ")");
        else
            writer(getExpression());
    }

    override void _semantic(Scope sc)
    {
        if(auto type = getType())
            type.semantic(sc);
        getExpression().semantic(sc);
    }

    override Type calcType()
    {
        if(type)
            return type;

        if(auto t = getType())
            type = getType().calcType();
        else
        {
            // extract basic type and attributes from expression
            Type t = getExpression().calcType();
            Attribute mattr = 0;
            while(t)
            {
                auto mf = cast(ModifiedType) t;
                if(!mf)
                    break;
                mattr |= tokenToAttribute(mf.id);
                t = mf.getType();
            }
            assert(t);
            if(mattr != attr)
            {
                // rebuild modified type
                for(Attribute a = attr, ta; a; a -= ta)
                {
                    ta = a & -a;
                    TokenId aid = attributeToToken(attr);
                    auto mt = new ModifiedType(aid, span);
                    mt.addMember(t);
                    t = mt;
                }
            }
            type = t;
        }
        return type;
    }

    override Value interpret(Context sc)
    {
        Value val = getExpression().interpret(sc);
        Type t = calcType();
        Type vt = val.getType();
        if(t.compare(vt))
            return val;
        Value v = t.createValue(sc, null);
        return v.doCast(val);
    }
}

//PostfixExpression:
//    PrimaryExpression
//    PostfixExpression . Identifier
//    PostfixExpression . NewExpression
//    PostfixExpression ++
//    PostfixExpression --
//    PostfixExpression ( )
//    PostfixExpression ( ArgumentList )
//    IndexExpression
//    SliceExpression
//
//IndexExpression:
//    PostfixExpression [ ArgumentList ]
//
//SliceExpression:
//    PostfixExpression [ ]
//    PostfixExpression [ AssignExpression .. AssignExpression ]
class PostfixExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    Expression getExpression() { return getMember!Expression(0); }

    override Type calcType()
    {
        if(type)
            return type;

        auto expr = getExpression();
        auto etype = expr.calcType();
        switch(id)
        {
            // TOK_dot handled by DotExpression
            case TOK_lbracket:
                if(members.length == 2) // if slice, same type as expression
                {
                    auto args = getMember!ArgumentList(1);
                    auto vidx = args.interpret(nullContext);
                    Value idx;
                    if(vidx.values.length != 1)
                        return semanticErrorType("exactly one value expected as array index");
                    idx = vidx.values[0];
                    type = etype.opIndex(idx.toInt());
                }
                else if(members.length == 3)
                {
                    Scope sc = getScope();
                    Value beg = getMember(1).interpret(nullContext);
                    Value end = getMember(2).interpret(nullContext);
                    type = etype.opSlice(beg.toInt(), end.toInt());
                }
                else
                {
                    assert(members.length == 1);  // full slice
                    type = etype;
                }
                break;
            case TOK_lparen:
                Type args;
                if(members.length == 2)
                    args = getMember!ArgumentList(1).calcType();
                else
                    args = new TypeArraySlice;
                type = etype.opCall(args);
                break;
            default:
                type = semanticErrorType("cannot determine type of ", this);
                break;
        }
        return type;
    }

    override ArgumentList getFunctionArguments()
    {
        switch(id)
        {
            case TOK_lparen:
                if(members.length == 2)
                    return getMember!ArgumentList(1);
                return new ArgumentList;
            default:
                return null;
        }
    }

    override Value interpret(Context sc)
    {
        Expression expr = getExpression();
        Value val = expr.interpret(sc);
        switch(id)
        {
            // TOK_dot handled by DotExpression
            case TOK_lbracket:
                if(members.length == 2)
                {
                    auto args = getMember!ArgumentList(1);
                    auto vidx = args.interpret(sc);
                    Value idx;
                    if(vidx.values.length != 1)
                        return semanticErrorValue("exactly one value expected as array index");
                    idx = vidx.values[0];
                    return val.opIndex(idx);
                }
                else if(members.length == 3)
                {
                    Value beg = getMember(1).interpret(sc);
                    Value end = getMember(2).interpret(sc);
                    return val.opSlice(beg, end);
                }
                assert(members.length == 1);  // full slice
                Node nodelen = val.getType().getScope().resolve("length", val.getType(), false);
                if(nodelen)
                    return val.opSlice(Value.create(0), nodelen.interpret(sc));
                return val;

            case TOK_lparen:
                TupleValue args;
                if(members.length == 2)
                    args = getMember!ArgumentList(1).interpret(sc);
                else
                    args = new TupleValue;
                return val.opCall(sc, args);

            case TOK_plusplus:
                Value v2 = val.getType().createValue(sc, val);
                val.opBin(sc, TOK_addass, Value.create(cast(byte)1));
                return v2;
            case TOK_minusminus:
                Value v2 = val.getType().createValue(sc, val);
                val.opBin(sc, TOK_minass, Value.create(cast(byte)1));
                return v2;
            case TOK_new:
            default:
                return super.interpret(sc);
        }
    }

    override void toD(CodeWriter writer)
    {
        Expression expr = getExpression();
        bool paren = (expr.getPrecedence() < getPrecedence());

        writeExpr(writer, expr, paren);
        switch(id)
        {
            case TOK_lbracket:
                writer("[");
                if(members.length == 2)
                    writer(getMember!ArgumentList(1));
                else if(members.length == 3)
                {
                    writer(getMember!Expression(1));
                    writer(" .. ");
                    writer(getMember!Expression(2));
                }
                writer("]");
                break;

            case TOK_lparen:
                writer("(");
                if(members.length > 1)
                    writer(getMember!ArgumentList(1));
                writer(")");
                break;

            case TOK_dot:
            case TOK_new:
                writer(".", getMember(1));
                break;

            default:
                writeOperator(writer, id, Spaces.Right);
                break;
        }
    }
}

class DotExpression : PostfixExpression
{
    mixin ForwardCtor!();

    Identifier getIdentifier() { return id == TOK_new ? null : getMember!Identifier(1); }

    Node resolved;

    override Node resolve()
    {
        if(resolved)
            return resolved;

        auto expr = getExpression();
        auto etype = expr.calcType();
        switch(id)
        {
            case TOK_new:
                auto nexpr = getMember!NewExpression(1);
                resolved = nexpr.calcType();
                break;
            default:
                auto id = getMember!Identifier(1);
                if(auto pt = cast(TypePointer)etype)
                    etype = pt.getNextType();
                Scope s = etype.getScope();
                resolved = s ? s.resolve(id.ident, id, false) : null;
                break;
        }
        return resolved;
    }

    override Type calcType()
    {
        if(type)
            return type;

        if(auto n = resolve())
            type = n.calcType();
        else if(id == TOK_new)
            type = semanticErrorType("cannot resolve type of new expression ", getMember(1));
        else
            type = semanticErrorType("cannot resolve type of property ", getMember!Identifier(1).ident);
        return type;
    }

    override Value interpret(Context sc)
    {
        Expression expr = getExpression();
        Value val = expr.interpret(sc);

        if(!type)
            calcType();
        if(!resolved)
            return Singleton!ErrorValue.get(); // calcType already produced an error

        //auto id = getMember!Identifier(1);
        auto ctx = new AggrContext(sc, val);
        if(expr.id == TOK_super)
            ctx.virtualCall = false;
        return resolved.interpret(ctx);
    }
}

//ArgumentList:
//    [Expression...]
class ArgumentList : Node
{
    mixin ForwardCtor!();

    override void _semantic(Scope sc)
    {
        foreach(m; members)
            m.semantic(sc);
    }

    override TupleValue interpret(Context sc)
    {
        TupleValue args = new TupleValue;
        foreach(m; members)
            args.addValue(m.interpret(sc));
        return args;
    }

    override void toD(CodeWriter writer)
    {
        bool writeSep = false;
        foreach(m; members)
        {
            if(writeSep)
                writer(", ");
            writeSep = true;

            bool paren = false;
            if(auto expr = cast(Expression) m)
                paren = (expr.getPrecedence() <= PREC.expr);

            if(paren)
                writer("(", m, ")");
            else
                writer(m);
        }
    }
}

//PrimaryExpression:
//    Identifier
//    . Identifier
//    TemplateInstance
//    this
//    super
//    null
//    true
//    false
//    $
//    __FILE__
//    __LINE__
//    IntegerLiteral
//    FloatLiteral
//    CharacterLiteral
//    StringLiterals
//    ArrayLiteral
//    AssocArrayLiteral
//    Lambda
//    FunctionLiteral
//    AssertExpression
//    MixinExpression
//    ImportExpression
//    TypeProperty
//    Typeof
//    TypeidExpression
//    IsExpression
//    ( Expression )
//    ( Type ) . Identifier
//    TraitsExpression

class PrimaryExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    override Value interpret(Context sc)
    {
        switch(id)
        {
            case TOK_super:
            case TOK_this:
                Value v = sc ? sc.getThis() : null;
                if(!v)
                    return semanticErrorValue("this needs context");
                return v;

            case TOK_true:  return Value.create(true);
            case TOK_false: return Value.create(false);
            case TOK_null:  return new NullValue;
            case TOK___LINE__: return Value.create(span.start.line);
            case TOK___FILE__: return createStringValue(getModuleFilename());
            case TOK_dollar:
            default:        return super.interpret(sc);
        }
    }

    override Type calcType()
    {
        if(type)
            return type;

        switch(id)
        {
            case TOK_this:
            case TOK_super:
                auto sc = getScope();
                type = sc ? sc.getThisType() : null;
                if(id == TOK_super)
                    if(auto clss = cast(Class)type)
                        if(auto bc = clss.getBaseClass())
                            type = bc.calcType();
                if(!type)
                    type = semanticErrorType("this needs context");
                break;

            case TOK_true:
            case TOK_false:
                type = createBasicType(TOK_bool);
                break;

            case TOK_null:
                type = Singleton!NullType.get();
                break;

            case TOK_dollar:
            case TOK___LINE__:
                type = createBasicType(TOK_uint);
                break;

            case TOK___FILE__:
                type = getTypeString!char();
                break;
            default:
                return super.calcType();
        }
        return type;
    }

    override void toD(CodeWriter writer)
    {
        writer(id);
    }
}

//ArrayLiteral:
//    [ ArgumentList ]
class ArrayLiteral : Expression
{
    bool isAssoc;

    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    ArgumentList getArgumentList() { return getMember!ArgumentList(0); }

    override void toD(CodeWriter writer)
    {
        writer("[");
        writer.writeArray(members);
        writer("]");
    }

    override void _semantic(Scope sc)
    {
        super._semantic(sc);

        auto argl = getArgumentList();
        int cntPairs = 0;
        int cntIndex = 0;
        foreach(m; argl.members)
        {
            m.semantic(sc);
            if(auto kv = cast(KeyValuePair) m)
            {
                Type kt = kv.getKey().calcType();
                Type st = BasicType.getSizeType();
                if(st.convertableFrom(kt, Type.ConversionFlags.kImpliciteConversion))
                    cntIndex++;
                cntPairs++;
            }
            else
                break;
        }
        if(cntPairs == argl.members.length && cntIndex < argl.members.length)
            isAssoc = true;

        if(!isAssoc)
        {
            type = new TypeDynamicArray;
            if(argl.members.length)
            {
                Type vt = argl.members[0].calcType();
                foreach(m; argl.members[1..$])
                    vt = vt.commonType(m.calcType());
                type.addMember(vt.clone());
            }
            else
                type.addMember(new AutoType(TOK_auto, span));
        }
    }

    override Type calcType()
    {
        if(type)
            return type;
        semantic(getScope());
        return type;
    }

    override Value interpret(Context sc)
    {
        TupleValue val;
        if(auto args = getArgumentList())
            val = args.interpret(sc);
        else
            val = new TupleValue;

        if(auto tda = cast(TypeDynamicArray) calcType())
        {
            auto telem = tda.getNextType();
            auto vda = new DynArrayValue(tda);
            vda.setLength(sc, val.values.length);
            for(size_t i = 0; i < val.values.length; i++)
                vda.setItem(sc, i, val.values[i]);
            debug vda.sval = vda.toStr();
            return vda;
        }
        return val;
    }
}

//VoidInitializer:
//    void
class VoidInitializer : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    override Type calcType()
    {
        if(!type)
            type = createBasicType(TOK_void);
        return type;
    }
    override void toD(CodeWriter writer)
    {
        writer("void");
    }
    override Value interpret(Context sc)
    {
        return theVoidValue();
    }
}

// used for Expression_opt in for and return statements
class EmptyExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.expr; }

    override void toD(CodeWriter writer)
    {
    }
}


//KeyValuePair:
//    [Expression Expression]
class KeyValuePair : BinaryExpression
{
    mixin ForwardCtor!();

    static this()
    {
        precedence[TOK_colon] = PREC.assign;
    }

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK_colon, tok.span);
    }

    Expression getKey() { return getMember!Expression(0); }
    Expression getValue() { return getMember!Expression(1); }
}

//FunctionLiteral:
//    id [ Type_opt ParameterList_opt FunctionBody ] attr
class FunctionLiteral : Expression
{
    mixin ForwardCtor!();

    Type getType() { return members.length > 2 ? getMember!Type(0) : null; }
    override ParameterList getParameterList() { return getMember!ParameterList(members.length - 2); }
    FunctionBody getFunctionBody() { return getMember!FunctionBody(members.length - 1); }

    override PREC getPrecedence() { return PREC.primary; }

    override void toD(CodeWriter writer)
    {
        if(id != 0)
            writer(id, " ");
        if(Type type = getType())
            writer(type, " ");
        writer(getParameterList(), " ");
        writer.writeAttributesAndAnnotations(attr, annotation, false);
        writer(getFunctionBody());
    }

    override bool createsScope() const { return true; }

    override void _semantic(Scope sc)
    {
        if(auto t = getType())
            t.semantic(sc);

        sc = enterScope(sc);
        getFunctionBody().semantic(sc);
        sc = sc.pop();
    }

    TypeFunction func;

    override Type calcType()
    {
        if(!func)
        {
            auto pl = getParameterList();
            if(!pl)
                pl = new ParameterList();

            if(id == TOK_function)
            {
                auto funclit = new TypeFunctionLiteral;
                funclit.paramList = pl;
                func = funclit;
            }
            else
            {
                auto funclit = new TypeDelegateLiteral;
                funclit.paramList = pl;
                func = funclit;
            }
            /+
            auto rt = getType();
            if(!rt)
            rt = new AutoType(TOK_auto, span);
            else
            rt = rt.clone();
            func.addMember(rt);

            auto pl = getParameterList();
            if(!pl)
            pl = new ParameterList();
            else
            pl = pl.clone();
            func.addMember(pl);
            +/

            auto decl = new FuncLiteralDeclarator;
            decl.type = func;
            decl.funcbody = getFunctionBody();
            func.funcDecl = decl;
        }
        return func;
    }

    override Value interpret(Context sc)
    {
        if(!func)
            calcType();

        if(id == TOK_function)
        {
            auto fn = new FunctionValue;
            fn.functype = func;
            return fn;
        }
        else
        {
            auto dg = new DelegateValue;
            dg.context = sc;
            dg.functype = func;
            return dg;
        }
    }
}

//Lambda:
//    [ ParameterList Expression ]
class Lambda : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0), " => ", getMember(1));
    }
}

class TypeFunctionLiteral : TypeFunction
{
    override Type getReturnType()
    {
        if (returnType)
            return returnType;
        if(members.length)
            returnType = getMember!Type(0);

        // TODO: infer return type from code
        if (!returnType)
            returnType = new AutoType;
        return returnType;
    }
}

class TypeDelegateLiteral : TypeDelegate
{
    override Type getReturnType()
    {
        if (returnType)
            return returnType;
        if(members.length)
            returnType = getMember!Type(0);

        // TODO: infer return type from code
        if (!returnType)
            returnType = new AutoType;
        return returnType;
    }
}

class FuncLiteralDeclarator : Declarator
{
    FunctionBody funcbody;

    override Value interpretCall(Context sc)
    {
        return funcbody.interpret(sc);
    }
}

//StructLiteral:
//    [ArrayValueList]
class StructLiteral : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    override void toD(CodeWriter writer)
    {
        writer("{ ", getMember(0), " }");
    }

    override Value interpret(Context sc)
    {
        return getMember(0).interpret(sc);
    }
}

//AssertExpression:
//    assert ( AssignExpression )
//    assert ( AssignExpression , AssignExpression )
class AssertExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    Expression getExpression() { return getMember!Expression(0); }
    Expression getMessage() { return getMember!Expression(1); }

    override void toD(CodeWriter writer)
    {
        writer("assert(");
        writer(getExpression());
        if(Expression msg = getMessage())
            writer(", ", msg);
        writer(")");
    }

    override Value interpret(Context sc)
    {
        auto actx = new AssertContext(sc);
        auto cond = getExpression().interpret(actx);
        if(!cond.toBool())
        {
            string msg;
            if(auto m = getMessage())
                msg = m.interpret(sc).toMixin();
            else
                msg = "assertion " ~ writeD(getExpression()) ~ " failed";
            foreach(id, val; actx.identVal)
                msg ~= "\n\t" ~ writeD(id) ~ " = " ~ val.toStr();
            return semanticErrorValue(msg);
        }
        return theVoidValue;
    }
}

//MixinExpression:
//    mixin ( AssignExpression )
class MixinExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    Expression getExpression() { return getMember!Expression(0); }

    Expression resolved;

    override void toD(CodeWriter writer)
    {
        if(resolved)
            resolved.toD(writer);
        else
            writer("mixin(", getMember!Expression(0), ")");
    }

    override void _semantic(Scope sc)
    {
        if(resolved)
            return;

        Value v = getMember(0).interpretCatch(nullContext);
        string s = v.toMixin();
        Parser parser = new Parser;
        if(auto prj = sc.getProject())
            parser.saveErrors = prj.saveErrors;

        Node n = parser.parseExpression(s, span);
        resolved = cast(Expression) n;
        if(resolved)
        {
            addMember(resolved);
            resolved.semantic(sc);
        }
    }

    override Type calcType()
    {
        if(!resolved)
            semantic(getScope());
        if(resolved)
            return resolved.calcType();
        return new ErrorType;
    }

    override Value interpret(Context sc)
    {
        if(!resolved)
            semantic(getScope());
        if(resolved)
            return resolved.interpret(sc);
        return semanticErrorValue("cannot interpret mixin");
    }
}

//ImportExpression:
//    import ( AssignExpression )
class ImportExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    Expression getExpression() { return getMember!Expression(0); }

    override Type calcType()
    {
        if(!type)
            type = getTypeString!char();
        return type;
    }
    override void toD(CodeWriter writer)
    {
        writer("import(", getMember!Expression(0), ")");
    }
}

//TypeidExpression:
//    typeid ( Type )
//    typeid ( Expression )
class TypeIdExpression : Expression
{
    mixin ForwardCtor!();

    override PREC getPrecedence() { return PREC.primary; }

    override void toD(CodeWriter writer)
    {
        writer("typeid(", getMember(0), ")");
    }
}

//IsExpression:
//    is ( Type )
//    is ( Type : TypeSpecialization )
//    is ( Type == TypeSpecialization )
//    is ( Type Identifier )
//    is ( Type Identifier : TypeSpecialization )
//    is ( Type Identifier == TypeSpecialization )
//    is ( Type Identifier : TypeSpecialization , TemplateParameterList )
//    is ( Type Identifier == TypeSpecialization , TemplateParameterList )
//
//TypeSpecialization:
//    Type
//    struct
//    union
//    class
//    interface
//    enum
//    function
//    delegate
//    super
//    const
//    immutable
//    inout
//    shared
//    return
//
class IsExpression : PrimaryExpression
{
    int kind;
    string ident;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK_is, tok.span);
    }

    override IsExpression clone()
    {
        IsExpression n = static_cast!IsExpression(super.clone());
        n.kind = kind;
        n.ident = ident;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.kind == kind
            && tn.ident == ident;
    }

    Type getType() { return getMember!Type(0); }
    TypeSpecialization getTypeSpecialization() { return members.length > 1 ? getMember!TypeSpecialization(1) : null; }

    override void toD(CodeWriter writer)
    {
        writer("is(", getType());
        if(ident.length)
        {
            writer(" ");
            writer.writeIdentifier(ident);
        }
        if(kind != 0)
            writer(" ", kind, " ");
        if(auto ts = getTypeSpecialization())
            writer(ts);
        writer(")");
    }

    override Type calcType()
    {
        if(!type)
            type = createBasicType(TOK_bool);
        return type;
    }
}

class TypeSpecialization : Node
{
    mixin ForwardCtor!();

    Type getType() { return getMember!Type(0); }

    override void toD(CodeWriter writer)
    {
        if(id != 0)
            writer(id);
        else
            writer(getMember(0));
    }
}

class IdentifierExpression : PrimaryExpression
{
    bool global;

    // semantic data
    Node resolved;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK_Identifier, tok.span);
    }

    override IdentifierExpression clone()
    {
        IdentifierExpression n = static_cast!IdentifierExpression(super.clone());
        n.global = global;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.global == global;
    }

    Identifier getIdentifier() { return getMember!Identifier(0); }

    override void toD(CodeWriter writer)
    {
        if(global)
            writer(".");
        writer(getIdentifier());
    }

    override void toC(CodeWriter writer)
    {
        //resolve();
        if(resolved)
        {
            Module thisMod = getModule();
            Module thatMod = resolved.getModule();
            if(global || thisMod is thatMod)
            {
                thatMod.writeNamespace(writer);
            }
        }
        writer(getIdentifier());
    }

    override Node resolve()
    {
        if(resolved)
            return resolved;

        if(!scop)
            semantic(getScope());
        auto id = getIdentifier();
        resolved = scop.resolveWithTemplate(id.ident, scop, id);
        return resolved;
    }

    override void _semantic(Scope sc)
    {
        if(global)
            scop = getModule().scop;
        else
            scop = sc;

        resolve();
    }

    override Type calcType()
    {
        if(type)
            return type;
        if(!scop)
            semantic(getScope());
        if(resolved)
            type = resolved.calcType();
        if(!type)
            return semanticErrorType("cannot determine type");
        return type;
    }

    override ArgumentList getFunctionArguments()
    {
        if(parent)
            return parent.getFunctionArguments();
        return null;
    }

    override Value interpret(Context sc)
    {
        if(!resolved)
            semantic(getScope());
        if(!resolved)
            return semanticErrorValue("unresolved identifier ", writeD(this));
        Value v = resolved.interpret(sc);
        if(auto actx = cast(AssertContext)sc)
            actx.identVal[this] = v;
        return v;
    }
}

class IntegerLiteralExpression : PrimaryExpression
{
    string txt;

    ulong value; // literals are never negative by themselves
    bool unsigned;
    bool lng;

    bool forceInt; // set in semantic pass
    bool forceShort;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        txt = tok.txt;
        initValue();
    }

    void initValue()
    {
        string val = txt;
        while(val.length > 1)
        {
            if(val[$-1] == 'L')
                lng = true;
            else if(val[$-1] == 'U' || val[$-1] == 'u')
                unsigned = true;
            else
                break;
            val = val[0..$-1];
        }
        int radix = 10;
        if(val[0] == '0' && val.length > 1)
        {
            if(val[1] == 'x' || val[1] == 'X')
            {
                radix = 16;
                val = val[2..$];
            }
            else if(val[1] == 'b' || val[1] == 'B')
            {
                radix = 2;
                val = val[2..$];
            }
            else
            {
                radix = 8;
            }
            unsigned = true;
        }
        import std.array : replace;
        val = val.replace("_", "");
        value = parse!ulong(val, radix);
    }

    override IntegerLiteralExpression clone()
    {
        IntegerLiteralExpression n = static_cast!IntegerLiteralExpression(super.clone());
        n.txt = txt;
        n.value = value;
        n.unsigned = unsigned;
        n.lng = lng;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.txt == txt
            && tn.value == value
            && tn.unsigned == unsigned
            && tn.lng == lng;
    }

    override void toD(CodeWriter writer)
    {
        writer(txt);
    }

    void forceLargerType(Type t)
    {
        if(t.id == TOK_int || t.id == TOK_uint)
            forceInt = true;
        if(t.id == TOK_short || t.id == TOK_ushort)
            forceShort = true;
    }

    override Type calcType()
    {
        if(type)
            return type;

        long lim = unsigned ? 0x1_0000_0000 : 0x8000_0000;
        if(lng || value >= lim)
            if(unsigned)
                type = new BasicType(TOK_ulong, span);
            else
                type = new BasicType(TOK_long, span);
        else if(true || forceInt || value >= (lim >> 16))
            if(unsigned)
                type = new BasicType(TOK_uint, span);
            else
                type = new BasicType(TOK_int, span);
        else if(forceShort || value >= (lim >= 24))
            if(unsigned)
                type = new BasicType(TOK_ushort, span);
            else
                type = new BasicType(TOK_short, span);
        else
            if(unsigned)
                type = new BasicType(TOK_ubyte, span);
            else
                type = new BasicType(TOK_byte, span);

        return type;
    }

    override void _semantic(Scope sc)
    {
        calcType().semantic(sc);
    }

    Value _interpret(Context sc)
    {
        if(lng || value >= 0x80000000)
            if(unsigned)
                return Value.create(cast(ulong)value);
            else
                return Value.create(cast(long)value);
        else if(true || forceInt || value >= 0x8000)
            if(unsigned)
                return Value.create(cast(uint)value);
            else
                return Value.create(cast(int)value);
        else if(forceShort || value >= 0x80)
            if(unsigned)
                return Value.create(cast(ushort)value);
            else
                return Value.create(cast(short)value);
        else
            if(unsigned)
                return Value.create(cast(ubyte)value);
            else
                return Value.create(cast(byte)value);
    }
    override Value interpret(Context sc)
    {
        Value v = _interpret(sc);
        v.literal = true;
        return v;
    }

    int getInt()
    {
        if(value > int.max)
            semanticErrorPos(span.start, text(value, " too large to fit an integer"));
        return cast(int) value;
    }
    uint getUInt()
    {
        if(value > uint.max)
            semanticErrorPos(span.start, text(value, " too large to fit an unsigned integer"));
        return cast(uint) value;
    }
}

class FloatLiteralExpression : PrimaryExpression
{
    string txt;

    real value;
    bool complex;
    bool lng;
    bool flt;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        txt = tok.txt;
        initValue();
    }

    void initValue()
    {
        string val = txt;
        while(val.length > 1)
        {
            if(val[$-1] == 'L')
                lng = true;
            else if(val[$-1] == 'f' || val[$-1] == 'F')
                flt = true;
            else if(val[$-1] == 'i')
                complex = true;
            else if(val[$-1] == '.')
            {
                val = val[0..$-1];
                break;
            }
            else
                break;
            val = val[0..$-1];
        }
        import std.array : replace;
        val = val.replace("_", "");
        value = parse!real(val);
    }

    override FloatLiteralExpression clone()
    {
        FloatLiteralExpression n = static_cast!FloatLiteralExpression(super.clone());
        n.txt = txt;
        n.value = value;
        n.complex = complex;
        n.lng = lng;
        n.flt = flt;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.txt == txt
            && tn.value == value
            && tn.complex == complex
            && tn.flt == flt
            && tn.lng == lng;
    }

    override Type calcType()
    {
        if(type)
            return type;

        if(complex)
            if(lng)
                type = new BasicType(TOK_ireal, span);
            else if(flt)
                type = new BasicType(TOK_ifloat, span);
            else
                type = new BasicType(TOK_idouble, span);
        else
            if(lng)
                type = new BasicType(TOK_real, span);
            else if(flt)
                type = new BasicType(TOK_float, span);
            else
                type = new BasicType(TOK_double, span);

        return type;
    }

    override void _semantic(Scope sc)
    {
        calcType().semantic(sc);
    }

    Value _interpret(Context sc)
    {
        if(complex)
            assert(0, "Complex numbers aren't supported anymore.");
        else
            if(lng)
                return Value.create(cast(real)value);
            else if(flt)
                return Value.create(cast(float)value);
            else
                return Value.create(cast(double)value);
    }
    override Value interpret(Context sc)
    {
        Value v = _interpret(sc);
        v.literal = true;
        return v;
    }

    override void toD(CodeWriter writer)
    {
        writer(txt);
    }
}

class StringLiteralExpression : PrimaryExpression
{
    string txt;
    string rawtxt;

    this() {} // default constructor needed for clone()

    static string raw(string s)
    {
        if(s.length == 0)
            return s;
        if(s.length > 2 && s[0] == 'q' && s[1] == '{' && s[$-1] == '}')
            return s[2..$-1];

        // TODO: missing hex/escape translation and delimiter string handling
        size_t p = 0;
        while(p < s.length && s[p] != '"' && s[p] != '`')
            p++;
        if(p >= s.length)
            return s;
        size_t q = s.length - 1;
        while(q > p && s[q] != s[p])
            q--;
        if(q <= p)
            return s;
        return s[p+1..q];
    }
    unittest
    {
        assert(raw(`r"abc"`) == "abc");
        assert(raw(`q{abc}`) == "abc");
        assert(raw(`"abc"c`) == "abc");
    }

    this(Token tok)
    {
        super(tok);
        txt = tok.txt;

        rawtxt = raw(txt);
    }

    void addText(Token tok)
    {
        txt ~= " " ~ tok.txt;
        rawtxt ~= raw(tok.txt);
    }

    override StringLiteralExpression clone()
    {
        StringLiteralExpression n = static_cast!StringLiteralExpression(super.clone());
        n.txt = txt;
        n.rawtxt = rawtxt;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.txt == txt;
    }

    override Type calcType()
    {
        if(!type)
        {
            switch(txt[$-1])
            {
                default:
                case 'c':
                    type = getTypeString!char();
                    break;
                case 'w':
                    type = getTypeString!wchar();
                    break;
                case 'd':
                    type = getTypeString!dchar();
                    break;
            }
        }
        return type;
    }
    override void _semantic(Scope sc)
    {
        calcType();
    }

    override Value interpret(Context sc)
    {
        Value v = Value.create(rawtxt);
        v.literal = true;
        return v;
    }

    override void toD(CodeWriter writer)
    {
        writer(txt);
    }
}

class CharacterLiteralExpression : PrimaryExpression
{
    string txt;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        txt = tok.txt;
    }

    override CharacterLiteralExpression clone()
    {
        CharacterLiteralExpression n = static_cast!CharacterLiteralExpression(super.clone());
        n.txt = txt;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.txt == txt;
    }

    override Type calcType()
    {
        if(type)
            return type;

        if(txt.length >= 3)
        {
            if(txt[$-1] == 'd')
                type = new BasicType(TOK_dchar, span);
            else if(txt[$-1] == 'w')
                type = new BasicType(TOK_wchar, span);
        }
        if(!type)
            type = new BasicType(TOK_char, span);

        return type;
    }

    Value _interpret(Context sc)
    {
        if(txt.length < 3)
            return Value.create(char.init);

        // TODO: missing escape decoding
        dchar ch = txt[1];
        if(txt[$-1] == 'd')
            return Value.create(ch);
        if(txt[$-1] == 'w')
            return Value.create(cast(wchar)ch);
        return Value.create(cast(char)ch);
    }

    override Value interpret(Context sc)
    {
        Value v = _interpret(sc);
        v.literal = true;
        return v;
    }

    override void _semantic(Scope sc)
    {
        calcType().semantic(sc);
    }

    override void toD(CodeWriter writer)
    {
        writer(txt);
    }
}

//TypeProperty:
//    [Type Identifier]
class TypeProperty : PrimaryExpression
{
    Node resolved;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(0, tok.span);
    }

    Type getType() { return getMember!Type(0); }
    Identifier getProperty() { return getMember!Identifier(1); }

    override void toD(CodeWriter writer)
    {
        Type type = getType();
        if(type.propertyNeedsParens())
            writer("(", getType(), ").", getProperty());
        else
            writer(getType(), ".", getProperty());
    }

    override Node resolve()
    {
        if(resolved)
            return resolved;

        auto id = getProperty();
        resolved = getType().getScope().resolve(id.ident, id);
        return resolved;
    }

    override Type calcType()
    {
        if(type)
            return type;

        if(auto n = resolve())
            type = n.calcType();
        else
            type = semanticErrorType("cannot determine type of property ", getProperty().ident);
        return type;
    }

    override Value interpret(Context sc)
    {
        if(!type)
            calcType();
        if(!resolved)
            return Singleton!ErrorValue.get(); // calcType already produced an error
        return resolved.interpret(nullContext);
    }
}

class StructConstructor : PrimaryExpression
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(0, tok.span);
    }

    Type getType() { return getMember!Type(0); }
    ArgumentList getArguments() { return getMember!ArgumentList(1); }

    override void toD(CodeWriter writer)
    {
        Type type = getType();
        if(type.propertyNeedsParens())
            writer("(", getType(), ")(", getArguments(), ")");
        else
            writer(getType(), "(", getArguments(), ")");
    }
}

class TraitsExpression : PrimaryExpression
{
    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(TOK___traits, tok.span);
    }

    override void toD(CodeWriter writer)
    {
        writer("__traits(", getMember(0));
        if(members.length > 1)
            writer(", ", getMember(1));
        writer(")");
    }
}

class TraitsArguments : TemplateArgumentList
{
    mixin ForwardCtorNoId!();
}
