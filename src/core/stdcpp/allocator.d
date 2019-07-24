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
extern(D):

    ///
    this(U)(ref allocator!U) {}

    ///
    alias value_type = T;

    ///
    alias rebind(U) = allocator!U;

    version (CppRuntime_Microsoft)
    {
        import core.stdcpp.xutility : _MSC_VER;

        ///
        T* allocate(size_t count) @nogc
        {
            static if (_MSC_VER <= 1800)
            {
                import core.stdcpp.xutility : _Xbad_alloc;
                if (count == 0)
                    return null;
                T* mem;
                if ((size_t.max / T.sizeof < count) || (mem = __cpp_new(count * T.sizeof)) == 0)
                    _Xbad_alloc();
                return mem;
            }
            else
            {
                enum _Align = _New_alignof!T;

                static size_t _Get_size_of_n(T)(const size_t _Count)
                {
                    static if (T.sizeof == 1)
                        return _Count;
                    else
                    {
                        enum size_t _Max_possible = size_t.max / T.sizeof;
                        return _Max_possible < _Count ? size_t.max : _Count * T.sizeof;
                    }
                }
                const size_t _Bytes = _Get_size_of_n!T(count);

                static if (!__cpp_aligned_new || _Align <= __STDCPP_DEFAULT_NEW_ALIGNMENT__)
                {
                    version (INTEL_ARCH)
                    {
                        if (_Bytes >= _Big_allocation_threshold)
                            return cast(T*)_Allocate_manually_vector_aligned(_Bytes);
                    }
                    return _Bytes ? cast(T*)__cpp_new(_Bytes) : null;
                }
                else
                {
                    if (_Bytes == 0)
                        return null;
                    size_t _Passed_align = _Align;
                    version (INTEL_ARCH)
                    {
                        if (_Bytes >= _Big_allocation_threshold)
                            _Passed_align = _Align < _Big_allocation_alignment ? _Big_allocation_alignment : _Align;
                    }
                    return cast(T*)__cpp_new_aligned(_Bytes, cast(align_val_t)_Passed_align);
                }
            }
        }
        ///
        void deallocate(T* ptr, size_t count) @nogc
        {
            static if (_MSC_VER <= 1800)
            {
                __cpp_delete(ptr);
            }
            else
            {
                // this is observed from VS2017
                void* _Ptr = ptr;
                size_t _Bytes = T.sizeof * count;

                enum _Align = _New_alignof!T;
                static if (!__cpp_aligned_new || _Align <= __STDCPP_DEFAULT_NEW_ALIGNMENT__)
                {
                    version (INTEL_ARCH)
                    {
                        if (_Bytes >= _Big_allocation_threshold)
                            _Adjust_manually_vector_aligned(_Ptr, _Bytes);
                    }
                    static if (_MSC_VER <= 1900)
                        __cpp_delete(ptr);
                    else
                        __cpp_delete_size(_Ptr, _Bytes);
                }
                else
                {
                    size_t _Passed_align = _Align;
                    version (INTEL_ARCH)
                    {
                        if (_Bytes >= _Big_allocation_threshold)
                            _Passed_align = _Align < _Big_allocation_alignment ? _Big_allocation_alignment : _Align;
                    }
                    __cpp_delete_size_aligned(_Ptr, _Bytes, cast(align_val_t)_Passed_align);
                }
            }
        }

        ///
        enum size_t max_size = size_t.max / T.sizeof;
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


private:

// MSVC has some bonus complexity!
version (CppRuntime_Microsoft)
{
    // some versions of VS require a `* const` pointer mangling hack
    // we need a way to supply the target VS version to the compile
    version = NeedsMangleHack;

    version (X86)
        version = INTEL_ARCH;
    version (X86_64)
        version = INTEL_ARCH;

    // HACK: should we guess _DEBUG for `debug` builds?
    version (NDEBUG) {}
    else debug version = _DEBUG;

    enum _New_alignof(T) = T.alignof > __STDCPP_DEFAULT_NEW_ALIGNMENT__ ? T.alignof : __STDCPP_DEFAULT_NEW_ALIGNMENT__;

    version (INTEL_ARCH)
    {
        enum size_t _Big_allocation_threshold = 4096;
        enum size_t _Big_allocation_alignment = 32;

        static assert(2 * (void*).sizeof <= _Big_allocation_alignment, "Big allocation alignment should at least match vector register alignment");
        static assert((v => v != 0 && (v & (v - 1)) == 0)(_Big_allocation_alignment), "Big allocation alignment must be a power of two");
        static assert(size_t.sizeof == (void*).sizeof, "uintptr_t is not the same size as size_t");

        // NOTE: this must track `_DEBUG` macro used in C++...
        version (_DEBUG)
            enum size_t _Non_user_size = 2 * (void*).sizeof + _Big_allocation_alignment - 1;
        else
            enum size_t _Non_user_size = (void*).sizeof + _Big_allocation_alignment - 1;

        version (Win64)
            enum size_t _Big_allocation_sentinel = 0xFAFAFAFAFAFAFAFA;
        else
            enum size_t _Big_allocation_sentinel = 0xFAFAFAFA;

        void* _Allocate_manually_vector_aligned(const size_t _Bytes) @nogc
        {
            size_t _Block_size = _Non_user_size + _Bytes;
            if (_Block_size <= _Bytes)
                _Block_size = size_t.max;

            const size_t _Ptr_container = cast(size_t)__cpp_new(_Block_size);
            if (!(_Ptr_container != 0))
                assert(false, "invalid argument");
            void* _Ptr = cast(void*)((_Ptr_container + _Non_user_size) & ~(_Big_allocation_alignment - 1));
            (cast(size_t*)_Ptr)[-1] = _Ptr_container;

            version (_DEBUG)
                (cast(size_t*)_Ptr)[-2] = _Big_allocation_sentinel;
            return (_Ptr);
        }

        void _Adjust_manually_vector_aligned(ref void* _Ptr, ref size_t _Bytes) pure nothrow @nogc
        {
            _Bytes += _Non_user_size;

            const size_t* _Ptr_user = cast(size_t*)_Ptr;
            const size_t _Ptr_container = _Ptr_user[-1];

            // If the following asserts, it likely means that we are performing
            // an aligned delete on memory coming from an unaligned allocation.
            assert(_Ptr_user[-2] == _Big_allocation_sentinel, "invalid argument");

            // Extra paranoia on aligned allocation/deallocation; ensure _Ptr_container is
            // in range [_Min_back_shift, _Non_user_size]
            version (_DEBUG)
                enum size_t _Min_back_shift = 2 * (void*).sizeof;
            else
                enum size_t _Min_back_shift = (void*).sizeof;

            const size_t _Back_shift = cast(size_t)_Ptr - _Ptr_container;
            if (!(_Back_shift >= _Min_back_shift && _Back_shift <= _Non_user_size))
                assert(false, "invalid argument");
            _Ptr = cast(void*)_Ptr_container;
        }
    }
}
