/*
TEST_OUTPUT:
---
fail_compilation/fail12749.d(39): Error: immutable field `inum` initialization is not allowed in foreach loop
            inum = i;
            ^
fail_compilation/fail12749.d(40): Error: const field `cnum` initialization is not allowed in foreach loop
            cnum = i;
            ^
fail_compilation/fail12749.d(45): Error: immutable field `inum` initialization is not allowed in nested function `set`
            inum = i;
            ^
fail_compilation/fail12749.d(46): Error: const field `cnum` initialization is not allowed in nested function `set`
            cnum = i;
            ^
fail_compilation/fail12749.d(59): Error: immutable variable `inum` initialization is not allowed in foreach loop
        inum = i;
        ^
fail_compilation/fail12749.d(60): Error: const variable `cnum` initialization is not allowed in foreach loop
        cnum = i;
        ^
fail_compilation/fail12749.d(65): Error: immutable variable `inum` initialization is not allowed in nested function `set`
        inum = i;
        ^
fail_compilation/fail12749.d(66): Error: const variable `cnum` initialization is not allowed in nested function `set`
        cnum = i;
        ^
---
*/
struct S
{
    immutable int inum;
    const     int cnum;

    this(int i)
    {
        foreach (n; Aggr())
        {
            inum = i;
            cnum = i;
        }

        void set(int i)
        {
            inum = i;
            cnum = i;
        }
    }
}

immutable int inum;
const     int cnum;
static this()
{
    int i = 10;

    foreach (n; Aggr())
    {
        inum = i;
        cnum = i;
    }

    void set(int i)
    {
        inum = i;
        cnum = i;
    }
}

struct Aggr
{
    int opApply(int delegate(int) dg) { return dg(1); }
}
