// REQUIRED_ARGS:
// PERMUTE_ARGS:
/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(45): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(44):        Previous initialization is here.
fail_compilation/fail9665a.d(55): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(54):        Previous initialization is here.
fail_compilation/fail9665a.d(60): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(59):        Previous initialization is here.
fail_compilation/fail9665a.d(65): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(64):        Previous initialization is here.
fail_compilation/fail9665a.d(75): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(74):        Previous initialization is here.
fail_compilation/fail9665a.d(80): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(79):        Previous initialization is here.
fail_compilation/fail9665a.d(85): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(84):        Previous initialization is here.
fail_compilation/fail9665a.d(98): Error: immutable field `v` initialization is not allowed in loops or after labels
fail_compilation/fail9665a.d(103): Error: immutable field `v` initialization is not allowed in loops or after labels
fail_compilation/fail9665a.d(108): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(107):        Previous initialization is here.
fail_compilation/fail9665a.d(113): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(112):        Previous initialization is here.
fail_compilation/fail9665a.d(118): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(117):        Previous initialization is here.
fail_compilation/fail9665a.d(132): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(131):        Previous initialization is here.
fail_compilation/fail9665a.d(136): Error: immutable field `w` initialized multiple times
fail_compilation/fail9665a.d(135):        Previous initialization is here.
fail_compilation/fail9665a.d(150): Error: static assert:  `__traits(compiles, this.v = 1)` is false
---
+/

/***************************************************/
// immutable field

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

struct S3
{
    int v;
    int w;
    this(int) immutable
    {
        v = 1;
        v = 2;  // multiple initialization

        if (true)
            w = 1;
        w = 2;  // multiple initialization
    }
}

/***************************************************/
// in __traits(compiles)

struct S4
{
    immutable int v;
    this(int)
    {
        static assert(__traits(compiles, v = 1));
        v = 1;
        static assert(__traits(compiles, v = 1)); // multiple initialization
    }
}

