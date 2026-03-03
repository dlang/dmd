/*
TEST_OUTPUT:
---
fail_compilation/issue19408.d(43): Error: function `issue19408.Infidel!(S).Infidel.get` is not `nothrow`
fail_compilation/issue19408.d(13):        which calls `this(this) { if (this.x > 0) throw new Exception19408; else this.x = 1; }`
fail_compilation/issue19408.d(42): Error: delegate `issue19408.failCompile.__lambda_L42_C18` may throw but is marked as `nothrow`
---
*/

struct Infidel(T)
{
    T value;
    T get() { return value; } // returns a copy
}

class Exception19408 : Exception
{
    this() { super("fail"); }
}

void assertThrown(void delegate() nothrow dg)
{
    dg();
}

void failCompile()
{
    static struct S
    {
        int x;
        this(this)
        {
            if (x > 0) throw new Exception19408();
            else x = 1;
        }
    }

    S s;
    auto sneak = Infidel!S(s);

    // shouldn't compile
    assertThrown(() nothrow {
        auto x = sneak.get();
    });
}
