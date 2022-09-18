// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.decl;

import vdc.util;
import vdc.lexer;
import vdc.semantic;
import vdc.logger;
import vdc.interpret;

import vdc.ast.node;
import vdc.ast.expr;
import vdc.ast.misc;
import vdc.ast.aggr;
import vdc.ast.tmpl;
import vdc.ast.stmt;
import vdc.ast.type;
import vdc.ast.mod;
import vdc.ast.writer;

import std.conv;
import stdext.util;

version(obsolete)
{
//Declaration:
//    alias Decl
//    Decl
class Declaration : Node
{
    mixin ForwardCtor!();
}
}

// AliasDeclaration:
//    [Decl]
class AliasDeclaration : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        if(writer.writeDeclarations)
            writer("alias ", getMember(0));
    }
    override void addSymbols(Scope sc)
    {
        getMember(0).addSymbols(sc);
    }
}

//Decl:
//    attributes annotations [Type Declarators FunctionBody_opt]
class Decl : Node
{
    mixin ForwardCtor!();

    bool hasSemi;
    bool isAlias;

    Type getType() { return getMember!Type(0); }
    Declarators getDeclarators() { return getMember!Declarators(1); }
    FunctionBody getFunctionBody() { return getMember!FunctionBody(2); }

    override Decl clone()
    {
        Decl n = static_cast!Decl(super.clone());
        n.hasSemi = hasSemi;
        n.isAlias = isAlias;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.hasSemi == hasSemi
            && tn.isAlias == isAlias;
    }

    override void toD(CodeWriter writer)
    {
        if(isAlias)
            writer(TOK_alias, " ");
        writer.writeAttributesAndAnnotations(attr, annotation);

        writer(getType(), " ", getDeclarators());
        bool semi = true;
        if(auto fn = getFunctionBody())
        {
            if(writer.writeImplementations)
            {
                writer.nl;
                writer(fn);
                semi = hasSemi;
            }
        }
        if(semi)
        {
            writer(";");
            writer.nl();
        }
    }

    override void toC(CodeWriter writer)
    {
        bool addExtern = false;
        if(!isAlias && writer.writeDeclarations && !(attr & Attr_ExternC))
        {
            Node p = parent;
            while(p && !cast(Aggregate) p && !cast(TemplateDeclaration) p && !cast(Statement) p)
                p = p.parent;

            if(!p)
                addExtern = true;
        }
        if(auto fn = getFunctionBody())
        {
            if(writer.writeReferencedOnly && getDeclarators().getDeclarator(0).semanticSearches == 0)
                return;

            writer.nl;
            if(isAlias)
                writer(TOK_alias, " ");
            writer.writeAttributesAndAnnotations(attr | (addExtern ? Attr_Extern : 0), annotation);

            bool semi = true;
            writer(getType(), " ", getDeclarators());
            if(writer.writeImplementations)
            {
                writer.nl;
                writer(fn);
                semi = hasSemi;
            }
            if(semi)
            {
                writer(";");
                writer.nl();
            }
        }
        else
        {
            foreach(i, d; getDeclarators().members)
            {
                if(writer.writeReferencedOnly && getDeclarators().getDeclarator(i).semanticSearches == 0)
                    continue;

                if(isAlias)
                    writer(TOK_alias, " ");
                writer.writeAttributesAndAnnotations(attr | (addExtern ? Attr_Extern : 0), annotation);

                writer(getType(), " ", d, ";");
                writer.nl();
            }
        }
    }

    override Type calcType()
    {
        return getType().calcType();
    }

    override void addSymbols(Scope sc)
    {
        getDeclarators().addSymbols(sc);
    }

    override void _semantic(Scope sc)
    {
        bool isTemplate = false;
        if(auto fn = getFunctionBody())
        {
            // if it is a function declaration, create a new scope including function parameters
            scop = sc.push(scop);
            scop.node = this;
            if(auto decls = getDeclarators())
                if(auto decl = decls.getDeclarator(0))
                {
                    foreach(m; decl.members) // template parameters and function parameters and constraint
                    {
                        if(cast(TemplateParameterList) m)
                        {
                            // it does not make sense to add symbols for unexpanded templates
                            isTemplate = decl._isTemplate = true;
                            break;
                        }
                        m.addSymbols(scop);
                    }
                }

            if(!isTemplate)
                super._semantic(scop);
            //fn.semantic(scop);
            sc = scop.pop();
        }
        else
            super._semantic(sc);
    }
}

//Declarators:
//    [DeclaratorInitializer|Declarator...]
class Declarators : Node
{
    mixin ForwardCtor!();

    Declarator getDeclarator(size_t n)
    {
        if(auto decl = cast(Declarator) getMember(n))
            return decl;

        return getMember!DeclaratorInitializer(n).getDeclarator();
    }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
        foreach(decl; members[1..$])
            writer(", ", decl);
    }
    override void addSymbols(Scope sc)
    {
        foreach(decl; members)
            decl.addSymbols(sc);
    }
}

//DeclaratorInitializer:
//    [Declarator Initializer_opt]
class DeclaratorInitializer : Node
{
    mixin ForwardCtor!();

    Declarator getDeclarator() { return getMember!Declarator(0); }
    Expression getInitializer() { return getMember!Expression(1); }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
        if(Expression expr = getInitializer())
        {
            if(expr.getPrecedence() <= PREC.assign)
                writer(" = (", expr, ")");
            else
                writer(" = ", getMember(1));
        }
    }

    override Type calcType()
    {
        return getInitializer().calcType();
    }

    override void addSymbols(Scope sc)
    {
        getDeclarator().addSymbols(sc);
    }
}

// unused
class DeclaratorIdentifierList : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        assert(false);
    }
}

// unused
class DeclaratorIdentifier : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        assert(false);
    }
}

class Initializer : Expression
{
    mixin ForwardCtor!();
}

//Declarator:
//    Identifier [DeclaratorSuffixes...]
class Declarator : Identifier, CallableNode
{
    mixin ForwardCtorTok!();

    Type type;
    Value value;
    Node aliasTo;
    ParameterList parameterList;
    bool isAlias;
    bool isRef;
    bool needsContext;
    bool _isTemplate;
    bool _inReinit;
    TemplateInstantiation[] tmpl;

    override Declarator clone()
    {
        Declarator n = static_cast!Declarator(super.clone());
        n.type = type;
        return n;
    }

    final Declarator cloneDeclaratorShallow()
    {
        auto decl = static_cast!Declarator(_cloneShallow());
        decl.ident = ident;
        if(parameterList)
            decl.addMember(parameterList.clone());
        // copy info from applySuffixes
        return decl;
    }

    Expression getInitializer()
    {
        if(auto di = cast(DeclaratorInitializer) parent)
            return di.getInitializer();
        return null;
    }

    override void toD(CodeWriter writer)
    {
        super.toD(writer);
        foreach(m; members) // template parameters and function parameters and constraint
            writer(m);
    }

    bool _isAlias()
    {
        for(Node p = parent; p; p = p.parent)
            if(auto decl = cast(Decl) p)
                return decl.isAlias;
            else if(auto pdecl = cast(ParameterDeclarator) p)
                break;
        return false;
    }
    // returns 0 for never, 1 for non-static statement declaration, 2 for yes
    bool _needsContext()
    {
        for(Node p = parent; p; p = p.parent)
            if(auto decl = cast(Decl) p)
            {
                if(!decl.parent || cast(Module)decl.parent)
                    return false;
                if (decl.attr & (Attr_Static | Attr_Shared | Attr_Gshared))
                    return false;
                return true;
            }
            else if(auto pdecl = cast(ParameterDeclarator) p)
                return true;

        return false;
    }

    override bool isTemplate()
    {
        return _isTemplate;
    }

    override Node expandTemplate(Scope sc, TemplateArgumentList args)
    {
        assert(_isTemplate);

        calcType(); // ensure suffixes applied
        TemplateParameterList tpl = getTemplateParameterList();

        ArgMatch[] vargs = matchTemplateArgs(ident, sc, args, tpl);
        if(vargs is null)
            return this;

        if(auto impl = getTemplateInstantiation(vargs))
            return impl.getDeclarator();

        // new instantiation has template parameters as parameterlist and contains
        //  a copy of the function declaration without template arguments
        auto tmpl = new TemplateInstantiation(this, vargs);
        addMember(tmpl); // add as suffix
        tmpl.semantic(getScope());
        return tmpl.getDeclarator();
    }

    TemplateInstantiation getTemplateInstantiation(ArgMatch[] args)
    {
        return null;
    }

    TemplateParameterList getTemplateParameterList()
    {
        for(int m = 0; m < members.length; m++)
        {
            auto member = members[0];
            if(auto tpl = cast(TemplateParameterList) member)
                return tpl;
        }
        return null;
    }

    override void addSymbols(Scope sc)
    {
        sc.addSymbol(ident, this);
    }

    Type applySuffixes(Type t)
    {
        // assumed to be only called once by calcType
        isAlias = _isAlias();
        needsContext = _needsContext();

        // template parameters and function parameters and constraint
        size_t mlen = members.length;
        for(int m = 0; m < members.length; m++)
        {
            auto member = members[m];
            if(auto pl = cast(ParameterList) member)
            {
                auto tf = needsContext ? new TypeDelegate(pl.id, pl.span) : new TypeFunction(pl.id, pl.span);
                tf.funcDecl = this;
                tf.returnType = t; // need clones?
                tf.paramList = pl;
                tf.scop = getScope(); // not fully added to node tree
                t = tf;
                parameterList = pl;
            }
            else if(auto sa = cast(SuffixArray) member)
            {
                auto idx = sa.getMember(0);
                if(auto tidx = cast(Type) idx) // TODO: need to resolve identifiers?
                {
                    auto taa = new TypeAssocArray(sa.id, sa.span);
                    taa.setNextType(t);  // need clones?
                    taa.keyType = tidx;
                    t = taa;
                }
                else
                {
                    auto tsa = new TypeStaticArray(sa.id, sa.span);
                    tsa.setNextType(t);  // need clones?
                    tsa.dimExpr = static_cast!Expression(idx);
                    t = tsa;
                }
                t.scop = getScope(); // not fully added to node tree
            }
            else if(auto sda = cast(SuffixDynamicArray) member)
            {
                auto tda = new TypeDynamicArray(sda.id, sda.span);
                tda.addMember(t.clone());
                t = tda;
                tda.scop = getScope(); // not fully added to node tree
            }
            // TODO: slice suffix? template parameters, constraint
        }

        //// after removal, limit span to remaining members
        //if(mlen > members.length)
        //{
        //    fulspan = span;
        //    foreach(m; members)
        //        extendSpan(m.fulspan);
        //}
        return t;
    }

    override Node resolve()
    {
        return this;
    }

    override Type calcType()
    {
        if(type)
            return type;
        if(aliasTo)
            return aliasTo.calcType();

        for(Node p = parent; p; p = p.parent)
        {
            if(auto decl = cast(Decl) p)
            {
                type = decl.getType();
                if(cast(AutoType)type)
                {
                    if(auto expr = getInitializer())
                        type = expr.calcType();
                }
                if(type)
                {
                    type = applySuffixes(type);
                    type = type.calcType();
                }
                return type;
            }
            else if(auto pdecl = cast(ParameterDeclarator) p)
            {
                type = pdecl.getType();
                if(type)
                {
                    type = applySuffixes(type);
                    type = type.calcType();
                }
                return type;
            }
        }
        type = semanticErrorType("cannot find Declarator type");
        return type;
    }

    override Value interpret(Context sc)
    {
        if(value)
            return value;
        if(aliasTo)
            return aliasTo.interpret(sc); // TODO: alias not restricted to types
        Type type = calcType();
        if(isAlias)
            return type.interpret(sc); // TODO: alias not restricted to types
        else if(needsContext)
        {
            if(!sc)
                return semanticErrorValue("evaluating ", ident, " needs context pointer");
            if(auto v = sc.getValue(this))
                return v;
        }
        return interpretReinit(sc);
    }

    Value interpretReinit(Context sc)
    {
        if(_inReinit)
            return semanticErrorValue("initializing ", ident, " refers to itself");
        _inReinit = true;
        scope(exit) _inReinit = false;

        if(aliasTo)
            return aliasTo.interpret(sc); // TODO: alias not restricted to types
        Type type = calcType();
        if(isAlias)
            return type.interpret(sc); // TODO: alias not restricted to types
        else if(needsContext)
        {
            if(!sc)
                return semanticErrorValue("evaluating ", ident, " needs context pointer");
            Value v;
            if(auto expr = getInitializer())
            {
                v = expr.interpret(sc);
                if(!v.getType().compare(type))
                    type.createValue(sc, v);
            }
            else
                v = type.createValue(sc, null);
            debug v.ident = ident;
            sc.setValue(this, v);
            return v;
        }
        else if(auto expr = getInitializer())
            value = type.createValue(sc, expr.interpret(sc));
        else
            value = type.createValue(sc, null);
        debug value.ident = ident;
        return value;
    }

    override ParameterList getParameterList()
    {
        calcType();
        return parameterList;
    }

    override FunctionBody getFunctionBody()
    {
        for(Node p = parent; p; p = p.parent)
            if(auto decl = cast(Decl) p)
                if(auto fbody = decl.getFunctionBody())
                    return fbody;
        return null;
    }

    override Value interpretCall(Context sc)
    {
        logInfo("calling %s", ident);

        if(auto fbody = getFunctionBody())
            return fbody.interpret(sc);

        return semanticErrorValue(ident, " is not an interpretable function");
    }
}

//TemplateInstantiation:
//    [ParameterList Decl]
class TemplateInstantiation : Node
{
    ArgMatch[] args;
    Declarator dec;

    override ParameterList getParameterList() { return getMember!ParameterList(0); }
    Declarator getDeclarator() { return dec; }

    this(Declarator ddec, ArgMatch[] vargs)
    {
        Decl decl = new Decl;
        dec = ddec.cloneDeclaratorShallow();
        args = vargs;

        for(Node p = ddec.parent; p; p = p.parent)
            if(auto ddecl = cast(Decl) p)
            {
                if(auto type = ddecl.getType())
                    decl.addMember(type.clone());
                Declarators decs = new Declarators;
                decs.addMember(dec);
                decl.addMember(decs);
                if(auto fbody = ddecl.getFunctionBody())
                    decl.addMember(fbody.clone());
                break;
            }
        assert(decl.members.length > 0);

        if(auto tpl = ddec.getTemplateParameterList())
            addMember(createTemplateParameterList(vargs));
        else
            addMember(new ParameterList);
        addMember(decl);
        logInfo("created template instance of ", dec.ident, " with args ", vargs);
    }

    override void toD(CodeWriter writer)
    {
        // suppress output (add a flag to the writer to enable output of expanded template?)
    }

    override void addSymbols(Scope sc)
    {
        getParameterList().addSymbols(sc);
    }

    override bool createsScope() const { return true; }

    override void _semantic(Scope sc)
    {
        sc = enterScope(sc);
        super._semantic(sc);
        sc = scop.pop();
    }
}

//IdentifierList:
//    [IdentifierOrTemplateInstance...]
class IdentifierList : Node
{
    mixin ForwardCtor!();

    bool global;

    // semantic data
    Node resolved;

    override IdentifierList clone()
    {
        IdentifierList n = static_cast!IdentifierList(super.clone());
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

    Node doResolve(bool isMixin)
    {
        // TODO: does not work for package qualified symbols
        Scope sc;
        if(global)
            sc = getModule().scop;
        else if(auto bc = cast(BaseClass) parent)
            if(auto clss = bc.parent)
                if(auto p = clss.parent)
                    sc = p.getScope();
        if(!sc)
            sc = getScope();

        Node res;
        for(int m = 0; sc && m < members.length; m++)
        {
            auto id = getMember!Identifier(m);
            res = sc.resolveWithTemplate(id.ident, sc, id);
            sc = (res ? res.getScope() : null);
        }
        if(!sc && !isMixin)
            res = semanticErrorType("cannot resolve ", writeD(this));
        return res;
    }

    override Node resolve()
    {
        if(resolved)
            return resolved;

        resolved = doResolve(false);
        return resolved;
    }

    override Type calcType()
    {
        if(Node n = resolve())
            return n.calcType();
        return semanticErrorType("cannot resolve type of ", writeD(this));
    }

    override Value interpret(Context sc)
    {
        if(Node n = resolve())
            return n.interpret(sc);
        return semanticErrorValue("cannot resolve ", writeD(this));
    }

    override void _semantic(Scope sc)
    {
        resolve();
    }

    override void toD(CodeWriter writer)
    {
        if(global)
            writer(".");
        writer.writeArray(members, ".");
    }
}

class Identifier : Node
{
    string ident;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override Identifier clone()
    {
        Identifier n = static_cast!Identifier(super.clone());
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

    override void toD(CodeWriter writer)
    {
        writer.writeIdentifier(ident);
    }

    override ArgumentList getFunctionArguments()
    {
        if(parent)
            return parent.getFunctionArguments();
        return null;
    }

    override Node resolve()
    {
        if(parent)
            return parent.resolve();
        return super.resolve();
    }

    override Type calcType()
    {
        if(auto p = cast(IdentifierList) parent)
            return p.calcType();
        if(auto p = cast(IdentifierExpression) parent)
            return p.calcType();
        if(auto p = cast(DotExpression) parent)
            return p.calcType();
        if(auto p = cast(ModuleFullyQualifiedName) parent)
        {
        }
        if(auto p = cast(ForeachType) parent)
            return parent.calcType();
        return super.calcType();
    }

    override Value interpret(Context ctx)
    {
        if(auto p = cast(IdentifierList) parent)
            return p.interpret(ctx);
        if(auto p = cast(IdentifierExpression) parent)
            return p.interpret(ctx);
        if(auto p = cast(DotExpression) parent)
            return p.interpret(ctx);
        if(auto p = cast(ModuleFullyQualifiedName) parent)
        {
        }
        if(auto p = cast(ForeachType) parent)
            return parent.interpret(ctx);
        return super.interpret(ctx);
    }
}

//ParameterList:
//    [Parameter...] attributes
class ParameterList : Node
{
    mixin ForwardCtor!();

    Parameter getParameter(size_t i) { return getMember!Parameter(i); }

    bool varargs;
    bool anonymous_varargs;

    override ParameterList clone()
    {
        ParameterList n = static_cast!ParameterList(super.clone());
        n.varargs = varargs;
        n.anonymous_varargs = anonymous_varargs;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.varargs == varargs && tn.anonymous_varargs == anonymous_varargs;
    }

    override void toD(CodeWriter writer)
    {
        writer("(");
        writer.writeArray(members);
        if(anonymous_varargs)
            writer(", ...");
        else if(varargs)
            writer("...");
        writer(")");
        if(attr)
        {
            writer.writeAttributesAndAnnotations(attr, annotation, true);
        }
    }

    override void addSymbols(Scope sc)
    {
        foreach(m; members)
            m.addSymbols(sc);
    }
}

//Parameter:
//    io [ParameterDeclarator Expression_opt]
class Parameter : Node
{
    mixin ForwardCtor!();

    TokenId io;

    ParameterDeclarator getParameterDeclarator() { return getMember!ParameterDeclarator(0); }
    Expression getInitializer() { return getMember!Expression(1); }

    override Parameter clone()
    {
        Parameter n = static_cast!Parameter(super.clone());
        n.io = io;
        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.io == io;
    }

    override void toD(CodeWriter writer)
    {
        if(io)
            writer(io, " ");
        writer(getMember(0));
        if(members.length > 1)
            writer(" = ", getMember(1));
    }

    override void addSymbols(Scope sc)
    {
        getParameterDeclarator().addSymbols(sc);
    }

    override Type calcType()
    {
        return getParameterDeclarator().calcType();
    }
}

//ParameterDeclarator:
//    attributes [Type Declarator]
class ParameterDeclarator : Node
{
    mixin ForwardCtor!();

    Type getType() { return getMember!Type(0); }
    Declarator getDeclarator() { return members.length > 1 ? getMember!Declarator(1) : null; }

    override void toD(CodeWriter writer)
    {
        writer.writeAttributesAndAnnotations(attr, annotation);
        writer(getType());
        if(auto decl = getDeclarator())
            writer(" ", decl);
    }

    override void addSymbols(Scope sc)
    {
        if (auto decl = getDeclarator())
            decl.addSymbols(sc);
    }

    override Type calcType()
    {
        if (auto decl = getDeclarator())
            return decl.calcType();
        return getType().calcType();
    }
}
