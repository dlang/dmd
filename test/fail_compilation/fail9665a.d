// REQUIRED_ARGS:
// PERMUTE_ARGS:

/***************************************************/
// immutable field

/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(106): Error: multiple field v initialization
fail_compilation/fail9665a.d(116): Error: multiple field v initialization
fail_compilation/fail9665a.d(121): Error: multiple field v initialization
fail_compilation/fail9665a.d(126): Error: multiple field v initialization
fail_compilation/fail9665a.d(136): Error: multiple field v initialization
fail_compilation/fail9665a.d(141): Error: multiple field v initialization
fail_compilation/fail9665a.d(146): Error: multiple field v initialization
---
+/
#line 100
struct S1A
{
    immutable int v;
    this(int)
    {
        v = 1;
        v = 2;  // multiple initialization
    }
}

struct S1B
{
    immutable int v;
    this(int)
    {
        if (true) v = 1; else v = 2;
        v = 3;  // multiple initialization
    }
    this(long)
    {
        if (true) v = 1;
        v = 3;  // multiple initialization
    }
    this(string)
    {
        if (true) {} else v = 2;
        v = 3;  // multiple initialization
    }
}

struct S1C
{
    immutable int v;
    this(int)
    {
        true ? (v = 1) : (v = 2);
        v = 3;  // multiple initialization
    }
    this(long)
    {
        auto x = true ? (v = 1) : 2;
        v = 3;  // multiple initialization
    }
    this(string)
    {
        auto x = true ? 1 : (v = 2);
        v = 3;  // multiple initialization
    }
}

/***************************************************/
// with control flow

/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(206): Error: field v initializing not allowed in loops or after labels
fail_compilation/fail9665a.d(211): Error: field v initializing not allowed in loops or after labels
fail_compilation/fail9665a.d(216): Error: multiple field v initialization
fail_compilation/fail9665a.d(221): Error: multiple field v initialization
fail_compilation/fail9665a.d(226): Error: multiple field v initialization
---
+/
#line 200
struct S2
{
    immutable int v;
    this(int)
    {
    L:
        v = 1;  // after labels
    }
    this(long)
    {
        foreach (i; 0..1)
            v = 1;  // in loops
    }
    this(string)
    {
        v = 1;  // initialization
    L:  v = 2;  // assignment after labels
    }
    this(wstring)
    {
        v = 1;  // initialization
        foreach (i; 0..1) v = 2;  // assignment in loops
    }
    this(dstring)
    {
        v = 1; return;
        v = 2;  // multiple initialization
    }
}

/***************************************************/
// with immutable constructor

/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(307): Error: multiple field v initialization
fail_compilation/fail9665a.d(311): Error: multiple field w initialization
---
+/
#line 300
struct S3
{
    int v;
    int w;
    this(int) immutable
    {
        v = 1;
        v = 2;  // multiplie initialization

        if (true)
            w = 1;
        w = 2;  // multiplie initialization
    }
}

/***************************************************/
// in __traits(compiles)

/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(406): Error: multiple field v initialization
---
+/
#line 400
struct S4
{
    immutable int v;
    this(int)
    {
        static assert(__traits(compiles, v = 1));
        v = 1;  // multiplie initialization
    }
}

