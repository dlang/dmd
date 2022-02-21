/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/test19097.d(40): Error: scope variable `s` may not be returned
fail_compilation/test19097.d(44): Error: scope variable `s1` may not be returned
fail_compilation/test19097.d(81): Error: scope variable `s` may not be returned
fail_compilation/test19097.d(85): Error: scope variable `s1` may not be returned
fail_compilation/test19097.d(102): Error: scope variable `s` may not be returned
fail_compilation/test19097.d(106): Error: scope variable `s1` may not be returned
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19097

@safe:

void betty(ref scope int* r, return scope int* p)
{
    r = p;
}

void freddy(out scope int* r, return scope int* p)
{
    r = p;
}

struct S
{
    int* a;
    this(return scope int* b) scope { a = b; }

    int* c;
    void mem(return scope int* d) scope { c = d; }
}

S thorin()
{
    int i;
    S s = S(&i); // should infer scope for s
    return s;    // so this should error

    S s1;
    s1.mem(&i);
    return s1;
}

/************************/

struct S2(T)
{
    int* p;

    void silent(lazy void dg);

    void foo()
    {
        char[] name;
        silent(name = parseType());
    }

    char[] parseType(char[] name = null);
}

S2!int s2;

/************************/
// https://issues.dlang.org/show_bug.cgi?id=22801
struct S3
{
    int* a;
    this(return ref int b) { a = &b; }

    int* c;
    void mem(return ref int d) scope { c = &d; }
}

S3 frerin()
{
    int i;
    S3 s = S3(i); // should infer scope for s
    return s;    // so this should error

    S3 s1;
    s1.mem(i);
    return s1;
}


struct S4
{
    int** a;
    this(return ref int* b) { a = &b; }

    int** c;
    void mem(return ref int* d) scope { c = &d; }
}

S4 dis()
{
    int* i = null;
    S4 s = S4(i); // should infer scope for s
    return s;    // so this should error

    S4 s1;
    s1.mem(i);
    return s1;
}
