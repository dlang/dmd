/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/fail19965.d(28): Error: returning `this.buffer.getData()` escapes a reference to parameter `this`, perhaps annotate with `return`
fail_compilation/fail19965.d(36): Error: template instance `fail19965.Foo!()` error instantiating
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19965

struct Buffer
{
    int[10] data;

    int[] getData() @safe return
    {
        return data[];
    }
}

struct Foo()
{
    Buffer buffer;

    int[] toArray() @safe
    {
        return buffer.getData;
    }
}

int[] a;

void main() @safe
{
    Foo!() f;
    a = f.toArray;
}
