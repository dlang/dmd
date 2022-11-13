// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt
//
// Interpretation passes around a context, holding the current variable stack
// class Context { Scope sc; Value[Node] vars; Context parent; }
//
// static shared values are not looked up in the context
// thread local static values are looked up in a global thread context
// non-static values are looked up in the current context
//
// member/field lookup in aggregates uses an instance specific Context
//
// when entering a scope, a new Context is created with the current
//  Context as parent
// when leaving a scope, the context is destroyed together with scoped values
//  created within the lifetime of the context
// a delegate value saves the current context to be used when calling the delegate
//
// local functions are called with the context of the enclosing function
// member functions are called with the context of the instance
// static or global functions are called with the thread context
//
module vdc.interpret;

import vdc.util;
import vdc.semantic;
import vdc.lexer;
import vdc.logger;

import vdc.ast.decl;
import vdc.ast.type;
import vdc.ast.aggr;
import vdc.ast.expr;
import vdc.ast.node;
import vdc.ast.writer;

import stdext.util;
import stdext.string;

import std.conv;
import std.meta;
import std.string;
import std.traits;
import std.utf;
import std.variant;

template Singleton(T, ARGS...)
{
    T get()
    {
        static T instance;
        if(!instance)
            instance = new T(ARGS);
        return instance;
    }
}

class Value
{
    bool mutable = true;
    bool literal = false;
    debug string sval;
    debug string ident;

    static T _create(T, V)(V val)
    {
        T v = new T;
        *v.pval = val;
        debug v.sval = v.toStr();
        return v;
    }

    static Value create(bool    v) { return _create!BoolValue   (v); }
    static Value create(byte    v) { return _create!ByteValue   (v); }
    static Value create(ubyte   v) { return _create!UByteValue  (v); }
    static Value create(short   v) { return _create!ShortValue  (v); }
    static Value create(ushort  v) { return _create!UShortValue (v); }
    static Value create(int     v) { return _create!IntValue    (v); }
    static Value create(uint    v) { return _create!UIntValue   (v); }
    static Value create(long    v) { return _create!LongValue   (v); }
    static Value create(ulong   v) { return _create!ULongValue  (v); }
    static Value create(char    v) { return _create!CharValue   (v); }
    static Value create(wchar   v) { return _create!WCharValue  (v); }
    static Value create(dchar   v) { return _create!DCharValue  (v); }
    static Value create(float   v) { return _create!FloatValue  (v); }
    static Value create(double  v) { return _create!DoubleValue (v); }
    static Value create(real    v) { return _create!RealValue   (v); }
    static Value create(string  v) { return createStringValue (v); }

    Type getType()
    {
        semanticError("cannot get type of ", this);
        return Singleton!(ErrorType).get();
    }

    bool toBool()
    {
        semanticError("cannot convert ", this, " to bool");
        return false;
    }

    int toInt()
    {
        long lng = toLong();
        return cast(int) lng;
    }

    long toLong()
    {
        semanticError("cannot convert ", this, " to integer");
        return 0;
    }

    void setLong(long lng)
    {
        semanticError("cannot convert long to ", this);
    }

    string toStr()
    {
        semanticError("cannot convert ", this, " to string");
        return "";
    }

    string toMixin()
    {
        semanticError("cannot convert ", this, " to mixin");
        return "";
    }

    Value getElement(size_t idx)
    {
        return semanticErrorValue("cannot get ", idx, ". element of array of ", this);
    }

    void setElements(size_t oldcnt, size_t newcnt)
    {
        semanticError("cannot set no of elements of array of ", this);
    }

    PointerValue toPointer(TypePointer to)
    {
        return null;
    }

    final void validate()
    {
        debug sval = toStr();
    }

    //override string toString()
    //{
    //    return text(getType(), ":", toStr());
    //}

    version(all)
    Value opBin(Context ctx, int tokid, Value v)
    {
        return semanticErrorValue("cannot calculate ", this, " ", tokenString(tokid), " ", v);
        //return semanticErrorValue("binary operator ", tokenString(tokid), " on ", this, " not implemented");
    }

    Value opBin_r(Context ctx, int tokid, Value v)
    {
        return semanticErrorValue("cannot calculate ", v, " ", tokenString(tokid), " ", this);
        //return semanticErrorValue("binary operator ", tokenString(tokid), " on ", this, " not implemented");
    }

    Value opUn(Context ctx, int tokid)
    {
        switch(tokid)
        {
            case TOK_and:        return opRefPointer();
            case TOK_mul:        return opDerefPointer();
            default: break;
        }
        return semanticErrorValue("unary operator ", tokenString(tokid), " on ", this, " not implemented");
    }

    Value opRefPointer()
    {
        auto tp = new TypePointer();
        tp.setNextType(getType()); //addMember(getType().clone());
        return PointerValue._create(tp, this);
    }
    Value opDerefPointer()
    {
        return semanticErrorValue("cannot dereference a ", this);
    }

    final Value interpretProperty(Context ctx, string prop)
    {
        if(Value v = _interpretProperty(ctx, prop))
            return v;
        return semanticErrorValue("cannot calculate property ", prop, " of value ", toStr());
    }

    Value _interpretProperty(Context ctx, string prop)
    {
        return getType()._interpretProperty(ctx, prop);
    }

    Value doCast(Value v)
    {
        return semanticErrorValue("cannot cast a ", v, " to ", this);
    }

    Value opIndex(Value v)
    {
        return semanticErrorValue("cannot index a ", this);
    }

    Value opSlice(Value b, Value e)
    {
        return semanticErrorValue("cannot slice a ", this);
    }

    Value opCall(Context sc, Value args)
    {
        return semanticErrorValue("cannot call a ", this);
    }

    //mixin template operators()
    version(none)
        Value opassign(string op)(Value v)
        {
            TypeInfo ti1 = typeid(this);
            TypeInfo ti2 = typeid(v);
            foreach(iv1; BasicTypeValues)
            {
                if(ti1 is typeid(iv1))
                {
                    foreach(iv2; BasicTypeValues)
                    {
                        if(ti2 is typeid(iv2))
                            static if (__traits(compiles, {
                                iv1.ValType x;
                                iv2.ValType y;
                                mixin("x " ~ op ~ "y;");
                            }))
                            {
                                iv2.ValType v2 = (cast(iv2) v).val;
                                static if(op == "/=" || op == "%=")
                                    if(v2 == 0)
                                        return semanticErrorValue("division by zero");
                                mixin("(cast(iv1) this).val " ~ op ~ "v2;");
                                return this;
                            }
                    }
                }
            }
            return semanticErrorValue("cannot execute ", op, " on a ", v, " with a ", this);
        }

    version(none)
        Value opBinOp(string op)(Value v)
        {
            TypeInfo ti1 = typeid(this);
            TypeInfo ti2 = typeid(v);
            foreach(iv1; BasicTypeValues)
            {
                if(ti1 is typeid(iv1))
                {
                    foreach(iv2; BasicTypeValues)
                    {
                        if(ti2 is typeid(iv2))
                        {
                            static if (__traits(compiles, {
                                iv1.ValType x;
                                iv2.ValType y;
                                mixin("auto z = x " ~ op ~ "y;");
                            }))
                            {
                                iv1.ValType v1 = (cast(iv1) this).val;
                                iv2.ValType v2 = (cast(iv2) v).val;
                                static if(op == "/" || op == "%")
                                    if(v2 == 0)
                                        return semanticErrorValue("division by zero");
                                mixin("auto z = v1 " ~ op ~ "v2;");
                                return create(z);
                            }
                            else
                            {
                                return semanticErrorValue("cannot calculate ", op, " on a ", this, " and a ", v);
                            }
                        }
                    }
                }
            }
            return semanticErrorValue("cannot calculate ", op, " on a ", this, " and a ", v);
        }

    version(none)
        Value opUnOp(string op)()
        {
            TypeInfo ti1 = typeid(this);
            foreach(iv1; BasicTypeValues)
            {
                if(ti1 is typeid(iv1))
                {
                    static if (__traits(compiles, {
                        iv1.ValType x;
                        mixin("auto z = " ~ op ~ "x;");
                    }))
                    {
                        mixin("auto z = " ~ op ~ "(cast(iv1) this).val;");
                        return create(z);
                    }
                }
            }
            return semanticErrorValue("cannot calculate ", op, " on a ", this);
        }

    ////////////////////////////////////////////////////////////
    mixin template mixinBinaryOp1(string op, iv2)
    {
        Value binOp1(Value v)
        {
            if(auto vv = cast(iv2) v)
            {
                iv2.ValType v2 = *vv.pval;
                static if(op == "/" || op == "%")
                    if(v2 == 0)
                        return semanticErrorValue("division by zero");
                mixin("auto z = *pval " ~ op ~ "v2;");
                return create(z);
            }
            return semanticErrorValue("cannot calculate ", op, " on ", this, " and ", v);
        }
    }

    mixin template mixinBinaryOp(string op, Types...)
    {
        Value binOp(Value v)
        {
            TypeInfo ti = typeid(v);
            foreach(iv2; Types)
            {
                if(ti is typeid(iv2))
                {
                    static if (__traits(compiles, {
                        iv2.ValType y;
                        mixin("auto z = (*pval) " ~ op ~ " y;");
                    }))
                    {
                        iv2.ValType v2 = *(cast(iv2) v).pval;
                        static if(op == "/" || op == "%")
                            if(v2 == 0)
                                return semanticErrorValue("division by zero");
                        static if(op == "^^" && isIntegral!(ValType) && isIntegral!(iv2.ValType))
                            if(v2 < 0)
                                return semanticErrorValue("integer pow with negative exponent");

                        mixin("auto z = (*pval) " ~ op ~ " v2;");
                        return create(z);
                    }
                    else
                        break;
                }
            }
            return semanticErrorValue("cannot calculate ", op, " on a ", this, " and a ", v);
        }
    }

    mixin template mixinAssignOp(string op, Types...)
    {
        Value assOp(Value v)
        {
            if(!mutable)
                return semanticErrorValue(this, " value is not mutable");

            TypeInfo ti = typeid(v);
            foreach(iv2; Types)
            {
                if(ti is typeid(iv2))
                {
                    static if (__traits(compiles, {
                        iv2.ValType y;
                        mixin("*pval " ~ op ~ " y;");
                    }))
                    {
                        iv2.ValType v2 = *(cast(iv2) v).pval;
                        static if(op == "/=" || op == "%=")
                            if(v2 == 0)
                                return semanticErrorValue("division by zero");
                        static if(op == "%=" && (is(T == float) || is(T == double) || is(T == real))) // compiler bug
                            mixin("*pval = *pval % v2;");
                        else
                            mixin("*pval " ~ op ~ " v2;");

                        debug logInfo("value %s changed by %s to %s", ident, op, toStr());
                        debug sval = toStr();
                        return this;
                    }
                    else
                        break;
                }
            }
            return semanticErrorValue("cannot assign ", op, " a ", v, " to a ", this);
        }
    }
}

T createInitValue(T)(Context ctx, Value initValue)
{
    T v = new T;
    if(initValue)
        v.opBin(ctx, TOK_assign, initValue);
    return v;
}

alias AliasSeq!(bool, byte, ubyte, short, ushort,
                int, uint, long, ulong,
                char, wchar, dchar,
                float, double, real,
                ifloat, idouble, ireal,
                cfloat, cdouble, creal) BasicTypes;

alias AliasSeq!(BoolValue, ByteValue, UByteValue, ShortValue, UShortValue,
                IntValue, UIntValue, LongValue, ULongValue,
                CharValue, WCharValue, DCharValue,
                FloatValue, DoubleValue, RealValue) BasicTypeValues;
alias AliasSeq!(BasicTypeValues, SetLengthValue) RHS_BasicTypeValues;

alias AliasSeq!(TOK_bool, TOK_byte, TOK_ubyte, TOK_short, TOK_ushort,
                TOK_int, TOK_uint, TOK_long, TOK_ulong,
                TOK_char, TOK_wchar, TOK_dchar,
                TOK_float, TOK_double, TOK_real) BasicTypeTokens;

int BasicType2Token(T)()     { return BasicTypeTokens[staticIndexOf!(T, BasicTypes)]; }

template BasicType2ValueType(T)
{
    alias BasicTypeValues[staticIndexOf!(T, BasicTypes)] BasicType2ValueType;
}

template Token2BasicType(int tok)
{
    alias BasicTypes[staticIndexOf!(tok, BasicTypeTokens)] Token2BasicType;
}

template Token2ValueType(int tok)
{
    alias BasicTypeValues[staticIndexOf!(tok, BasicTypeTokens)] Token2ValueType;
}

class ValueT(T) : Value
{
    alias T ValType;

    ValType* pval;

    this()
    {
        pval = (new ValType[1]).ptr;
        debug sval = toStr();
    }

    static int getTypeIndex() { return staticIndexOf!(ValType, BasicTypes); }

    override Type getType()
    {
        static Type instance;
        if(!instance)
            instance = createBasicType(BasicTypeTokens[getTypeIndex()]);
        return instance;
    }

    override string toStr()
    {
        return to!string(*pval);
    }

    override Value getElement(size_t idx)
    {
        alias BasicTypeValues[getTypeIndex()] ValueType;
        auto v = new ValueType;
        v.pval = pval + idx;
        debug v.sval = v.toStr();
        return v;
    }

    override void setElements(size_t oldcnt, size_t newcnt)
    {
        ValType[] arr = pval[0 .. oldcnt];
        arr.length = newcnt;
        pval = arr.ptr;
        debug sval = toStr();
    }

//    pragma(msg, ValType);
//    pragma(msg, text(" compiles?", __traits(compiles, val ? true : false )));

    // pragma(msg, "toBool " ~ ValType.stringof ~ (__traits(compiles, *pval ? true : false) ? " compiles" : " fails"));
    static if(__traits(compiles, *pval ? true : false))
        override bool toBool()
        {
            return *pval ? true : false;
        }

    // pragma(msg, "toLong " ~ ValType.stringof ~ (__traits(compiles, function long () { ValType v; return v; }) ? " compiles" : " fails"));
    static if(__traits(compiles, function long () { ValType v; return v; } ))
        override long toLong()
        {
            return *pval;
        }

    ////////////////////////////////////////////////////////////
    static string genMixinBinOpAll()
    {
        string s;
        for(int i = TOK_binaryOperatorFirst; i <= TOK_binaryOperatorLast; i++)
        {
            static if(!supportUnorderedCompareOps) if(i >= TOK_unorderedOperatorFirst && i <= TOK_unorderedOperatorLast)
                continue;
            if(i >= TOK_assignOperatorFirst && i <= TOK_assignOperatorLast)
                s ~= text("mixin mixinAssignOp!(\"", tokenString(i), "\", RHS_BasicTypeValues) ass_", operatorName(i), ";\n");
            else
                s ~= text("mixin mixinBinaryOp!(\"", tokenString(i), "\", RHS_BasicTypeValues) bin_", operatorName(i), ";\n");
        }
        return s;
    }

    mixin(genMixinBinOpAll());
    mixin mixinBinaryOp!("is", RHS_BasicTypeValues) bin_is;

    static string genBinOpCases()
    {
        string s;
        for(int i = TOK_binaryOperatorFirst; i <= TOK_binaryOperatorLast; i++)
        {
            static if(!supportUnorderedCompareOps) if(i >= TOK_unorderedOperatorFirst && i <= TOK_unorderedOperatorLast)
                continue;
            if(i >= TOK_assignOperatorFirst && i <= TOK_assignOperatorLast)
                s ~= text("case ", i, ": return ass_", operatorName(i), ".assOp(v);\n");
            else
                s ~= text("case ", i, ": return bin_", operatorName(i), ".binOp(v);\n");
        }
        return s;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            mixin(genBinOpCases());
            case TOK_is: return bin_is.binOp(v);
            default: break;
        }

        return semanticErrorValue("cannot calculate '", tokenString(tokid), "' on a ", this, " and a ", v);
    }

    ////////////////////////////////////////////////////////////
    mixin template mixinUnaryOp(string op)
    {
        Value unOp()
        {
            static if (__traits(compiles, { mixin("auto z = " ~ op ~ "(*pval);"); }))
            {
                mixin("auto z = " ~ op ~ "(*pval);");
                return create(z);
            }
            else
            {
                return semanticErrorValue("cannot calculate '", op, "' on a ", this);
            }
        }
    }

    enum int[] unOps = [ TOK_plusplus, TOK_minusminus, TOK_min, TOK_add, TOK_not, TOK_tilde ];

    static string genMixinUnOpAll()
    {
        string s;
        foreach(id; unOps)
            s ~= text("mixin mixinUnaryOp!(\"", tokenString(id), "\") un_", operatorName(id), ";\n");
        return s;
    }

    mixin(genMixinUnOpAll());

    static string genUnOpCases()
    {
        string s;
        foreach(id; unOps)
            s ~= text("case ", id, ": return un_", operatorName(id), ".unOp();\n");
        return s;
    }

    override Value opUn(Context ctx, int tokid)
    {
        switch(tokid)
        {
            case TOK_and:        return opRefPointer();
            case TOK_mul:        return opDerefPointer();
            mixin(genUnOpCases());
            default: break;
        }
        return semanticErrorValue("cannot calculate '", tokenString(tokid), "' on a ", this);
    }

    override Value doCast(Value v)
    {
        if(!mutable) // doCast changes this value
            return semanticErrorValue(this, " value is not mutable");

        TypeInfo ti = typeid(v);
        foreach(iv2; RHS_BasicTypeValues)
        {
            if(ti is typeid(iv2))
            {
                static if (__traits(compiles, {
                    iv2.ValType y;
                    *pval = cast(ValType)(y);
                }))
                {
                    iv2.ValType v2 = *(cast(iv2) v).pval;
                    *pval = cast(ValType)(v2);

                    debug logInfo("value %s changed by cast(" ~ ValType.stringof ~ ") to %s", ident, toStr());
                    debug sval = toStr();
                    return this;
                }
                else
                    break;
            }
        }
        return super.doCast(v);
    }
}

class VoidValue : Value
{
    override string toStr()
    {
        return "void";
    }
}

VoidValue _theVoidValue;

@property VoidValue theVoidValue()
{
    if(!_theVoidValue)
    {
        _theVoidValue = new VoidValue;
        _theVoidValue.mutable = false;
    }
    return _theVoidValue;
}

class ErrorValue : Value
{
    override string toStr()
    {
        return "_error_";
    }

    override Type getType()
    {
        return Singleton!ErrorType.get();
    }
}

class NullValue : Value
{
    override string toStr()
    {
        return "null";
    }

    override Type getType()
    {
        return Singleton!NullType.get();
    }
}

class BoolValue : ValueT!bool
{
}

class ByteValue : ValueT!byte
{
}

class UByteValue : ValueT!ubyte
{
}

class ShortValue : ValueT!short
{
}

class UShortValue : ValueT!ushort
{
}

class IntValue : ValueT!int
{
}

class UIntValue : ValueT!uint
{
}

class LongValue : ValueT!long
{
}

class ULongValue : ValueT!ulong
{
}

class CharValue : ValueT!char
{
    override string toStr()
    {
        return "'" ~ toUTF8Safe(pval[0..1]) ~ "'";
    }
}

class WCharValue : ValueT!wchar
{
    override string toStr()
    {
        return "'" ~ toUTF8Safe(pval[0..1]) ~ "'w";
    }
}

class DCharValue : ValueT!dchar
{
    override string toStr()
    {
        return "'" ~ toUTF8Safe(pval[0..1]) ~ "'d";
    }
}

class FloatValue : ValueT!float
{
}

class DoubleValue : ValueT!double
{
}

class RealValue : ValueT!real
{
}

class ArrayValueBase : Value
{
    Value first;
    size_t len;

    override string toStr()
    {
        string s = "[";
        for(size_t i = 0; i < len; i++)
        {
            if(i > 0)
                s ~= ",";
            Value v = first.getElement(i);
            s ~= v.toStr();
        }
        s ~= "]";
        return s;
    }

    override Value opIndex(Value v)
    {
        int idx = v.toInt();
        if(idx < 0 || idx >= len)
            return semanticErrorValue("index ", idx, " out of bounds on value tuple");
        return first.getElement(idx);
    }

    void setItem(Context ctx, size_t idx, Value v)
    {
        if(idx < 0 || idx >= len)
            return semanticError("index ", idx, " out of bounds on dynamic array");
        first.getElement(idx).opBin(ctx, TOK_assign, v);
    }

    ArrayValueBase createResultArray(Context ctx, Value fv, size_t nlen)
    {
        auto dim = new IntegerLiteralExpression();
        dim.txt = to!string(nlen);
        dim.value = nlen;
        auto ntype = new TypeStaticArray;
        ntype.addMember(fv.getType().clone());
        ntype.addMember(dim);

        auto narr = static_cast!ArrayValueBase(ntype.createValue(ctx, null));
        narr.first.getElement(0).opBin(ctx, TOK_assign, fv);
        return narr;
    }

    private Value getItem(size_t idx)
    {
        return first.getElement(idx);
    }

    static Value _opBin(Context ctx, int tokid, Value v1, Value v2, bool reverse)
    {
        if(reverse)
            return v2.opBin(ctx, tokid, v1);
        return v1.opBin(ctx, tokid, v2);
    }

    Value _opBin(Context ctx, int tokid, Value v, bool reverse)
    {
        switch(tokid)
        {
            case TOK_equal:
            case TOK_lt:
            case TOK_le:
            case TOK_gt:
            case TOK_ge:
        static if(supportUnorderedCompareOps) {
            case TOK_unord:
            case TOK_ue:
            case TOK_lg:
            case TOK_leg:
            case TOK_ule:
            case TOK_ul:
            case TOK_uge:
            case TOK_ug:
        }
            //case TOK_notcontains:
            //case TOK_notidentity:
            //case TOK_is:
            //case TOK_in:
                if(auto tv = cast(ArrayValueBase) v)
                {
                    if(tv.len != len)
                        return Value.create(false);
                    for(int i = 0; i < len; i++)
                        if(!_opBin(ctx, tokid, first.getElement(i), tv.first.getElement(i), reverse).toBool())
                            return Value.create(false);
                    return Value.create(true);
                }
                for(int i = 0; i < len; i++)
                    if(!_opBin(ctx, tokid, first.getElement(i), v, reverse).toBool())
                        return Value.create(false);
                return Value.create(true);

            case TOK_notequal:
                return Value.create(!opBin(ctx, TOK_equal, v).toBool());

            case TOK_add:
            case TOK_min:
            case TOK_mul:
            case TOK_div:
            case TOK_mod:
            case TOK_pow:
            case TOK_shl:
            case TOK_shr:
            case TOK_ushr:
            case TOK_xor:
            case TOK_or:
            case TOK_and:
            //case TOK_cat:
                if(auto tv = cast(ArrayValueBase) v)
                {
                    if(tv.len != len)
                        return semanticErrorValue(tokenString(tokid), " on arrays of different length ", len, " and ", tv.len);

                    if(len == 0)
                        return getType().createValue(ctx, null);

                    Value fv = _opBin(ctx, tokid, first.getElement(0), tv.first.getElement(0), reverse);
                    auto narr = createResultArray(ctx, fv, len);
                    for(int i = 1; i < len; i++)
                    {
                        fv = _opBin(ctx, tokid, first.getElement(i), tv.first.getElement(i), reverse);
                        narr.first.getElement(i).opBin(ctx, TOK_assign, fv);
                    }
                    debug narr.sval = narr.toStr();
                    return narr;
                }

                if(len == 0)
                    return getType().createValue(ctx, null);

                Value fv = _opBin(ctx, tokid, first.getElement(0), v, reverse);
                auto narr = createResultArray(ctx, fv, len);
                for(int i = 1; i < len; i++)
                {
                    fv = _opBin(ctx, tokid, first.getElement(i), v, reverse);
                    narr.first.getElement(i).opBin(ctx, TOK_assign, fv);
                }
                debug narr.sval = narr.toStr();
                return narr;

            default:
                if(reverse)
                    return super.opBin_r(ctx, tokid, v);
                return super.opBin(ctx, tokid, v);
        }
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_addass:
            case TOK_minass:
            case TOK_mulass:
            case TOK_divass:
            case TOK_modass:
            case TOK_powass:
            case TOK_shlass:
            case TOK_shrass:
            case TOK_ushrass:
            case TOK_xorass:
            case TOK_orass:
            case TOK_andass:
            //case TOK_catass:
                if(auto tv = cast(ArrayValueBase) v)
                {
                    if(tv.len != len)
                        return semanticErrorValue(tokenString(tokid), " on arrays of different length ", len, " and ", tv.len);
                    for(int i = 0; i < len; i++)
                        first.getElement(i).opBin(ctx, tokid, tv.first.getElement(i));
                }
                else
                {
                    for(int i = 0; i < len; i++)
                        first.getElement(i).opBin(ctx, tokid, v);
                }
                debug sval = toStr();
                return this;

            default:
                return _opBin(ctx, tokid, v, false);
        }
    }

    override Value opBin_r(Context ctx, int tokid, Value v)
    {
        return _opBin(ctx, tokid, v, true);
    }

    override Value opUn(Context ctx, int tokid)
    {
        switch(tokid)
        {
            case TOK_add:
            case TOK_min:
            case TOK_not:
            case TOK_tilde:
                if(len == 0)
                    return getType().createValue(ctx, null);

                Value fv = first.getElement(0).opUn(ctx, tokid);
                auto narr = createResultArray(ctx, fv, len);
                for(int i = 1; i < len; i++)
                {
                    fv = first.getElement(i).opUn(ctx, tokid);
                    narr.first.getElement(i).opBin(ctx, TOK_assign, fv);
                }
                return narr;
            default:
                return super.opUn(ctx, tokid);
        }
    }
}

class ArrayValue(T) : ArrayValueBase
{
    T type;

    void setLength(Context ctx, size_t newlen)
    {
        if(newlen > len)
        {
            if(len == 0)
            {
                first = type.getNextType().createValue(ctx, null);
                first.setElements(1, newlen);
            }
            else
                first.setElements(len, newlen);
        }
        len = newlen;
        // intermediate state, cannot set sval yet
    }

    override Value opSlice(Value b, Value e)
    {
        int idxb = b.toInt();
        int idxe = e.toInt();
        if(idxb < 0 || idxb > len || idxe < idxb || idxe > len)
            return semanticErrorValue("slice [", idxb, "..", idxe, "] out of bounds on value ", toStr());
        auto nv = type.opSlice(idxb, idxe).createValue(nullContext, null);
        if(auto arr = cast(ArrayValueBase) nv)
        {
            if(idxb == 0)
                arr.first = first;
            else
                arr.first = first.getElement(idxb);
            arr.len = idxe - idxb;
        }
        debug nv.sval = nv.toStr();
        return nv;
    }

}

class DynArrayValue : ArrayValue!TypeDynamicArray
{
    this(TypeDynamicArray t)
    {
        type = t;
        debug sval = toStr();
    }

    override string toStr()
    {
        if(isString())
            return "\"" ~ toMixin() ~ "\"";

        return super.toStr();
    }

    override Type getType()
    {
        return type;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_assign:
                if(auto tv = cast(ArrayValueBase) v)
                {
                    if(tv.len == 0)
                        first = null;
                    else
                        first = tv.first.getElement(0); // create copy of "ptr" value
                    len = tv.len;
                }
                else if(cast(NullValue) v)
                {
                    first = null;
                    len = 0;
                }
                else
                    return semanticErrorValue("cannot assign ", v, " to ", this);
                debug sval = toStr();
                return this;

            case TOK_tilde:
                if(auto ev = cast(ErrorValue) v)
                    return v;
                auto nv = new DynArrayValue(type);
                if(auto tv = cast(DynArrayValue) v)
                {
                    nv.setLength(ctx, len + tv.len);
                    for(size_t i = 0; i < len; i++)
                        nv.setItem(ctx, i, getItem(i));
                    for(size_t i = 0; i < tv.len; i++)
                        nv.setItem(ctx, len + i, tv.getItem(i));
                }
                else
                {
                    nv.setLength(ctx, len + 1);
                    for(size_t i = 0; i < len; i++)
                        nv.setItem(ctx, i, getItem(i));
                    nv.setItem(ctx, len, v);
                }
                debug nv.sval = nv.toStr();
                return nv;

            case TOK_catass:
                size_t oldlen = len;
                if(auto ev = cast(ErrorValue) v)
                    return v;
                if(auto tv = cast(DynArrayValue) v)
                {
                    setLength(ctx, len + tv.len);
                    for(size_t i = 0; i < tv.len; i++)
                        setItem(ctx, oldlen + i, tv.getItem(i));
                }
                else
                {
                    setLength(ctx, len + 1);
                    setItem(ctx, oldlen, v);
                }
                debug sval = toStr();
                return this;

            default:
                return super.opBin(ctx, tokid, v);
        }
    }

    bool isString()
    {
        auto t = type.getNextType().unqualified();

        if(auto bt = cast(BasicType) t)
            if(bt.id == TOK_char || bt.id == TOK_wchar || bt.id == TOK_dchar)
                return true;
        return false;
    }

    override PointerValue toPointer(TypePointer to)
    {
        // TODO: implementation here just to satisfy string -> C const char* conversion
        if(isString())
        {
            Value nfirst = first;
            auto nt = type.getNextType();
            auto nto = to.getNextType();
            if(literal)
            {
                // automatic conversion between string,wstring,dstring
                auto uto = nto.unqualified();
                auto ut = nt.unqualified();
                if(auto bt = cast(BasicType) ut)
                    if(auto bto = cast(BasicType) uto)
                    {
                        if(bt.id != bto.id)
                        {
                            semanticErrorValue("literal string conversion not implemented!");

                            DynArrayValue nv;
                            switch(bto.id)
                            {
                                case TOK_char:
                                    string s;
                                    switch(bt.id)
                                    {
                                        case TOK_wchar:
                                        case TOK_dchar:
                                        default:
                                            break;
                                    }
                                    nv = createStringValue(s);
                                    break;
                                case TOK_wchar:
                                    wstring s;
                                    switch(bt.id)
                                    {
                                        case TOK_char:
                                        case TOK_dchar:
                                        default:
                                            break;
                                    }
                                    nv = createStringValue(s);
                                    break;
                                case TOK_dchar:
                                    dstring s;
                                    switch(bt.id)
                                    {
                                        case TOK_char:
                                        case TOK_wchar:
                                        default:
                                            break;
                                    }
                                    nv = createStringValue(s);
                                    break;
                                default:
                                    assert(0);
                            }
                            nfirst = nv.first;
                        }
                    }
            }
            PointerValue pv = new PointerValue;
            auto tp = new TypePointer;
            tp.setNextType(nto);
            pv.type = tp;
            pv.pval = nfirst;
            debug pv.sval = pv.toStr();
            return pv;
        }
        return super.toPointer(to);
    }

    override string toMixin()
    {
        if(isString())
        {
            if(len == 0)
                return "";
            if(auto cv = cast(CharValue)first)
                return toUTF8Safe(cv.pval[0..len]);
            if(auto wv = cast(WCharValue)first)
                return toUTF8Safe(wv.pval[0..len]);
            if(auto dv = cast(DCharValue)first)
                return toUTF8Safe(dv.pval[0..len]);
        }
        return super.toMixin();
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        switch(prop)
        {
            case "length":
                return new SetLengthValue(this);
            default:
                return super._interpretProperty(ctx, prop);
        }
    }
}

class SetLengthValue : UIntValue
{
    DynArrayValue array;

    this(DynArrayValue a)
    {
        array = a;
        super();
        debug sval = toStr();
    }

    override string toStr()
    {
        return array.toStr() ~ ".length";
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_assign:
                int len = v.toInt();
                array.setLength(ctx, len);
                debug array.sval = array.toStr();
                return this;
            default:
                return super.opBin(ctx, tokid, v);
        }
    }

}

DynArrayValue createStringValue(C)(immutable(C)[] s)
{
    DynArrayValue dav = new DynArrayValue(getTypeString!C());
    auto cv = new BasicType2ValueType!C;
    cv.mutable = false;
    cv.pval = cast(C*) s.ptr;
    debug cv.sval = cv.toStr();
    dav.first = cv;
    dav.len = s.length;
    dav.literal = true;
    debug dav.sval = dav.toStr();
    return dav;
}

class StaticArrayValue : ArrayValue!TypeStaticArray
{
    this(TypeStaticArray t)
    {
        type = t;
        debug sval = toStr();
    }

    override Type getType()
    {
        return type;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_assign:
                if(auto tv = cast(ArrayValueBase) v)
                {
                    if(tv.len != len)
                        return semanticErrorValue("different length in assignment from ", v, " to ", this);

                    IntValue idxval = new IntValue;
                    for(int i = 0; i < len; i++)
                    {
                        *(idxval.pval) = i;
                        Value vidx = v.opIndex(idxval);
                        auto idx = opIndex(idxval);
                        idx.opBin(ctx, TOK_assign, vidx);
                    }
                }
                else
                    return semanticErrorValue("cannot assign ", v, " to ", this);
                debug sval = toStr();
                return this;

            default:
                return super.opBin(ctx, tokid, v);
        }
    }

}

alias AliasSeq!(CharValue, WCharValue, DCharValue, StringValue) StringTypeValues;

class StringValue : Value
{
    alias string ValType;

    ValType* pval;

    this()
    {
        pval = (new string[1]).ptr;
        debug sval = toStr();
    }

    this(string s)
    {
        pval = (new string[1]).ptr;
        *pval = s;
        debug sval = toStr();
    }

    static StringValue _create(string s)
    {
        StringValue sv = new StringValue(s);
        return sv;
    }

    override Type getType()
    {
        return getTypeString!char();
    }

    override string toStr()
    {
        return '"' ~ *pval ~ '"';
    }

    override string toMixin()
    {
        return *pval;
    }

    override PointerValue toPointer(TypePointer to)
    {
        // TODO: implementation here just to satisfy string -> C const char* conversion
        PointerValue pv = new PointerValue;
        pv.type = new TypePointer;
        pv.type.addMember(createBasicType(TOK_char));
        pv.pval = this;
        debug pv.sval = pv.toStr();
        return pv;
    }

    override bool toBool()
    {
        return *pval !is null;
    }

    mixin mixinAssignOp!("=",  StringTypeValues) ass_assign;
    mixin mixinAssignOp!("~=", StringTypeValues) ass_catass;
    mixin mixinBinaryOp!("~",  StringTypeValues) bin_tilde;
    mixin mixinBinaryOp1!("<",  StringValue) bin_lt;
    mixin mixinBinaryOp1!(">",  StringValue) bin_gt;
    mixin mixinBinaryOp1!("<=", StringValue) bin_le;
    mixin mixinBinaryOp1!(">=", StringValue) bin_ge;
    mixin mixinBinaryOp1!("==", StringValue) bin_equal;
    mixin mixinBinaryOp1!("!=", StringValue) bin_notequal;

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_assign:
                auto rv = ass_assign.assOp(v);
                debug sval = toStr();
                return rv;
            case TOK_catass:
                auto rv = ass_catass.assOp(v);
                debug sval = toStr();
                return rv;
            case TOK_tilde:    return bin_tilde.binOp(v);
            case TOK_lt:       return bin_lt.binOp1(v);
            case TOK_gt:       return bin_gt.binOp1(v);
            case TOK_le:       return bin_le.binOp1(v);
            case TOK_ge:       return bin_ge.binOp1(v);
            case TOK_equal:    return bin_equal.binOp1(v);
            case TOK_notequal: return bin_notequal.binOp1(v);
            default:           return super.opBin(ctx, tokid, v);
        }
    }

    override Value opIndex(Value v)
    {
        int idx = v.toInt();
        if(idx < 0 || idx >= (*pval).length)
            return semanticErrorValue("index ", idx, " out of bounds on ", *pval);
        return create((*pval)[idx]);
    }
}

class PointerValue : Value
{
    TypePointer type;  // type of pointer
    Value pval; // Value is a class type, so its a reference, i.e. a pointer to the value

    override string toStr()
    {
        return pval ? "&" ~ pval.toStr() : "null";
    }

    static PointerValue _create(TypePointer type, Value v)
    {
        PointerValue pv = new PointerValue;
        pv.type = type;
        pv.pval = v;
        debug pv.sval = pv.toStr();
        return pv;
    }

    override Type getType()
    {
        return type;
    }

    override bool toBool()
    {
        return pval !is null;
    }

    override PointerValue toPointer(TypePointer to)
    {
        return this;
    }

    override Value opDerefPointer()
    {
        if(!pval)
            return semanticErrorValue("dereferencing a null pointer");
        return pval;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_assign:
                auto pv = v.toPointer(type);
                if(!v)
                    pval = null;
                else if(!pv)
                    return semanticErrorValue("cannot convert value ", v, " to pointer of type ", type);
                else if(type.convertableFromImplicite(pv.type))
                    pval = pv.pval;
                else
                    return semanticErrorValue("cannot convert pointer type ", pv.type, " to ", type);
                debug sval = toStr();
                return this;
            case TOK_equal:
            case TOK_notequal:
                auto pv = cast(PointerValue)v;
                if(!pv || (!pv.type.convertableFromImplicite(type) && !type.convertableFromImplicite(pv.type)))
                    return semanticErrorValue("cannot compare types ", v.getType(), " and ", type);
                if(tokid == TOK_equal)
                    return Value.create(pv.pval is pval);
                else
                    return Value.create(pv.pval !is pval);
            default:
                return super.opBin(ctx, tokid, v);
        }
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        switch(prop)
        {
            case "init":
                return _create(type, null);
            default:
                if(!pval)
                    return semanticErrorValue("dereferencing null pointer");
                return pval._interpretProperty(ctx, prop);
        }
    }
}

class TypeValue : Value
{
    Type type;

    this(Type t)
    {
        type = t;
        debug sval = toStr();
    }

    override Type getType()
    {
        return type;
    }

    override string toStr()
    {
        return writeD(type);
    }

    override Value opCall(Context sc, Value vargs)
    {
        return type.createValue(sc, vargs);
    }
}

class AliasValue : Value
{
    IdentifierList id;

    this(IdentifierList _id)
    {
        id = _id;
        debug sval = toStr();
    }

    Node resolve()
    {
        return id.resolve();
    }

    override Type getType()
    {
        return id.calcType();
    }

    override string toStr()
    {
        return writeD(id);
    }
}

class TupleValue : Value
{
private:
    Value[] _values;
public:
    this()
    {
        debug sval = toStr();
    }

    @property Value[] values()
    {
        return _values;
    }
    @property void values(Value[] v)
    {
        _values = v;
        debug sval = toStr();
    }
    void addValue(Value v)
    {
        _values ~= v;
        debug sval = toStr();
    }
    void setValuesLength(size_t len)
    {
        _values.length = len;
    }

    override string toStr()
    {
        return _toStr("(", ")");
    }

    string _toStr(string open, string close)
    {
        string s = open;
        foreach(i, v; values)
        {
            if(i > 0)
                s ~= ",";
            s ~= v.toStr();
        }
        s ~= close;
        return s;
    }

    override Value opIndex(Value v)
    {
        int idx = v.toInt();
        if(idx < 0 || idx >= values.length)
            return semanticErrorValue("index ", idx, " out of bounds on value tuple");
        return values[idx];
    }

    override Value opSlice(Value b, Value e)
    {
        int idxb = b.toInt();
        int idxe = e.toInt();
        if(idxb < 0 || idxb > values.length || idxe < idxb || idxe > values.length)
            return semanticErrorValue("slice [", idxb, "..", idxe, "] out of bounds on value tuple");
        auto nv = new TupleValue;
        nv._values = _values[idxb..idxe];
        return nv;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_equal:
                if(auto tv = cast(TupleValue) v)
                {
                    if(tv.values.length != values.length)
                        return Value.create(false);
                    for(int i = 0; i < values.length; i++)
                        if(!values[i].opBin(ctx, TOK_equal, tv.values[i]).toBool())
                            return Value.create(false);
                    return Value.create(true);
                }
                return semanticErrorValue("cannot compare ", v, " to ", this);
            case TOK_notequal:
                return Value.create(!opBin(ctx, TOK_equal, v).toBool());

            case TOK_assign:
                if(auto tv = cast(TupleValue) v)
                    values = tv.values;
                else
                    return semanticErrorValue("cannot assign ", v, " to ", this);
                debug sval = toStr();
                return this;

            case TOK_tilde:
                auto nv = new TupleValue;
                if(auto tv = cast(TupleValue) v)
                    nv._values = _values ~ tv._values;
                else
                    nv._values = _values ~ v;
                return nv;

            case TOK_catass:
                if(auto tv = cast(TupleValue) v)
                    _values ~= tv._values;
                else
                    _values ~= v;
                return this;

            default:
                return super.opBin(ctx, tokid, v);
        }
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        switch(prop)
        {
            case "length":
                return create(values.length);
            default:
                return super._interpretProperty(ctx, prop);
        }
    }
}

Value doCall(CallableNode funcNode, Context sc, ParameterList params, Value vargs)
{
    if(!funcNode)
        return semanticErrorValue("calling null reference");

    auto ctx = new Context(sc);

    auto args = static_cast!TupleValue(vargs);
    auto numparams = params.members.length;
    auto numargs = args ? args.values.length : 0;
    if(params.anonymous_varargs)
    {
        if(numargs < numparams)
            return semanticErrorValue("too few arguments");
        // TODO: add _arguments and _argptr variables
    }
    else if(params.varargs)
    {
        if(numargs < numparams - 1)
            return semanticErrorValue("too few arguments");
        numparams--;
    }
    else if(numargs != numparams)
        return semanticErrorValue("incorrect number of arguments");

    for(size_t p = 0; p < numparams; p++)
    {
        if(auto decl = params.getParameter(p).getParameterDeclarator().getDeclarator())
        {
            Value v = args.values[p];
            Type t = v.getType();
            if(!decl.isRef)
                v = decl.calcType().createValue(sc, v); // if not ref, always create copy
            else if(!t.compare(decl.calcType()))
                return semanticErrorValue("cannot create reference of incompatible type", v.getType());
            ctx.setValue(decl, v);
        }
    }
    if(params.varargs)
    {
        // TODO: pack remaining arguments into array
        auto decl = params.getParameter(numparams).getParameterDeclarator();
        auto vdecl = decl.getDeclarator();
        if(!vdecl)
            return semanticErrorValue("cannot pack remaining arguments into parameter", decl);
        Value arr = vdecl.calcType().createValue(ctx, null);
        if(auto darr = cast(DynArrayValue) arr)
        {
            darr.setLength(ctx, args.values.length - numparams);
            for(size_t n = numparams; n < args.values.length; n++)
            {
                Value v = args.values[n];
                Type t = v.getType();
                v = t.createValue(sc, v); // if not ref, always create copy
                darr.setItem(ctx, n - numparams, v);
            }
            debug darr.sval = darr.toStr();
            ctx.setValue(vdecl, darr);
        }
        else
            return semanticErrorValue("array type expected for variable argument parameter");
    }
    Value retVal = funcNode.interpretCall(ctx);
    return retVal ? retVal : theVoidValue;
}

class FunctionValue : Value
{
    TypeFunction functype;
    bool adr;

    override string toStr()
    {
        if(!functype.funcDecl)
            return "null";
        if(!functype.funcDecl.ident)
            return "_funcliteral_";
        return "&" ~ functype.funcDecl.ident;
    }

    override Value opCall(Context sc, Value vargs)
    {
        return doCall(functype.funcDecl, threadContext, functype.getParameters(), vargs);
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        FunctionValue dg = cast(FunctionValue) v;
        if(!dg)
            return semanticErrorValue("cannot assign ", v, " to function");
        //! TODO: verify compatibility of types
        switch(tokid)
        {
            case TOK_assign:
                functype = dg.functype;
                debug sval = toStr();
                return this;
            case TOK_equal:
                return Value.create(functype.compare(dg.functype));
            case TOK_notequal:
                return Value.create(!functype.compare(dg.functype));
            default:
                return super.opBin(ctx, tokid, v);
        }
    }

    override Type getType()
    {
        return functype;
    }

    override Value opRefPointer()
    {
        adr = true;
        return this;
    }
}

class DelegateValue : FunctionValue
{
    Context context;

    override Value opCall(Context sc, Value vargs)
    {
        return doCall(functype.funcDecl, context, functype.getParameters(), vargs);
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        DelegateValue dg = cast(DelegateValue) v;
        if(!dg)
            return semanticErrorValue("cannot assign ", v, " to delegate");
        //! TODO: verify compatibility of types
        switch(tokid)
        {
            case TOK_assign:
                context = dg.context;
                functype = dg.functype;
                debug sval = toStr();
                return this;
            case TOK_equal:
                return Value.create((context is dg.context) && functype.compare(dg.functype));
            case TOK_notequal:
                return Value.create((context !is dg.context) || !functype.compare(dg.functype));
            default:
                return super.opBin(ctx, tokid, v);
        }
    }
}

class AggrValue : TupleValue
{
    Context outer;
    AggrContext context;

    abstract override Aggregate getType();

    override string toStr()
    {
        if(auto t = getType())
            return t.ident ~ _toStr("{", "}");
        return "<notype>" ~ _toStr("{", "}");
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        auto type = getType();
        if(Value v = type.getProperty(this, prop, true))
            return v;
        if(Value v = type.getStaticProperty(prop))
            return v;
        if(!context)
            context = new AggrContext(outer, this);
        if(Value v = super._interpretProperty(context, prop))
            return v;

        //if(outer) // TODO: outer checked after super?
        //    if(Value v = outer._interpretProperty(ctx, prop))
        //        return v;
        //
        return null;
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        switch(tokid)
        {
            case TOK_equal:
                if(Value fv = getType().getProperty(this, "opEquals", true))
                {
                    auto tctx = new AggrContext(ctx, this);
                    auto tv = new TupleValue;
                    tv.addValue(v);
                    return fv.opCall(tctx, tv);
                }
                return super.opBin(ctx, tokid, v);
            case TOK_is:
                return Value.create(v is this);
            case TOK_notidentity:
                return Value.create(v !is this);
            default:
                return super.opBin(ctx, tokid, v);
        }
    }
}

class AggrValueT(T) : AggrValue
{
    T type;

    this(T t)
    {
        type = t;
        debug sval = toStr();
    }

    override Aggregate getType()
    {
        return type;
    }
}

class StructValue : AggrValueT!Struct
{
    this(Struct t)
    {
        super(t);
    }
}

class UnionValue : AggrValueT!Union
{
    this(Union t)
    {
        super(t);
    }
}

class ClassInstanceValue : AggrValueT!Class
{
    this(Class t)
    {
        super(t);
    }
}

class ReferenceValue : Value
{
    ClassInstanceValue instance;
    bool insideToStr;

    override string toStr()
    {
        if(!instance)
            return "null";
        if(insideToStr)
            return "recursive-toStr";
        insideToStr = true;
        scope(exit) insideToStr = false;
        return instance.toStr();
    }

    override Value opBin(Context ctx, int tokid, Value v)
    {
        ClassInstanceValue other;
        if(auto cv = cast(ReferenceValue) v)
            other = cv.instance;
        else if(!cast(NullValue) v)
            return super.opBin(ctx, tokid, v);

        switch(tokid)
        {
            case TOK_assign:
                instance = other;
                debug sval = toStr();
                return this;
            case TOK_equal:
                if(instance is other)
                    return Value.create(true);
                if(!instance || !other)
                    return Value.create(false);
                return instance.opBin(ctx, TOK_equal, other);
            case TOK_is:
                return Value.create(instance is other);
            case TOK_notidentity:
                return Value.create(instance !is other);
            default:
                return super.opBin(ctx, tokid, v);
        }
    }

}

class ReferenceValueT(T) : ReferenceValue
{
    T type;

    this(T t)
    {
        type = t;
    }

    override T getType()
    {
        return type;
    }

    override Value _interpretProperty(Context ctx, string prop)
    {
        if(instance)
            if(Value v = instance._interpretProperty(ctx, prop))
                return v;
        if(Value v = type.getStaticProperty(prop))
            return v;
        return super._interpretProperty(ctx, prop);
    }

    override Value doCast(Value v)
    {
        if(cast(NullValue) v)
        {
            instance = null;
            return this;
        }
        if(auto cv = cast(ReferenceValue) v)
        {
            if(type.convertableFrom(cv.getType(), Type.ConversionFlags.kImpliciteConversion))
                instance = cv.instance;
            else
                instance = null;
            return this;
        }
        return super.doCast(v);
    }
}

class ClassValue : ReferenceValueT!Class
{
    this(Class t, ClassInstanceValue inst = null)
    {
        super(t);
        instance = inst;
        validate();
    }
}

class InterfaceValue : ReferenceValueT!Intrface
{
    this(Intrface t)
    {
        super(t);
        validate();
    }
}

class AnonymousClassInstanceValue : AggrValueT!AnonymousClass
{
    this(AnonymousClass t)
    {
        super(t);
        validate();
    }
}

class AnonymousClassValue : ReferenceValueT!AnonymousClass
{
    this(AnonymousClass t)
    {
        super(t);
        validate();
    }
}

////////////////////////////////////////////////////////////////////////
// program control
class ProgramControlValue : Value
{
    string label;
}

class BreakValue : ProgramControlValue
{
    this(string s)
    {
        label = s;
    }
}

class ContinueValue : ProgramControlValue
{
    this(string s)
    {
        label = s;
    }
}

class GotoValue : ProgramControlValue
{
    this(string s)
    {
        label = s;
    }
}

class GotoCaseValue : ProgramControlValue
{
    this(string s)
    {
        label = s;
    }
}
