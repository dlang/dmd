// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.aggr;

import vdc.util;
import vdc.lexer;
import vdc.logger;
import vdc.semantic;
import vdc.interpret;

import vdc.ast.node;
import vdc.ast.mod;
import vdc.ast.tmpl;
import vdc.ast.decl;
import vdc.ast.expr;
import vdc.ast.misc;
import vdc.ast.type;
import vdc.ast.writer;

import stdext.array;
import stdext.util;

import std.algorithm;
import std.conv;

//Aggregate:
//    [TemplateParameterList_opt Constraint_opt BaseClass... StructBody]
class Aggregate : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return true; }
    abstract bool isReferenceType() const;

    bool hasBody = true;
    bool hasTemplArgs;
    bool hasConstraint;
    string ident;

    TemplateParameterList getTemplateParameterList() { return hasTemplArgs ? getMember!TemplateParameterList(0) : null; }
    Constraint getConstraint() { return hasConstraint ? getMember!Constraint(1) : null; }
    StructBody getBody() { return hasBody ? getMember!StructBody(members.length - 1) : null; }

    override Aggregate clone()
    {
        Aggregate n = static_cast!Aggregate(super.clone());

        n.hasBody = hasBody;
        n.hasTemplArgs = hasTemplArgs;
        n.hasConstraint = hasConstraint;
        n.ident = ident;

        return n;
    }

    override bool compare(const(Node) n) const
    {
        if(!super.compare(n))
            return false;

        auto tn = static_cast!(typeof(this))(n);
        return tn.hasBody == hasBody
            && tn.hasTemplArgs == hasTemplArgs
            && tn.hasConstraint == hasConstraint
            && tn.ident == ident;
    }

    void bodyToD(CodeWriter writer)
    {
        if(auto bdy = getBody())
        {
            writer.nl;
            writer(getBody());
            writer.nl;
        }
        else
        {
            writer(";");
            writer.nl;
        }
    }
    void tmplToD(CodeWriter writer)
    {
        if(TemplateParameterList tpl = getTemplateParameterList())
            writer(tpl);
        if(auto constraint = getConstraint())
            writer(constraint);
    }

    override bool createsScope() const { return true; }

    override Scope enterScope(ref Scope nscope, Scope sc)
    {
        if(!nscope)
        {
            nscope = new AggregateScope;
            nscope.annotations = sc.annotations;
            nscope.attributes = sc.attributes;
            nscope.mod = sc.mod;
            nscope.parent = sc;
            nscope.node = this;
            addMemberSymbols(nscope);
            return nscope;
        }
        return sc.push(nscope);
    }

    override void _semantic(Scope sc)
    {
        // TODO: TemplateParameterList, Constraint
        if(auto bdy = getBody())
        {
            sc = super.enterScope(sc);
            bdy.semantic(sc);
            sc = sc.pop();
        }
        if(!initVal)
        {
            if(mapName2Value.length == 0)
                _initFields(0);
            if(mapName2Method.length == 0 && constructors.length == 0)
                _initMethods();
        }
    }

    override void addSymbols(Scope sc)
    {
        if(ident.length)
            sc.addSymbol(ident, this);
    }

    // always tree internal references
    size_t mapDeclOffset;
    size_t[Declarator] mapDecl2Value;
    size_t[string] mapName2Value;
    Declarator[string] mapName2Method;
    bool[Declarator] isMethod;

    Constructor[] constructors;
    TupleValue initVal;
    TypeValue typeVal;

    abstract TupleValue _initValue();

    void _setupInitValue(AggrValue sv)
    {
        auto bdy = getBody();
        if(!bdy)
            return;
        auto ctx = new AggrContext(nullContext, sv);
        ctx.scop = scop;
        bdy.iterateDeclarators(false, false, (Declarator decl) {
            Type type = decl.calcType();
            Value value;
            if(auto expr = decl.getInitializer())
                value = type.createValue(ctx, expr.interpret(ctx));
            else
                value = type.createValue(ctx, null);
            debug value.ident = decl.ident;
            sv.addValue(value);
        });
    }

    void _initValues(AggrContext thisctx, Value[] initValues)
    {
        if(!initVal)
        {
            initVal = _initValue();
            _initMethods();
        }
        auto inst = static_cast!AggrValue(thisctx.instance);

        mapDeclOffset = inst.values.length;
        inst.setValuesLength(mapDeclOffset + mapDecl2Value.length);
        foreach(decl, idx; mapDecl2Value)
        {
            Value v = mapDeclOffset + idx < initValues.length ? initValues[mapDeclOffset + idx] : initVal.values[idx];
            Type t = decl.calcType();
            v = t.createValue(thisctx, v);
            debug v.ident = decl.ident;
            inst.values[mapDeclOffset + idx] = v;
        }
    }

    ValueType _createValue(ValueType, Args...)(Context ctx, Value initValue, Args a)
    {
        //! TODO: check type of initValue
        ValueType sv = new ValueType(a);
        auto bdy = getBody();
        if(!bdy)
        {
            semanticErrorValue("cannot create value of incomplete type ", ident);
            return sv;
        }
        Value[] initValues;
        if(initValue)
        {
            auto tv = cast(TupleValue) initValue;
            if(!tv)
            {
                semanticErrorValue("cannot initialize a ", sv, " from ", initValue);
                return sv;
            }
            initValues = tv.values;
        }
        auto aggr = cast(AggrValue) initValue;
        if(aggr)
            sv.outer = aggr.outer;
        else if(!(attr & Attr_Static) && ctx)
            sv.outer = ctx;

        if(initValue)
            logInfo("creating new instance of %s with args ", ident, initValue.toStr());
        else
            logInfo("creating new instance of %s", ident);

        auto thisctx = new AggrContext(ctx, sv);
        thisctx.scop = scop;
        _initValues(thisctx, initValues); // appends to sv.values

        if(constructors.length > 0)
        {
            doCall(constructors[0], thisctx, constructors[0].getParameterList(), initValue);
        }
        return sv;
    }

    int _initFields(int off)
    {
        if(auto bdy = getBody())
            bdy.iterateDeclarators(false, false, (Declarator decl) {
                mapDecl2Value[decl] = off;
                mapName2Value[decl.ident] = off++;
            });
        return off;
    }

    void _initMethods()
    {
        if(auto bdy = getBody())
        {
            bdy.iterateDeclarators(false, true, (Declarator decl) {
                isMethod[decl] = true;
                mapName2Method[decl.ident] = decl;
            });

            bdy.iterateConstructors(false, (Constructor ctor) {
                if(!ctor.isPostBlit())
                    constructors ~= ctor;
            });
        }
    }

    override Value getProperty(Value sv, string prop, bool virtualCall)
    {
        if(auto pidx = prop in mapName2Value)
        {
            if(AggrValue av = cast(AggrValue)sv)
                return av.values[*pidx];
        }
        else if(auto pdecl = prop in mapName2Method)
        {
            return getProperty(sv, *pdecl, virtualCall);
        }
        return null;
    }

    override Value getProperty(Value sv, Declarator decl, bool virtualCall)
    {
        if(auto tv = cast(TypeValue) sv)
        {
            if(decl.needsContext)
                return new TypeValue(decl.calcType());
            return decl.interpret(nullContext);
        }
        if(auto rv = cast(ReferenceValue) sv)
            sv = rv.instance;
        AggrValue av = static_cast!AggrValue(sv);
        if(Value v = _getProperty(av, decl, virtualCall))
            return v;
        if(av && av.outer)
            return av.outer.getValue(decl);
        return null;
    }

    Value _getProperty(AggrValue av, Declarator decl, bool virtualCall)
    {
        if(auto pidx = decl in mapDecl2Value)
        {
            if(!av)
                return semanticErrorValue("member access needs non-null instance pointer");
            return av.values[*pidx + mapDeclOffset];
        }
        if(decl in isMethod)
        {
            if(!av)
                return semanticErrorValue("method access needs non-null instance pointer");
            if(virtualCall)
                decl = findOverride(av, decl);
            auto func = decl.calcType();
            auto cv = new AggrContext(nullContext, av);
            cv.scop = scop;
            Value dgv = func.createValue(cv, null);
            return dgv;
        }
        return null;
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        if(Value v = getStaticProperty(prop))
            return v;
        Value vt = ctx.getThis();
        auto av = cast(AggrValue) vt;
        if(!av)
            if(auto rv = cast(ReferenceValue) vt)
                av = rv.instance;
        if(av)
            if(Value v = getProperty(av, prop, true))
                return v;
        return super._interpretProperty(ctx, prop);
    }

    Value getStaticProperty(string prop)
    {
        if(!scop && parent)
            semantic(parent.getScope());
        if(!scop)
            return semanticErrorValue(this, ": no scope set in lookup of ", prop);

        Scope.SearchSet res = scop.search(prop, false, true, true);
        if(res.length == 0)
            return null;
        if(res.length > 1)
            semanticError("ambiguous identifier " ~ prop);

        foreach(n, b; res)
        {
            if(n.attr & Attr_Static)
                return n.interpret(nullContext);
        }
        return null; // delay into getProperty
    }

    override Type opCall(Type args)
    {
        // must be a constructor
        return this;
    }

    override Value interpret(Context sc)
    {
        if(!typeVal)
            typeVal = new TypeValue(this);
        return typeVal;
    }

    final Declarator findOverride(AggrValue av, Declarator decl)
    {
        Aggregate clss = av.getType();
        return clss._findOverride(av, decl);
    }

    Declarator _findOverride(AggrValue av, Declarator decl)
    {
        return decl;
    }
}

class AggregateScope : Scope
{
    override Type getThisType()
    {
        return static_cast!Aggregate(node);
    }
}

class Struct : Aggregate
{
    this() {} // default constructor needed for clone()

    override bool isReferenceType() const { return false; }

    this(ref const(TextSpan) _span)
    {
        super(_span);
    }

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override void toD(CodeWriter writer)
    {
        if(writer.writeReferencedOnly && semanticSearches == 0)
            return;

        writer("struct ");
        writer.writeIdentifier(ident);
        tmplToD(writer);
        if(writer.writeClassImplementations)
            bodyToD(writer);
    }

    override TupleValue _initValue()
    {
        StructValue sv = new StructValue(this);
        _setupInitValue(sv);
        return sv;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        return _createValue!StructValue(ctx, initValue, this);
    }
}

class Union : Aggregate
{
    this() {} // default constructor needed for clone()

    override bool isReferenceType() const { return false; }

    this(ref const(TextSpan) _span)
    {
        super(_span);
    }

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override void toD(CodeWriter writer)
    {
        if(writer.writeReferencedOnly && semanticSearches == 0)
            return;

        writer("union ");
        writer.writeIdentifier(ident);
        tmplToD(writer);
        if(writer.writeClassImplementations)
            bodyToD(writer);
    }

    override TupleValue _initValue()
    {
        UnionValue sv = new UnionValue(this);
        _setupInitValue(sv);
        return sv;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        return _createValue!UnionValue(ctx, initValue, this);
    }
}

class InheritingAggregate : Aggregate
{
    mixin ForwardCtor!();

    override bool isReferenceType() const { return true; }

    BaseClass[] baseClasses;

    void addBaseClass(BaseClass bc)
    {
        addMember(bc);
        baseClasses ~= bc;
    }

    override Scope enterScope(ref Scope nscope, Scope sc)
    {
        if(!nscope)
        {
            nscope = new InheritingScope;
            nscope.annotations = sc.annotations;
            nscope.attributes = sc.attributes;
            nscope.mod = sc.mod;
            nscope.parent = sc;
            nscope.node = this;
            addMemberSymbols(nscope);
            return nscope;
        }
        return sc.push(nscope);
    }

    override InheritingAggregate clone()
    {
        InheritingAggregate n = static_cast!InheritingAggregate(super.clone());

        for(int m = 0; m < members.length; m++)
            if(arrIndex(cast(Node[]) baseClasses, members[m]) >= 0)
                n.baseClasses ~= static_cast!BaseClass(n.members[m]);

        return n;
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
            return true;

        if(flags & ConversionFlags.kAllowBaseClass)
            if(auto inh = cast(InheritingAggregate) from)
            {
                foreach(bc; inh.baseClasses)
                    if(auto inhbc = bc.getClass())
                        if(convertableFrom(inhbc, flags))
                            return true;
            }
        return false;
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        foreach(bc; baseClasses)
            if(Value v = bc._interpretProperty(ctx, prop))
                return v;
        return super._interpretProperty(ctx, prop);
    }

    override void toD(CodeWriter writer)
    {
        // class/interface written by derived class
        writer.writeIdentifier(ident);
        tmplToD(writer);
        if(writer.writeClassImplementations)
        {
            if(baseClasses.length)
            {
                if(ident.length > 0)
                    writer(" : ");
                writer(baseClasses[0]);
                foreach(bc; baseClasses[1..$])
                    writer(", ", bc);
            }
            bodyToD(writer);
        }
    }

    override void _initValues(AggrContext thisctx, Value[] initValues)
    {
        if(baseClasses.length > 0)
            if(auto bc = cast(Class)baseClasses[0].getClass())
                bc._initValues(thisctx, initValues);
        super._initValues(thisctx, initValues);
    }

    override Value _getProperty(AggrValue av, Declarator decl, bool virtualCall)
    {
        if(Value v = super._getProperty(av, decl, virtualCall))
            return v;
        if(baseClasses.length > 0)
            if(auto bc = baseClasses[0].getClass())
                if(Value v = bc._getProperty(av, decl, virtualCall))
                    return v;
        return null;
    }

    override Declarator _findOverride(AggrValue av, Declarator decl)
    {
        if(auto pdecl = decl.ident in mapName2Method)
            return *pdecl;

        if(baseClasses.length > 0)
            if(auto bc = baseClasses[0].getClass())
                return bc._findOverride(av, decl);

        return decl;
    }
}

class InheritingScope : AggregateScope
{
    override void searchParents(string ident, bool inParents, bool privateImports, bool publicImports, ref SearchSet syms)
    {
        auto ia = static_cast!InheritingAggregate(node);
        foreach(bc; ia.baseClasses)
            if(auto sc = bc.calcType().getScope())
                addunique(syms, sc.search(ident, false, false, true));

        super.searchParents(ident, inParents, privateImports, publicImports, syms);
    }
}

class Class : InheritingAggregate
{
    this() {} // default constructor needed for clone()

    this(ref const(TextSpan) _span)
    {
        super(_span);
    }

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override void toD(CodeWriter writer)
    {
        if(writer.writeReferencedOnly && semanticSearches == 0)
            return;

        writer("class ");
        super.toD(writer);
    }

    Class getBaseClass()
    {
        if(baseClasses.length > 0)
            if(auto bc = cast(Class)baseClasses[0].getClass())
                return bc;
        return null;
    }

    override TupleValue _initValue()
    {
        ClassInstanceValue sv = new ClassInstanceValue(this);
        _setupInitValue(sv);
        return sv;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        if(!scop && parent)
            semantic(parent.getScope());

        auto v = new ClassValue(this);
        if(!initValue)
            return v;
        if(auto rv = cast(ReferenceValue)initValue)
            return v.opBin(ctx, TOK_assign, rv);

        v.instance = _createValue!ClassInstanceValue(ctx, initValue, this);
        v.validate();
        return v;
    }
}

class AnonymousClass : Class
{
    mixin ForwardCtorNoId!();

    override void toD(CodeWriter writer)
    {
        // "class(args) " written by AnonymousClassType, so skip Class.toD
        InheritingAggregate.toD(writer);
    }

    override TupleValue _initValue()
    {
        ClassInstanceValue sv = new ClassInstanceValue(this);
        _setupInitValue(sv);
        return sv;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        auto v = new ClassValue(this);
        if(!initValue)
            return v;
        if(auto rv = cast(ReferenceValue)initValue)
            return v.opBin(ctx, TOK_assign, rv);

        v.instance = _createValue!ClassInstanceValue(ctx, initValue, this);
        v.validate();
        return v;
    }
}

// Interface conflicts with object.Interface
class Intrface : InheritingAggregate
{
    this() {} // default constructor needed for clone()

    this(ref const(TextSpan) _span)
    {
        super(_span);
    }

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override void toD(CodeWriter writer)
    {
        if(writer.writeReferencedOnly && semanticSearches == 0)
            return;

        writer(TOK_interface, " ");
        super.toD(writer);
    }

    override TupleValue _initValue()
    {
        semanticError("Intrface::_initValue should not be called!");
        return new TupleValue;
    }
    override Value createValue(Context ctx, Value initValue)
    {
        Value v = new InterfaceValue(this);
        if(!initValue)
            return v;
        return v.opBin(ctx, TOK_assign, initValue);
    }
}

// BaseClass:
//    [IdentifierList]
class BaseClass : Node
{
    mixin ForwardCtor!();

    Type type;

    this() {} // default constructor needed for clone()

    this(TokenId prot, ref const(TextSpan) _span)
    {
        super(prot, _span);
    }

    TokenId getProtection() { return id; }
    IdentifierList getIdentifierList() { return getMember!IdentifierList(0); }

    InheritingAggregate getClass()
    {
        auto res = getIdentifierList().resolve();
        if(auto inh = cast(InheritingAggregate) res)
            return inh;
        if (res) // if null, resolve already issued an error
            semanticError("class or interface expected instead of ", res);
        return null;
    }

    override Type calcType()
    {
        if(type)
            return type;

        type = getClass();
        if(!type)
            type = semanticErrorType("cannot resolve base class ", this);
        return type;
    }

    override void toD(CodeWriter writer)
    {
        // do not output protection in anonymous classes, and public is the default anyway
        if(id != TOK_public)
            writer(id, " ");
        writer(getMember(0));
    }

    override void toC(CodeWriter writer)
    {
        writer("public ", getMember(0)); // protection diffent from C
    }

    Value _interpretProperty(Context ctx, string prop)
    {
        if(auto clss = getClass())
            return clss._interpretProperty(ctx, prop);
        return null;
    }
}

// StructBody:
//    [DeclDef...]
class StructBody : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("{");
        writer.nl();
        {
            auto indent = CodeIndenter(writer);
            foreach(n; members)
                writer(n);
        }
        writer("}");
        writer.nl();
    }

    void initStatics(Scope sc)
    {
        foreach(m; members)
        {
            Decl decl = cast(Decl) m;
            if(!decl)
                continue;
            if(!(decl.attr & Attr_Static))
                continue;
            if(decl.isAlias || decl.getFunctionBody())
                continue; // nothing to do for local functions

            auto decls = decl.getDeclarators();
            for(int n = 0; n < decls.members.length; n++)
            {
                auto d = decls.getDeclarator(n);
                d.interpretCatch(nullContext);
            }
        }
    }

    void iterateDeclarators(bool wantStatics, bool wantFuncs, void delegate(Declarator d) dg)
    {
        foreach(m; members)
        {
            Decl decl = cast(Decl) m;
            if(!decl)
                continue;
            if(decl.isAlias)
                continue; // nothing to do for aliases
            bool isStatic = (decl.attr & Attr_Static) != 0;
            if(isStatic != wantStatics)
                continue;

            auto decls = decl.getDeclarators();
            for(int n = 0; n < decls.members.length; n++)
            {
                auto d = decls.getDeclarator(n);
                bool isFunc = d.getParameterList() !is null;
                if(isFunc != wantFuncs)
                    continue; // nothing to do for aliases and local functions
                dg(d);
            }
        }
    }

    void iterateConstructors(bool wantStatics, void delegate(Constructor ctor) dg)
    {
        foreach(m; members)
        {
            Constructor ctor = cast(Constructor) m;
            if(!ctor)
                continue;
            bool isStatic = (ctor.attr & Attr_Static) != 0;
            if(isStatic != wantStatics)
                continue;

            dg(ctor);
        }
    }

    override void _semantic(Scope sc)
    {
        super._semantic(sc);
        initStatics(sc);
    }

    override void addSymbols(Scope sc)
    {
        addMemberSymbols(sc);
    }
}

//Constructor:
//    [TemplateParameters_opt Parameters_opt Constraint_opt FunctionBody]
//    if no parameters: this ( this )
class Constructor : Node, CallableNode
{
    mixin ForwardCtor!();

    override bool isTemplate() const { return members.length > 2; }

    TemplateParameterList getTemplateParameters() { return isTemplate() ? getMember!TemplateParameterList(0) : null; }
    Constraint getConstraint() { return isTemplate() && members.length > 3 ? getMember!Constraint(2) : null; }

    override ParameterList getParameterList() { return members.length > 1 ? getMember!ParameterList(isTemplate() ? 1 : 0) : null; }
    override FunctionBody getFunctionBody() { return getMember!FunctionBody(members.length - 1); }

    bool isPostBlit() {    return members.length <= 1; }

    override void toD(CodeWriter writer)
    {
        writer("this");
        if(auto tpl = getTemplateParameters())
            writer(tpl);
        if(auto pl = getParameterList())
            writer(pl);
        else
            writer("(this)");
        if(auto c = getConstraint())
            writer(c);

        if(writer.writeImplementations)
        {
            writer.nl;
            writer(getFunctionBody());
        }
        else
        {
            writer(";");
            writer.nl;
        }
    }

    override bool createsScope() const { return true; }

    override void _semantic(Scope sc)
    {
        if(auto fbody = getFunctionBody())
        {
            sc = enterScope(sc);
            fbody.semantic(sc);
            sc = sc.pop();
        }
    }

    override Value interpretCall(Context sc)
    {
        logInfo("calling ctor");

        if(auto fbody = getFunctionBody())
            return fbody.interpret(sc);
        return semanticErrorValue("ctor is not a interpretable function");
    }
}

//Destructor:
//    [FunctionBody]
class Destructor : Node
{
    mixin ForwardCtor!();

    FunctionBody getBody() { return getMember!FunctionBody(0); }

    override void toD(CodeWriter writer)
    {
        writer("~this()");
        if(writer.writeImplementations)
        {
            writer.nl;
            writer(getBody());
        }
        else
        {
            writer(";");
            writer.nl;
        }
    }
}

//Invariant:
//    [BlockStatement]
class Invariant : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("invariant()");
        if(writer.writeImplementations)
        {
            writer.nl;
            writer(getMember(0));
        }
        else
        {
            writer(";");
            writer.nl;
        }
    }
}

//ClassAllocator:
//    [Parameters FunctionBody]
class ClassAllocator : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("new", getMember(0));
        writer.nl;
        writer(getMember(1));
    }
}

//ClassDeallocator:
//    [Parameters FunctionBody]
class ClassDeallocator : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("delete", getMember(0));
        writer.nl;
        writer(getMember(1));
    }
}


//AliasThis:
class AliasThis : Node
{
    string ident;

    mixin ForwardCtor!();

    this() {} // default constructor needed for clone()

    this(Token tok)
    {
        super(tok);
        ident = tok.txt;
    }

    override AliasThis clone()
    {
        AliasThis n = static_cast!AliasThis(super.clone());
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
        writer("alias ");
        writer.writeIdentifier(ident);
        writer(" this;");
        writer.nl;
    }
}
