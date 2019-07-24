/**
 * D header file for interaction with C++ std::optional.
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/optional.d)
 */

module core.stdcpp.optional;

import core.stdcpp.exception : exception;

version (CppRuntime_DigitalMars)
{
    pragma(msg, "std::optional not supported by DMC");
}
version (CppRuntime_Clang)
{
    private alias AliasSeq(Args...) = Args;
    private enum StdNamespace = AliasSeq!("std", "__1");
}
else
{
    private enum StdNamespace = "std";
}


extern(C++, "std")
{
    ///
    class bad_optional_access : exception
    {
    @nogc:
        ///
        this(const(char)* message = "bad exception") nothrow { super(message); }
    }
}


extern(C++, (StdNamespace)):

///
struct nullopt_t {}

///
enum nullopt_t nullopt = nullopt_t();

///
struct in_place_t {}

///
enum in_place_t in_place = in_place_t();

/**
 * D language counterpart to C++ std::optional.
 *
 * C++ reference: $(LINK2 https://en.cppreference.com/w/cpp/utility/optional)
 */
extern(C++, class) struct optional(T)
{
    static assert(!is(Unqual!T == nullopt_t), "T in optional!T cannot be nullopt_t (N4659 23.6.2 [optional.syn]/1).");
    static assert(!is(Unqual!T == in_place_t), "T in optional!T cannot be in_place_t (N4659 23.6.2 [optional.syn]/1).");
    static assert(!__traits(hasMember, T, "__xpostblit"), "T in optional!T may not have a postblit `this(this)` constructor. Use copy constructor instead.");
//    static assert(is_reference_v<_Ty> || is_object_v<_Ty>, "T in optional!T must be an object type (N4659 23.6.3 [optional.optional]/3).");
//    static assert(is_destructible_v<_Ty> && !is_array_v<_Ty>, "T in optional!T must satisfy the requirements of Destructible (N4659 23.6.3 [optional.optional]/3).");

    import core.internal.traits : AliasSeq, Unqual, hasElaborateDestructor, hasElaborateCopyConstructor, hasElaborateDestructor;
    import core.lifetime : forward, moveEmplace, core_emplace = emplace;

extern(D):
pragma(inline, true):

    ///
    this(nullopt_t) pure nothrow @nogc @safe
    {
    }

    ///
    this(Args...)(in_place_t, auto ref Args args)
    {
        static if (Args.length == 1 && is(Unqual!(Args[0]) == T))
            moveEmplace(args[0], _value);
        else
            core_emplace(&_value, forward!args);
        _engaged = true;
    }

    static if (hasElaborateCopyConstructor!T)
    {
        ///
        this(ref return scope inout(optional) rhs) inout
        {
            _engaged = rhs._engaged;
            if (rhs._engaged)
                core_emplace(cast(T*)&_value, rhs._value);
        }
    }

    static if (hasElaborateDestructor!T)
    {
        ///
        ~this()
        {
            if (_engaged)
                destroy!false(_value);
        }
    }

    ///
    void opAssign(nullopt_t)
    {
        reset();
    }

    ///
    void opAssign()(auto ref optional!T rhs)
    {
        if (rhs._engaged)
            opAssign(forward!rhs._value);
        else
            reset();
    }

    ///
    void opAssign()(auto ref T rhs)
    {
        if (_engaged)
            _value = forward!rhs;
        else
        {
            core_emplace(&_value, forward!rhs);
            _engaged = true;
        }
    }

    ///
    bool opCast(T : bool)() const pure nothrow @nogc @safe
    {
        return has_value();
    }

    ///
    void reset()
    {
        static if (hasElaborateDestructor!T)
        {
            if (_engaged)
            {
                destroy!false(_value);
                _engaged = false;
            }
        }
        else
            _engaged = false;
    }

    ///
    ref T emplace(Args...)(auto ref Args args)
    {
        reset();
        core_emplace(&_value, forward!args);
        _engaged = true;
        return _value;
    }

    ///
    bool has_value() const pure nothrow @nogc @safe
    {
        return _engaged;
    }

    // TODO: return by-val (move _value) if `this` is an rvalue... (auto ref return?)
    ///
    ref inout(T) value() inout return pure @trusted // @nogc //(DIP1008)
        in (_engaged == true)
    {
        // TODO: support C++ exceptions?
//        if (!_engaged)
//            throw new bad_optional_access();
        return _value;
    }

    // TODO: return by-val (move _value) if `this` is an rvalue... (auto ref return?)
    ///
    ref inout(T) value_or(scope return ref inout(T) or) inout return pure nothrow @nogc @trusted
    {
        return _engaged ? _value : or;
    }

private:
    // amazingly, MSVC, Clang and GCC all share the same struct!
    union
    {
        ubyte _dummy = 0;
        Unqual!T _value = void;
    }
    bool _engaged = false;
}
