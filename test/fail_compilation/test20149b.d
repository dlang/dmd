/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/test20149b.d(31): Error: returning `sb.opSlice(0LU, 2LU)` escapes a reference to local variable `sb`
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
