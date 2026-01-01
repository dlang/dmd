// Related issue: https://github.com/dlang/dmd/issues/17198
import core.memory : GC;

void main()
{
    int i;
    struct S
    {
        this(this) {
            throw new Exception("!!!");
        }
        ~this() { ++i; }
    }

    auto a1 = [S()];
    S[] a2;

    try
    {
        a2 = a1.dup; // throws
    }
    catch (Exception e)
    {
    }

    assert(a2.length == 0);

    GC.collect();
}
