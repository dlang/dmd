// meant to be able to link without druntime
extern (C) int main(int argc, char **argv) { return 0; }
extern (C) void _d_dso_registry() { }
version (FreeBSD)
{
    extern (C) void __dmd_personality_v0() { }
}
