debug (SENTINEL)
void main()
{
    import core.stdc.stdio : printf;
    import core.sys.posix.unistd : _exit;
    import core.thread : Thread, thread_detachThis;
    import core.memory : GC;

    // Create a new thread and immediately detach it from the runtime,
    // so that the pointer p will not be visible to the GC.
    auto t = new Thread({
        thread_detachThis();

        auto p = cast(ubyte*)GC.malloc(1);
        assert(p[-1] == 0xF4);
        assert(p[ 1] == 0xF5);

        p[1] = 0;
        try
        {
            GC.collect();

            printf("Clobbered sentinel not detected by GC.collect!\n");
            _exit(1);
        }
        catch (Error e)
        {
            printf("Clobbered sentinel successfully detected by GC.collect.\n");
            _exit(0);
        }
    });
    t.start();
    t.join();
    assert(false, "Unreachable");
}
else
    static assert(false);
