// https://github.com/dlang/dmd/pull/24176
// needs release build to reproduce
import core.atomic : atomicLoad, atomicStore;
import core.memory : GC;
import core.stdc.stdio : printf;
import core.sys.windows.windows : MEMORY_BASIC_INFORMATION, PAGE_GUARD, VirtualQuery;
import core.thread : Thread;
import core.time : msecs;

shared bool stop;

// Lower RSP by `delta` without touching the memory, spin, then restore it.
// This stretches the few instructions between a prologue's `sub rsp, N` and
// its first store into a window that a collection is sure to land in.
extern (C) void parkStackPointer(size_t delta, size_t spins)
{
    version (Win64)
    {
        asm
        {
            naked;
            sub RSP, RCX;
        L1: dec RDX;
            jnz L1;
            add RSP, RCX;
            ret;
        }
    }
    else version (Win32)
    {
        asm
        {
            naked;
            mov EAX, [ESP+4];
            mov EDX, [ESP+8];
            sub ESP, EAX;
        L1: dec EDX;
            jnz L1;
            add ESP, EAX;
            ret;
        }
    }
}

// NT_TIB.StackLimit of the calling thread: the bottom of its committed stack.
extern (C) size_t stackLimit()
{
    version (Win64)
    {
        asm
        {
            naked;
            mov RAX, 0x10;
            mov RAX, GS:[RAX];
            ret;
        }
    }
    else version (Win32)
    {
        asm
        {
            naked;
            mov EAX, 0x8;
            mov EAX, FS:[EAX];
            ret;
        }
    }
}

void worker()
{
    ubyte here;    // a local: roughly the current stack pointer
    immutable size_t limit = stackLimit();
    MEMORY_BASIC_INFORMATION mbi;
    VirtualQuery(cast(void*) (limit - 1), &mbi, mbi.sizeof);
    assert(mbi.Protect & PAGE_GUARD, "expected the guard page below StackLimit");

    // Park RSP 512 bytes into the guard page, which nothing ever touches.
    immutable size_t delta = (cast(size_t) &here - limit + 512 + 15) & ~cast(size_t) 15;
    while (!atomicLoad(stop))
        parkStackPointer(delta, 1_000_000);
}

void main()
{
    Thread[] workers;
    foreach (i; 0 .. 4)
        workers ~= new Thread(&worker).start();
    Thread.sleep(100.msecs);

    foreach (i; 0 .. 100)
        GC.collect();          // suspends the workers and scans [Rsp, StackBase)

    printf("no fault\n");      // not reached
    atomicStore(stop, true);
    foreach (t; workers)
        t.join();
}
