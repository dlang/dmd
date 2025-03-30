// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.tmpl;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.decl;
import vdc.parser.expr;
import vdc.parser.mod;
import ast = vdc.ast.all;

//-- GRAMMAR_BEGIN --
//TemplateDeclaration:
//    template TemplateIdentifier ( TemplateParameterList ) Constraint_opt { DeclDefs }
class TemplateDeclaration
{
    mixin SequenceNode!(ast.TemplateDeclaration, TOK_template, Identifier, TOK_lparen,
                        TemplateParameterList, TOK_rparen, Opt!(Constraint, TOK_if), DeclDefsBlock);
}

class DeclDefsBlock
{
    mixin SequenceNode!(ast.DeclarationBlock, TOK_lcurly, DeclDefs, TOK_rcurly);
}

//-- GRAMMAR_BEGIN --
//TemplateIdentifier:
//    Identifier
//
//TemplateParameters:
//    ( TemplateParameterList )
class TemplateParameters
{
    mixin SequenceNode!(NoASTNode, TOK_lparen, TemplateParameterList, TOK_rparen);
}

//-- GRAMMAR_BEGIN --
//TemplateParameterList:
//    TemplateParameter
//    TemplateParameter ,
//    TemplateParameter , TemplateParameterList
class TemplateParameterList
{
    mixin ListNode!(ast.TemplateParameterList, TemplateParameter, TOK_comma, true, true);
}

//-- GRAMMAR_BEGIN --
//TemplateParameter:
//    TemplateTypeParameter
//    TemplateValueParameter
//    TemplateAliasParameter
//    TemplateTupleParameter
//    TemplateThisParameter
//
//TemplateTupleParameter:
//    Identifier ...
class TemplateParameter
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_this:
                return TemplateThisParameter.enter(p);
            case TOK_alias:
                return TemplateAliasParameter.enter(p);
            default:
                return TemplateValueParameter.enter(p);
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_comma:
            case TOK_rparen:
                Token tok = p.popToken();
                p.pushNode(new ast.TemplateTypeParameter(tok));
                return Forward;

            case TOK_colon:
            case TOK_assign:
                return TemplateTypeParameter!false.enterIdentifier(p);

            case TOK_dotdotdot:
                Token tok = p.popToken();
                p.pushNode(new ast.TemplateTupleParameter(tok));
                return Accept;

            default:
                return TemplateValueParameter.enterIdentifier(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//IdentifierOrTemplateInstance:
//    Identifier
//    TemplateInstance
//
//TemplateInstance:
//    TemplateIdentifier ! ( TemplateArgumentList )
//    TemplateIdentifier ! TemplateSingleArgument
class IdentifierOrTemplateInstance
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                return p.parseError("identifier expected");
        }
    }

    // assumes identifier token on the info stack
    static Action enterIdentifier(Parser p)
    {
        return shiftIdentifier(p);
    }

    static Action shiftIdentifier(Parser p)
    {
        auto tok = p.popToken();
        switch(p.tok.id)
        {
            case TOK_not:
                p.pushNode(new ast.TemplateInstance(tok));
                p.pushState(&shiftNot);
                return Accept;
            default:
                p.pushNode(new ast.Identifier(tok));
                return Forward;
        }
    }

    static Action shiftNot(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftArgumentList);
                p.pushState(&TemplateArgumentList.enter);
                return Accept;

            mixin(case_TOKs_TemplateSingleArgument);
                p.pushNode(new ast.TemplateArgumentList(p.tok));
                p.pushState(&shiftSingleArgument);
                return PrimaryExpression.enter(p);

            case TOK___vector:
            mixin(case_TOKs_BasicTypeX);
                auto n = new ast.TemplateArgumentList(p.tok);
                n.addMember(new ast.BasicType(p.tok));
                p.topNode!(ast.TemplateInstance).addMember(n);
                return Accept;

            default:
                return p.parseError("'(' or single argument template expected after '!'");
        }
    }

    static Action shiftArgumentList(Parser p)
    {
        p.popAppendTopNode!(ast.TemplateInstance);
        switch(p.tok.id)
        {
            case TOK_rparen:
                return Accept;
            default:
                return p.parseError("closing parenthesis expected");
        }
    }

    static Action shiftSingleArgument(Parser p)
    {
        p.popAppendTopNode!(ast.TemplateArgumentList);
        p.popAppendTopNode!(ast.TemplateInstance);
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//TemplateArgumentList:
//    TemplateArgument
//    TemplateArgument ,
//    TemplateArgument , TemplateArgumentList
//
//TemplateArgument:
//    Type
//    AssignExpression
//    Symbol /* same as IdentifierList, so already in Type and AssignExpression */

//Symbol:
//    SymbolTail
//    . SymbolTail
//
//// identical to IdentifierList
//SymbolTail:
//    Identifier
//    Identifier . SymbolTail
//    TemplateInstance
//    TemplateInstance . SymbolTail
class TemplateArgumentList
{
    mixin ListNode!(ast.TemplateArgumentList, TypeOrExpression!(TOK_comma, TOK_rparen), TOK_comma, true, true);
}

//-- GRAMMAR_BEGIN --
//TemplateSingleArgument:
//    Identifier
//    BasicTypeX
//    CharacterLiteral
//    StringLiteral
//    IntegerLiteral
//    FloatLiteral
//    true
//    false
//    null
//    __FILE__
//    __LINE__

//-- GRAMMAR_BEGIN --
//TemplateTypeParameter:
//    Identifier
//    Identifier TemplateTypeParameterSpecialization
//    Identifier TemplateTypeParameterDefault
//    Identifier TemplateTypeParameterSpecialization TemplateTypeParameterDefault
//
//TemplateTypeParameterSpecialization:
//    : Type
//
//TemplateTypeParameterDefault:
//    = Type
class TemplateTypeParameter(bool exprDefault = false)
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.TemplateTypeParameter(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                return p.parseError("identifier expected");
        }
    }

    static Action enterIdentifier(Parser p)
    {
        Token tok = p.popToken();
        p.pushNode(new ast.TemplateTypeParameter(tok));
        return shiftIdentifier(p);
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_colon:
                p.pushState(&shiftSpecialization);
                p.pushState(&Type.enter);
                return Accept;
            case TOK_assign:
                p.pushState(&shiftDefault);
                static if(exprDefault)
                    p.pushState(&TypeOrExpression!(TOK_rparen, TOK_comma).enter);
                else
                    p.pushState(&Type.enter);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftSpecialization(Parser p)
    {
        auto special = p.popNode!(ast.Type)();
        auto param = p.topNode!(ast.TemplateTypeParameter);
        param.specialization = special;
        param.addMember(special);

        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftDefault);
                static if(exprDefault)
                    p.pushState(&TypeOrExpression!(TOK_rparen, TOK_comma).enter);
                else
                    p.pushState(&Type.enter);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftDefault(Parser p)
    {
        auto def = p.popNode();
        auto param = p.topNode!(ast.TemplateTypeParameter);
        param.def = def;
        param.addMember(def);
        return Forward;
    }
}

//TemplateThisParameter:
//    this TemplateTypeParameter
class TemplateThisParameter
{
    mixin SequenceNode!(ast.TemplateThisParameter, TOK_this, TemplateTypeParameter!false);
}

//-- GRAMMAR_BEGIN --
//TemplateValueParameter:
//    TemplateValueDeclaration
//    TemplateValueDeclaration TemplateValueParameterSpecialization
//    TemplateValueDeclaration TemplateValueParameterDefault
//    TemplateValueDeclaration TemplateValueParameterSpecialization TemplateValueParameterDefault
//
//TemplateValueDeclaration:
//    ParameterDeclarator /* without storage classes */
//
//TemplateValueParameterSpecialization:
//    : ConditionalExpression
//
//TemplateValueParameterDefault:
//    = __FILE__ /* already part of ConditionalExpression */
//    = __LINE__ /* already part of ConditionalExpression */
//    = ConditionalExpression
class TemplateValueParameter
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.TemplateValueParameter(p.tok));
        p.pushState(&shiftDecl);
        return ParameterDeclarator.enter(p);
    }

    static Action enterIdentifier(Parser p)
    {
        p.pushNode(new ast.TemplateValueParameter(p.tok));
        p.pushState(&shiftDecl);
        return ParameterDeclarator.enterTypeIdentifier(p);
    }

    static Action shiftDecl(Parser p)
    {
        p.popAppendTopNode!(ast.TemplateValueParameter)();
        switch(p.tok.id)
        {
            case TOK_colon:
                p.pushState(&shiftSpecialization);
                p.pushState(&ConditionalExpression.enter);
                return Accept;
            case TOK_assign:
                p.pushState(&shiftDefault);
                p.pushState(&ConditionalExpression.enter);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftSpecialization(Parser p)
    {
        auto special = p.popNode!(ast.Expression)();
        auto param = p.topNode!(ast.TemplateValueParameter);
        param.specialization = special;
        param.addMember(special);

        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftDefault);
                p.pushState(&ConditionalExpression.enter);
                return Accept;
            default:
                return Forward;
        }
    }

    static Action shiftDefault(Parser p)
    {
        auto def = p.popNode!(ast.Expression)();
        auto param = p.topNode!(ast.TemplateValueParameter);
        param.def = def;
        param.addMember(def);
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//TemplateAliasParameter:
//    alias Type_opt Identifier TemplateAliasParameterSpecialization_opt TemplateAliasParameterDefault_opt
//
//TemplateAliasParameterSpecialization:
//    : Type
//
//TemplateAliasParameterDefault:
//    = TypeOrExpression
class TemplateAliasParameter
{
    mixin SequenceNode!(ast.TemplateAliasParameter, TOK_alias, TemplateTypeParameter!true);
}

//-- GRAMMAR_BEGIN --
//ClassTemplateDeclaration:
//    class Identifier ( TemplateParameterList ) Constraint_opt BaseClassList_opt ClassBody
//
//InterfaceTemplateDeclaration:
//    interface Identifier ( TemplateParameterList ) Constraint_opt BaseInterfaceList_opt InterfaceBody
//
//TemplateMixinDeclaration:
//    mixin template TemplateIdentifier ( TemplateParameterList ) Constraint_opt { DeclDefs }
class TemplateMixinDeclaration
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_mixin:
                p.pushState(&shiftTemplateDeclaration);
                p.pushState(&TemplateDeclaration.enter);
                return Accept;
            default:
                return p.parseError("mixin expected in mixin template declaration");
        }
    }

    static Action enterAfterMixin(Parser p)
    {
        p.pushState(&shiftTemplateDeclaration);
        return TemplateDeclaration.enter(p);
    }

    static Action shiftTemplateDeclaration(Parser p)
    {
        p.topNode!(ast.TemplateDeclaration).id = TOK_mixin;
        return Forward;
    }
}

//TemplateMixin:
//    mixin TemplateIdentifier ;
//    mixin TemplateIdentifier MixinIdentifier ;
//    mixin TemplateIdentifier ! ( TemplateArgumentList ) ;
//    mixin TemplateIdentifier ! ( TemplateArgumentList ) MixinIdentifier ;
//
//MixinIdentifier:
//    Identifier
//
// translated to
//-- GRAMMAR_BEGIN --
//TemplateMixin:
//    mixin GlobalIdentifierList MixinIdentifier_opt ;
//    mixin Typeof . IdentifierList MixinIdentifier_opt ;
class TemplateMixin
{
    mixin SequenceNode!(ast.TemplateMixin, TOK_mixin, GlobalIdentifierList, Opt!(Identifier, TOK_Identifier), TOK_semicolon);

    static Action enterAfterMixin(Parser p)
    {
        p.pushNode(new ast.TemplateMixin(p.tok));
        switch(p.tok.id)
        {
            case TOK_typeof:
                p.pushState(&shiftTypeof);
                return PostfixExpression.enter(p);
            default:
                return shift1.shift(p);
        }
    }

    static Action shiftTypeof(Parser p)
    {
        // already in shift2.shift(): p.popAppendTopNode!(ast.TemplateMixin)();
        return shift2.shift(p);
    }
}

//-- GRAMMAR_BEGIN --
//Constraint:
//    if ( ConstraintExpression )
//
//ConstraintExpression:
//    Expression
class Constraint
{
    mixin SequenceNode!(ast.Constraint, TOK_if, TOK_lparen, Expression, TOK_rparen);
}
