/* REQUIRED_ARGS: -betterC
   PERMUTE_ARGS:
   DISABLED: win32
 */

__gshared bool dtorRan;

struct S
{
    ~this()
    {
        dtorRan = true;
    }

    void m() {}
}

extern(C) int main()
{
    dtorRan = false;
    {
        S s;
        s.m();
    }
    assert(dtorRan);
    return 0;
}
