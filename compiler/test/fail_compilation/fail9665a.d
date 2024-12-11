/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(97): Error: immutable field `v` initialized multiple times
        v = 2;  // multiple initialization
        ^
fail_compilation/fail9665a.d(96):        Previous initialization is here.
        v = 1;
        ^
fail_compilation/fail9665a.d(107): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(106):        Previous initialization is here.
        if (true) v = 1; else v = 2;
                              ^
fail_compilation/fail9665a.d(112): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(111):        Previous initialization is here.
        if (true) v = 1;
                  ^
fail_compilation/fail9665a.d(117): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(116):        Previous initialization is here.
        if (true) {} else v = 2;
                          ^
fail_compilation/fail9665a.d(127): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(126):        Previous initialization is here.
        true ? (v = 1) : (v = 2);
                          ^
fail_compilation/fail9665a.d(132): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(131):        Previous initialization is here.
        auto x = true ? (v = 1) : 2;
                         ^
fail_compilation/fail9665a.d(137): Error: immutable field `v` initialized multiple times
        v = 3;  // multiple initialization
        ^
fail_compilation/fail9665a.d(136):        Previous initialization is here.
        auto x = true ? 1 : (v = 2);
                             ^
fail_compilation/fail9665a.d(150): Error: immutable field `v` initialization is not allowed in loops or after labels
        v = 1;  // after labels
        ^
fail_compilation/fail9665a.d(155): Error: immutable field `v` initialization is not allowed in loops or after labels
            v = 1;  // in loops
            ^
fail_compilation/fail9665a.d(160): Error: immutable field `v` initialized multiple times
    L:  v = 2;  // assignment after labels
        ^
fail_compilation/fail9665a.d(159):        Previous initialization is here.
        v = 1;  // initialization
        ^
fail_compilation/fail9665a.d(165): Error: immutable field `v` initialized multiple times
        foreach (i; 0..1) v = 2;  // assignment in loops
                          ^
fail_compilation/fail9665a.d(164):        Previous initialization is here.
        v = 1;  // initialization
        ^
fail_compilation/fail9665a.d(170): Error: immutable field `v` initialized multiple times
        v = 2;  // multiple initialization
        ^
fail_compilation/fail9665a.d(169):        Previous initialization is here.
        v = 1; return;
        ^
fail_compilation/fail9665a.d(184): Error: immutable field `v` initialized multiple times
        v = 2;  // multiple initialization
        ^
fail_compilation/fail9665a.d(183):        Previous initialization is here.
        v = 1;
        ^
fail_compilation/fail9665a.d(188): Error: immutable field `w` initialized multiple times
        w = 2;  // multiple initialization
        ^
fail_compilation/fail9665a.d(187):        Previous initialization is here.
            w = 1;
            ^
fail_compilation/fail9665a.d(202): Error: static assert:  `__traits(compiles, this.v = 1)` is false
        static assert(__traits(compiles, v = 1)); // multiple initialization
        ^
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
