/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/test19097.d(36): Error: scope variable `s` may not be returned
fail_compilation/test19097.d(66): Error: scope variable `z` assigned to `refPtr` with longer lifetime
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

struct S3
{
    int* ptr;
    void assign(ref int* refPtr, return scope int* z) scope @safe
    {
        this.ptr = z; // allowed, first ref
        refPtr = z; // should not be allowed
    }
}

int* escape() @safe
{
    int local;

    S3 escapeThis;
    int* escapeRef;

    escapeThis.assign(escapeRef, &local);

    return escapeRef;
}
