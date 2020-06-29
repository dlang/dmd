// PERMUTE_ARGS:
/+
TEST_OUTPUT:
---
fail_compilation/fail9665a.d(44): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(43):        Previous initialization is here.
fail_compilation/fail9665a.d(54): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(53):        Previous initialization is here.
fail_compilation/fail9665a.d(59): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(58):        Previous initialization is here.
fail_compilation/fail9665a.d(64): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(63):        Previous initialization is here.
fail_compilation/fail9665a.d(74): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(73):        Previous initialization is here.
fail_compilation/fail9665a.d(79): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(78):        Previous initialization is here.
fail_compilation/fail9665a.d(84): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(83):        Previous initialization is here.
fail_compilation/fail9665a.d(97): Error: immutable field `v` initialization is not allowed in loops or after labels
fail_compilation/fail9665a.d(102): Error: immutable field `v` initialization is not allowed in loops or after labels
fail_compilation/fail9665a.d(107): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(106):        Previous initialization is here.
fail_compilation/fail9665a.d(112): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(111):        Previous initialization is here.
fail_compilation/fail9665a.d(117): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(116):        Previous initialization is here.
fail_compilation/fail9665a.d(131): Error: immutable field `v` initialized multiple times
fail_compilation/fail9665a.d(130):        Previous initialization is here.
fail_compilation/fail9665a.d(135): Error: immutable field `w` initialized multiple times
fail_compilation/fail9665a.d(134):        Previous initialization is here.
fail_compilation/fail9665a.d(149): Error: static assert:  `__traits(compiles, this.v = 1)` is false
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

