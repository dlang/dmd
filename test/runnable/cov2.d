// PERMUTE_ARGS:
// POST_SCRIPT: runnable/extra-files/coverage-postscript.sh
// REQUIRED_ARGS: -cov
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

extern(C) void dmd_coverDestPath(string pathname);

/***************************************************/

void test1()
{
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

void test3()
{
    long total = 0;
    for (size_t i = 0; i < 10_000_000; i++)
        total += i;
}

/***************************************************/

int main(string[] args)
{
    dmd_coverDestPath(args[1]);
    test1();
    test2();
    test3();
    return 0;
}

