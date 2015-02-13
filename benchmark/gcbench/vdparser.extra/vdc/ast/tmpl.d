// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.tmpl;

import vdc.util;
import vdc.lexer;
import vdc.ast.node;
import vdc.ast.decl;
import vdc.ast.expr;
import vdc.ast.type;
import vdc.ast.writer;
import vdc.interpret;
import vdc.semantic;

import stdext.util;

//TemplateDeclaration:
//    [Identifier TemplateParameterList Constraint_opt DeclarationBlock]
class TemplateDeclaration : Node
{
    mixin ForwardCtor!();

    Identifier getIdentifier() { return getMember!Identifier(0); }
    TemplateParameterList getTemplateParameterList() { return getMember!TemplateParameterList(1); }
    Constraint getConstraint() { return members.length > 3 ? getMember!Constraint(2) : null; }
    Node getBody() { return getMember(members.length - 1); }
    bool isMixin() { return id == TOK_mixin; }

    override TemplateDeclaration clone()
    {
        TemplateDeclaration n = static_cast!TemplateDeclaration(super.clone());
        return n;
    }

    override void toD(CodeWriter writer)
    {
        if(isMixin())
            writer("mixin ");
        writer("template ", getIdentifier(), getTemplateParameterList());
        writer.nl();
        if(getConstraint())
        {
            writer(getConstraint());
            writer.nl();
        }
//        writer("{");
//        writer.nl();
//        {
//            CodeIndenter indent = CodeIndenter(writer);
            writer(getBody());
//        }
//        writer("}");
//        writer.nl();
        writer.nl();
    }
    override void toC(CodeWriter writer)
    {
        // we never write the template, only instantiations
    }

    override void addSymbols(Scope sc)
    {
        string ident = getIdentifier().ident;
        sc.addSymbol(ident, this);
    }

    override void _semantic(Scope sc)
    {
        // do not recurse into declaration, it only makes sense for an instance
    }

    override bool isTemplate() const { return true; }

    override Node expandTemplate(Scope sc, TemplateArgumentList args)
    {
        TemplateParameterList tpl = getTemplateParameterList();
        string ident = getIdentifier().ident;

        ArgMatch[] vargs = matchTemplateArgs(ident, sc, args, tpl);
        ParameterList pl = createTemplateParameterList(vargs);

        auto bdy = getBody().clone();
        auto inst = new TemplateMixinInstance;
        inst.addMember(pl);
        inst.addMember(bdy);
        return inst;
    }
}

//TemplateMixinInstance:
//    name [ParameterList DeclarationBlock]
class TemplateMixinInstance : Type
{
    mixin ForwardCtor!();

    // semantic data
    string instanceName; // set when named instance created by cloning
    TypeValue typeVal;

    ParameterList getTemplateParameterList() { return getMember!ParameterList(0); }
    Node getBody() { return getMember(1); }

    override bool propertyNeedsParens() const { return false; }

    override void toD(CodeWriter writer)
    {
        writer("mixin ", getBody(), " ", instanceName);
    }

    override void _semantic(Scope sc)
    {
        // TODO: TemplateParameterList, Constraint
        sc = enterScope(sc);
        super._semantic(sc);
        sc = sc.pop();
    }

    override void addSymbols(Scope sc)
    {
        if(instanceName.length)
            sc.addSymbol(instanceName, this);
        else
        {
            sc = enterScope(sc).pop();

            // put symbols into parent scope aswell
            foreach(id, sym; scop.symbols)
                foreach(s, b; sym)
                    sc.addSymbol(id, s);
        }
    }

    override Type calcType()
    {
        return this;
    }

    override Value interpret(Context sc)
    {
        if(!typeVal)
            typeVal = new TypeValue(calcType());
        return typeVal;
    }
}

//TemplateParameterList:
//    [ TemplateParameter... ]
class TemplateParameterList : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("(");
        writer.writeArray(members);
        writer(")");
    }
}

//TemplateParameter:
//    TemplateTypeParameter
//    TemplateValueParameter
//    TemplateAliasParameter
//    TemplateTupleParameter
//    TemplateThisParameter
class TemplateParameter : Node
{
    mixin ForwardCtor!();
}

//TemplateInstance:
//    ident [ TemplateArgumentList ]
class TemplateInstance : Identifier
{
    mixin ForwardCtorTok!();

    TemplateArgumentList getTemplateArgumentList() { return getMember!TemplateArgumentList(0); }

    override void toD(CodeWriter writer)
    {
        writer.writeIdentifier(ident);
        writer("!(", getMember(0), ")");
    }

    override Value interpret(Context sc)
    {
        return super.interpret(sc);
    }
}
//
//
//TemplateArgumentList:
//    [ TemplateArgument... ]
class TemplateArgumentList : Node
{
    mixin ForwardCtorNoId!();

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

//
//TemplateArgument:
//    Type
//    AssignExpression
//    Symbol
//
//// identical to IdentifierList
//Symbol:
//    SymbolTail
//    . SymbolTail
//
//SymbolTail:
//    Identifier
//    Identifier . SymbolTail
//    TemplateInstance
//    TemplateInstance . SymbolTail
//
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

//TemplateTypeParameter:
//    Identifier
//    Identifier TemplateTypeParameterSpecialization
//    Identifier TemplateTypeParameterDefault
//    Identifier TemplateTypeParameterSpecialization TemplateTypeParameterDefault
class TemplateTypeParameter : TemplateParameter
{
    string ident;
    Type specialization;
    Node def;

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override TemplateTypeParameter clone()
    {
        TemplateTypeParameter n = static_cast!TemplateTypeParameter(super.clone());
        n.ident = ident;
        for(int m = 0; m < members.length; m++)
        {
            if(members[m] is specialization)
                n.specialization = static_cast!Type(n.members[m]);
            if(members[m] is def)
                n.def = n.members[m];
        }
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
        if(specialization)
            writer(" : ", specialization);
        if(def)
            writer(" = ", def);
    }
}

//TemplateTypeParameterSpecialization:
//    : Type
//
//TemplateTypeParameterDefault:
//    = Type

//TemplateThisParameter:
//    [ TemplateTypeParameter ]
class TemplateThisParameter : TemplateParameter
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("this ", getMember(0));
    }
}
//
//TemplateValueParameter:
//    Declaration
//    Declaration TemplateValueParameterSpecialization
//    Declaration TemplateValueParameterDefault
//    Declaration TemplateValueParameterSpecialization TemplateValueParameterDefault
class TemplateValueParameter : TemplateParameter
{
    mixin ForwardCtor!();

    Expression specialization;
    Expression def;

    ParameterDeclarator getParameterDeclarator() { return getMember!ParameterDeclarator(0); }

    override TemplateValueParameter clone()
    {
        TemplateValueParameter n = static_cast!TemplateValueParameter(super.clone());
        for(int m = 0; m < members.length; m++)
        {
            if(members[m] is specialization)
                n.specialization = static_cast!Expression(n.members[m]);
            if(members[m] is def)
                n.def = static_cast!Expression(n.members[m]);
        }
        return n;
    }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
        if(specialization)
            writer(" : ", specialization);
        if(def)
            writer(" = ", def);
    }
}
//
//TemplateValueParameterSpecialization:
//    : ConditionalExpression
//
//TemplateValueParameterDefault:
//    = __FILE__
//    = __LINE__
//    = ConditionalExpression
//
//TemplateAliasParameter:
//    alias Identifier TemplateAliasParameterSpecialization_opt TemplateAliasParameterDefault_opt
//
//TemplateAliasParameterSpecialization:
//    : Type
//
//TemplateAliasParameterDefault:
//    = Type
class TemplateAliasParameter : TemplateParameter
{
    mixin ForwardCtor!();

    string getIdent() { return getMember!TemplateTypeParameter(0).ident; }

    override void toD(CodeWriter writer)
    {
        writer("alias ", getMember(0));
    }
}
//
//TemplateTupleParameter:
//    Identifier ...
class TemplateTupleParameter : TemplateParameter
{
    string ident;

    override TemplateTupleParameter clone()
    {
        TemplateTupleParameter n = static_cast!TemplateTupleParameter(super.clone());
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

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }
    override void toD(CodeWriter writer)
    {
        writer.writeIdentifier(ident);
        writer("...");
    }
}
//
//ClassTemplateDeclaration:
//    class Identifier ( TemplateParameterList ) BaseClassList_opt ClassBody
//
//InterfaceTemplateDeclaration:
//    interface Identifier ( TemplateParameterList ) Constraint_opt BaseInterfaceList_opt InterfaceBody
//
//TemplateMixinDeclaration:
//    mixin template TemplateIdentifier ( TemplateParameterList ) Constraint_opt { DeclDefs }

//TemplateMixin:
//    mixin TemplateIdentifier ;
//    mixin TemplateIdentifier MixinIdentifier ;
//    mixin TemplateIdentifier ! ( TemplateArgumentList ) ;
//    mixin TemplateIdentifier ! ( TemplateArgumentList ) MixinIdentifier ;
//
// translated to
//TemplateMixin:
//    [IdentifierList MixinIdentifier_opt]
//    [Typeof MixinIdentifier]
class TemplateMixin : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("mixin ", getMember(0));
        if(members.length > 1)
            writer(" ", getMember(1));
        writer(";");
        writer.nl();
    }

    override Node[] expandNonScopeInterpret(Scope sc, Node[] athis)
    {
        Node tmpl = getMember(0);
        Node n;
        if(auto prop = cast(TypeProperty) tmpl)
            n = prop.resolve();
        else if(auto idlist = cast(IdentifierList) tmpl)
            n = idlist.doResolve(true);

        if(!n)
            semanticError("cannot resolve ", tmpl);
        else if(auto tmi = cast(TemplateMixinInstance) n)
        {
            // TODO: match constraints, replace parameters
            if(members.length > 1)
            {
                // named instance
                string name = getMember!Identifier(1).ident;
                tmi.instanceName = name;
            }
            return [ tmi ];
        }
        else
            semanticError(n, " is not a TemplateMixinInstance");
        return athis;
    }
}

//
//Constraint:
//    if ( ConstraintExpression )
class Constraint : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer(" if(", getMember(0), ")");
    }
}
//
//ConstraintExpression:
//    Expression
//
//MixinIdentifier:
//    Identifier
//

ArgMatch[] matchTemplateArgs(string ident, Scope sc, TemplateArgumentList args, TemplateParameterList tpl)
{
    if(args.members.length != tpl.members.length)
    {
        semanticError("incorrect number of arguments for template expansion of ", ident);
        return null;
    }
    ArgMatch[] vargs;
    Context ctx = new Context(nullContext);
    ctx.scop = sc;
    int m;
    for(m = 0; m < args.members.length; m++)
    {
        Value v;
        string name;
        auto am = args.members[m];
        auto pm = tpl.members[m];
        if(auto typeparam = cast(TemplateTypeParameter) pm)
        {
            v = am.interpret(ctx);
            name = typeparam.ident;
            if(!cast(TypeValue) v)
            {
                semanticError(ident, ": ", m+1, ". argument must evaluate to a type, not ", v.toStr());
                v = null;
            }
        }
        else if(auto thisparam = cast(TemplateThisParameter) pm)
        {
            semanticError("cannot infer this parameter for ", ident);
        }
        else if(auto valueparam = cast(TemplateValueParameter) pm)
        {
            v = am.interpret(ctx);
            auto decl = valueparam.getParameterDeclarator().getDeclarator();
            v = decl.calcType().createValue(ctx, v);
            name = decl.ident;
        }
        else if(auto aliasparam = cast(TemplateAliasParameter) pm)
        {
            if(auto idtype = cast(IdentifierType) am)
                v = new AliasValue(idtype.getIdentifierList());
            else if(auto type = cast(Type) am)
                v = new TypeValue(type);
            else if(auto id = cast(IdentifierExpression) am)
            {
                auto idlist = new IdentifierList;
                idlist.addMember(id.getIdentifier().clone());
                v = new AliasValue(idlist);
            }
            else
                semanticError(ident, ": ", m+1, ". argument must evaluate to an identifier, not ", am);
            name = aliasparam.getIdent();
        }
        else if(auto tupleparam = cast(TemplateTupleParameter) pm)
        {
            semanticError("cannot infer template tuple parameter for ", ident);
        }
        if(!v)
            return null;
        vargs ~= ArgMatch(v, name);
    }
    return vargs;
}


ParameterList createTemplateParameterList(ArgMatch[] vargs)
{
    ParameterList pl = new ParameterList;
    for(int m = 0; m < vargs.length; m++)
    {
        auto pd = new ParameterDeclarator;
        pd.addMember(vargs[m].value.getType().clone());

        auto d = new Declarator;
        d.ident = vargs[m].name;
        if(auto av = cast(AliasValue) vargs[m].value)
        {
            d.isAlias = true;
            d.aliasTo = av.resolve();
        }
        else
        {
            d.value = vargs[m].value;
        }
        pd.addMember(d);
        pl.addMember(pd);
    }
    return pl;
}