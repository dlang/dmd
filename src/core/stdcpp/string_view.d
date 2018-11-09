/**
 * D header file for interaction with C++ std::string_view.
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/string_view.d)
 */

module core.stdcpp.string_view;

import core.stdc.stddef : wchar_t;

// hacks to support DMD on Win32
version (CppRuntime_Microsoft)
{
    version = CppRuntime_Windows; // use the MS runtime ABI for win32
}
else version (CppRuntime_DigitalMars)
{
    version = CppRuntime_Windows; // use the MS runtime ABI for win32
    pragma(msg, "std::basic_string_view not supported by DMC");
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

extern(C++, (StdNamespace)):

///
alias string_view = basic_string_view!char;
//alias u16string_view = basic_string_view!wchar; // TODO: can't mangle these yet either...
//alias u32string_view = basic_string_view!dchar;
//alias wstring_view = basic_string_view!wchar_t; // TODO: we can't mangle wchar_t properly (yet?)


/**
 * Character traits classes specify character properties and provide specific
 * semantics for certain operations on characters and sequences of characters.
 */
extern(C++, struct) struct char_traits(CharT) {}


/**
* D language counterpart to C++ std::basic_string_view.
*
* C++ reference: $(LINK2 hhttps://en.cppreference.com/w/cpp/string/basic_string_view)
*/
extern(C++, class) struct basic_string_view(T, Traits = char_traits!T)
{
extern(D):
pragma(inline, true):

    ///
    enum size_type npos = size_type.max;

    ///
    alias size_type = size_t;
    ///
    alias difference_type = ptrdiff_t;
    ///
    alias value_type = T;
    ///
    alias pointer = T*;
    ///
    alias const_pointer = const(T)*;

    ///
    alias as_array this;

    ///
    alias length = size;
    ///
    alias opDollar = length;
    ///
    bool empty() const nothrow @safe @nogc                          { return size() == 0; }

    ///
    ref const(T) front() const nothrow @safe @nogc                  { return this[0]; }
    ///
    ref const(T) back() const nothrow @safe @nogc                   { return this[$-1]; }

    version (CppRuntime_Windows)
    {
        ///
        this(const(T)[] str) nothrow @trusted @nogc                 { _Mydata = str.ptr; _Mysize = str.length; }

        ///
        size_type size() const nothrow @safe @nogc                  { return _Mysize; }
        ///
        const(T)* data() const nothrow @safe @nogc                  { return _Mydata; }
        ///
        const(T)[] as_array() const inout @trusted @nogc            { return _Mydata[0 .. _Mysize]; }
        ///
        ref const(T) at(size_type i) const nothrow @trusted @nogc   { return _Mydata[0 .. _Mysize][i]; }

        version (CppRuntime_Microsoft)
        {
            import core.stdcpp.xutility : MSVCLinkDirectives;
            mixin MSVCLinkDirectives!false;
        }

    private:
        const_pointer _Mydata;
        size_type _Mysize;
    }
    else version (CppRuntime_Gcc)
    {
        ///
        this(const(T)[] str) nothrow @trusted @nogc                 { _M_str = str.ptr; _M_len = str.length; }

        ///
        size_type size() const nothrow @safe @nogc                  { return _M_len; }
        ///
        const(T)* data() const nothrow @safe @nogc                  { return _M_str; }
        ///
        const(T)[] as_array() const nothrow @trusted @nogc          { return _M_str[0 .. _M_len]; }
        ///
        ref const(T) at(size_type i) const nothrow @trusted @nogc   { return _M_str[0 .. _M_len][i]; }

    private:
        size_t _M_len;
        const(T)* _M_str;
    }
    else version (CppRuntime_Clang)
    {
        ///
        this(const(T)[] str) nothrow @trusted @nogc                 { __data = str.ptr; __size = str.length; }

        ///
        size_type size() const nothrow @safe @nogc                  { return __size; }
        ///
        const(T)* data() const nothrow @safe @nogc                  { return __data; }
        ///
        const(T)[] as_array() const nothrow @trusted @nogc          { return __data[0 .. __size]; }
        ///
        ref const(T) at(size_type i) const nothrow @trusted @nogc   { return __data[0 .. __size][i]; }

    private:
        const value_type* __data;
        size_type __size;
    }
    else
    {
        static assert(false, "C++ runtime not supported");
    }
}
