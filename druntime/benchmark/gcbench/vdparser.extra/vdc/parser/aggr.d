// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.aggr;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.mod;
import vdc.parser.tmpl;
import vdc.parser.decl;
import vdc.parser.misc;
import vdc.parser.stmt;

import ast = vdc.ast.all;

import stdext.util;

//-- GRAMMAR_BEGIN --
//AggregateDeclaration:
//    struct Identifier StructBody
//    union Identifier StructBody
//    struct Identifier ;
//    union Identifier ;
//    StructTemplateDeclaration
//    UnionTemplateDeclaration
//    ClassDeclaration
//    InterfaceDeclaration
//
//StructTemplateDeclaration:
//    struct Identifier ( TemplateParameterList ) Constraint_opt StructBody
//
//UnionTemplateDeclaration:
//    union Identifier ( TemplateParameterList ) Constraint_opt StructBody
//
//ClassDeclaration:
//    class Identifier BaseClassList_opt ClassBody
//    ClassTemplateDeclaration
//
//BaseClassList:
//    : SuperClass
//    : SuperClass , InterfaceClasses
//    : InterfaceClass
//
//SuperClass:
//    GlobalIdentifierList
//    Protection GlobalIdentifierList
//
//InterfaceClasses:
//    InterfaceClass
//    InterfaceClass , InterfaceClasses
//
//InterfaceClass:
//    GlobalIdentifierList
//    Protection GlobalIdentifierList
//
//InterfaceDeclaration:
//    interface Identifier BaseInterfaceList_opt InterfaceBody
//    InterfaceTemplateDeclaration
//
//BaseInterfaceList:
//    : InterfaceClasses
//
//StructBody:
//    { DeclDefs_opt }
//
//ClassBody:
//    { DeclDefs_opt }
//
//InterfaceBody:
//    { DeclDefs_opt }
//
//Protection:
//    private
//    package
//    public
//    export
class AggregateDeclaration
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_union:
                p.pushState(&shiftUnion);
                return Accept;
            case TOK_struct:
                p.pushState(&shiftStruct);
                return Accept;
            case TOK_class:
                p.pushState(&shiftClass);
                return Accept;
            case TOK_interface:
                p.pushState(&shiftInterface);
                return Accept;
            default:
                return p.parseError("class, struct or union expected");
        }
    }

    static Action shiftStruct(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.Struct(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_lcurly:
            case TOK_lparen:
                p.pushNode(new ast.Struct(p.tok.span));
                return shiftIdentifier(p);

            default:
                return p.parseError("struct identifier expected");
        }
    }

    static Action shiftUnion(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.Union(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_lcurly:
            case TOK_lparen:
                p.pushNode(new ast.Union(p.tok.span));
                return shiftIdentifier(p);

            default:
                return p.parseError("union identifier expected");
        }
    }

    static Action shiftClass(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.Class(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                return p.parseError("class identifier expected");
        }
    }

    static Action shiftInterface(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.pushNode(new ast.Intrface(p.tok));
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                return p.parseError("interface identifier expected");
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.topNode!(ast.Aggregate).hasBody = false;
                return Accept;
            case TOK_lcurly:
                return shiftLcurly(p);
            case TOK_lparen:
                p.pushState(&shiftLparen);
                return Accept;

            case TOK_colon:
                if(!cast(ast.Class) p.topNode() && !cast(ast.Intrface) p.topNode())
                    return p.parseError("only classes and interfaces support inheritance");
                p.pushState(&shiftColon);
                return Accept;

            default:
                return p.parseError("';', '(' or '{' expected after struct or union identifier");
        }
    }

    // NewArguments ClassArguments $ BaseClassList_opt ClassBody
    static Action enterAnonymousClass(Parser p)
    {
        p.pushNode(new ast.AnonymousClass(p.tok));
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftLparen);
                return Accept;
            case TOK_lcurly:
                return shiftLcurly(p);
            default:
                return shiftColon(p);
        }
    }

    static Action shiftColon(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_dot:
            case TOK_Identifier:
                p.pushNode(new ast.BaseClass(TOK_public, p.tok.span));
                p.pushState(&shiftBaseClass);
                return GlobalIdentifierList.enter(p);
            case TOK_private:
            case TOK_package:
            case TOK_public:
            case TOK_export:
                p.pushToken(p.tok);
                p.pushState(&shiftProtection);
                return Accept;
            default:
                return p.parseError("identifier or protection attribute expected");
        }
    }

    static Action shiftProtection(Parser p)
    {
        Token tok = p.popToken();
        switch(p.tok.id)
        {
            case TOK_dot:
            case TOK_Identifier:
                p.pushNode(new ast.BaseClass(tok.id, tok.span));
                p.pushState(&shiftBaseClass);
                return GlobalIdentifierList.enter(p);
            default:
                return p.parseError("identifier expected after protection attribute");
        }
    }

    static Action shiftBaseClass(Parser p)
    {
        p.popAppendTopNode();
        auto bc = p.popNode!(ast.BaseClass)();
        p.topNode!(ast.InheritingAggregate).addBaseClass(bc);
        switch(p.tok.id)
        {
            case TOK_comma:
                p.pushState(&shiftColon);
                return Accept;
            case TOK_lcurly:
                return shiftLcurly(p);
            default:
                return p.parseError("'{' expected after base class list");
        }
    }

    static Action shiftLparen(Parser p)
    {
        p.pushState(&shiftTemplateParameterList);
        return TemplateParameterList.enter(p);
    }

    static Action shiftTemplateParameterList(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.popAppendTopNode!(ast.Aggregate)();
                p.topNode!(ast.Aggregate).hasTemplArgs = true;
                p.pushState(&shiftRparen);
                return Accept;
            default:
                return p.parseError("')' expected after template parameter list");
        }
    }

    static Action shiftRparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.topNode!(ast.Aggregate).hasBody = false;
                return Accept;
            case TOK_colon:
                if(!cast(ast.Class) p.topNode() && !cast(ast.Intrface) p.topNode())
                    return p.parseError("only classes and interfaces support inheritance");
                p.pushState(&shiftColon);
                return Accept;
            case TOK_if:
                p.pushState(&shiftConstraint);
                return Constraint.enter(p);
            case TOK_lcurly:
                return shiftLcurly(p);
            default:
                return p.parseError("'{' expected after template parameter list");
        }
    }

    static Action shiftConstraint(Parser p)
    {
        p.popAppendTopNode!(ast.Aggregate)();
        p.topNode!(ast.Aggregate).hasConstraint = true;
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.topNode!(ast.Aggregate).hasBody = false;
                return Accept;
            case TOK_lcurly:
                return shiftLcurly(p);
            case TOK_colon:
                if(!cast(ast.Class) p.topNode() && !cast(ast.Intrface) p.topNode())
                    return p.parseError("only classes and interfaces support inheritance");
                p.pushState(&shiftColon);
                return Accept;
            default:
                return p.parseError("'{' expected after constraint");
        }
    }

    static Action shiftLcurly(Parser p)
    {
        assert(p.tok.id == TOK_lcurly);

        p.pushNode(new ast.StructBody(p.tok));
        p.pushState(&shiftDeclDefs);
        p.pushState(&DeclDefs.enter);
        return Accept;
    }

    static Action shiftDeclDefs(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rcurly:
                p.popAppendTopNode!(ast.Aggregate)();
                return Accept;
            default:
                return p.parseError("closing curly brace expected to terminate aggregate body");
        }
    }
}

//-- GRAMMAR_BEGIN --
//Constructor:
//    this TemplateParameters_opt Parameters MemberFunctionAttributes_opt Constraint_opt FunctionBody
//    this ( this ) Constraint_opt FunctionBody
class Constructor
{
    mixin stateAppendClass!(FunctionBody, Parser.forward) stateFunctionBody;
    //////////////////////////////////////////////////////////////

    mixin stateAppendClass!(Constraint, stateFunctionBody.shift) stateConstraint;

    static Action stateMemberFunctionAttributes(Parser p)
    {
        switch(p.tok.id)
        {
            mixin(case_TOKs_MemberFunctionAttribute);
                {
                    auto ctor = p.topNode!(ast.Constructor);
                    auto list = static_cast!(ast.ParameterList)(ctor.members[$-1]);
                    if(auto attr = tokenToAttribute(p.tok.id))
                        p.combineAttributes(list.attr, attr);
                    if(auto annot = tokenToAnnotation(p.tok.id))
                        p.combineAnnotations(list.annotation, annot);

                    p.pushState(&stateMemberFunctionAttributes);
                    return Accept;
                }
            case TOK_if:
                return stateConstraint.shift(p);
            default:
                return stateFunctionBody.shift(p);
        }
    }

    mixin stateAppendClass!(Parameters, stateMemberFunctionAttributes) stateParametersTemplate;

    mixin stateAppendClass!(TemplateParameters, stateParametersTemplate.shift) stateTemplateParameterList;

    //////////////////////////////////////////////////////////////
    static Action shiftRparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                return Reject; // retry with template arguments
            default:
                p.popRollback();
                return stateMemberFunctionAttributes(p);
        }
    }

    static Action shiftParameters(Parser p)
    {
        p.popAppendTopNode!(ast.Constructor)();
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.pushState(&shiftRparen);
                return Accept;
            default:
                return p.parseError("')' expected");
        }
    }

    static Action gotoParameters(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.topNode!(ast.Constructor)().addMember(new ast.ParameterList(p.tok));
                p.pushState(&shiftRparen);
                return Accept;
            default:
                p.pushState(&shiftParameters);
                return ParameterList.enter(p);
        }
    }

    mixin stateShiftToken!(TOK_rparen, stateFunctionBody.shift) stateThis;

    static Action gotoThis(Parser p)
    {
        p.popRollback();
        return stateThis.shift(p);
    }

    mixin stateShiftToken!(TOK_this, gotoThis,
                           -1, gotoParameters) stateParameters;

    static Action rollbackParameters(Parser p)
    {
        p.topNode!(ast.Constructor)().reinit();

        assert(p.tok.id == TOK_lparen);
        return stateTemplateParameterList.shift(p);
    }

    static Action stateLparen(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushRollback(&rollbackParameters);
                p.pushState(&stateParameters.shift);
                return Accept;
            default:
                return p.parseError("'(' expected in constructor");
        }
    }

    mixin stateEnterToken!(TOK_this, ast.Constructor, stateLparen);
}

//-- GRAMMAR_BEGIN --
//Destructor:
//    ~ this ( ) FunctionBody
class Destructor
{
    mixin SequenceNode!(ast.Destructor, TOK_tilde, TOK_this, TOK_lparen, TOK_rparen, FunctionBody);
}

//-- GRAMMAR_BEGIN --
//StaticConstructor:
//    static this ( ) FunctionBody
//
//StaticDestructor:
//    static ~ this ( ) FunctionBody
//
//SharedStaticConstructor:
//    shared static this ( ) FunctionBody
//
//SharedStaticDestructor:
//    shared static ~ this ( ) FunctionBody
//
//
//StructAllocator:
//    ClassAllocator
//
//StructDeallocator:
//    ClassDeallocator
//
//StructConstructor:
//    this ( ParameterList ) FunctionBody
//
//StructPostblit:
//    this ( this ) FunctionBody
//
//StructDestructor:
//    ~ this ( ) FunctionBody
//
//
//Invariant:
//    invariant ( ) BlockStatement
class Invariant
{
    mixin SequenceNode!(ast.Unittest, TOK_invariant, TOK_lparen, TOK_rparen, BlockStatement);
}

//-- GRAMMAR_BEGIN --
//ClassAllocator:
//    new Parameters FunctionBody
class ClassAllocator
{
    mixin SequenceNode!(ast.ClassAllocator, TOK_new, Parameters, FunctionBody);
}

//-- GRAMMAR_BEGIN --
//ClassDeallocator:
//    delete Parameters FunctionBody
class ClassDeallocator
{
    mixin SequenceNode!(ast.ClassDeallocator, TOK_delete, Parameters, FunctionBody);
}
