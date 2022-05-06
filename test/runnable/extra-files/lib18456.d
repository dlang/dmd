
__gshared int initVar;

pragma(crt_constructor)
void mir_cpuid_crt_init()
{
    initVar = 42;
}
