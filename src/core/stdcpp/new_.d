/**
 * D binding to C++ <new>
 *
 * Copyright: Copyright (c) 2019 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/new_.d)
 */

module core.stdcpp.new_;

import core.stdcpp.xutility : __cpp_sized_deallocation, __cpp_aligned_new;

// TODO: this really should come from __traits(getTargetInfo, "defaultNewAlignment")
enum size_t __STDCPP_DEFAULT_NEW_ALIGNMENT__ = 16;


extern (C++):

///
extern (C++, "std") enum align_val_t : size_t { defaultAlignment = __STDCPP_DEFAULT_NEW_ALIGNMENT__ };

/// Binding for ::operator new(std::size_t count)
pragma(mangle, __new_mangle)
void* __cpp_new(size_t count) @nogc;

/// Binding for ::operator delete(void* ptr)
pragma(mangle, __delete_mangle)
void __cpp_delete(void* ptr) @nogc;

static if (__cpp_sized_deallocation)
{
    /// Binding for ::operator delete(void* ptr, size_t size)
    pragma(mangle, __delete_size_mangle)
    void __cpp_delete_size(void* ptr, size_t size) @nogc;
}
static if (__cpp_aligned_new)
{
    /// Binding for ::operator new(std::size_t count, std::align_val_t al)
    pragma(mangle, __new_align_mangle)
    void* __cpp_new_aligned(size_t count, align_val_t alignment) @nogc;

    /// Binding for ::operator delete(void* ptr, std::align_val_t al)
    pragma(mangle, __delete_align_mangle)
    void __cpp_delete_aligned(void* ptr, align_val_t alignment) @nogc;

    /// Binding for ::operator delete(void* ptr, size_t size, std::align_val_t al)
    pragma(mangle, __delete_size_align_mangle)
    void __cpp_delete_size_aligned(void* ptr, size_t size, align_val_t alignment) @nogc;
}

private:

// we have to hard-code the mangling for the global new/delete operators
version (CppRuntime_Microsoft)
{
    version (D_LP64)
    {
        enum __new_mangle               = "??2@YAPEAX_K@Z";
        enum __delete_mangle            = "??3@YAXPEAX@Z";
        enum __delete_size_mangle       = "??3@YAXPEAX_K@Z";
        enum __new_align_mangle         = "??2@YAPEAX_KW4align_val_t@std@@@Z";
        enum __delete_align_mangle      = "??3@YAXPEAXW4align_val_t@std@@@Z";
        enum __delete_size_align_mangle = "??3@YAXPEAX_KW4align_val_t@std@@@Z";
    }
    else
    {
        enum __new_mangle               = "??2@YAPAXI@Z";
        enum __delete_mangle            = "??3@YAXPAX@Z";
        enum __delete_size_mangle       = "??3@YAXPAXI@Z";
        enum __new_align_mangle         = "??2@YAPAXIW4align_val_t@std@@@Z";
        enum __delete_align_mangle      = "??3@YAXPAXW4align_val_t@std@@@Z";
        enum __delete_size_align_mangle = "??3@YAXPAXIW4align_val_t@std@@@Z";
    }
}
else
{
    version (D_LP64)
    {
        enum __new_mangle               = "_Znwm";
        enum __delete_mangle            = "_ZdlPv";
        enum __delete_size_mangle       = "_ZdlPvm";
        enum __new_align_mangle         = "_ZnwmSt11align_val_t";
        enum __delete_align_mangle      = "_ZdlPvSt11align_val_t";
        enum __delete_size_align_mangle = "_ZdlPvmSt11align_val_t";
    }
    else
    {
        enum __new_mangle               = "_Znwj";
        enum __delete_mangle            = "_ZdlPv";
        enum __delete_size_mangle       = "_ZdlPvj";
        enum __new_align_mangle         = "_ZnwjSt11align_val_t";
        enum __delete_align_mangle      = "_ZdlPvSt11align_val_t";
        enum __delete_size_align_mangle = "_ZdlPvjSt11align_val_t";
    }
}
