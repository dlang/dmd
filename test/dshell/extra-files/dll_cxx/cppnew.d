module cppnew;

/* This module contains copies from core.stdcpp.new_.d, but with
 * modifications for DMC. */

T* cpp_new(T, Args...)(auto ref Args args) if (!is(T == class))
{
    import core.lifetime : emplace, forward;

    T* mem = cast(T*)__cpp_new(T.sizeof);
    return mem.emplace(forward!args);
}

T cpp_new(T, Args...)(auto ref Args args) if (is(T == class))
{
    import core.lifetime : emplace, forward;

    T mem = cast(T)__cpp_new(__traits(classInstanceSize, T));
    return mem.emplace(forward!args);
}

void cpp_delete(T)(T* ptr) if (!is(T == class))
{
    destroy!false(*ptr);
    __cpp_delete(ptr);
}

void cpp_delete(T)(T instance) if (is(T == class))
{
    destroy!false(instance);
    __cpp_delete(cast(void*) instance);
}

/// Binding for ::operator new(std::size_t count)
pragma(mangle, __new_mangle)
extern(C++) void* __cpp_new(size_t count);

/// Binding for ::operator delete(void* ptr)
pragma(mangle, __delete_mangle)
extern(C++) void __cpp_delete(void* ptr);

// we have to hard-code the mangling for the global new/delete operators
version (CppRuntime_Microsoft)
{
    version (D_LP64)
    {
        enum __new_mangle                   = "??2@YAPEAX_K@Z";
        enum __delete_mangle                = "??3@YAXPEAX@Z";
    }
    else
    {
        enum __new_mangle                   = "??2@YAPAXI@Z";
        enum __delete_mangle                = "??3@YAXPAX@Z";
    }
}
else version (CppRuntime_DigitalMars)
{
    version (D_LP64)
    {
        enum __new_mangle                   = "??2@YAPEAX_K@Z";
        enum __delete_mangle                = "??3@YAXPEAX@Z";
    }
    else
    {
        enum __new_mangle                   = "??2@YAPAXI@Z";
        enum __delete_mangle                = "??3@YAXPAX@Z";
    }
}
else
{
    version (D_LP64)
    {
        enum __new_mangle                   = "_Znwm";
        enum __delete_mangle                = "_ZdlPv";
    }
    else
    {
        enum __new_mangle                   = "_Znwj";
        enum __delete_mangle                = "_ZdlPv";
    }
}
