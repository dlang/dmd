/*
TEST_OUTPUT:
---
fail_compilation/ice10651.d(13): Error: can only throw class objects derived from `Throwable`, not type `int*`
fail_compilation/ice10651.d(19): Deprecation: cannot throw immutable object `c`
fail_compilation/ice10651.d(20): Deprecation: cannot throw immutable object `new immutable(Dummy)([])`
---
*/

void main()
{
    alias T = int;
    throw new T();  // ICE
}

void f()
{
    immutable c = new Exception("");
    if (c) throw c;
    throw new immutable Dummy([]);
}

class Dummy: Exception
{
    int[] data;
    @safe pure nothrow this(immutable int[] data) immutable
    {
        super("Dummy");
        this.data = data;
    }
}
