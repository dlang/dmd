module defaultlib;

int defaultlibFunc() { return 42; }

extern (C) void _d_dso_registry() { }
version (FreeBSD)
{
    extern (C) void __dmd_personality_v0() { }
}
version (Windows)
{
    extern (Windows) int _DllMainCRTStartup(void*,uint,void*) { return 0; }
}
