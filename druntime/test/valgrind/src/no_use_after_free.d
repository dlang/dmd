// Explicit use-after-free.

import core.memory;

int main()
{
    auto p = cast(int*)GC.malloc(int.sizeof * 3);
    GC.free(p);
    return *p;
}
