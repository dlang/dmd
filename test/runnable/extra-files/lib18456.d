
__gshared int initVar;

pragma(crt_constructor)
extern(C) void mir_cpuid_crt_init()
{
    initVar = 42;
}
