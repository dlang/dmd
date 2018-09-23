/**
 * D binding to C++ std::allocator.
 *
 * Copyright: Copyright (c) 2019 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/allocator.d)
 */

module core.stdcpp.allocator;

import core.stdcpp.new_;
import core.stdcpp.xutility : __cpp_sized_deallocation, __cpp_aligned_new;

// some versions of VS require a `* const` pointer mangling hack
// we need a way to supply the target VS version to the compile
version (CppRuntime_Microsoft)
    version = NeedsMangleHack;

/**
 * Allocators are classes that define memory models to be used by some parts of
 * the C++ Standard Library, and most specifically, by STL containers.
 */
extern(C++, class)
extern(C++, "std")
struct allocator(T)
{
    static assert(!is(T == const), "The C++ Standard forbids containers of const elements because allocator!(const T) is ill-formed.");
    static assert(!is(T == immutable), "immutable is not representable in C++");
    static assert(!is(T == class), "Instantiation with `class` is not supported; D can't mangle the base (non-pointer) type of a class. Use `extern (C++, class) struct T { ... }` instead.");

    ///
    alias value_type = T;

    version (CppRuntime_Microsoft)
    {
        ///
        T* allocate(size_t count) @nogc;
        ///
        void deallocate(T* ptr, size_t count) @nogc;

        ///
        enum size_t max_size = size_t.max / T.sizeof;

        version (NeedsMangleHack)
        {
            // HACK: workaround to make `deallocate` link as a `T * const`
            private extern (D) enum string constHack(string name) = (){
                version (Win64)
                    enum sub = "AAXPE";
                else
                    enum sub = "AEXPA";
                foreach (i; 0 .. name.length - sub.length)
                    if (name[i .. i + sub.length] == sub[])
                        return name[0 .. i + 3] ~ 'Q' ~ name[i + 4 .. $];
                assert(false, "substitution string not found!");
            }();
            pragma(linkerDirective, "/alternatename:" ~ deallocate.mangleof ~ "=" ~ constHack!(deallocate.mangleof));
        }
    }
    else version (CppRuntime_Gcc)
    {
        ///
        T* allocate(size_t count, const(void)* = null) @nogc
        {
//            if (count > max_size)
//                std::__throw_bad_alloc();

            static if (__cpp_aligned_new && T.alignof > __STDCPP_DEFAULT_NEW_ALIGNMENT__)
                return cast(T*)__cpp_new_aligned(count * T.sizeof, cast(align_val_t)T.alignof);
            else
                return cast(T*)__cpp_new(count * T.sizeof);
        }
        ///
        void deallocate(T* ptr, size_t count) @nogc
        {
            // NOTE: GCC doesn't seem to use the sized delete when it's available...

            static if (__cpp_aligned_new && T.alignof > __STDCPP_DEFAULT_NEW_ALIGNMENT__)
                __cpp_delete_aligned(cast(void*)ptr, cast(align_val_t)T.alignof);
            else
                __cpp_delete(cast(void*)ptr);
        }

        ///
        enum size_t max_size = (ptrdiff_t.max < size_t.max ? cast(size_t)ptrdiff_t.max : size_t.max) / T.sizeof;
    }
    else version (CppRuntime_Clang)
    {
        ///
        T* allocate(size_t count, const(void)* = null) @nogc
        {
//            if (count > max_size)
//                __throw_length_error("allocator!T.allocate(size_t n) 'n' exceeds maximum supported size");

            static if (__cpp_aligned_new && T.alignof > __STDCPP_DEFAULT_NEW_ALIGNMENT__)
                return cast(T*)__cpp_new_aligned(count * T.sizeof, cast(align_val_t)T.alignof);
            else
                return cast(T*)__cpp_new(count * T.sizeof);
        }
        ///
        void deallocate(T* ptr, size_t count) @nogc
        {
            static if (__cpp_aligned_new && T.alignof > __STDCPP_DEFAULT_NEW_ALIGNMENT__)
            {
                static if (__cpp_sized_deallocation)
                    return __cpp_delete_size_aligned(cast(void*)ptr, count * T.sizeof, cast(align_val_t)T.alignof);
                else
                    return __cpp_delete_aligned(cast(void*)ptr, cast(align_val_t)T.alignof);
            }
            else static if (__cpp_sized_deallocation)
                return __cpp_delete_size(cast(void*)ptr, count * T.sizeof);
            else
                return __cpp_delete(cast(void*)ptr);
        }

        ///
        enum size_t max_size = size_t.max / T.sizeof;
    }
    else
    {
        static assert(false, "C++ runtime not supported");
    }
}
