// https://github.com/dlang/dmd/issues/24476
// Thread started in a shared static destructor is not joined at termination
import core.internal.thread : isSingleThreaded;
import core.atomic : atomicLoad, atomicStore;
import core.thread : Thread;
import core.time : msecs;

shared bool finished;

shared static ~this()
{
    static if (!isSingleThreaded)
    {
        new Thread({
            Thread.sleep(100.msecs);
            atomicStore(finished, true);
        }).start();
    }
}

// runs in exit(), after druntime has terminated
pragma(crt_destructor) extern(C) void checkJoined()
{
    static if (!isSingleThreaded)
    {
        if (!atomicLoad(finished))
        {
            import core.stdc.stdio : fflush, puts;
            import core.stdc.stdlib : _Exit;

            puts("thread started in shared static ~this() was not joined");
            fflush(null);
            _Exit(1);
        }
    }
}

void main()
{
}
