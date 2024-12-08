/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test17959.d(22): Error: scope variable `this` assigned to non-scope `this.escape`
        this.escape = &this.escfoo;
                    ^
fail_compilation/test17959.d(23): Error: scope variable `this` assigned to non-scope `this.f`
        f = this;
          ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17959

class Foo
{
    void delegate () @safe escape;
    Foo f;

    void escfoo() @safe scope
    {
        this.escape = &this.escfoo;
        f = this;
    }
}
