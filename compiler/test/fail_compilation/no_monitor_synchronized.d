/*
DFLAGS:
REQUIRED_ARGS: -c
EXTRA_SOURCES: extra-files/no_monitor_synchronized/object.d
TEST_OUTPUT:
---
fail_compilation/no_monitor_synchronized.d(20): Error: cannot `synchronize` on a `Foo` because `object.Object` has no `__monitor` field
---
*/

// Test using synchronized(obj) with a custom druntime that has no __monitor field

class Foo
{
    int x;
}

void test(Foo f)
{
    synchronized(f) {}

    // Bare synchronized (uses critical section, not monitor) still compiles
    synchronized {}
}

// Check that there's only a vtbl before x, no hidden monitor field
static assert(Foo.x.offsetof == size_t.sizeof);
