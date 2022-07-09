// https://issues.dlang.org/show_bug.cgi?id=22558
module core.stdc.stdio;

version (X86_64)
{
    version (Posix)
    {
        struct __va_list_tag
        {
            uint gp_offset;
            uint fp_offset;
            void* overflow_arg_area;
            void* reg_save_area;
        }
        alias __builtin_va_list = __va_list_tag*;
    }
    else version (Windows)
    {
        alias __builtin_va_list = char*;
    }
}
else version (X86)
{
    alias __builtin_va_list = char*;
}

static if (__traits(compiles, __builtin_va_list))
{
    alias va_list = __builtin_va_list;
    struct FILE;

    extern(C)
    {
        pragma(printf)
        int vfprintf(FILE* stream, scope const char* format, va_list arg);
    }
}
