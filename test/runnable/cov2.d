// PERMUTE_ARGS:
// POST_SCRIPT: runnable/extra-files/cov2-postscript.sh
// REQUIRED_ARGS: -cov

extern(C) void dmd_coverDestPath(string pathname);

/***************************************************/

void test1()
{
    dmd_coverDestPath("test_results/runnable");

    int counter = 20;
    do {
        --counter;
    }
    while(counter > 0);
}

/***************************************************/

struct S2
{
    this(this) { int x = 1; }
    ~this() { int x = 1; }
    ref S2 opAssign(S2) { return this; }
    bool opEquals(ref const S2) const { return true; }
}
struct T2
{
    S2 s;

    this(this) { int x = 1; }
    ~this() { int x = 1; }
}
void test2()
{
    T2 ta;
    T2 tb = ta;
    tb = ta;
    typeid(T2).equals(&ta, &tb);
}

/***************************************************/

int main()
{
    test1();
    test2();
    return 0;
}

