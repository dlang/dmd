// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.stmt;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.expr;
import vdc.parser.decl;
import vdc.parser.iasm;
import vdc.parser.mod;
import vdc.parser.misc;
import vdc.parser.tmpl;
import vdc.parser.aggr;

import ast = vdc.ast.all;

import stdext.util;

//-- GRAMMAR_BEGIN --
//Statement:
//    ScopeStatement
class Statement
{
    static Action enter(Parser p)
    {
        return ScopeStatement.enter(p);
    }
}

//-- GRAMMAR_BEGIN --
//ScopeStatement:
//    ;
//    NonEmptyStatement
//    ScopeBlockStatement
//
//ScopeBlockStatement:
//    BlockStatement
class ScopeStatement : Statement
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.pushNode(new ast.EmptyStatement(p.tok));
                return Accept;
            case TOK_lcurly:
                return BlockStatement.enter(p);
            default:
                return NonEmptyStatement.enter(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//ScopeNonEmptyStatement:
//    NonEmptyStatement
//    BlockStatement
class ScopeNonEmptyStatement : Statement
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                return BlockStatement.enter(p);
            default:
                return NonEmptyStatement.enter(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//NoScopeNonEmptyStatement:
//    NonEmptyStatement
//    BlockStatement
alias ScopeNonEmptyStatement NoScopeNonEmptyStatement;

//-- GRAMMAR_BEGIN --
//NoScopeStatement:
//    ;
//    NonEmptyStatement
//    BlockStatement
alias ScopeStatement NoScopeStatement;

//-- GRAMMAR_BEGIN --
//NonEmptyStatement:
//    LabeledStatement
//    ExpressionStatement
//    DeclarationStatement
//    IfStatement
//    WhileStatement
//    DoStatement
//    ForStatement
//    ForeachStatement
//    SwitchStatement
//    FinalSwitchStatement
//    CaseStatement
//    CaseRangeStatement
//    DefaultStatement
//    ContinueStatement
//    BreakStatement
//    ReturnStatement
//    GotoStatement
//    WithStatement
//    SynchronizedStatement
//    VolatileStatement
//    TryStatement
//    ScopeGuardStatement
//    ThrowStatement
//    AsmStatement
//    PragmaStatement
//    MixinStatement
//    ForeachRangeStatement
//    ConditionalStatement
//    StaticAssert
//    TemplateMixin
//    EnumDeclaration
//    ClassDeclaration
//    InterfaceDeclaration
//    AggregateDeclaration
//    TemplateDeclaration
//
//LabeledStatement:
//    Identifier : NoScopeStatement
class NonEmptyStatement : Statement
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_if:
                return IfStatement.enter(p);
            case TOK_while:
                return WhileStatement.enter(p);
            case TOK_do:
                return DoStatement.enter(p);
            case TOK_for:
                return ForStatement.enter(p);
            case TOK_foreach:
            case TOK_foreach_reverse:
                return ForeachStatement.enter(p); // includes ForeachRangeStatement
            case TOK_switch:
                return SwitchStatement.enter(p);
            case TOK_final:
                // could also be a declaration?
                return FinalSwitchStatement.enter(p);
            case TOK_case:
                return CaseStatement.enter(p); // includes CaseRangeStatement
            case TOK_default:
                return DefaultStatement.enter(p);
            case TOK_continue:
                return ContinueStatement.enter(p);
            case TOK_break:
                return BreakStatement.enter(p);
            case TOK_return:
                return ReturnStatement.enter(p);
            case TOK_goto:
                return GotoStatement.enter(p);
            case TOK_with:
                return WithStatement.enter(p);
            case TOK_synchronized:
                // could also be a declaration?
                return SynchronizedStatement.enter(p);
            case TOK_volatile:
                // could also be a declaration?
                return VolatileStatement.enter(p);
            case TOK_try:
                return TryStatement.enter(p);
            case TOK_scope:
                p.pushState(&shiftScope);
                return Accept;
            case TOK_throw:
                return ThrowStatement.enter(p);
            case TOK_asm:
                return AsmStatement.enter(p);
            case TOK_pragma:
                return PragmaStatement.enter(p);
            case TOK_mixin:
                p.pushRollback(&rollbackDeclFailure);
                p.pushState(&shiftMixin);
                return Accept;

            case TOK_debug:
            case TOK_version:
                return ConditionalStatement.enter(p);

            case TOK_static: // can also be static assert or declaration
                p.pushToken(p.tok);
                p.pushState(&shiftStatic);
                return Accept;

            case TOK_Identifier:
                // label, declaration or expression
                p.pushRollback(&rollbackDeclFailure);
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_enum:
                p.pushState(&shiftDeclaration);
                return EnumDeclaration.enter(p);

            case TOK_struct:
            case TOK_union:
            case TOK_class:
            case TOK_interface:
                p.pushState(&shiftDeclaration);
                return AggregateDeclaration.enter(p);

            case TOK_template:
                p.pushState(&shiftDeclaration);
                return TemplateDeclaration.enter(p);

            case TOK_align:
            case TOK_extern:
                p.pushState(&shiftDeclaration);
                return AttributeSpecifier.enter(p);

            mixin(case_TOKs_BasicTypeX);
                goto case;
            case TOK_deprecated:
            // case TOK_static:
            // case TOK_final:
            case TOK_override:
            case TOK_abstract:
            case TOK_const:
            case TOK_auto:
            // case TOK_scope:
            case TOK___gshared:
            case TOK___thread:
            case TOK___vector:
            case TOK_shared:
            case TOK_immutable:
            case TOK_inout:
            mixin(case_TOKs_FunctionAttribute);
                p.pushState(&shiftDeclaration);
                return Declaration.enter(p);

            case TOK_import:
                p.pushRollback(&rollbackDeclFailure);
                p.pushState(&shiftImport);
                return ImportDeclaration.enter(p);

            default:
                p.pushRollback(&rollbackDeclFailure);
                p.pushState(&shiftDecl);
                return Declaration.enter(p);
        }
    }

    // assumes identifier token pushed on token stack
    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_colon:
                p.popRollback();
                Token tok = p.popToken();
                p.pushNode(new ast.LabeledStatement(tok));
                p.pushState(&shiftLabeledStatement);
                p.pushState(&NoScopeStatement.enter);
                return Accept;

            default:
                p.pushState(&shiftDecl);
                return Decl!true.enterTypeIdentifier(p);
        }
    }

    static Action shiftLabeledStatement(Parser p)
    {
        p.popAppendTopNode!(ast.LabeledStatement);
        return Forward;
    }

    static Action shiftDecl(Parser p)
    {
        p.popRollback();
        return shiftDeclaration(p);
    }

    static rollbackDeclFailure(Parser p)
    {
        return ExpressionStatement.enter(p);
    }

    static Action shiftStatic(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_if:
                p.popToken();
                return ConditionalStatement.enterAfterStatic(p);
            case TOK_assert:
                p.popToken();
                return StaticAssert.enterAfterStatic(p);
            default:
                p.pushState(&shiftDeclaration);
                return AttributeSpecifier.enterAfterStatic(p);
        }
    }

    static Action shiftMixin(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_template:
                p.pushState(&shiftDeclaration);
                return TemplateMixinDeclaration.enterAfterMixin(p);
            case TOK_lparen:
                p.pushState(&shiftMixInStatement);
                return MixinStatement.enterAfterMixin(p);
            default:
                return TemplateMixin.enterAfterMixin(p);
        }
    }

    static Action shiftScope(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                return ScopeGuardStatement.enterAfterScope(p);
            default:
                return Decl!true.enterAfterStorageClass(p, TOK_scope);
        }
    }

    static Action shiftDeclaration(Parser p)
    {
        p.appendReplaceTopNode(new ast.DeclarationStatement(p.topNode().span));
        return Forward;
    }

    static Action shiftMixInStatement(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.popRollback();
                return Accept;
            default:
                // roll back for mixin expression
                return p.parseError("';' expected after mixin statement");
        }
    }

    static Action shiftImport(Parser p)
    {
        p.popRollback();
        p.appendReplaceTopNode(new ast.ImportStatement(p.topNode().span));
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//BlockStatement:
//    { }
//    { StatementList }
//
//StatementList:
//    Statement
//    Statement StatementList
class BlockStatement : Statement
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                p.pushNode(new ast.BlockStatement(p.tok));
                p.pushRecoverState(&recover);
                p.pushState(&Parser.keepRecover);   // add a "guard" state to avoid popping recover
                p.pushState(&shiftLcurly);
                return Accept;
            default:
                return p.parseError("opening curly brace expected");
        }
    }

    static Action shiftLcurly(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rcurly:
                return Accept;
            case TOK_EOF:
                return Forward;
            default:
                p.pushState(&shiftStatement);
                return Statement.enter(p);
        }
    }

    static Action shiftStatement(Parser p)
    {
        p.popAppendTopNode!(ast.BlockStatement)();
        return shiftLcurly(p);
    }

    static Action recover(Parser p)
    {
        auto node = new ast.ParseRecoverNode(p.tok);
        if(p.nodeStack.depth)
            node.fulspan.start = p.topNode().fulspan.end; // record span of removed text
        p.pushNode(node);
        p.pushState(&afterRecover);
        return Parser.recoverSemiCurly(p);
    }

    static Action afterRecover(Parser p)
    {
        p.popAppendTopNode!(ast.BlockStatement, ast.ParseRecoverNode)();

        p.pushRecoverState(&recover);
        p.pushState(&Parser.keepRecover);   // add a "guard" state to avoid popping recover

        return shiftLcurly(p);
    }
}

//-- GRAMMAR_BEGIN --
//ExpressionStatement:
//    Expression ;
class ExpressionStatement : Statement
{
    mixin SequenceNode!(ast.ExpressionStatement, Expression, TOK_semicolon);
}

//-- GRAMMAR_BEGIN --
//DeclarationStatement:
//    Declaration
//
//IfStatement:
//    if ( IfCondition ) ThenStatement
//    if ( IfCondition ) ThenStatement else ElseStatement
//
//ThenStatement:
//    ScopeNonEmptyStatement
//
//ElseStatement:
//    ScopeNonEmptyStatement
class IfStatement : Statement
{
    // if ( IfCondition ) $ ThenStatement else ElseStatement
    mixin stateAppendClass!(ScopeNonEmptyStatement, shiftElse) stateThenStatement;

    // if ( IfCondition $ ) ThenStatement else ElseStatement
    mixin stateShiftToken!(TOK_rparen, stateThenStatement.shift) stateRparen;

    // if ( $ IfCondition ) ThenStatement else ElseStatement
    mixin stateAppendClass!(IfCondition, stateRparen.shift) stateCondition;

    // if $ ( IfCondition ) ThenStatement else ElseStatement
    mixin stateShiftToken!(TOK_lparen, stateCondition.shift) stateLparen;

    // $ if ( IfCondition ) ThenStatement else ElseStatement
    mixin stateEnterToken!(TOK_if, ast.IfStatement, stateLparen.shift);

    // if ( IfCondition ) ThenStatement $ else ElseStatement
    static Action shiftElse(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_else:
                p.pushState(&shiftElseStatement);
                p.pushState(&ScopeNonEmptyStatement.enter);
                return Accept;
            default:
                return Forward;
        }
    }

    // if ( IfCondition ) ThenStatement else ElseStatement $
    static Action shiftElseStatement(Parser p)
    {
        p.popAppendTopNode!(ast.IfStatement, ast.Statement)();
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//IfCondition:
//    Expression
//    auto Identifier = Expression
//    BasicType BasicTypes2_opt Declarator = Expression
//
class IfCondition
{
    static Action enter(Parser p)
    {
        p.pushRollback(&rollbackTypeFailure);
        p.pushState(&shiftDecl);
        return Decl!false.enter(p);
    }

    static Action shiftDecl(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("')' expected after declaration");

        p.popRollback();
        return Forward;
    }

    static Action rollbackTypeFailure(Parser p)
    {
        return Expression.enter(p);
    }
}

//-- GRAMMAR_BEGIN --
//WhileStatement:
//    while ( Expression ) ScopeNonEmptyStatement
class WhileStatement : Statement
{
    mixin SequenceNode!(ast.WhileStatement, TOK_while, TOK_lparen, Expression, TOK_rparen, ScopeNonEmptyStatement);
}

//-- GRAMMAR_BEGIN --
//DoStatement:
//    do ScopeNonEmptyStatement while ( Expression )
// trailing ';' currently not part of grammar ;-(
class DoStatement : Statement
{
    mixin SequenceNode!(ast.DoStatement, TOK_do, ScopeNonEmptyStatement, TOK_while, TOK_lparen, Expression, TOK_rparen); //, TOK_semicolon);
}

//-- GRAMMAR_BEGIN --
//ForStatement:
//    for ( Initialize Test ; Increment ) ScopeNonEmptyStatement
//Initialize:
//    ;
//    NoScopeNonEmptyStatement
//
//Test:
//    Expression_opt
//
//Increment:
//    Expression_opt
//
class ForStatement : Statement
{
    mixin SequenceNode!(ast.ForStatement, TOK_for, TOK_lparen, Initialize, Expression_opt, TOK_semicolon, Expression_opt, TOK_rparen, ScopeNonEmptyStatement);
}

class Initialize
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
                p.pushNode(new ast.EmptyStatement(p.tok));
                return Accept;
            default:
                return NoScopeNonEmptyStatement.enter(p);
        }
    }
}

class Expression_opt
{
    // cerates "void" if no expression
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
            case TOK_rcurly:
            case TOK_rbracket:
            case TOK_rparen:
                p.pushNode(new ast.EmptyExpression(p.tok));
                return Forward;
            default:
                return Expression.enter(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//ForeachStatement:
//    Foreach ( ForeachTypeList ; Aggregate ) NoScopeNonEmptyStatement
//
//Foreach:
//    foreach
//    foreach_reverse
//
//Aggregate:
//    Expression
//    Type
//
//ForeachRangeStatement:
//    Foreach ( ForeachType ; LwrExpression .. UprExpression ) ScopeNonEmptyStatement
//
//LwrExpression:
//    Expression
//
//UprExpression:
//    Expression
class ForeachStatement : Statement
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_foreach:
            case TOK_foreach_reverse:
                p.pushNode(new ast.ForeachStatement(p.tok));
                p.pushState(&stateLparen.shift);
                return Accept;
            default:
                return p.parseError("foreach or foreach_reverse expected");
        }
    }

    // Foreach ( ForeachTypeList ; Aggregate ) $ NoScopeNonEmptyStatement
    mixin stateAppendClass!(NoScopeNonEmptyStatement, Parser.forward) stateStatement;

    // Foreach ( ForeachTypeList ; LwrExpression .. UprExpression $ ) NoScopeNonEmptyStatement
    mixin stateShiftToken!(TOK_rparen, stateStatement.shift) stateRparen;

    // Foreach ( ForeachType ; LwrExpression .. $ UprExpression ) ScopeNonEmptyStatement
    mixin stateAppendClass!(Expression, stateRparen.shift) stateUprExpression;

    // Foreach ( ForeachTypeList ; Aggregate $ ) NoScopeNonEmptyStatement
    // Foreach ( ForeachType ; LwrExpression $ .. UprExpression ) ScopeNonEmptyStatement
    static Action shiftExpression(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_slice:
                p.popAppendTopNode!();
                p.popRollback();
                p.pushState(&stateUprExpression.shift);
                return Accept;
            case TOK_rparen:
                p.popAppendTopNode!();
                p.popRollback();
                p.pushState(&stateStatement.shift);
                return Accept;
            default:
                return p.parseError("closing parenthesis expected");
        }
    }

    static Action shiftType(Parser p)
    {
        // static foreach with type tuple
        switch(p.tok.id)
        {
            case TOK_rparen:
                p.popAppendTopNode!();
                p.pushState(&stateStatement.shift);
                return Accept;
            default:
                return p.parseError("closing parenthesis expected");
        }
    }

    // Foreach ( ForeachTypeList ; $ Aggregate ) NoScopeNonEmptyStatement
    static Action stateExpression(Parser p)
    {
        p.pushRollback(&rollbackExpression);
        p.pushState(&shiftExpression);
        return Expression.enter(p);
    }
    static Action rollbackExpression(Parser p)
    {
        p.pushState(&shiftType);
        return Type.enter(p);
    }

    // Foreach ( ForeachTypeList $ ; Aggregate ) NoScopeNonEmptyStatement
    mixin stateShiftToken!(TOK_semicolon, stateExpression) stateSemicolon;

    // Foreach ( $ ForeachTypeList ; Aggregate ) NoScopeNonEmptyStatement
    mixin stateAppendClass!(ForeachTypeList, stateSemicolon.shift) stateForeachTypeList;

    // Foreach $ ( ForeachTypeList ; Aggregate ) NoScopeNonEmptyStatement
    mixin stateShiftToken!(TOK_lparen, stateForeachTypeList.shift) stateLparen;
}

//-- GRAMMAR_BEGIN --
//ForeachTypeList:
//    ForeachType
//    ForeachType , ForeachTypeList
class ForeachTypeList
{
    mixin ListNode!(ast.ForeachTypeList, ForeachType, TOK_comma);
}

//-- GRAMMAR_BEGIN --
//ForeachType:
//    ref_opt Type_opt Identifier
//
class ForeachType
{
    static Action enter(Parser p)
    {
        auto n = new ast.ForeachType(p.tok);
        p.pushNode(n);
        return shiftRef(p);
    }

    static Action shiftRef(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_ref:
                auto n = p.topNode!(ast.ForeachType)();
                n.isRef = true;
                p.pushState(&shiftRef);
                return Accept;

            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;

            case TOK_const:
            case TOK_immutable:
            case TOK_shared:
            case TOK_inout:
                p.pushToken(p.tok);
                p.pushState(&shiftTypeModifier);
                return Accept;

            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftTypeModifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&shiftType);
                return Type.enterTypeModifier(p);

            default:
                auto tok = p.popToken();
                auto n = p.topNode!(ast.ForeachType)();
                combineAttributes(n.attr, tokenToAttribute(tok.id));
                return shiftRef(p);
        }
    }

    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_semicolon:
            case TOK_comma:
                auto tok = p.popToken();
                auto n = p.topNode!(ast.ForeachType)();
                // add auto type here?
                n.addMember(new ast.Identifier(tok));
                return Forward;
            default:
                p.pushState(&shiftType);
                return Type.enterIdentifier(p);
        }
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.ForeachType, ast.Type)();

        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.topNode!(ast.ForeachType).addMember(new ast.Identifier(p.tok));
                return Accept;
            default:
                return p.parseError("identifier expected");
        }
    }
}

//-- GRAMMAR_BEGIN --
//SwitchStatement:
//    switch ( Expression ) ScopeNonEmptyStatement
class SwitchStatement : Statement
{
    mixin SequenceNode!(ast.SwitchStatement, TOK_switch, TOK_lparen, Expression, TOK_rparen, ScopeNonEmptyStatement);
}

//-- GRAMMAR_BEGIN --
//FinalSwitchStatement:
//    final switch ( Expression ) ScopeNonEmptyStatement
//
class FinalSwitchStatement : Statement
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_final)
            return p.parseError("final expected");
        p.pushState(&shiftFinal);
        return Accept;
    }

    static Action shiftFinal(Parser p)
    {
        if(p.tok.id != TOK_switch)
            return p.parseError("switch expected");
        p.pushState(&shiftSwitch);
        return SwitchStatement.enter(p);
    }

    static Action shiftSwitch(Parser p)
    {
        p.topNode!(ast.SwitchStatement)().isFinal = true;
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//CaseStatement:
//    case ArgumentList : Statement_opt
//
//CaseRangeStatement:
//    case FirstExp : .. case LastExp : Statement_opt
//
//FirstExp:
//    AssignExpression
//
//LastExp:
//    AssignExpression
class CaseStatement : Statement
{
    // also used by DefaultStatement
    static Action stateStatement(Parser p)
    {
        return Forward;
/+
        switch(p.tok.id)
        {
            case TOK_case:
            case TOK_default:
            case TOK_rcurly:
                return Forward;
            default:
                p.pushState(&Parser.popForward);
                return Statement.enter(p);
        }
+/
    }

    // argument list
    mixin stateShiftToken!(TOK_comma, stateArgumentList_shift,
                           TOK_colon, stateStatement) stateAfterArg;

    // mixin expanded due to unresolvable forward references
    // mixin stateAppendClass!(AssignExpression, stateAfterArg.shift) stateArgumentList;
    static Action stateArgumentList_shift(Parser p)
    {
        p.pushState(&stateArgumentList_reduce);
        return AssignExpression.enter(p);
    }
    static Action stateArgumentList_reduce(Parser p)
    {
        p.popAppendTopNode!();
        return stateAfterArg.shift(p);
    }

    // range
    mixin stateShiftToken!(TOK_colon, stateStatement) stateAfterLast;

    mixin stateAppendClass!(AssignExpression, stateAfterLast.shift) stateCaseLast;

    mixin stateShiftToken!(TOK_case, stateCaseLast.shift) stateRange;

    static Action stateRememberRange(Parser p)
    {
        p.topNode!(ast.CaseStatement).id = TOK_slice;
        return stateRange.shift(p);
    }

    // disambiguation
    mixin stateShiftToken!(TOK_slice, stateRememberRange,
                           -1, stateStatement) stateFirstArgument;

    mixin stateShiftToken!(TOK_comma, stateArgumentList_shift,
                           TOK_colon, stateFirstArgument.shift) stateAfterFirstArg;

    mixin stateAppendClass!(AssignExpression, stateAfterFirstArg.shift) stateArgument;

    // $ case ArgumentList : Statement
    // $ case AssignExpression : Statement
    // $ case FirstExp : .. case LastExp : Statement
    mixin stateEnterToken!(TOK_case, ast.CaseStatement, stateArgument.shift);

}

//-- GRAMMAR_BEGIN --
//DefaultStatement:
//    default : Statement_opt
class DefaultStatement : Statement
{
    mixin SequenceNode!(ast.DefaultStatement, TOK_default, TOK_colon, CaseStatement.stateStatement);
}

//-- GRAMMAR_BEGIN --
//ContinueStatement:
//    continue ;
//    continue Identifier ;
class ContinueStatement : Statement
{
    mixin SequenceNode!(ast.ContinueStatement, TOK_continue, Identifier_opt!(ast.ContinueStatement), TOK_semicolon);
}

class Identifier_opt(T) : Statement
{
    enum doNotPopNode = true;

    static Action enter(Parser p)
    {
        if(p.tok.id == TOK_Identifier)
        {
            p.topNode!T().ident = p.tok.txt;
            return Accept;
        }
        return Forward;
    }
}

//-- GRAMMAR_BEGIN --
//BreakStatement:
//    break ;
//    break Identifier ;
class BreakStatement : Statement
{
    mixin SequenceNode!(ast.BreakStatement, TOK_break, Identifier_opt!(ast.BreakStatement), TOK_semicolon);
}


//-- GRAMMAR_BEGIN --
//ReturnStatement:
//    return ;
//    return Expression ;
class ReturnStatement : Statement
{
    mixin SequenceNode!(ast.ReturnStatement, TOK_return, Expression_opt, TOK_semicolon);
}


//-- GRAMMAR_BEGIN --
//GotoStatement:
//    goto Identifier ;
//    goto default ;
//    goto case ;
//    goto case Expression ;
class GotoStatement : Statement
{
    mixin stateShiftToken!(TOK_semicolon, Parser.forward) stateSemicolon;

    mixin stateAppendClass!(Expression, stateSemicolon.shift) stateExpression;

    mixin stateShiftToken!(TOK_semicolon, Parser.forward,
                           -1, stateExpression.shift) stateCase;

    static Action rememberArgument(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.topNode!(ast.GotoStatement).ident = p.tok.txt;
                p.topNode!(ast.GotoStatement).id = TOK_Identifier;
                p.pushState(&stateSemicolon.shift);
                return Accept;
            case TOK_default:
                p.topNode!(ast.GotoStatement).id = TOK_default;
                p.pushState(&stateSemicolon.shift);
                return Accept;
            case TOK_case:
                p.topNode!(ast.GotoStatement).id = TOK_case;
                p.pushState(&stateCase.shift);
                return Accept;
            default:
                return p.parseError("identifier, case or default expected in goto statement");
        }
    }

    mixin stateEnterToken!(TOK_goto, ast.GotoStatement, rememberArgument);
}

//-- GRAMMAR_BEGIN --
//WithStatement:
//    with ( Expression ) ScopeNonEmptyStatement
//    with ( Symbol ) ScopeNonEmptyStatement
//    with ( TemplateInstance ) ScopeNonEmptyStatement
class WithStatement : Statement
{
    // Symbol, TemplateInstance also syntactically included by Expression
    mixin SequenceNode!(ast.WithStatement, TOK_with, TOK_lparen, Expression, TOK_rparen, ScopeNonEmptyStatement);
}

//-- GRAMMAR_BEGIN --
//SynchronizedStatement:
//    synchronized ScopeNonEmptyStatement
//    synchronized ( Expression ) ScopeNonEmptyStatement
class SynchronizedStatement : Statement
{
    mixin stateAppendClass!(ScopeNonEmptyStatement, Parser.forward) stateStatement;

    mixin stateShiftToken!(TOK_rparen, stateStatement.shift) stateRparen;

    mixin stateAppendClass!(Expression, stateRparen.shift) stateExpression;

    mixin stateShiftToken!(TOK_lparen, stateExpression.shift,
                           -1, stateStatement.shift) stateLparen;

    mixin stateEnterToken!(TOK_synchronized, ast.SynchronizedStatement, stateLparen.shift);
}

//-- GRAMMAR_BEGIN --
//VolatileStatement:
//    volatile ScopeNonEmptyStatement
class VolatileStatement : Statement
{
    mixin SequenceNode!(ast.VolatileStatement, TOK_volatile, ScopeNonEmptyStatement);
}


//-- GRAMMAR_BEGIN --
//TryStatement:
//    try ScopeNonEmptyStatement Catches
//    try ScopeNonEmptyStatement Catches FinallyStatement
//    try ScopeNonEmptyStatement FinallyStatement
//
//Catches:
//    LastCatch
//    Catch
//    Catch Catches
//
//LastCatch:
//    catch NoScopeNonEmptyStatement
//
//FinallyStatement:
//    finally NoScopeNonEmptyStatement
class TryStatement : Statement
{
    mixin stateAppendClass!(FinallyStatement, Parser.forward) stateFinally;

    static Action reduceLastCatch(Parser p)
    {
        p.popAppendTopNode!(ast.Catch, ast.Statement)();
        p.popAppendTopNode!(ast.TryStatement, ast.Catch)();
        switch(p.tok.id)
        {
            case TOK_finally:
                return stateFinally.shift(p);
            default:
                return Forward;
        }
    }

    static Action reduceCatch(Parser p)
    {
        p.popAppendTopNode!(ast.TryStatement, ast.Catch)();
        return stateCatches_shift(p);
    }

    static Action shiftCatch(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lparen:
                p.pushState(&reduceCatch);
                return Catch.enterAfterCatch(p);
            default:
                p.pushState(&reduceLastCatch);
                p.pushNode(new ast.Catch(p.tok));
                return NoScopeNonEmptyStatement.enter(p);
        }
    }

    static Action stateCatches_shift(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_catch:
                p.pushState(&shiftCatch);
                return Accept;
            case TOK_finally:
                return stateFinally.shift(p);
            default:
                if(p.topNode!(ast.TryStatement).members.length < 2)
                    return p.parseError("catch or finally expected");
                return Forward;
        }
    }

    mixin stateAppendClass!(ScopeNonEmptyStatement, stateCatches_shift) stateTryStatement;

    mixin stateEnterToken!(TOK_try, ast.TryStatement, stateTryStatement.shift);
}

//-- GRAMMAR_BEGIN --
//Catch:
//    catch ( CatchParameter ) NoScopeNonEmptyStatement
//
//CatchParameter:
//    BasicType Identifier
class Catch
{
    mixin SequenceNode!(ast.Catch, TOK_catch, TOK_lparen, BasicType, Opt!(Identifier, TOK_Identifier), TOK_rparen, NoScopeNonEmptyStatement);

    static Action enterAfterCatch(Parser p)
    {
        p.pushNode(new ast.Catch(p.tok));
        return shift1.shift(p);
    }
}

class FinallyStatement
{
    mixin SequenceNode!(ast.FinallyStatement, TOK_finally, NoScopeNonEmptyStatement);
}

//-- GRAMMAR_BEGIN --
//ThrowStatement:
//    throw Expression ;
class ThrowStatement : Statement
{
    mixin SequenceNode!(ast.ThrowStatement, TOK_throw, Expression, TOK_semicolon);
}

//-- GRAMMAR_BEGIN --
//ScopeGuardStatement:
//    scope ( "exit" ) ScopeNonEmptyStatement
//    scope ( "success" ) ScopeNonEmptyStatement
//    scope ( "failure" ) ScopeNonEmptyStatement
class ScopeGuardStatement : Statement
{
    mixin SequenceNode!(ast.ScopeGuardStatement, TOK_scope, TOK_lparen, ScopeGuardIdentifier, TOK_rparen, ScopeNonEmptyStatement);

    static Action enterAfterScope(Parser p)
    {
        p.pushNode(new ast.ScopeGuardStatement(p.tok));
        return shift1.shift(p);
    }
}

class ScopeGuardIdentifier
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected");
        if(!isIn(p.tok.txt, "exit", "success", "failure"))
            return p.parseError("one of exit, success and failure expected in scope guard statement");

        p.pushNode(new ast.Identifier(p.tok));
        return Accept;
    }
}

//-- GRAMMAR_BEGIN --
//AsmStatement:
//    asm { }
//    asm { AsmInstructionList }
//
//AsmInstructionList:
//    AsmInstruction ;
//    AsmInstruction ; AsmInstructionList
class AsmStatement : Statement
{
    mixin SequenceNode!(ast.AsmStatement, TOK_asm, TOK_lcurly, AsmInstructionList, TOK_rcurly);
}

class AsmInstructionList
{
    mixin ListNode!(ast.AsmInstructionList, AsmInstruction, TOK_semicolon, true);
}

//-- GRAMMAR_BEGIN --
//PragmaStatement:
//    Pragma NoScopeStatement
class PragmaStatement : Statement
{
    mixin SequenceNode!(ast.PragmaStatement, Pragma, NoScopeStatement);
}

//-- GRAMMAR_BEGIN --
//MixinStatement:
//    mixin ( AssignExpression ) ;
class MixinStatement : Statement
{
    mixin SequenceNode!(ast.MixinStatement, TOK_mixin, TOK_lparen, AssignExpression, TOK_rparen);

    static Action enterAfterMixin(Parser p)
    {
        p.pushNode(new ast.MixinStatement(p.tok));
        return shift1.shift(p);
    }
}
