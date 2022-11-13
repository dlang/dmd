// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.parser.misc;

import vdc.util;
import vdc.lexer;
import vdc.parser.engine;
import vdc.parser.expr;
import vdc.parser.decl;
import vdc.parser.stmt;
import vdc.parser.mod;

import ast = vdc.ast.all;

import stdext.util;

//-- GRAMMAR_BEGIN --
//EnumDeclaration:
//    enum EnumTag EnumBody
//    enum EnumBody
//    enum EnumTag : EnumBaseType EnumBody
//    enum : EnumBaseType EnumBody
//    enum EnumTag ;
//    enum EnumInitializers ;
//    enum Type EnumInitializers ;
//
//EnumTag:
//    Identifier
//
//EnumBaseType:
//    Type
//
//EnumInitializers:
//    EnumInitializer
//    EnumInitializers , EnumInitializer
//
//EnumInitializer:
//    Identifier = AssignExpression
class EnumDeclaration
{
    static Action enter(Parser p)
    {
        if(p.tok.id != TOK_enum)
            return p.parseError("enum expected");

        p.pushNode(new ast.EnumDeclaration(p.tok));
        p.pushState(&shiftEnum);
        return Accept;
    }

    static Action shiftEnum(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_lcurly:
                p.pushState(&shiftEnumBody);
                return EnumBody.enter(p);
            case TOK_colon:
                p.pushState(&shiftColon);
                return Accept;
            case TOK_Identifier:
                p.pushToken(p.tok);
                p.pushState(&shiftIdentifier);
                return Accept;
            default:
                p.pushState(&shiftType);
                return Type.enter(p);
        }
    }

    static Action shiftColon(Parser p)
    {
        p.pushState(&shiftBaseType);
        return Type.enter(p);
    }

    static Action shiftType(Parser p)
    {
        p.popAppendTopNode!(ast.EnumDeclaration)();
        switch(p.tok.id)
        {
            case TOK_Identifier:
                p.topNode!(ast.EnumDeclaration)().ident = p.tok.txt;
                p.pushState(&shiftAssignAfterType);
                return Accept;
            default:
                return p.parseError("identifier expected after enum type");
        }
    }

    // assumes token on stack
    static Action shiftIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_colon:
                p.topNode!(ast.EnumDeclaration)().ident = p.popToken().txt;
                p.pushState(&shiftColon);
                return Accept;
            case TOK_semicolon:
                p.topNode!(ast.EnumDeclaration)().ident = p.popToken().txt;
                return Accept;
            case TOK_assign:
                p.topNode!(ast.EnumDeclaration)().ident = p.popToken().txt;
                p.pushState(&shiftAssign);
                return Accept;
            case TOK_lcurly:
                p.topNode!(ast.EnumDeclaration)().ident = p.popToken().txt;
                p.pushState(&shiftEnumBody);
                return EnumBody.enter(p);
            default:
                p.pushState(&shiftType);
                return Type.enterIdentifier(p);
        }
    }

    static Action shiftBaseType(Parser p)
    {
        p.popAppendTopNode!(ast.EnumDeclaration)();
        p.pushState(&shiftEnumBody);
        return EnumBody.enter(p);
    }

    static Action shiftEnumBody(Parser p)
    {
        p.popAppendTopNode!(ast.EnumDeclaration)();
        return Forward;
    }

    static Action shiftAssignAfterType(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftAssign);
                return Accept;
            default:
                return p.parseError("'=' expected to initialize enum");
        }
    }

    static Action shiftAssign(Parser p)
    {
        p.pushState(&shiftExpression);
        return AssignExpression.enter(p);
    }

    static Action shiftExpression(Parser p)
    {
        auto expr = p.popNode();
        auto ed   = p.topNode!(ast.EnumDeclaration)();

        // rebuild as anonymous enum with single member
        auto b = new ast.EnumBody(TOK_lcurly, ed.span);
        auto m = new ast.EnumMembers(TOK_Identifier, ed.span);
        auto e = new ast.EnumMember(TOK_Identifier, ed.span);
        e.addMember(expr);
        e.ident = ed.ident;
        m.addMember(e);
        b.addMember(m);

        ed.ident = null;
        ed.isDecl = true;
        ed.addMember(b);

        switch(p.tok.id)
        {
            case TOK_semicolon:
                return Accept;
            case TOK_comma:
                p.pushState(&shiftNextIdentifier);
                return Accept;
            default:
                return p.parseError("';' expected after single line enum");
        }
    }

    static Action shiftNextIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_Identifier:
                auto e = new ast.EnumMember(p.tok);
                e.ident = p.tok.txt;
                p.pushNode(e);
                p.pushState(&shiftAssignAfterNextIdentifier);
                return Accept;
            default:
                return p.parseError("identifier expected after enum type");
        }
    }

    static Action shiftAssignAfterNextIdentifier(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                p.pushState(&shiftNextAssign);
                return Accept;
            default:
                return p.parseError("'=' expected to initialize enum");
        }
    }

    static Action shiftNextAssign(Parser p)
    {
        p.pushState(&shiftNextExpression);
        return AssignExpression.enter(p);
    }

    static Action shiftNextExpression(Parser p)
    {
        p.popAppendTopNode!(ast.EnumMember)();
        auto m = p.popNode!(ast.EnumMember)();
        auto ed = p.topNode!(ast.EnumDeclaration)();
        auto eb = ed.getBody();
        auto em = static_cast!(ast.EnumMembers)(eb.getMember(0));
        em.addMember(m);

        switch(p.tok.id)
        {
            case TOK_semicolon:
                return Accept;
            case TOK_comma:
                p.pushState(&shiftNextIdentifier);
                return Accept;
            default:
                return p.parseError("';' expected after single line enum");
        }
    }
}

//-- GRAMMAR_BEGIN --
// forward declaration not needed with proper handling
//EnumBody:
//    ;
//    { EnumMembers }
class EnumBody
{
    mixin SequenceNode!(ast.EnumBody, TOK_lcurly, EnumMembersRecover, TOK_rcurly);
}
class EnumMembersRecover
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.EnumMembers(p.tok));

        // recover code inserted into EnumMembers.enter
        p.pushRecoverState(&recover);
        p.pushState(&Parser.keepRecover);   // add a "guard" state to avoid popping recover
        p.pushState(&verifyCurly);

        p.pushState(&EnumMembers.shift);
        return EnumMember.enter(p);
    }

    static Action verifyCurly(Parser p)
    {
        if(p.tok.id != TOK_rcurly)
            return p.parseError("'}' expected after enum");
        return Forward;
    }

    static Action recover(Parser p)
    {
        return Parser.recoverSemiCurly(p);
    }
}

//-- GRAMMAR_BEGIN --
//EnumMembers:
//    EnumMember
//    EnumMember ,
//    EnumMember , EnumMembers
class EnumMembers
{
    mixin ListNode!(ast.EnumMembers, EnumMember, TOK_comma, true);
}

//-- GRAMMAR_BEGIN --
//EnumMember:
//    Identifier
//    Identifier = AssignExpression
//    Type Identifier = AssignExpression
class EnumMember
{
    static Action enter(Parser p)
    {
        p.pushNode(new ast.EnumMember(p.tok));

        if(p.tok.id != TOK_Identifier)
        {
            p.pushState(&shiftType);
            return Type.enter(p);
        }
        p.pushState(&shiftIdentifierOrType);
        p.pushToken(p.tok);
        return Accept;
    }

    static Action shiftIdentifierOrType(Parser p)
    {
        if(p.tok.id != TOK_assign && p.tok.id != TOK_comma && p.tok.id != TOK_rcurly)
        {
            p.pushState(&shiftType);
            return Type.enterIdentifier(p);
        }
        Token tok = p.popToken();
        ast.EnumMember em = p.topNode!(ast.EnumMember)();
        em.ident = tok.txt;
        return shiftIdentifier(p);
    }

    static Action shiftAssign(Parser p)
    {
        p.pushState(&shiftExpression);
        return AssignExpression.enter(p);
    }

    static Action shiftExpression(Parser p)
    {
        p.popAppendTopNode!(ast.EnumMember, ast.Expression)();
        return Forward;
    }

    static Action shiftType(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected after type in enum");

        p.popAppendTopNode!(ast.EnumMember, ast.Type)();
        auto em = p.topNode!(ast.EnumMember)();
        em.ident = p.tok.txt;

        p.pushState(&shiftIdentifier);
        return Accept;
    }

    static Action shiftIdentifier(Parser p)
    {
        if(p.tok.id != TOK_assign)
            return Forward;

        p.pushState(&shiftAssign);
        return Accept;
    }
}

////////////////////////////////////////////////////////////////
//-- GRAMMAR_BEGIN --
//FunctionBody:
//    BlockStatement
//    BodyStatement
//    InStatement BodyStatement
//    OutStatement BodyStatement
//    InStatement OutStatement BodyStatement
//    OutStatement InStatement BodyStatement
//
//InStatement:
//    in BlockStatement
//
//OutStatement:
//    out BlockStatement
//    out ( Identifier ) BlockStatement
//
//BodyStatement:
//    body BlockStatement
//
// body statement might be missing in interface contracts
//
class FunctionBody
{
    static bool isInitTerminal(Token tok)
    {
        switch(tok.id)
        {
            case TOK_lcurly:
            case TOK_body:
            case TOK_in:
            case TOK_out:
                return true;
            default:
                return false;
        }
    }

    static Action enter(Parser p)
    {
        ast.FunctionBody fb = new ast.FunctionBody(p.tok);
        p.pushNode(fb);

        if(p.tok.id == TOK_lcurly)
        {
            p.pushState(&shiftBodyStatement);
            return BlockStatement.enter(p);
        }
        return shiftStatement(p);
    }

    static Action shiftBodyStatement(Parser p)
    {
        auto bodyStmt = p.topNode!(ast.BlockStatement)();
        p.popAppendTopNode();
        p.topNode!(ast.FunctionBody)().bodyStatement = bodyStmt;
        return Forward;
    }

    static Action shiftInStatement(Parser p)
    {
        auto inStmt = p.topNode!(ast.BlockStatement)();
        p.popAppendTopNode();
        p.topNode!(ast.FunctionBody)().inStatement = inStmt;
        return shiftStatement(p);
    }

    static Action shiftOutStatement(Parser p)
    {
        auto outStmt = p.topNode!(ast.BlockStatement)();
        p.popAppendTopNode();
        p.topNode!(ast.FunctionBody)().outStatement = outStmt;
        return shiftStatement(p);
    }

    static Action shiftStatement(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_body:
                p.pushState(&shiftBodyStatement);
                p.pushState(&BlockStatement.enter);
                return Accept;
            case TOK_in:
                if(p.topNode!(ast.FunctionBody)().inStatement)
                    return p.parseError("duplicate in block");
                p.pushState(&shiftInStatement);
                p.pushState(&BlockStatement.enter);
                return Accept;
            case TOK_out:
                if(p.topNode!(ast.FunctionBody)().outStatement)
                    return p.parseError("duplicate out block");
                p.pushState(&shiftOut);
                return Accept;
            default:
                return Forward; // p.parseError("expected body or in or out block");
        }
    }

    static Action shiftOut(Parser p)
    {
        if(p.tok.id == TOK_lparen)
        {
            p.pushState(&shiftLparen);
            return Accept;
        }
        p.pushState(&shiftOutStatement);
        return BlockStatement.enter(p);
    }

    static Action shiftLparen(Parser p)
    {
        if(p.tok.id != TOK_Identifier)
            return p.parseError("identifier expected for return value in out contract");

        auto outid = new ast.OutIdentifier(p.tok);
        p.topNode!(ast.FunctionBody)().addMember(outid);
        p.topNode!(ast.FunctionBody)().outIdentifier = outid;
        p.pushState(&shiftOutIdentifier);
        return Accept;
    }

    static Action shiftOutIdentifier(Parser p)
    {
        if(p.tok.id != TOK_rparen)
            return p.parseError("closing parenthesis expected in out contract");
        p.pushState(&shiftOutStatement);
        p.pushState(&BlockStatement.enter);
        return Accept;
    }
}

////////////////////////////////////////////////////////////////
// disambiguate between VersionCondition and VersionSpecification
class VersionCondOrSpec
{
    static Action enter(Parser p)
    {
        assert(p.tok.id == TOK_version);
        p.pushState(&shiftVersion);
        return Accept;
    }

    static Action shiftVersion(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                return VersionSpecification.enterAfterVersion(p);
            case TOK_lparen:
                return ConditionalDeclaration.enterAfterVersion(p);
            default:
                return p.parseError("'=' or '(' expected after version");
        }
    }
}

//-- GRAMMAR_BEGIN --
//ConditionalDeclaration:
//    Condition DeclarationBlock
//    Condition DeclarationBlock else DeclarationBlock
//    Condition: DeclDefs_opt
class ConditionalDeclaration
{
    // Condition DeclarationBlock else $ DeclarationBlock
    mixin stateAppendClass!(DeclarationBlock, Parser.forward) stateElseDecl;

    // Condition DeclarationBlock $ else DeclarationBlock
    mixin stateShiftToken!(TOK_else, stateElseDecl.shift,
                           -1, Parser.forward) stateElse;

    // Condition $ DeclarationBlock else DeclarationBlock
    mixin stateAppendClass!(DeclarationBlock, stateElse.shift) stateThenDecl;

    static Action shiftCondition(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_colon:
                auto declblk = new ast.DeclarationBlock(p.tok);
                p.topNode!(ast.ConditionalDeclaration).id = TOK_colon;
                p.pushNode(declblk);
                p.pushState(&enterDeclarationBlock);
                return Accept;
            default:
                return stateThenDecl.shift(p);
        }
    }
    static Action enterDeclarationBlock(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_rcurly:
            case TOK_EOF:
                return shiftDeclarationBlock(p);
            default:
                p.pushState(&shiftDeclarationBlock);
                return DeclDefs.enter(p);
        }
    }

    static Action shiftDeclarationBlock(Parser p)
    {
        p.popAppendTopNode!(ast.ConditionalDeclaration,ast.DeclarationBlock)();
        return Forward;
    }

    // $ Condition DeclarationBlock else DeclarationBlock
    mixin stateEnterClass!(Condition, ast.ConditionalDeclaration, shiftCondition);

    static Action enterAfterVersion(Parser p)
    {
        p.pushNode(new ast.ConditionalDeclaration(p.tok));
        p.pushState(&enterReduce);
        return VersionCondition.enterAfterVersion(p);
    }
    static Action enterAfterDebug(Parser p)
    {
        p.pushNode(new ast.ConditionalDeclaration(p.tok));
        p.pushState(&enterReduce);
        return DebugCondition.enterAfterDebug(p);
    }
    static Action enterAfterStatic(Parser p)
    {
        p.pushNode(new ast.ConditionalDeclaration(p.tok));
        p.pushState(&enterReduce);
        return StaticIfCondition.enterAfterStatic(p);
    }
}

//-- GRAMMAR_BEGIN --
//ConditionalStatement:
//    Condition NoScopeNonEmptyStatement
//    Condition NoScopeNonEmptyStatement else NoScopeNonEmptyStatement
class ConditionalStatement
{
    // Condition $ NoScopeNonEmptyStatement else NoScopeNonEmptyStatement
    mixin stateAppendClass!(NoScopeNonEmptyStatement, Parser.forward) stateElseStmt;

    mixin stateShiftToken!(TOK_else, stateElseStmt.shift,
                           -1, Parser.forward) stateElse;

    // Condition $ NoScopeNonEmptyStatement else NoScopeNonEmptyStatement
    mixin stateAppendClass!(NoScopeNonEmptyStatement, stateElse.shift) stateThenStmt;

    // $ Condition NoScopeNonEmptyStatement else NoScopeNonEmptyStatement
    mixin stateEnterClass!(Condition, ast.ConditionalStatement, stateThenStmt.shift);

    static Action enterAfterStatic(Parser p)
    {
        p.pushNode(new ast.ConditionalStatement(p.tok));
        p.pushState(&enterReduce);
        return StaticIfCondition.enterAfterStatic(p);
    }
}

//-- GRAMMAR_BEGIN --
//Condition:
//    VersionCondition
//    DebugCondition
//    StaticIfCondition
class Condition
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_version:
                return VersionCondition.enter(p);
            case TOK_debug:
                return DebugCondition.enter(p);
            case TOK_static:
                return StaticIfCondition.enter(p);
            default:
                return p.parseError("version, debug or static if expected");
        }
    }
}

//-- GRAMMAR_BEGIN --
//VersionCondition:
//    version ( Integer )
//    version ( Identifier )
//    version ( unittest )
//    version ( assert )
class VersionCondition
{
    // version ( Integer $ )
    mixin stateShiftToken!(TOK_rparen, Parser.forward) stateRparen;

    // version ( $ Integer )
    mixin stateAppendClass!(IdentifierOrInteger, stateRparen.shift) stateArgument2;

    static Action shiftUnittest(Parser p)
    {
        p.topNode!(ast.VersionCondition).id = TOK_unittest;
        return stateRparen.shift(p);
    }

    static Action shiftAssert(Parser p)
    {
        p.topNode!(ast.VersionCondition).id = TOK_assert;
        return stateRparen.shift(p);
    }

    mixin stateShiftToken!(TOK_unittest, shiftUnittest,
                           TOK_assert, shiftAssert,
                            -1, stateArgument2.shift) stateArgument;

    // version $ ( Integer )
    mixin stateShiftToken!(TOK_lparen, stateArgument.shift) stateLparen;

    // $ version ( Integer )
    mixin stateEnterToken!(TOK_version, ast.VersionCondition, stateLparen.shift);

    static Action enterAfterVersion(Parser p)
    {
        p.pushNode(new ast.VersionCondition(p.tok));
        return stateLparen.shift(p);
    }
}

//-- GRAMMAR_BEGIN --
//VersionSpecification:
//    version = Identifier ;
//    version = Integer ;
class VersionSpecification
{
    mixin stateShiftToken!(TOK_semicolon, Parser.forward) stateSemi;

    mixin stateAppendClass!(IdentifierOrInteger, stateSemi.shift) stateArgument;

    mixin stateShiftToken!(TOK_assign, stateArgument.shift) stateAssign;

    mixin stateEnterToken!(TOK_version, ast.VersionSpecification, stateAssign.shift);

    static Action enterAfterVersion(Parser p)
    {
        p.pushNode(new ast.VersionSpecification(p.tok));
        return stateAssign.shift(p);
    }
}

// disambiguate between DebugCondition and DebugSpecification
class DebugCondOrSpec
{
    static Action enter(Parser p)
    {
        assert(p.tok.id == TOK_debug);
        p.pushState(&shiftDebug);
        return Accept;
    }

    static Action shiftDebug(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_assign:
                return DebugSpecification.enterAfterDebug(p);
            default:
                return ConditionalDeclaration.enterAfterDebug(p);
        }
    }
}

//-- GRAMMAR_BEGIN --
//DebugCondition:
//    debug
//    debug ( Integer )
//    debug ( Identifier )
class DebugCondition
{
    // debug ( Integer $ )
    mixin stateShiftToken!(TOK_rparen, Parser.forward) stateRparen;

    // debug ( $ Integer )
    mixin stateAppendClass!(IdentifierOrInteger, stateRparen.shift) stateArgument;

    // debug $ ( Integer )
    mixin stateShiftToken!(TOK_lparen, stateArgument.shift,
                           -1, Parser.forward) stateLparen;

    // $ debug ( Integer )
    mixin stateEnterToken!(TOK_debug, ast.DebugCondition, stateLparen.shift);

    static Action enterAfterDebug(Parser p)
    {
        p.pushNode(new ast.DebugCondition(p.tok));
        return stateLparen.shift(p);
    }
}

//-- GRAMMAR_BEGIN --
//DebugSpecification:
//    debug = Identifier ;
//    debug = Integer ;
class DebugSpecification
{
    // debug = Integer $ ;
    mixin stateShiftToken!(TOK_semicolon, Parser.forward) stateSemi;

    // debug = $ Integer ;
    mixin stateAppendClass!(IdentifierOrInteger, stateSemi.shift) stateArgument;

    // debug $ = Integer ;
    mixin stateShiftToken!(TOK_assign, stateArgument.shift) stateAssign;

    // $ debug = Integer ;
    mixin stateEnterToken!(TOK_debug, ast.DebugSpecification, stateAssign.shift);

    static Action enterAfterDebug(Parser p)
    {
        p.pushNode(new ast.DebugSpecification(p.tok));
        return stateAssign.shift(p);
    }
}

class IdentifierOrInteger
{
    static Action enter(Parser p)
    {
        switch(p.tok.id)
        {
            case TOK_IntegerLiteral:
                p.pushNode(new ast.IntegerLiteralExpression(p.tok));
                return Accept;
            case TOK_Identifier:
                p.pushNode(new ast.Identifier(p.tok));
                return Accept;
            default:
                return p.parseError("integer or identifier expected");
        }
    }
}

//-- GRAMMAR_BEGIN --
//StaticIfCondition:
//    static if ( AssignExpression )
class StaticIfCondition
{
    mixin SequenceNode!(ast.StaticIfCondition, TOK_static, TOK_if, TOK_lparen, AssignExpression, TOK_rparen);

    static Action enterAfterStatic(Parser p)
    {
        p.pushNode(new ast.StaticIfCondition(p.tok));
        return shift1.shift(p); // jump into sequence before TOK_if
    }
}

//-- GRAMMAR_BEGIN --
//StaticAssert:
//    static assert ( AssignExpression ) ;
//    static assert ( AssignExpression , AssignExpression ) ;
class StaticAssert
{
    mixin SequenceNode!(ast.StaticAssert, TOK_static, TOK_assert, TOK_lparen, ArgumentList, TOK_rparen, TOK_semicolon);

    static Action enterAfterStatic(Parser p)
    {
        p.pushNode(new ast.StaticAssert(p.tok));
        return shift1.shift(p); // jump into sequence before TOK_assert
    }
}
