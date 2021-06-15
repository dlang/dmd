/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/test20149b.d(22): Error: returning `this.buf[lower..upper]` escapes a reference to parameter `this`
fail_compilation/test20149b.d(22):        perhaps annotate the parameter with `return`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=20149

@safe:

struct ScopeBuffer
{
    this(char[4] init)
    {
        this.buf = init;
    }

    inout(char)[] opSlice(size_t lower, size_t upper) inout
    {
        return buf[lower .. upper];
    }

    char[4] buf;
}

char[] fun()
{
    char[4] buf = "abcd";
    auto sb = ScopeBuffer(buf);
    return sb[0..2];
}

void main()
{
    auto s = fun();
}
