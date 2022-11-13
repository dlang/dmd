version(DLL)
{
    import core.sys.windows.dll;
    import core.memory;
    import core.thread;
    import core.sync.event;

    mixin SimpleDllMain;

    class Task
    {
        bool stop;
        Event event;
        ThreadID tid;

        this()
        {
            event.initialize(true, false);
            tid = createLowLevelThread(&run, 0, &term);
        }

        void run() nothrow
        {
            while (!stop)
            {
                event.wait(100.msecs);
            }
        }
        void term() nothrow
        {
            stop = true;
            event.set();
            joinLowLevelThread(tid);
        }
    }

    static this()
    {
        auto tsk = new Task;
        assert(tsk.tid != ThreadID.init);
    }

    static ~this()
    {
        // creating thread in shutdown should fail
        auto tsk = new Task;
        assert(tsk.tid == ThreadID.init);
    }
}
else
{
    void main()
    {
        import core.runtime;
        import core.time;
        import core.thread;
        import core.sys.windows.windows : GetModuleHandleA;

        auto dll = Runtime.loadLibrary("dllgc.dll");
        assert(dll);
        Runtime.unloadLibrary(dll);
        // the DLL might not be unloaded immiediately, but should do so eventually
        for (int i = 0; i < 100; i++)
        {
            if (!GetModuleHandleA("dllgc.dll"))
                return;
            Thread.sleep(10.msecs);
        }
        assert(false);
    }
}
