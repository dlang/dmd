/** Container with internal pointer
 * bugzilla: https://issues.dlang.org/show_bug.cgi?id=20321
 */
struct Container
{
    long[3] data;
    void* p;

    this(int) { p = &data[0]; }
    this(ref Container) { p = &data[0]; }

    /** Ensure the internal pointer is correct */
    void check(int line = __LINE__, string file = __FILE__)()
    {
        if (p != &data[0])
        {
            //import core.stdc.stdio : printf;
            //printf("%s(%d): %s\n", file.ptr, line, "error".ptr);
            assert(0, "internal pointer corrupted");
        }
    }
}

void main()
{
    Container v = Container(1);
    v.check(); // ok

    Container[] darr;
    darr ~= v;
    darr[0].check(); // error
}
