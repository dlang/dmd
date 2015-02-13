// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.misc;

import vdc.lexer;
import vdc.semantic;
import vdc.interpret;
import vdc.util;

import vdc.ast.node;
import vdc.ast.expr;
import vdc.ast.decl;
import vdc.ast.stmt;
import vdc.ast.type;
import vdc.ast.writer;

import stdext.util;

import std.algorithm;

//EnumDeclaration:
//    enum EnumTag EnumBody
//    enum EnumBody
//    enum EnumTag : EnumBaseType EnumBody
//    enum : EnumBaseType EnumBody
//    enum Identifier = AssignExpression ;
//
//EnumTag:
//    Identifier
//
//EnumBaseType:
//    Type
class EnumDeclaration : Type
{
    mixin ForwardCtor!();

    string ident;
    bool isDecl; // does not have body syntax

    override bool propertyNeedsParens() const { return false; }

    override EnumDeclaration clone()
    {
        EnumDeclaration n = static_cast!EnumDeclaration(super.clone());
        n.ident = ident;
        n.isDecl = isDecl;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.isDecl == isDecl
            && tn.ident == ident;
    }

    Type getBaseType() { return members.length > 1 ? getMember!Type(0) : null; }
    EnumBody getBody() { return members.length > 0 ? getMember!EnumBody(members.length - 1) : null; }

    override void toD(CodeWriter writer)
    {
        if(!writer.writeDeclarations)
            return;
        if(writer.writeReferencedOnly)
        {
            if(ident.length)
            {
                if(semanticSearches == 0)
                    return;
            }
            else if(auto bdy = getBody())
                if(!bdy.hasSemanticSearches())
                    return;
        }
        if(isDecl)
        {
            writer("enum ");
            if (auto type = getBaseType())
                writer(type, " ");
            writer.writeArray(getBody().getEnumMembers().members);
            writer(";");
            writer.nl;
        }
        else
        {
            writer("enum ");
            writer.writeIdentifier(ident);
            if(writer.writeClassImplementations)
            {
                if(Type type = getBaseType())
                    writer(" : ", type);
                if (members.length > 0)
                {
                    writer.nl();
                    writer(getBody());
                }
                else
                {
                    writer(";");
                    writer.nl;
                }
            }
        }
    }

    override bool createsScope() const { return ident.length > 0; }

    override void addSymbols(Scope sc)
    {
        if(ident.length)
            sc.addSymbol(ident, this);

        else if(auto bdy = getBody())
            bdy.addSymbols(sc);
    }

    override Value createValue(Context ctx, Value initValue)
    {
        if(auto bt = getBaseType())
            return getBaseType().createValue(ctx, initValue);
        if(initValue)
            return initValue.getType().createValue(ctx, initValue);
        return Value.create(0);
    }
}

// forward declaration not needed with proper handling
//EnumBody:
//    ;
//    { EnumMembers }
class EnumBody : Node
{
    mixin ForwardCtor!();

    EnumMembers getEnumMembers() { return getMember!EnumMembers(0); }

    override void toD(CodeWriter writer)
    {
        writer("{");
        writer.nl();
        {
            CodeIndenter indent = CodeIndenter(writer);
            writer(getMember(0));
        }
        writer("}");
        writer.nl();
    }

    bool hasSemanticSearches()
    {
        return getEnumMembers().hasSemanticSearches();
    }

    override void addSymbols(Scope sc)
    {
        getMember(0).addSymbols(sc);
    }
}

//EnumMembers:
//    EnumMember
//    EnumMember ,
//    EnumMember , EnumMembers
class EnumMembers : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        foreach(m; members)
        {
            writer(m, ",");
            writer.nl();
        }
    }

    bool hasSemanticSearches()
    {
        foreach(m; members)
            if(m.semanticSearches > 0)
                return true;
        return false;
    }

    override void addSymbols(Scope sc)
    {
        addMemberSymbols(sc);
    }
}

//EnumMember:
//    Identifier
//    Identifier = AssignExpression
//    Type Identifier = AssignExpression
class EnumMember : Node
{
    mixin ForwardCtor!();

    string ident;
    Type type;
    Value value;

    override EnumMember clone()
    {
        EnumMember n = static_cast!EnumMember(super.clone());
        n.ident = ident;
        return n;
    }
    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.ident == ident;
    }

    string getIdentifier() { return ident; }
    Expression getInitializer() { return members.length > 0 ? getMember!Expression(members.length - 1) : null; }
    Type getType() { return members.length > 1 ? getMember!Type(0) : null; }

    override Type calcType()
    {
        if(type)
            return type;

        if(auto dtype = getType())
            type = dtype.calcType();
        else if(parent && parent.parent && parent.parent)
            if(auto ed = cast(EnumDeclaration)parent.parent.parent)
                type = ed.calcType();

        if(!type)
            type = semanticErrorType("cannot determine type of enum member ", ident);
        return type;
    }

    override void toD(CodeWriter writer)
    {
        if(Type type = getType())
            writer(type, " ");
        writer.writeIdentifier(ident);
        if(auto expr = getInitializer())
            writer(" = ", expr);
    }

    override void addSymbols(Scope sc)
    {
        sc.addSymbol(ident, this);
    }

    override Value interpret(Context sc)
    {
        if(value)
            return value;

        Value ival;
        if(Expression expr = getInitializer())
            ival = expr.interpret(sc);
        else if(auto em = cast(EnumMembers)parent)
        {
            auto n = countUntil(parent.members, this);
            if(n > 0)
            {
                ival = parent.members[n - 1].interpret(sc);
                ival = ival.opBin(sc, TOK_add, Value.create(cast(byte)1));
            }
        }
        value = calcType().createValue(sc, ival);
        return value;
    }
}

////////////////////////////////////////////////////////////////
//FunctionBody:
//    [InStatement_opt OutStatement_opt BodyStatement] outIdentifier
class FunctionBody : Node
{
    mixin ForwardCtor!();

    Statement inStatement;
    Statement outStatement;
    Statement bodyStatement;
    OutIdentifier outIdentifier;

    Scope inScop;
    Scope outScop;

    override FunctionBody clone()
    {
        FunctionBody n = static_cast!FunctionBody(super.clone());
        for(int m = 0; m < members.length; m++)
        {
            if(members[m] is inStatement)
                n.inStatement = static_cast!Statement(n.members[m]);
            if(members[m] is outStatement)
                n.outStatement = static_cast!Statement(n.members[m]);
            if(members[m] is bodyStatement)
                n.bodyStatement = static_cast!Statement(n.members[m]);
            if(members[m] is outIdentifier)
                n.outIdentifier = static_cast!OutIdentifier(n.members[m]);
        }
        return n;
    }

    override void toD(CodeWriter writer)
    {
        if(inStatement)
        {
            writer("in");
            writer.nl();
            writer(inStatement);
        }
        if(outStatement)
        {
            if(outIdentifier)
                writer("out(", outIdentifier, ")");
            else
                writer("out");
            writer.nl();
            writer(outStatement);
        }
        if(bodyStatement)
        {
            if(inStatement || outStatement)
            {
                writer("body");
                writer.nl();
            }
            writer(bodyStatement);
        }
        writer.nl; // should not be written for function literals
    }

    override bool createsScope() const { return true; }

    override Scope enterScope(ref Scope nscope, Scope sc)
    {
        if(!nscope)
        {
            nscope = new Scope;
            nscope.annotations = sc.annotations;
            nscope.attributes = sc.attributes;
            nscope.mod = sc.mod;
            nscope.parent = sc;
            nscope.node = this;

            ParameterList pl;
            if(auto callable = cast(CallableNode) parent)
                pl = callable.getParameterList();
            if(auto decl = cast(Decl) parent)
                if(auto decls = decl.getDeclarators())
                    if(auto callable = cast(CallableNode) decls.getDeclarator(0))
                        pl = callable.getParameterList();
            if(pl)
                pl.addSymbols(nscope);
            return nscope;
        }
        return sc.push(nscope);
    }

    override void _semantic(Scope sc)
    {
        if(inStatement)
        {
            sc = enterScope(inScop, sc);
            inStatement.semantic(sc);
            sc = sc.pop();
        }
        if(bodyStatement)
        {
            sc = super.enterScope(sc);
            bodyStatement.semantic(sc);
            sc = sc.pop();
        }
        if(outStatement)
        {
            // TODO: put into scope of inStatement?
            sc = enterScope(outScop, sc);
            if(outIdentifier)
                sc.addSymbol(outIdentifier.ident, outIdentifier); // TODO: create Symbol for outIdentifier
            outStatement.semantic(sc);
            sc = sc.pop();
        }
    }

    override Value interpret(Context sc)
    {
        Value value;
        if(inStatement)
        {
            inStatement.interpret(sc);
        }
        if(bodyStatement)
        {
            value = bodyStatement.interpret(sc);
        }
        if(outStatement)
        {
            // TODO: put into scope of inStatement?
            outStatement.interpret(sc);
        }
        if(!value)
            return theVoidValue;
        return value;
    }
}

class OutIdentifier : Identifier
{
    mixin ForwardCtorTok!();

    override Type calcType()
    {
        auto fb = cast(FunctionBody)parent;
        if(fb)
        {
            auto type = fb.parent.calcType();
            if(auto tf = cast(TypeFunction) type)
                return tf.getReturnType();
        }
        return semanticErrorType("cannot calculate type of out identifier ", ident);
    }
}

////////////////////////////////////////////////////////////////
class ConditionalDeclaration : Node
{
    mixin ForwardCtor!();

    Condition getCondition() { return getMember!Condition(0); }
    Node getThenDeclarations() { return getMember(1); }
    Node getElseDeclarations() { return getMember(2); }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
        if(id == TOK_colon)
            writer(":");
        writer.nl;
        {
            CodeIndenter indent = CodeIndenter(writer);
            writer(getMember(1));
        }
        if(members.length > 2)
        {
            writer("else");
            writer.nl;
            {
                CodeIndenter indent = CodeIndenter(writer);
                writer(getMember(2));
            }
        }
    }

    override Node[] expandNonScopeBlock(Scope sc, Node[] athis)
    {
        Node n;
        if(getCondition().evalCondition(sc))
            n = getThenDeclarations();
        else
            n = getElseDeclarations();
        if(!n)
            return null;
        athis[0] = removeMember(n);
        return athis;
    }
}

class ConditionalStatement : Statement
{
    mixin ForwardCtor!();

    Condition getCondition() { return getMember!Condition(0); }
    Statement getThenStatement() { return getMember!Statement(1); }
    Statement getElseStatement() { return getMember!Statement(2); }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
        writer.nl;
        {
            CodeIndenter indent = CodeIndenter(writer);
            writer(getMember(1));
        }
        if(members.length > 2)
        {
            writer("else");
            writer.nl;
            {
                CodeIndenter indent = CodeIndenter(writer);
                writer(getMember(2));
            }
        }
    }

    override Node[] expandNonScopeBlock(Scope sc, Node[] athis)
    {
        if(cast(StaticIfCondition) getCondition())
            return athis;

        Node n;
        if(getCondition().evalCondition(sc))
            n = getThenStatement();
        else
            n = getElseStatement();
        if(!n)
            return null;
        athis[0] = removeMember(n);
        return athis;
    }

    override Node[] expandNonScopeInterpret(Scope sc, Node[] athis)
    {
        if(!cast(StaticIfCondition) getCondition())
            return athis;

        Node n;
        if(getCondition().evalCondition(sc))
            n = getThenStatement();
        else
            n = getElseStatement();
        if(!n)
            return null;
        athis[0] = n;
        return athis;
    }
}

mixin template GetIdentifierOrInteger(int pos = 0)
{
    bool isIdentifier() { return getMember(pos).id == TOK_Identifier; }
    string getIdentifier() { return getMember!Identifier(pos).ident; }
    int getInteger() { return getMember!IntegerLiteralExpression(pos).getInt(); }
}

class VersionSpecification : Node
{
    mixin ForwardCtor!();
    mixin GetIdentifierOrInteger!();

    override void toD(CodeWriter writer)
    {
        writer("version = ", getMember(0), ";");
        writer.nl;
    }

    override Node[] expandNonScopeBlock(Scope sc, Node[] athis)
    {
        auto mod = sc.mod;
        if(isIdentifier())
            mod.specifyVersion(getIdentifier(), span.start);
        else
            mod.specifyVersion(getInteger());
        return [];
    }
}

class DebugSpecification : Node
{
    mixin ForwardCtor!();
    mixin GetIdentifierOrInteger!();

    override void toD(CodeWriter writer)
    {
        writer("debug = ", getMember(0), ";");
        writer.nl;
    }

    override Node[] expandNonScopeBlock(Scope sc, Node[] athis)
    {
        auto mod = sc.mod;
        if(isIdentifier())
            mod.specifyDebug(getIdentifier(), span.start);
        else
            mod.specifyDebug(getInteger());
        return [];
    }
}

class Condition : Node
{
    mixin ForwardCtor!();

    abstract bool evalCondition(Scope sc);
}

class VersionCondition : Condition
{
    mixin ForwardCtor!();
    mixin GetIdentifierOrInteger!();

    override bool evalCondition(Scope sc)
    {
        if(members.length == 0)
        {
            assert(id == TOK_unittest || id == TOK_assert);
            if(auto mod = getModule())
                if(auto prj = mod.getProject())
                    return prj.options.unittestOn || (id == TOK_assert && prj.options.debugOn);
            return false;
        }
        auto mod = getModule();
        if(isIdentifier())
            return mod.versionEnabled(getIdentifier(), span.start);
        return mod.versionEnabled(getInteger());
    }

    override void toD(CodeWriter writer)
    {
        if(members.length > 0)
            writer("version(", getMember(0), ") ");
        else
        {
            assert(id == TOK_unittest);
            writer("version(", id, ")");
        }
    }
}

class DebugCondition : Condition
{
    mixin ForwardCtor!();
    mixin GetIdentifierOrInteger!();

    override bool evalCondition(Scope sc)
    {
        auto mod = getModule();
        if(members.length == 0)
            return mod.debugEnabled();
        if(isIdentifier())
            return mod.debugEnabled(getIdentifier(), span.start);
        return mod.debugEnabled(getInteger());
    }

    override void toD(CodeWriter writer)
    {
        if(members.length > 0)
            writer("debug(", getMember(0), ") ");
        else
            writer("debug ");
    }
}

class StaticIfCondition : Condition
{
    mixin ForwardCtor!();

    override bool evalCondition(Scope sc)
    {
        Context ctx = new Context(nullContext);
        ctx.scop = sc;
        return getMember!Expression(0).interpret(ctx).toBool();
    }

    override void toD(CodeWriter writer)
    {
        writer("static if(", getMember(0), ")");
    }
}

//Aggregate:
//    [ArgumentList]
class StaticAssert : Statement
{
    mixin ForwardCtor!();

    ArgumentList getArgumentList() { return getMember!ArgumentList(0); }

    override void toD(CodeWriter writer)
    {
        if(writer.writeImplementations)
        {
            writer("static assert(", getMember(0), ");");
            writer.nl();
        }
    }
    override void toC(CodeWriter writer)
    {
    }

    override void _semantic(Scope sc)
    {
        auto args = getArgumentList();
        auto expr = args.getMember!Expression(0);
        if(!expr.interpretCatch(globalContext).toBool())
        {
            string txt;
            for(int a = 1; a < args.members.length; a++)
            {
                auto arg = args.getMember!Expression(a);
                txt ~= arg.interpret(globalContext).toMixin();
            }
            if(txt.length == 0)
                txt = "static assertion " ~ writeD(expr) ~ " failed";
            semanticErrorPos(span.start, txt);
        }
    }

    override Value interpret(Context sc)
    {
        return null; // "execution" done in _sementic
    }
}
