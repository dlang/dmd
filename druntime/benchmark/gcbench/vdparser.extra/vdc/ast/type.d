// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.ast.type;

import vdc.util;
import vdc.lexer;
import vdc.semantic;
import vdc.interpret;

import vdc.ast.node;
import vdc.ast.expr;
import vdc.ast.misc;
import vdc.ast.aggr;
import vdc.ast.tmpl;
import vdc.ast.stmt;
import vdc.ast.decl;
import vdc.ast.writer;

import stdext.util;
import std.conv;

class BuiltinPropertyBase : Symbol
{
    string ident;
}

class BuiltinProperty(T) : BuiltinPropertyBase
{
    Value value;

    this(string id, T val)
    {
        ident = id;
        value = Value.create(val);
    }

    override void toD(CodeWriter writer)
    {
        _assert(false);
    }

    override Type calcType()
    {
        return value.getType();
    }
    override Value interpret(Context sc)
    {
        return value;
    }
}

Symbol newBuiltinProperty(T)(Scope sc, string id, T val)
{
    auto bp = new BuiltinProperty!T(id, val);
    sc.addSymbol(id, bp);
    return bp;
}

class BuiltinType(T) : Node
{
}

Scope[int] builtInScopes;
alias AssociativeArray!(int, Scope) _wa1; // fully instantiate type info

Scope getBuiltinBasicTypeScope(int tokid)
{
    if(auto ps = tokid in builtInScopes)
        return *ps;

    Scope sc = new Scope;

    foreach(tok; BasicTypeTokens)
    {
        if (tokid == tok)
        {
            alias Token2BasicType!(tok) BT;

            newBuiltinProperty(sc, "init",     BT.init);
            newBuiltinProperty(sc, "sizeof",   BT.sizeof);
            newBuiltinProperty(sc, "mangleof", BT.mangleof);
            newBuiltinProperty(sc, "alignof",  BT.alignof);
            newBuiltinProperty(sc, "stringof", BT.stringof);
            static if(__traits(compiles, BT.min))
                newBuiltinProperty(sc, "min", BT.min);
            static if(__traits(compiles, BT.max))
                newBuiltinProperty(sc, "max", BT.max);
            static if(__traits(compiles, BT.nan))
                newBuiltinProperty(sc, "nan", BT.nan);
        }
    }
    builtInScopes[tokid] = sc;
    return sc;
}

class Type : Node
{
    // semantic data
    TypeInfo typeinfo;

    mixin ForwardCtor!();

    abstract bool propertyNeedsParens() const;

    override Type clone()
    {
        Type n = static_cast!Type(super.clone());
        return n;
    }

    enum ConversionFlags
    {
        kAllowBaseClass          = 1 << 0,
        kAllowConstConversion    = 1 << 1,
        kAllowBaseTypeConversion = 1 << 2,

        // flags to clear on indirection
        kIndirectionClear = kAllowBaseClass | kAllowBaseTypeConversion,
        kImpliciteConversion = kAllowBaseClass | kAllowConstConversion | kAllowBaseTypeConversion,
    }

    bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(from == this)
            return true;
        return false;
    }
    final bool convertableFromImplicite(Type from)
    {
        return convertableFrom(from, ConversionFlags.kImpliciteConversion);
    }

    Type commonType(Type other)
    {
        if(convertableFromImplicite(other))
            return this;
        if(other.convertableFromImplicite(this))
            return other;
        return semanticErrorType(this, " has no common type with ", other);
    }

    override void _semantic(Scope sc)
    {
        if(!typeinfo)
            typeSemantic(sc);
    }

    void typeSemantic(Scope sc)
    {
        super._semantic(sc);
    }

    override Type calcType()
    {
        return this;
    }

    override Value interpret(Context sc)
    {
        return new TypeValue(this);
    }

    Value getProperty(Value sv, string ident, bool virtualCall)
    {
        return null;
    }

    Value getProperty(Value sv, Declarator decl, bool virtualCall)
    {
        return null;
    }

    final Value interpretProperty(Context ctx, string prop)
    {
        if(Value v = _interpretProperty(ctx, prop))
            return v;
        return semanticErrorValue("cannot calculate property ", prop, " of type ", this);
    }
    Value _interpretProperty(Context ctx, string prop)
    {
        return null;
    }

    Value createValue(Context ctx, Value initValue)
    {
        return semanticErrorValue("cannot create value of type ", this);
    }

    Type opIndex(int v)
    {
        return semanticErrorType("cannot index a ", this);
    }

    Type opSlice(int b, int e)
    {
        return semanticErrorType("cannot slice a ", this);
    }

    Type opCall(Type args)
    {
        return semanticErrorType("cannot call a ", this);
    }

    //////////////////////////////////////////////////////////////
    Type unqualified()
    {
        return this;
    }
}

class ErrorType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return false; }
    override void toD(CodeWriter writer) { writer("_errortype_"); }

    override Scope getScope()
    {
        if(!scop)
            scop = new Scope();
        return scop;
    }
}

// moved out of BasicType due to BUG9672
Type createBasicType(int tokid)
{
    BasicType type = new BasicType;
    type.id = tokid;
    return type;
}

//BasicType only created for standard types associated with tokens
class BasicType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return false; }

    static Type getSizeType()
    {
        return getType(TOK_uint); // TOK_ulong if compiling for 64-bit
    }

    static Type getType(int tokid)
    {
        static Type[] cachedTypes;
        if(tokid >= cachedTypes.length)
            cachedTypes.length = tokid + 1;
        if(!cachedTypes[tokid])
            cachedTypes[tokid] = createBasicType(tokid);
        return cachedTypes[tokid];
    }

    static TypeInfo getTypeInfo(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
                return typeid(Token2BasicType!(tok));
        }
        return null;
    }

    static size_t getSizeof(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
                return Token2BasicType!(tok).sizeof;
        }
        _assert(false);
        return int.sizeof;
    }

    static string getMangleof(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
                return Token2BasicType!(tok).mangleof;
        }
        _assert(false);
        return null;
    }

    static size_t getAlignof(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
                return Token2BasicType!(tok).alignof;
        }
        _assert(false);
        return int.alignof;
    }

    static string getStringof(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
                return Token2BasicType!(tok).stringof;
        }
        _assert(false);
        return null;
    }

    static Value getMin(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            static if(__traits(compiles, Token2BasicType!(tok).min))
                if (id == tok)
                    return Value.create(Token2BasicType!(tok).min);
        }
        return .semanticErrorValue(tokenString(id), " has no min property");
    }

    static Value getMax(int id)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            static if(__traits(compiles, Token2BasicType!(tok).max))
                if (id == tok)
                    return Value.create(Token2BasicType!(tok).max);
        }
        return .semanticErrorValue(tokenString(id), " has no max property");
    }

    override Value createValue(Context ctx, Value initValue)
    {
        // TODO: convert foreach to table access for faster lookup
        foreach(tok; BasicTypeTokens)
        {
            if (id == tok)
            {
                if(initValue)
                    return createInitValue!(Token2ValueType!(tok))(ctx, initValue);
                return Value.create(Token2BasicType!(tok).init);
            }
        }
        return semanticErrorValue("cannot create value of type ", this);
    }

    override void typeSemantic(Scope sc)
    {
        _assert(id != TOK_auto);
        typeinfo = getTypeInfo(id);
    }

    override Scope getScope()
    {
        if(!scop)
            scop = getBuiltinBasicTypeScope(id);
        return scop;
    }

    enum Category { kInteger, kFloat, kComplex, kVoid }

    static int categoryLevel(int id)
    {
        switch(id)
        {
            case TOK_bool:    return 0;
            case TOK_byte:    return 1;
            case TOK_ubyte:   return 1;
            case TOK_short:   return 2;
            case TOK_ushort:  return 2;
            case TOK_int:     return 4;
            case TOK_uint:    return 4;
            case TOK_long:    return 8;
            case TOK_ulong:   return 8;
            case TOK_char:    return 1;
            case TOK_wchar:   return 2;
            case TOK_dchar:   return 4;
            case TOK_float:   return 10; // assume al floats convertable, ignore lost accuracy
            case TOK_double:  return 10;
            case TOK_real:    return 10;
            case TOK_ifloat:  return 10;
            case TOK_idouble: return 10;
            case TOK_ireal:   return 10;
            case TOK_cfloat:  return 16;
            case TOK_cdouble: return 16;
            case TOK_creal:   return 16;
            default: assert(false);
        }
    }

    static Category category(int id)
    {
        switch(id)
        {
            case TOK_bool:    return Category.kInteger;
            case TOK_byte:    return Category.kInteger;
            case TOK_ubyte:   return Category.kInteger;
            case TOK_short:   return Category.kInteger;
            case TOK_ushort:  return Category.kInteger;
            case TOK_int:     return Category.kInteger;
            case TOK_uint:    return Category.kInteger;
            case TOK_long:    return Category.kInteger;
            case TOK_ulong:   return Category.kInteger;
            case TOK_char:    return Category.kInteger;
            case TOK_wchar:   return Category.kInteger;
            case TOK_dchar:   return Category.kInteger;
            case TOK_float:   return Category.kFloat;
            case TOK_double:  return Category.kFloat;
            case TOK_real:    return Category.kFloat;
            case TOK_ifloat:  return Category.kFloat;
            case TOK_idouble: return Category.kFloat;
            case TOK_ireal:   return Category.kFloat;
            case TOK_cfloat:  return Category.kComplex;
            case TOK_cdouble: return Category.kComplex;
            case TOK_creal:   return Category.kComplex;
            case TOK_void:    return Category.kVoid;
            default: break;
        }
        _assert(false);
        return Category.kVoid;
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        switch(prop)
        {
            // all types
            case "init":
                return createValue(nullContext, null);
            case "sizeof":
                return Value.create(getSizeof(id));
            case "alignof":
                return Value.create(getAlignof(id));
            case "mangleof":
                return Value.create(getMangleof(id));
            case "stringof":
                return Value.create(getStringof(id));

            // integer types
            case "min":
                return getMin(id);
            case "max":
                return getMax(id);

            // floating point types
            case "infinity":
            case "nan":
            case "dig":
            case "epsilon":
            case "mant_dig":
            case "max_10_exp":
            case "max_exp":
            case "min_10_exp":
            case "min_exp":
            case "min_normal":
            case "re":
            case "im":
            default:
                return super._interpretProperty(ctx, prop);
        }
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
            return true;

        auto bt = cast(BasicType) from;
        if(!bt)
            return false;
        if(id == bt.id)
            return true;

        Category cat = category(id);
        Category fcat = category(bt.id);

        if(flags & ConversionFlags.kAllowBaseTypeConversion)
            return cat == fcat;
        if(flags & ConversionFlags.kImpliciteConversion)
        {
            if(cat == Category.kVoid || fcat != Category.kVoid)
                return cat == fcat;
            return (categoryLevel(id) >= categoryLevel(bt.id));
        }
        return false;
    }

    override void toD(CodeWriter writer)
    {
        _assert(id != TOK_auto);
        writer(id);
    }
}

class NullType : Type
{
    override bool propertyNeedsParens() const { return false; }

    override void toD(CodeWriter writer)
    {
        writer("Null");
    }
}

//AutoType:
//    auto added implicitely if there is no other type specified
class AutoType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return false; }

    override void toD(CodeWriter writer)
    {
        if(id != TOK_auto) // only implicitely added?
            writer(id);
    }

    override Value createValue(Context ctx, Value initValue)
    {
        if(!initValue)
            return semanticErrorValue("no initializer in auto declaration");
        return initValue;
    }

    override Type calcType()
    {
        Expression expr;

        if(auto decl = cast(Decl) parent)
        {
            Declarators decls = decl.getDeclarators();
            if(auto declinit = cast(DeclaratorInitializer) decls.getMember(0))
                expr = declinit.getInitializer();
        }
        if(expr)
            return expr.calcType();
        return semanticErrorType("no initializer in auto declaration");
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        return calcType().convertableFrom(from, flags);
    }
}

class VectorType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return true; }

    override void toD(CodeWriter writer)
    {
        writer("__vector(", getMember(0), ")");
    }
}

//ModifiedType:
//    [Type]
class ModifiedType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return true; }

    Type getType() { return getMember!Type(0); } // ignoring modifiers

    override Type unqualified()
    {
        return getType();
    }

    override void typeSemantic(Scope sc)
    {
        TypeInfo_Const ti;
        switch(id)
        {
            case TOK_const:     ti = new TypeInfo_Const; break;
            case TOK_immutable: ti = new TypeInfo_Invariant; break;
            case TOK_inout:     ti = new TypeInfo_Inout;  break;
            case TOK_shared:    ti = new TypeInfo_Shared; break;
            default: _assert(false);
        }

        auto type = getType();
        type.semantic(sc);
        ti.base = type.typeinfo;

        typeinfo = ti;
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
            return true;

        Type nextThis = getType();
        auto modfrom = cast(ModifiedType) from;
        if(modfrom)
        {
            Type nextFrom = modfrom.getType();
            if(id == modfrom.id)
                if(nextThis.convertableFrom(nextFrom, flags))
                    return true;

            if(flags & ConversionFlags.kAllowConstConversion)
                if(id == TOK_const && modfrom.id == TOK_immutable)
                    if(nextThis.convertableFrom(nextFrom, flags))
                        return true;
        }
        if(flags & ConversionFlags.kAllowConstConversion)
            if(id == TOK_const)
                if(nextThis.convertableFrom(from, flags))
                    return true;
        return false;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        return getType().createValue(ctx, initValue); // TODO: ignores modifier
    }

    override void toD(CodeWriter writer)
    {
        writer(id, "(", getMember(0), ")");
    }
}

//IdentifierType:
//    [IdentifierList]
class IdentifierType : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return false; }

    //Node resolved;
    Type type;

    IdentifierList getIdentifierList() { return getMember!IdentifierList(0); }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0));
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        return calcType().convertableFrom(from, flags);
    }

    override Type calcType()
    {
        if(type)
            return type;

        auto idlist = getIdentifierList();
        type = idlist.calcType();
        return type;
    }

    override Value interpret(Context sc)
    {
        // might also be called inside an alias, actually resolving to a value
        return new TypeValue(this);
    }
}


//Typeof:
//    [Expression/Type_opt IdentifierList_opt]
class Typeof : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return false; }

    bool isReturn() { return id == TOK_return; }

    IdentifierList getIdentifierList() { return getMember!IdentifierList(1); }

    override void toD(CodeWriter writer)
    {
        if(isReturn())
            writer("typeof(return)");
        else
            writer("typeof(", getMember(0), ")");
        if(auto identifierList = getIdentifierList())
            writer(".", identifierList);
    }

    override Value interpret(Context sc)
    {
        if(isReturn())
        {
            return semanticErrorValue("typeof(return) not implemented");
        }
        Node n = getMember(0);
        Type t = n.calcType();
        return new TypeValue(t);
    }
}

// base class for types that have an indirection, i.e. pointer and arrays
class TypeIndirection : Type
{
    mixin ForwardCtor!();

    override TypeIndirection clone()
    {
        auto n = static_cast!TypeIndirection(super.clone());
        if(members.length == 0)
            n.setNextType(_next);
        return n;
    }

    Type _next;

    override bool propertyNeedsParens() const { return true; }

    //Type getType() { return getMember!Type(0); }

    void setNextType(Type t)
    {
        _next = t.calcType();
    }

    Type getNextType()
    {
        if(_next)
            return _next;
        _next = getMember!Type(0).calcType();
        return _next;
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
            return true;

        Type nextThis = getNextType();
        if (typeid(this) != typeid(from))
            return false;
        auto ifrom = static_cast!TypeIndirection(from);
        _assert(ifrom !is null);

        // could allow A* -> const(B*) if class A derives from B
        // even better    -> head_const(B*)
        return nextThis.convertableFrom(ifrom.getNextType(), flags & ~ConversionFlags.kIndirectionClear);
    }

    override Type opIndex(int v)
    {
        //_assert(false);
        return getNextType();
    }

    override Type opSlice(int b, int e)
    {
        _assert(false);
        return this;
    }

}

//TypePointer:
//    [Type]
class TypePointer : TypeIndirection
{
    mixin ForwardCtor!();

    override void typeSemantic(Scope sc)
    {
        auto type = getNextType();
        //type.semantic(sc);
        auto typeinfo_ptr = new TypeInfo_Pointer;
        typeinfo_ptr.m_next = type.typeinfo;
        typeinfo = typeinfo_ptr;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        auto v = PointerValue._create(this, null);
        if(initValue)
            v.opBin(ctx, TOK_assign, initValue);
        return v;
    }

    bool convertableTo(TypePointer t)
    {
        auto type = getNextType();
        auto otype = t.getNextType();
        return otype.compare(type);
    }

    override void toD(CodeWriter writer)
    {
        if(auto m = getMember(0))
            writer(m, "*");
        else if(_next)
            writer(_next, "*");
        else
            writer("_missingtype_*");
    }
}

class LengthProperty : Symbol
{
    Type type;

    override Type calcType()
    {
        if(!type)
            type = createBasicType(TOK_uint);
        return type;
    }

    override Value interpret(Context sc)
    {
        if(auto ac = cast(AggrContext)sc)
        {
            if(auto dav = cast(DynArrayValue) ac.instance)
                return new SetLengthValue(dav);
            return semanticErrorValue("cannot calulate length of ", ac.instance);
        }
        return semanticErrorValue("no context to length of ", sc);
    }

    override void toD(CodeWriter writer)
    {
        writer("length");
    }
}

class PtrProperty : Symbol
{
    Type type;

    this(Type t)
    {
        auto tp = new TypePointer(TOK_mul, t.span);
        tp.setNextType(t);
        type = tp;
    }

    override Type calcType()
    {
        return type;
    }

    override Value interpret(Context sc)
    {
        if(auto ac = cast(AggrContext)sc)
        {
            if(auto dav = cast(DynArrayValue) ac.instance)
            {
                if(dav.first)
                    return dav.first.opRefPointer();
                else
                    return type.createValue(sc, null);
            }
            return semanticErrorValue("cannot calculate ptr of ", ac.instance);
        }
        return semanticErrorValue("no context to ptr of ", sc);
    }

    override void toD(CodeWriter writer)
    {
        writer("ptr");
    }
}

//TypeDynamicArray:
//    [Type]
class TypeDynamicArray : TypeIndirection
{
    mixin ForwardCtor!();

    static Scope cachedScope;

    override void typeSemantic(Scope sc)
    {
        auto type = getNextType();
        //type.semantic(sc);
        auto typeinfo_arr = new TypeInfo_Array;
        typeinfo_arr.value = type.typeinfo;
        typeinfo = typeinfo_arr;
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
            return true;

        if (typeid(from) is typeid(TypeStaticArray))
        {
            Type nextThis = getNextType();
            auto arrfrom = static_cast!TypeStaticArray(from);
            assert(arrfrom);

            // should allow A[] -> const(B[]) if class A derives from B
            // even better      -> head_const(B[])
            if(nextThis.convertableFrom(arrfrom.getNextType(), flags & ~ConversionFlags.kIndirectionClear))
                return true;
        }
        return false;
    }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0), "[]");
    }

    override Scope getScope()
    {
        if(!scop)
        {
            Scope sc = parent ? parent.getScope() : null;
            scop = sc ? sc.pushClone() : new Scope;
            scop.addSymbol("length", new LengthProperty);
            scop.addSymbol("ptr", new PtrProperty(getNextType()));
        }
        return scop;
    }

    override Value createValue(Context ctx, Value initValue)
    {
    version(none)
        if(auto mtype = cast(ModifiedType) getType())
            if(mtype.id == TOK_immutable)
                if(auto btype = cast(BasicType) mtype.getType())
                    if(btype.id == TOK_char)
                        return createInitValue!StringValue(ctx, initValue);

        auto val = new DynArrayValue(this);
        if(initValue)
            val.opBin(ctx, TOK_assign, initValue);
        return val;
    }

    override Type opSlice(int b, int e)
    {
        return this;
        /+
        auto da = new TypeStaticArray;
        da.setNextType(getNextType()); //addMember(nextType().clone());
        return da;
        +/
    }

/+    Value deepCopy(Context sc, Value initValue)
    {
        auto val = new DynArrayValue(this);
        if(int dim = initValue ? initValue.interpretProperty(sc, "length").toInt() : 0)
        {
            auto type = getType();
            Value[] values;
            values.length = dim;
            IntValue idxval = new IntValue;
            for(int i = 0; i < dim; i++)
            {
                *(idxval.pval) = i;
                Value v = initValue ? initValue.opIndex(idxval) : null;
                values[i] = type.createValue(sc, v);
            }
            val.values = values;
        }
        return val;
    }
+/
}

//SuffixDynamicArray:
//    []
class SuffixDynamicArray : Node
{
    mixin ForwardCtor!();

    override void toD(CodeWriter writer)
    {
        writer("[]");
    }
}

// can be both static or assoc, which one is correct cannot be decided by the parser in general
//SuffixArray:
//    [Expression|Type]
class SuffixArray : Node
{
    mixin ForwardCtor!();

    Expression getDimension() { return getMember!Expression(0); }
    Type getKeyType() { return getMember!Type(0); }

    override void toD(CodeWriter writer)
    {
        writer("[", getMember(0), "]");
    }
}

//TypeStaticArray:
//    [Type Expression]
class TypeStaticArray : TypeIndirection
{
    mixin ForwardCtor!();

    override TypeStaticArray clone()
    {
        auto n = static_cast!TypeStaticArray(super.clone());
        n.dimExpr = dimExpr;
        return n;
    }

    Expression getDimension() { return dimExpr ? dimExpr : getMember!Expression(1); }

    Expression dimExpr;

    override void typeSemantic(Scope sc)
    {
        auto type = getNextType();
        //type.semantic(sc);
        auto typeinfo_arr = new TypeInfo_StaticArray;
        typeinfo_arr.value = type.typeinfo;

        Context ctx = new Context(nullContext);
        ctx.scop = sc;
        typeinfo_arr.len = getDimension().interpret(ctx).toInt();
        typeinfo = typeinfo_arr;
    }

    override Scope getScope()
    {
        if(!scop)
        {
            enterScope(parent.getScope());
            Context ctx = new Context(nullContext);
            ctx.scop = scop;
            size_t len = getDimension().interpret(ctx).toInt();
            newBuiltinProperty(scop, "length", len);
        }
        return scop;
    }

    /+
    override Scope getScope()
    {
        if(!scop)
        {
            scop = createTypeScope();
            //scop.addSymbol("length", new BuiltinProperty!uint(BasicType.getType(TOK_uint), 0));
            scop.parent = super.getScope();
        }
        return scop;
    }
    +/

    override void toD(CodeWriter writer)
    {
        writer(getMember(0), "[", getMember(1), "]");
    }

    override Value createValue(Context ctx, Value initValue)
    {
        int dim = getDimension().interpret(ctx).toInt();
        auto val = new StaticArrayValue(this);
        val.setLength(ctx, dim);
        if(initValue)
            val.opBin(ctx, TOK_assign, initValue);

        return val;
    }

    override Type opSlice(int b, int e)
    {
        auto da = new TypeDynamicArray;
        da.setNextType(getNextType()); //addMember(nextType().clone());
        return da;
        //return this;
    }

}

//TypeAssocArray:
//    [Type Type]
class TypeAssocArray : TypeIndirection
{
    mixin ForwardCtor!();

    override TypeAssocArray clone()
    {
        auto n = static_cast!TypeAssocArray(super.clone());
        n.keyType = keyType;
        return n;
    }

    Type getKeyType() { return keyType ? keyType : getMember!Type(1); }

    Type keyType;

    override void typeSemantic(Scope sc)
    {
        auto vtype = getNextType();
        //vtype.semantic(sc);
        auto ktype = getKeyType();
        //ktype.semantic(sc);

        auto typeinfo_arr = new TypeInfo_AssociativeArray;
        typeinfo_arr.value = vtype.typeinfo;
        typeinfo_arr.key = ktype.typeinfo;
        typeinfo = typeinfo_arr;
    }

    override bool convertableFrom(Type from, ConversionFlags flags)
    {
        if(super.convertableFrom(from, flags))
        {
            auto aafrom = static_cast!TypeAssocArray(from); // verified in super.convertableFrom
            if(getKeyType().convertableFrom(aafrom.getKeyType(), flags & ~ConversionFlags.kIndirectionClear))
                return true;
        }
        return false;
    }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0), "[", getMember(1), "]");
    }
}

//TypeArraySlice:
//    [Type Expression Expression]
class TypeArraySlice : Type
{
    mixin ForwardCtor!();

    override bool propertyNeedsParens() const { return true; }

    Type getType() { return getMember!Type(0); }
    Expression getLower() { return getMember!Expression(1); }
    Expression getUpper() { return getMember!Expression(2); }

    override void typeSemantic(Scope sc)
    {
        auto rtype = getType();
        if(auto tpl = cast(TypeInfo_Tuple) rtype.typeinfo)
        {
            Context ctx = new Context(nullContext);
            ctx.scop = sc;
            int lo = getLower().interpret(ctx).toInt();
            int up = getUpper().interpret(ctx).toInt();
            if(lo > up || lo < 0 || up > tpl.elements.length)
            {
                semanticError("tuple slice out of bounds");
                typeinfo = tpl;
            }
            else
            {
                auto ntpl = new TypeInfo_Tuple;
                ntpl.elements = tpl.elements[lo..up];
                typeinfo = ntpl;
            }
        }
        else
        {
            semanticError("type is not a tuple");
            typeinfo = rtype.typeinfo;
        }
    }

    override void toD(CodeWriter writer)
    {
        writer(getMember(0), "[", getLower(), " .. ", getUpper(), "]");
    }
}

//TypeFunction:
//    [Type ParameterList]
class TypeFunction : Type
{
    mixin ForwardCtor!();

    override TypeFunction clone()
    {
        auto n = static_cast!TypeFunction(super.clone());
        n.paramList = paramList;
        n.returnType = returnType;
        n.funcDecl = funcDecl;
        return n;
    }

    override bool propertyNeedsParens() const { return true; }

    Type getReturnType() { return returnType ? returnType : getMember!Type(0); } // overwritten in TypeFunctionLiteral/TypeDelegateLiteral
    ParameterList getParameters() { return paramList ? paramList : getMember!ParameterList(1); }

    ParameterList paramList;
    Type returnType;

    Declarator funcDecl; // the actual function pointer

    override void typeSemantic(Scope sc)
    {
        auto ti_fn = new TypeInfo_FunctionX;

        auto rtype = getReturnType();
        rtype.semantic(sc);
        auto params = getParameters();
        params.semantic(sc);

        ti_fn.next = rtype.typeinfo;
        ti_fn.parameters = new TypeInfo_Tuple;
        for(size_t p = 0; p < params.members.length; p++)
            ti_fn.parameters.elements ~= params.getParameter(p).getParameterDeclarator().getType().typeinfo;
        ti_fn.attributes = combineAttributes(attr, params.attr);
        typeinfo = ti_fn;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        auto fv = new FunctionValue;
        if(FunctionValue ifv = cast(FunctionValue) initValue)
        {
            // TODO: verfy types
            fv.functype = ifv.functype;
        }
        else if(initValue)
            return semanticErrorValue("cannot assign ", initValue, " to ", this);
        else
            fv.functype = this;
        return fv;
    }

    override Type opCall(Type args)
    {
        return getReturnType().calcType();
    }

    override void toD(CodeWriter writer)
    {
        writer(getReturnType(), " function", getParameters());
        writer.writeAttributesAndAnnotations(attr, annotation, true);
    }
}

//TypeDelegate:
//    [Type ParameterList]
class TypeDelegate : TypeFunction
{
    mixin ForwardCtor!();

    override void typeSemantic(Scope sc)
    {
        auto ti_dg = new TypeInfo_DelegateX;

        auto rtype = getReturnType();
        rtype.semantic(sc);
        auto params = getParameters();
        params.semantic(sc);

        ti_dg.next = rtype.typeinfo;
        ti_dg.parameters = new TypeInfo_Tuple;
        for(size_t p = 0; p < params.members.length; p++)
            ti_dg.parameters.elements ~= params.getParameter(p).getParameterDeclarator().getType().typeinfo;
        ti_dg.attributes = combineAttributes(attr, params.attr);
        // no context information when defining the type, only with an instance
        typeinfo = ti_dg;
    }

    override Value createValue(Context ctx, Value initValue)
    {
        auto fv = new DelegateValue;
        if(DelegateValue ifv = cast(DelegateValue) initValue)
        {
            // TODO: verfy types
            fv.functype = ifv.functype;
            fv.context = ifv.context;
        }
        else if(initValue)
            return semanticErrorValue("cannot assign ", initValue, " to ", this);
        else
        {
            fv.functype = this;
            fv.context = ctx;
        }
        return fv;
    }

    override void toD(CodeWriter writer)
    {
        writer(getReturnType(), " delegate", getParameters());
        writer.writeAttributesAndAnnotations(attr, annotation, true);
    }
}

class TypeInfo_FunctionX : TypeInfo_Function
{
    TypeInfo_Tuple parameters;
    int attributes;
}

class TypeInfo_DelegateX : TypeInfo_Delegate
{
    TypeInfo_Tuple parameters;
    int attributes;
    TypeInfo context;
}

class TypeString : TypeDynamicArray
{
    mixin ForwardCtor!();

    version(none)
    override Value createValue(Context ctx, Value initValue)
    {
        return createInitValue!StringValue(ctx, initValue);
    }

}

TypeDynamicArray createTypeString(C)()
{
    TextSpan span;
    return createTypeString!C(span);
}

TypeDynamicArray createTypeString(C)(ref const(TextSpan) span)
{
    auto arr = new TypeString(span);

    BasicType ct = new BasicType(BasicType2Token!C(), span);
    ModifiedType mt = new ModifiedType(TOK_immutable, span);
    mt.addMember(ct);
    arr.addMember(mt);
    return arr;
}

TypeDynamicArray getTypeString(C)()
{
    static TypeDynamicArray cachedTypedString;
    if(!cachedTypedString)
    {
        TextSpan span;
        cachedTypedString = createTypeString!C(span);
    }
    return cachedTypedString;
}
