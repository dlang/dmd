debug (SENTINEL)
void main()
{
    import core.stdc.stdio : printf;
    import core.sys.posix.unistd : _exit;
    import core.memory : GC;

    auto p = cast(ubyte*)GC.malloc(1);
    assert(p[ 1] == 0xF5);

    p[1] = 0;
    try
    {
        GC.free(p);

        printf("Clobbered sentinel not detected by GC.free!\n");
        _exit(1);
    }
    catch (Error e)
    {
        printf("Clobbered sentinel successfully detected by GC.free.\n");
        _exit(0);
    }
}
else
    static assert(false);
