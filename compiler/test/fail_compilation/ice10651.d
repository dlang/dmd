/*
TEST_OUTPUT:
---
fail_compilation/ice10651.d(19): Error: can only throw class objects derived from `Throwable`, not type `int*`
    throw new T();  // ICE
    ^
fail_compilation/ice10651.d(25): Deprecation: cannot throw object of qualified type `immutable(Exception)`
    if (c) throw c;
                 ^
fail_compilation/ice10651.d(26): Deprecation: cannot throw object of qualified type `const(Dummy)`
    throw new const Dummy([]);
          ^
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
    throw new const Dummy([]);
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
