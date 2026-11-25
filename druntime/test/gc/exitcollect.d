// https://issues.dlang.org/show_bug.cgi?id=20567
// The collection at termination must not start threads for parallel marking.

import core.sys.posix.dirent;

// Number of threads of this process, as the kernel reports them.
size_t numThreads() nothrow @nogc
{
    auto dir = opendir("/proc/self/task");
    assert(dir);
    size_t n;
    for (auto entry = readdir(dir); entry; entry = readdir(dir))
        if (entry.d_name[0] != '.')
            ++n;
    closedir(dir);
    return n;
}

class C
{
    ~this()
    {
        // called by the collection at termination
        assert(numThreads() == 1);
    }
}

void main()
{
    assert(numThreads() == 1);
    foreach (i; 0 .. 100)
        new C;
}
