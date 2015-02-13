// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.expr;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.decl;
import vdc.parser.tmpl;
import vdc.parser.misc;
import vdc.parser.aggr;
import ast = vdc.ast.all;

alias ast.PREC PREC;

////////////////////////////////////////////////////////////////
//-- GRAMMAR_BEGIN --
//Expression:
//    CommaExpression
class Expression
{
    static Action enter(Parser p)
    {
        return CommaExpression.enter(p);
    }
}

class BinaryExpression : Expression
{
}

mixin template BinaryExpr(ASTNodeType, PREC prec, string recursion, SubType, ops...)
{
    shared static this()
    {
        foreach(o; ops)
        {
            ast.precedence[o] = prec;
            ast.recursion[o] = recursion[0];
        }
    }

    mixin BinaryNode!(ASTNodeType, recursion, SubType, ops);
}

//-- GRAMMAR_BEGIN --
//CommaExpression:
//    AssignExpression
//    AssignExpression , CommaExpression
class CommaExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.CommaExpression, PREC.expr, "R", AssignExpression, TOK_comma);
}

//-- GRAMMAR_BEGIN --
//AssignExpression:
//    ConditionalExpression
//    ConditionalExpression = AssignExpression
//    ConditionalExpression += AssignExpression
//    ConditionalExpression -= AssignExpression
//    ConditionalExpression *= AssignExpression
//    ConditionalExpression /= AssignExpression
//    ConditionalExpression %= AssignExpression
//    ConditionalExpression &= AssignExpression
//    ConditionalExpression |= AssignExpression
//    ConditionalExpression ^= AssignExpression
//    ConditionalExpression ~= AssignExpression
//    ConditionalExpression <<= AssignExpression
//    ConditionalExpression >>= AssignExpression
//    ConditionalExpression >>>= AssignExpression
//    ConditionalExpression ^^= AssignExpression
class AssignExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.AssignExpression, PREC.assign, "R", ConditionalExpression,
                      TOK_assign, TOK_addass, TOK_minass, TOK_mulass, TOK_divass, TOK_modass,
                      TOK_andass, TOK_orass, TOK_xorass, TOK_catass, TOK_shlass, TOK_shrass,
                      TOK_ushrass, TOK_powass);
}

//-- GRAMMAR_BEGIN --
//ConditionalExpression:
//    OrOrExpression
//    OrOrExpression ? Expression : ConditionalExpression
class ConditionalExpression : Expression
{
    mixin TernaryNode!(ast.ConditionalExpression, OrOrExpression, TOK_question, Expression, TOK_colon);
}

//-- GRAMMAR_BEGIN --
//OrOrExpression:
//    AndAndExpression
//    OrOrExpression || AndAndExpression
class OrOrExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.OrOrExpression, PREC.oror, "L", AndAndExpression, TOK_oror);
}

//-- GRAMMAR_BEGIN --
//AndAndExpression:
//    OrExpression
//    AndAndExpression && OrExpression
class AndAndExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.AndAndExpression, PREC.andand, "L", OrExpression, TOK_andand);
}

//-- GRAMMAR_BEGIN --
//OrExpression:
//    XorExpression
//    OrExpression | XorExpression
class OrExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.OrExpression, PREC.or, "L", XorExpression, TOK_or);
}

//-- GRAMMAR_BEGIN --
//XorExpression:
//    AndExpression
//    XorExpression ^ AndExpression
class XorExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.XorExpression, PREC.xor, "L", AndExpression, TOK_xor);
}

//-- GRAMMAR_BEGIN --
//AndExpression:
//    CmpExpression
//    AndExpression & CmpExpression
class AndExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.AndExpression, PREC.and, "L", CmpExpression, TOK_and);
}

//-- GRAMMAR_BEGIN --
//CmpExpression:
//    ShiftExpression
//    EqualExpression
//    IdentityExpression
//    RelExpression
//    InExpression
//
//EqualExpression:
//    ShiftExpression == ShiftExpression
//    ShiftExpression != ShiftExpression
//
//IdentityExpression:
//    ShiftExpression is ShiftExpression
//    ShiftExpression !is ShiftExpression
//
//RelExpression:
//    ShiftExpression < ShiftExpression
//    ShiftExpression <= ShiftExpression
//    ShiftExpression > ShiftExpression
//    ShiftExpression >= ShiftExpression
//    ShiftExpression !<>= ShiftExpression
//    ShiftExpression !<> ShiftExpression
//    ShiftExpression <> ShiftExpression
//    ShiftExpression <>= ShiftExpression
//    ShiftExpression !> ShiftExpression
//    ShiftExpression !>= ShiftExpression
//    ShiftExpression !< ShiftExpression
//    ShiftExpression !<= ShiftExpression
//
//InExpression:
//    ShiftExpression in ShiftExpression
//    ShiftExpression !in ShiftExpression
class CmpExpression : BinaryExpression
{
    static if(!supportUnorderedCompareOps)
        mixin BinaryExpr!(ast.CmpExpression, PREC.rel, "N", ShiftExpression,
                          TOK_equal, TOK_notequal, TOK_is, TOK_notidentity,
                          TOK_lt, TOK_le, TOK_gt, TOK_ge,
                          // TOK_unord, TOK_ue, TOK_lg, TOK_leg, TOK_ule, TOK_ul, TOK_uge, TOK_ug,
                          TOK_in, TOK_notcontains);
    else
        mixin BinaryExpr!(ast.CmpExpression, PREC.rel, "N", ShiftExpression,
                          TOK_equal, TOK_notequal, TOK_is, TOK_notidentity,
                          TOK_lt, TOK_le, TOK_gt, TOK_ge,
                          // TOK_unord, TOK_ue, TOK_lg, TOK_leg, TOK_ule, TOK_ul, TOK_uge, TOK_ug,
                          TOK_in, TOK_notcontains);
}

//-- GRAMMAR_BEGIN --
//ShiftExpression:
//    AddExpression
//    ShiftExpression << AddExpression
//    ShiftExpression >> AddExpression
//    ShiftExpression >>> AddExpression
class ShiftExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.ShiftExpression, PREC.shift, "L", AddExpression, TOK_shl, TOK_shr, TOK_ushr);
}

//-- GRAMMAR_BEGIN --
//AddExpression:
//    MulExpression
//    AddExpression + MulExpression
//    AddExpression - MulExpression
//    CatExpression:
//CatExpression:
//    AddExpression ~ MulExpression
class AddExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.AddExpression, PREC.add, "L", MulExpression, TOK_add, TOK_min, TOK_tilde);
}

//-- GRAMMAR_BEGIN --
//MulExpression:
//    SignExpression
//    MulExpression * SignExpression
//    MulExpression / SignExpression
//    MulExpression % SignExpression
class MulExpression : BinaryExpression
{
    mixin BinaryExpr!(ast.MulExpression, PREC.mul, "L", SignExpression, TOK_mul, TOK_div, TOK_mod);
}

//-- GRAMMAR_BEGIN --
//SignExpression:
//    PowExpression
//    + SignExpression
//    - SignExpression
class SignExpression : Expression
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_min:
            case TOK_add:
                auto expr = new ast.UnaryExpression(p.tok);
                p.pushNode(expr);
                p.pushState(&shift);
                p.pushState(&enter);
                return Accept;
            default:
                return PowExpression.enter(p);
        }
    }

    static Action shift(Parser p)
    {
        p.popAppendTopNode!(ast.UnaryExpression)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//PowExpression:
//    UnaryExpression
//    UnaryExpression ^^ SignExpression
class PowExpression : BinaryExpression
{
    static Action shiftExponent(Parser p)
    {
        p.popAppendTopNode!(ast.PowExpression)();
        return Forward;
    }

    static Action shiftPow(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_pow:
                auto pe = new ast.PowExpression(p.tok);
                p.appendReplaceTopNode(pe);
                p.pushState(&shiftExponent);
                p.pushState(&SignExpression.enter);
                return Accept;
            default:
                return Forward;
        }
    }
    mixin stateEnterClass!(UnaryExpression, NoASTNode, shiftPow);
}

//-- GRAMMAR_BEGIN --
//UnaryExpression:
//    PostfixExpression
//    & UnaryExpression
//    ++ UnaryExpression
//    -- UnaryExpression
//    * UnaryExpression
//    - UnaryExpression
//    + UnaryExpression
//    ! UnaryExpression
//    ~ UnaryExpression
//    NewExpression
//    DeleteExpression
//    CastExpression
//    /*NewAnonClassExpression*/
//
// DeleteExpression:
//     delete UnaryExpression
class UnaryExpression : Expression
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_and:
            case TOK_plusplus:
            case TOK_minusminus:
            case TOK_mul:
            case TOK_min:
            case TOK_add:
            case TOK_not:
            case TOK_tilde:
            case TOK_delete:
                auto expr = new ast.UnaryExpression(p.tok);
                p.pushNode(expr);
                p.pushState(&shift);
                p.pushState(&enter);
                return Accept;
            case TOK_new:
                return NewExpression.enter(p);
            case TOK_cast:
                return CastExpression.enter(p);
            default:
                return PostfixExpression.enter(p);
        }
    }

    static Action shift(Parser p)
    {
        p.popAppendTopNode!(ast.UnaryExpression)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//NewExpression:
//    NewArguments Type [ AssignExpression ]
//    NewArguments Type ( ArgumentList )
//    NewArguments Type
//    NewArguments ClassArguments BaseClassList_opt { DeclDefs_opt }
//
//NewArguments:
//    new ( ArgumentList )
//    new ( )
//    new
//
//ClassArguments:
//    class ( ArgumentList )
//    class ( )
//    class
class NewExpression : UnaryExpression
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.NewExpression(p.tok));
        switch(p.tok.id)
        {
            case TOK_new:
                p.pushState(&shiftNew);
                return Accept;
            default:
                return p.parseError("new expected");
        }
    }

    static Action shiftNew(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftNewLparen);
                return Accept;
            case TOK_class:
                p.pushState(&shiftClass);
                return AnonymousClass.enter(p);
            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.NewExpression);
        switch(p.tok.id)
        {
            // [] are parsed as part of the type
            case TOK_lparen:
                p.pushState(&shiftTypeLparen);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftTypeLparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                return Accept; // empty argument list as good as none
            default:
                p.pushState(&shiftArgumentList);
                return ArgumentList.enter(p);
        }
    }
    static Action shiftArgumentList(Parser p)
    {
        switch(p.tok.id)
        {
            // [] are parsed as part of the type
            case TOK_rparen:
                p.popAppendTopNode!(ast.NewExpression);
                return Accept;
            default:
                return p.parseError("')' expected");
        }
    }

    static Action shiftNewLparen(Parser p)
    {
        p.pushState(&shiftNewArgumentList);
        return ArgumentList.enter(p);
    }

    static Action shiftNewArgumentList(Parser p)
    {
        p.popAppendTopNode!(ast.NewExpression);
        p.topNode!(ast.NewExpression).hasNewArgs = true;

        switch(p.tok.id)
        {
            case TOK_rparen:
                p.pushState(&shiftRparen);
                return Accept;
            default:
                return p.parseError("')' expected for new argument list");
        }
    }

    static Action shiftRparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_class:
                p.pushState(&shiftClass);
                return AnonymousClass.enter(p);
            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftClass(Parser p)
    {
        p.popAppendTopNode!(ast.NewExpression);
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
// AnonymousClass:
//     ClassArguments BaseClassList_opt { DeclDefs_opt }
class AnonymousClass
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_class:
                p.pushNode(new ast.AnonymousClassType(p.tok));
                p.pushState(&shiftClass);
                return Accept;
            default:
                return p.parseError("class expected");
        }
    }
    static Action shiftClass(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftLparen);
                return Accept;
            default:
                p.pushState(&shiftClassDeclaration);
                return AggregateDeclaration.enterAnonymousClass(p);
        }
    }

    static Action shiftLparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.topNode!(ast.AnonymousClassType).addMember(new ast.ArgumentList(p.tok));
                p.pushState(&shiftClassDeclaration);
                p.pushState(&AggregateDeclaration.enterAnonymousClass);
                return Accept;
            default:
                p.pushState(&shiftArgumentList);
                return ArgumentList.enter(p);
        }
    }

    static Action shiftClassDeclaration(Parser p)
    {
        p.popAppendTopNode!(ast.AnonymousClassType);
        return Forward;
    }

    static Action shiftArgumentList(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.popAppendTopNode!(ast.AnonymousClassType);
                p.pushState(&shiftClassDeclaration);
                p.pushState(&AggregateDeclaration.enterAnonymousClass);
                return Accept;
            default:
                return p.parseError("')' expected");
        }
    }
}

//-- GRAMMAR_BEGIN --
//CastExpression:
//    cast ( Type )         UnaryExpression
//    cast ( )              UnaryExpression
//    cast ( const )        UnaryExpression
//    cast ( const shared ) UnaryExpression
//    cast ( immutable )    UnaryExpression
//    cast ( inout )        UnaryExpression
//    cast ( inout shared ) UnaryExpression
//    cast ( shared )       UnaryExpression
//    cast ( shared const ) UnaryExpression
//    cast ( shared inout ) UnaryExpression
class CastExpression : UnaryExpression
{
    mixin stateAppendClass!(UnaryExpression, Parser.forward) stateExpression;

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.CastExpression)();
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.pushState(&stateExpression.shift);
                return Accept;
            default:
                return p.parseError("')' expected");
        }
    }

    mixin stateShiftToken!(TOK_rparen, stateExpression.shift) stateRparen;

    static Action shiftModifier(Parser p)
    {
        Token tok;
        switch(p.tok.id)
        {
            case TOK_rparen:
                tok = p.popToken();
                p.topNode!(ast.CastExpression)().attr = tokenToAttribute(tok.id);
                p.pushState(&stateExpression.shift);
                return Accept;

            case TOK_const:
            case TOK_inout:
                tok = p.topToken();
                if(tok.id != TOK_shared)
                    goto default;
            L_combineAttr:
                tok = p.popToken();
                auto attr = tokenToAttribute(tok.id);
                p.combineAttributes(attr, tokenToAttribute(p.tok.id));
                p.topNode!(ast.CastExpression)().attr = attr;
                p.pushState(&stateRparen.shift);
                return Accept;

            case TOK_shared:
                tok = p.topToken();
                if(tok.id != TOK_inout && tok.id != TOK_const)
                    goto default;
                goto L_combineAttr;

            default:
                p.pushState(&shiftType);
                return Type.enterTypeModifier(p);
        }
    }

    static Action stateType(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.pushState(&stateExpression.shift);
                return Accept;
            case TOK_const:
            case TOK_immutable:
            case TOK_inout:
            case TOK_shared:
                p.pushToken(p.tok);
                p.pushState(&shiftModifier);
                return Accept;
            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    mixin stateShiftToken!(TOK_lparen, stateType) stateLparen;

    mixin stateEnterToken!(TOK_cast, ast.CastExpression, stateLparen.shift);
}

//-- GRAMMAR_BEGIN --
//PostfixExpression:
//    PrimaryExpression
//    PostfixExpression . IdentifierOrTemplateInstance
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
    static Action enter(Parser p)
    {
        p.pushState(&shift);
        return PrimaryExpression.enter(p);
    }

    static Action shift(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_plusplus:
            case TOK_minusminus:
                p.appendReplaceTopNode(new ast.PostfixExpression(p.tok));
                return Accept;

            case TOK_dot:
                p.pushState(&shiftDot);
                p.appendReplaceTopNode(new ast.DotExpression(p.tok));
                return Accept;

            case TOK_lparen:
                p.pushState(&shiftLParen);
                p.appendReplaceTopNode(new ast.PostfixExpression(p.tok));
                return Accept;

            case TOK_lbracket:
                p.pushState(&shiftLBracket);
                p.appendReplaceTopNode(new ast.PostfixExpression(p.tok));
                return Accept;

            default:
                return Forward;
        }
    }

    static Action shiftDot(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                auto expr = p.topNode!(ast.DotExpression)();
                expr.id = TOK_dot;
                p.pushState(&shiftIdentifierOrTemplateInstance);
                return IdentifierOrTemplateInstance.enter(p);

            case TOK_RECOVER:
                auto expr = p.topNode!(ast.DotExpression)();
                expr.id = TOK_dot;
                auto id = new ast.Identifier(p.tok);
                expr.addMember(id);
                return Forward;

            case TOK_new:
                p.pushState(&shiftNewExpression);
                return NewExpression.enter(p);

            default:
                return p.parseError("identifier or new expected after '.'");
        }
    }

    static Action shiftIdentifierOrTemplateInstance(Parser p)
    {
        p.popAppendTopNode!(ast.PostfixExpression, ast.Identifier)();
        return shift(p);
    }

    static Action shiftLParen(Parser p)
    {
        if(p.tok.id == TOK_rparen)
        {
            p.pushState(&shift);
            return Accept;
        }

        p.pushState(&shiftRParen);
        return ArgumentList.enter(p); // ArgumentList also starts with AssignExpression
    }

    static Action shiftRParen(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");

        p.popAppendTopNode!(ast.PostfixExpression)();
        p.pushState(&shift);
        return Accept;
    }

    static Action shiftLBracket(Parser p)
    {
        if(p.tok.id == TOK_rbracket)
        {
            p.pushState(&shift);
            return Accept;
        }

        p.pushState(&shiftRBracket);
        return ArgumentList.enter(p);
    }

    static Action shiftRBracket(Parser p)
    {
        if(p.tok.id == TOK_slice)
        {
            // throw away the argument list, just use the expression
            ast.Node arglist = p.popNode();
            if (arglist.members.length != 1)
                return p.parseError("a single expression is expected before ..");

            p.topNode().addMember(arglist.removeMember(0));
            p.pushState(&shiftSlice);
            p.pushState(&AssignExpression.enter);
            return Accept;
        }
        else if(p.tok.id != TOK_rbracket)
            return p.parseError("closing bracket or .. expected");

        p.popAppendTopNode!(ast.PostfixExpression)();
        p.pushState(&shift);
        return Accept;
    }

    static Action shiftSlice(Parser p)
    {
        if(p.tok.id != TOK_rbracket)
            return p.parseError("closing bracket expected");

        p.popAppendTopNode!(ast.PostfixExpression)();
        p.pushState(&shift);
        return Accept;
    }

    static Action shiftNewExpression(Parser p)
    {
        p.popAppendTopNode!(ast.PostfixExpression)();
        auto expr = p.topNode!(ast.PostfixExpression)();
        expr.id = TOK_new;
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//ArgumentList:
//    AssignExpression
//    AssignExpression ,
//    AssignExpression , ArgumentList
class ArgumentList
{
    mixin ListNode!(ast.ArgumentList, AssignExpression, TOK_comma, true);
}

//-- GRAMMAR_BEGIN --
//Arguments:
//    ( )
//    ( ArgumentList )
class Arguments
{
    mixin SequenceNode!(NoASTNode, TOK_lparen, EmptyArgumentList, TOK_rparen);
}

class EmptyArgumentList
{
    mixin ListNode!(ast.ArgumentList, AssignExpression, TOK_comma, false, true);
}

//-- GRAMMAR_BEGIN --
//PrimaryExpression:
//    IdentifierOrTemplateInstance
//    . IdentifierOrTemplateInstance
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
//    StringLiteral
//    ArrayLiteral
//    AssocArrayLiteral
//    Lambda
//    FunctionLiteral
//    StructLiteral            // deprecated
//    AssertExpression
//    MixinExpression
//    ImportExpression
//    TypeidExpression
//    IsExpression
//    ( Expression )
//    BasicType . IdentifierOrTemplateInstance
//    Typeof    . IdentifierOrTemplateInstance
//    ( Type )  . IdentifierOrTemplateInstance
//    BasicType Arguments
//    Typeof    Arguments
//    ( Type )  Arguments
//    TraitsExpression

class PrimaryExpression : Expression
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_typeid:
                return TypeIdExpression.enter(p);
            case TOK_is:
                return IsExpression.enter(p);
            case TOK_notidentity:
                return IsExpression.enterNotIs(p);
            case TOK_import:
                return ImportExpression.enter(p);
            case TOK_mixin:
                return MixinExpression.enter(p);
            case TOK_assert:
                return AssertExpression.enter(p);
            case TOK___traits:
                return TraitsExpression.enter(p);

            case TOK_this:
            case TOK_super:
            case TOK_null:
            case TOK_true:
            case TOK_false:
            case TOK_dollar:
            case TOK___FILE__:
            case TOK___LINE__:
            case TOK___FUNCTION__:
            case TOK___PRETTY_FUNCTION__:
            case TOK___MODULE__:
                auto expr = new ast.PrimaryExpression(p.tok);
                p.pushNode(expr);
                return Accept;

            case TOK_typeof: // cannot make this part of Type, because it will also eat the property
                p.pushState(&shiftType);
                return Typeof.enter(p);

            case TOK___vector:
            mixin(case_TOKs_TypeModifier);
            mixin(case_TOKs_BasicTypeX);
                p.pushState(&shiftType);
                return Type.enter(p);

            case TOK_dot:
                p.pushState(&shiftDot);
                return Accept;
            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_IntegerLiteral:
                p.pushNode(new ast.IntegerLiteralExpression(p.tok));
                return Accept;
            case TOK_FloatLiteral:
                p.pushNode(new ast.FloatLiteralExpression(p.tok));
                return Accept;
            case TOK_CharacterLiteral:
                p.pushNode(new ast.CharacterLiteralExpression(p.tok));
                return Accept;
            case TOK_StringLiteral:
                p.pushNode(new ast.StringLiteralExpression(p.tok));
                p.pushState(&shiftStringLiteral);
                return Accept;

            case TOK_lbracket:
                return ArrayLiteral.enter(p);

            case TOK_delegate:
            case TOK_function:
                return FunctionLiteral!true.enter(p); // SPEC: allowing lambda not in the language spec
            case TOK_lcurly:
                p.pushRollback(&rollbackFunctionLiteralFailure);
                p.pushState(&shiftFunctionLiteral);
                return FunctionLiteral!false.enter(p);

            case TOK_lparen:
                p.pushRollback(&rollbackExpressionFailure);
                p.pushState(&shiftLparenExpr);
                p.pushState(&Expression.enter);
                return Accept;

            default:
                return p.parseError("primary expression expected");
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lambda:
                // id => expr
                auto tok = p.popToken();
                auto lambda = new ast.Lambda(p.tok);
                auto pdecl = new ast.ParameterDeclarator;
                auto type = new ast.AutoType;
                auto id = new ast.Declarator(tok);
                pdecl.addMember(type);
                pdecl.addMember(id);
                auto pl = new ast.ParameterList;
                pl.addMember(pdecl);
                lambda.addMember(pl);
                p.pushNode(lambda);
                p.pushState(&shiftLambda);
                p.pushState(&AssignExpression.enter);
                return Accept;

            default:
                auto tok = p.topToken();
                p.pushNode(new ast.IdentifierExpression(tok));
                p.pushState(&shiftIdentifierOrTemplateInstance);
                return IdentifierOrTemplateInstance.enterIdentifier(p);
        }
    }

    static Action shiftLambda(Parser p)
    {
        p.popAppendTopNode!(ast.Lambda)();
        return Forward;
    }

    // ( Expression )
    // ( Type ) . Identifier
    // FunctionLiteral: ParameterAttributes FunctionBody
    static Action shiftLparenExpr(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");

        p.pushState(&shiftRparenExpr);
        return Accept;
    }
    static Action shiftRparenExpr(Parser p)
    {
        if(p.tok.id == TOK_lcurly || p.tok.id == TOK_lambda)
            return Reject;

        p.popRollback();
        return Forward;
    }


    static Action rollbackExpressionFailure(Parser p)
    {
        assert(p.tok.id == TOK_lparen);
        p.pushRollback(&rollbackTypeFailure);
        p.pushState(&shiftLparenType);
        p.pushState(&Type.enter);
        return Accept;
    }

    static Action rollbackFunctionLiteralFailure(Parser p)
    {
        assert(p.tok.id == TOK_lcurly || p.tok.id == TOK_lambda);
        return StructLiteral.enter(p);
    }

    static Action shiftFunctionLiteral(Parser p)
    {
        p.popRollback();
        return Forward;
    }

    static Action shiftLparenType(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected");
        p.pushState(&shiftLparenTypeDot);
        return Accept;
    }
    static Action shiftLparenTypeDot(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
                p.popRollback();
                p.appendReplaceTopNode(new ast.TypeProperty(p.tok));
                p.pushState(&shiftTypeDot);
                p.pushState(&IdentifierOrTemplateInstance.enter);
                return Accept;
            case TOK_lparen:
                p.popRollback();
                p.appendReplaceTopNode(new ast.StructConstructor(p.tok));
                p.pushState(&shiftStructArguments);
                return Arguments.enter(p);
            default:
                return p.parseError("'.' expected for type property");
        }
    }

    static Action rollbackTypeFailure(Parser p)
    {
        assert(p.tok.id == TOK_lparen);
        return FunctionLiteral!true.enter(p);
    }

    static Action shiftDot(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected");

        auto id = new ast.IdentifierExpression(p.tok);
        id.global = true;
        p.pushNode(id);

        p.pushState(&shiftIdentifierOrTemplateInstance);
        return IdentifierOrTemplateInstance.enter(p);
    }

    static Action shiftIdentifierOrTemplateInstance(Parser p)
    {
        p.popAppendTopNode!(ast.IdentifierExpression, ast.Identifier)();
        return Forward;
    }

    // BasicType . Identifier
    static Action shiftType(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
                p.appendReplaceTopNode(new ast.TypeProperty(p.tok));
                p.pushState(&shiftTypeDot);
                p.pushState(&IdentifierOrTemplateInstance.enter);
                return Accept;
            case TOK_lparen:
                p.appendReplaceTopNode(new ast.StructConstructor(p.tok));
                p.pushState(&shiftStructArguments);
                return Arguments.enter(p);
            default:
                return p.parseError("'.' expected for type property");
        }
    }

    static Action shiftTypeDot(Parser p)
    {
        p.popAppendTopNode!(ast.TypeProperty)();
        return Forward;
    }

    static Action shiftStructArguments(Parser p)
    {
        p.popAppendTopNode!(ast.StructConstructor)();
        return Forward;
    }

    static Action shiftStringLiteral(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_StringLiteral:
                p.topNode!(ast.StringLiteralExpression).addText(p.tok);
                p.pushState(&shiftStringLiteral);
                return Accept;
            default:
                return Forward;
        }
    }
}

//-- GRAMMAR_BEGIN --
//VoidInitializer:
//    void
//
//ArrayLiteral:
//    [ ArgumentList ]
//
//AssocArrayLiteral:
//    [ KeyValuePairs ]
class ArrayLiteral : Expression
{
    // combines all array literals, has to be disambiguated when assigned
    mixin SequenceNode!(ast.ArrayLiteral, TOK_lbracket, ArrayValueList, TOK_rbracket);
}

//-- GRAMMAR_BEGIN --
//ArrayValueList:
//    ArrayValue
//    ArrayValue , ArrayValue
class ArrayValueList
{
    mixin ListNode!(ast.ArgumentList, ArrayValue, TOK_comma, true, true);
}

//-- GRAMMAR_BEGIN --
//ArrayValue:
//    AssignExpression
//    AssignExpression : AssignExpression
class ArrayValue : BinaryExpression
{
    mixin stateAppendClass!(AssignExpression, Parser.forward) stateValue;

    static Action statePrepareValue(Parser p)
    {
        auto kp = new ast.KeyValuePair(p.tok);
        p.appendReplaceTopNode(kp);
        return stateValue.shift(p);
    }

    mixin stateShiftToken!(TOK_colon, statePrepareValue, -1) stateColon;
    mixin stateEnterClass!(AssignExpression, NoASTNode, stateColon.shift);
}

//-- GRAMMAR_BEGIN --
//FunctionLiteral:
//    function Type_opt ParameterAttributes_opt FunctionBody
//    delegate Type_opt ParameterAttributes_opt FunctionBody
//    ParameterAttributes FunctionBody
//    FunctionBody
//
//ParameterAttributes:
//    Parameters
//    Parameters FunctionAttributes
class FunctionLiteral(bool allowLambda) : Expression
{
    static Action enter(Parser p)
    {
        auto lit = new ast.FunctionLiteral(0, p.tok.span);
        p.pushNode(lit);

        switch(p.tok.id)
        {
            case TOK_function:
            case TOK_delegate:
                lit.id = p.tok.id;
                p.pushState(&shiftFunctionDelegate);
                return Accept;

            case TOK_lcurly:
                lit.addMember(new ast.ParameterList(p.tok));
                p.pushState(&shiftFunctionBody);
                return FunctionBody.enter(p);

            case TOK_lparen:
                p.pushState(&shiftParameters);
                return Parameters.enter(p);

            default:
                return p.parseError("unexpected token for function/delegate literal");
        }
    }

    static Action shiftFunctionDelegate(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                auto lit = p.topNode!(ast.FunctionLiteral)();
                lit.addMember(new ast.ParameterList(p.tok));
                p.pushState(&shiftFunctionBody);
                return FunctionBody.enter(p);

            case TOK_lparen:
                p.pushState(&shiftParameters);
                return Parameters.enter(p);

            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.FunctionLiteral);
        switch(p.tok.id)
        {
            case TOK_lcurly:
                auto lit = p.topNode!(ast.FunctionLiteral)();
                lit.addMember(new ast.ParameterList(p.tok));
                p.pushState(&shiftFunctionBody);
                return FunctionBody.enter(p);

            case TOK_lparen:
                p.pushState(&shiftParameters);
                return Parameters.enter(p);

            default:
                return p.parseError("'(' or '{' expected in function literal");
        }
    }

    static Action shiftParameters(Parser p)
    {
        p.popAppendTopNode!(ast.FunctionLiteral)();
        return shiftFunctionAttribute(p);
    }

    static Action shiftFunctionAttribute(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                p.pushState(&shiftFunctionBody);
                return FunctionBody.enter(p);

            static if(allowLambda)
            {
            case TOK_lambda:
                p.pushState(&shiftLambda);
                p.pushState(&AssignExpression.enter);
                return Accept;
            }
            mixin(case_TOKs_FunctionAttribute);
                auto lit = p.topNode!(ast.FunctionLiteral)();
                p.combineAttributes(lit.attr, tokenToAttribute(p.tok.id));
                p.combineAnnotations(lit.annotation, tokenToAnnotation(p.tok.id));
                p.pushState(&shiftFunctionAttribute);
                return Accept;

            default:
                return p.parseError("'{' expected in function literal");
        }
    }

    static Action shiftFunctionBody(Parser p)
    {
        p.popAppendTopNode!(ast.FunctionLiteral);
        return Forward;
    }

    static Action shiftLambda(Parser p)
    {
        auto expr = p.popNode!(ast.Expression)();
        auto ret = new ast.ReturnStatement;
        ret.addMember(expr);
        auto blk = new ast.BlockStatement;
        blk.addMember(ret);
        auto bdy = new ast.FunctionBody;
        bdy.addMember(blk);
        bdy.bodyStatement = blk;

        auto lit = p.topNode!(ast.FunctionLiteral)();
        lit.addMember(bdy);
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//StructLiteral:
//    { ArrayValueList }
class StructLiteral : Expression
{
    mixin SequenceNode!(ast.StructLiteral, TOK_lcurly, ArrayValueList, TOK_rcurly);

}

//-- GRAMMAR_BEGIN --
//AssertExpression:
//    assert ( AssignExpression )
//    assert ( AssignExpression , AssignExpression )
class AssertExpression : Expression
{
    // assert ( AssignExpression , AssignExpression $ )
    mixin stateShiftToken!(TOK_rparen, Parser.forward) stateRparen;

    // assert ( AssignExpression , $ AssignExpression )
    mixin stateAppendClass!(AssignExpression, stateRparen.shift) stateMessage;

    // assert ( AssignExpression $ )
    // assert ( AssignExpression $ , AssignExpression )
    mixin stateShiftToken!(TOK_rparen, Parser.forward,
                           TOK_comma, stateMessage.shift) stateRparenComma;

    // assert ( $ AssignExpression , AssignExpression )
    mixin stateAppendClass!(AssignExpression, stateRparenComma.shift) stateExpression;

    // assert $ ( AssignExpression , AssignExpression )
    mixin stateShiftToken!(TOK_lparen, stateExpression.shift) stateLparen;

    // $ assert ( AssignExpression , AssignExpression )
    mixin stateEnterToken!(TOK_assert, ast.AssertExpression, stateLparen.shift);
}

//-- GRAMMAR_BEGIN --
//MixinExpression:
//    mixin ( AssignExpression )
class MixinExpression : Expression
{
    mixin SequenceNode!(ast.MixinExpression, TOK_mixin, TOK_lparen, AssignExpression, TOK_rparen);
}

//-- GRAMMAR_BEGIN --
//ImportExpression:
//    import ( AssignExpression )
class ImportExpression : Expression
{
    mixin SequenceNode!(ast.ImportExpression, TOK_import, TOK_lparen, AssignExpression, TOK_rparen);
}

//-- GRAMMAR_BEGIN --
//TypeidExpression:
//    typeid ( Type )
//    typeid ( Expression )
class TypeIdExpression : Expression
{
    mixin SequenceNode!(ast.TypeIdExpression, TOK_typeid, TOK_lparen, TypeOrExpression!TOK_rparen, TOK_rparen);
}

class TypeOrExpression(ops...)
{
    static Action enter(Parser p)
    {
        p.pushRollback(&rollbackTypeFailure);
        p.pushState(&shiftType);
        return Type.enter(p);
    }

    static Action shiftType(Parser p)
    {
        if(!isInOps!(ops)(p.tok.id))
            return p.parseError("not a type!");

        p.popRollback();
        return Forward;
    }

    static Action rollbackTypeFailure(Parser p)
    {
        return AssignExpression.enter(p);
    }
}

//-- GRAMMAR_BEGIN --
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
//    TypeWithModifier
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
//    __parameters
//    __argTypes
//
// !is specially treated, because it's a token to the lexer
class IsExpression : Expression
{
    // is ( Type Identifier == TypeSpecialization , TemplateParameterList $ )
    mixin stateShiftToken!(TOK_rparen, Parser.forward) stateRparen;

    // is ( Type Identifier == TypeSpecialization , $ TemplateParameterList )
    mixin stateAppendClass!(TemplateParameterList, stateRparen.shift) stateTemplateParameterList;

    // is ( Type : TypeSpecialization $ )
    // ...
    // is ( Type Identifier == TypeSpecialization $ , TemplateParameterList )
    mixin stateShiftToken!(TOK_rparen, Parser.forward,
                           TOK_comma, stateTemplateParameterList.shift) stateRparenComma;

    // is ( Type : $ TypeSpecialization )
    // is ( Type == $ TypeSpecialization )
    mixin stateAppendClass!(TypeSpecialization, stateRparenComma.shift) stateTypeSpecialization;

    static Action rememberColon(Parser p)
    {
        p.topNode!(ast.IsExpression).kind = TOK_colon;
        return stateTypeSpecialization.shift(p);
    }
    static Action rememberAssign(Parser p)
    {
        p.topNode!(ast.IsExpression).kind = TOK_equal;
        return stateTypeSpecialization.shift(p);
    }
    mixin stateShiftToken!(TOK_rparen, Parser.forward,
                           TOK_colon, rememberColon,
                           TOK_equal, rememberAssign) stateAfterIdentifier;

    static Action rememberIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.topNode!(ast.IsExpression).ident = p.tok.txt;
                p.pushState(&stateAfterIdentifier.shift);
                return Accept;
            default:
                return p.parseError("')', ':', '==' or identifier expected");
        }
    }

    // is ( Type $ )
    // is ( Type $ : TypeSpecialization )
    // is ( Type $ == TypeSpecialization )
    // is ( Type $ Identifier == TypeSpecialization , TemplateParameterList )
    mixin stateShiftToken!(TOK_rparen, Parser.forward,
                           TOK_colon, rememberColon,
                           TOK_equal, rememberAssign,
                           -1, rememberIdentifier) stateIdentifier;

    // is ( $ Type Identifier == TypeSpecialization , TemplateParameterList )
    mixin stateAppendClass!(Type, stateIdentifier.shift) stateType;

    // is $ ( Type Identifier == TypeSpecialization , TemplateParameterList )
    mixin stateShiftToken!(TOK_lparen, stateType.shift) stateLparen;

    // $ is ( Type Identifier == TypeSpecialization , TemplateParameterList )
    mixin stateEnterToken!(TOK_is, ast.IsExpression, stateLparen.shift);

    static Action enterNotIs(Parser p)
    {
        p.pushNode(new ast.UnaryExpression(TOK_not, p.tok.span));
        p.pushNode(new ast.IsExpression(p.tok));
        p.pushState(&shiftNotIsExpression);
        p.pushState(&stateLparen.shift);
        return Accept;
    }

    static Action shiftNotIsExpression(Parser p)
    {
        p.popAppendTopNode!(ast.UnaryExpression)();
        return Forward;
    }
}

class TypeSpecialization
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_struct:
            case TOK_union:
            case TOK_class:
            case TOK_interface:
            case TOK_enum:
            case TOK_function:
            case TOK_delegate:
            case TOK_super:
            case TOK_return:
            case TOK_typedef:
            case TOK___parameters:
            case TOK___argTypes:
                p.pushNode(new ast.TypeSpecialization(p.tok));
                return Accept;
            case TOK_const:
            case TOK_immutable:
            case TOK_inout:
            case TOK_shared:
                p.pushToken(p.tok);
                p.pushState(&shiftModifier);
                return Accept;
            default:
                p.pushNode(new ast.TypeSpecialization(0, p.tok.span));
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftModifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushNode(new ast.TypeSpecialization(0, p.tok.span));
                p.pushState(&shiftType);
                return Type.enterTypeModifier(p);
            case TOK_rparen:
            case TOK_comma:
                auto tok = p.popToken();
                p.pushNode(new ast.TypeSpecialization(tok));
                return Forward;
            default:
                p.pushNode(new ast.TypeSpecialization(0, p.tok.span));
                p.pushState(&shiftType);
                return TypeWithModifier.shiftModifier(p);
        }
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.TypeSpecialization)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//TraitsExpression:
//    __traits ( TraitsKeyword , TraitsArguments )
//
//TraitsKeyword:
//    "isAbstractClass"
//    "isArithmetic"
//    "isAssociativeArray"
//    "isFinalClass"
//    "isFloating"
//    "isIntegral"
//    "isScalar"
//    "isStaticArray"
//    "isUnsigned"
//    "isVirtualFunction"
//    "isAbstractFunction"
//    "isFinalFunction"
//    "isStaticFunction"
//    "isRef"
//    "isOut"
//    "isLazy"
//    "hasMember"
//    "identifier"
//    "getMember"
//    "getOverloads"
//    "getVirtualFunctions"
//    "classInstanceSize"
//    "allMembers"
//    "derivedMembers"
//    "isSame"
//    "compiles"
class TraitsExpression : Expression
{
    mixin stateShiftToken!(TOK_rparen, Parser.forward) stateRparen;

    mixin stateAppendClass!(TraitsArguments, stateRparen.shift) stateArguments;

    mixin stateShiftToken!(TOK_comma, stateArguments.shift,
                           TOK_rparen, Parser.forward) stateComma;

    mixin stateAppendClass!(Identifier, stateComma.shift) stateIdentifier;

    mixin stateShiftToken!(TOK_lparen, stateIdentifier.shift) stateLparen;

    mixin stateEnterToken!(TOK___traits, ast.TraitsExpression, stateLparen.shift);
}

//-- GRAMMAR_BEGIN --
//TraitsArguments:
//    TraitsArgument
//    TraitsArgument , TraitsArguments
//
//TraitsArgument:
//    AssignExpression
//    Type
class TraitsArguments
{
    mixin ListNode!(ast.TraitsArguments, TypeOrExpression!(TOK_comma, TOK_rparen), TOK_comma, false, false);
}
