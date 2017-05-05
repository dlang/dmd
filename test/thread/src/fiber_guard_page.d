import core.thread;
import core.sys.posix.sys.mman;

// this should be true for most architectures
version = StackGrowsDown;

int recurse(int i)
{
    return i == 0 ? 0 : recurse(i - 1) + i;
}

void main()
{
    import core.stdc.stdio;
    enum stackSize = 4096;
    enum n = size_t.sizeof == 8 ? 128 : 512;
    auto fib1 = new Fiber(function{ recurse(n); }, stackSize);
    // allocate a page below (above) the fiber's stack to make stack overflows possible (w/o segfaulting)
    version (StackGrowsDown)
    {
        auto stackBottom1 = fib1.tupleof[8]; // m_pmem
        auto p = mmap(stackBottom1 - 8 * stackSize, 8 * stackSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        assert(p !is null, "failed to allocate page");
    }
    else
    {
        auto stackTop1 = fib1.tupleof[8] + fib1.tupleof[7]; // m_pmem + m_sz
        auto p = mmap(stackTop1, 8 * stackSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
        assert(p !is null, "failed to allocate page");
    }
    // the guard page should prevent a mem corruption by stack overflow and cause a segfault instead
    fib1.call();
}
