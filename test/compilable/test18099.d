
/* REQUIRED_ARGS: -betterC
 */

// https://issues.dlang.org/show_bug.cgi?id=18099

struct D
{
    static struct V
    {
        ~this() nothrow { }
    }

    V get() nothrow
    {
        V v;
        return v;
    }
}
