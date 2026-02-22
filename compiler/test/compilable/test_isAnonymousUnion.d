// REQUIRED_ARGS:

struct S1
{
    int a;
    union
    {
        int x;
        float y;
    }
    int b;
}

// Basic anonymous union detection
static assert(__traits(isAnonymousUnion, S1, S1.x));
static assert(__traits(isAnonymousUnion, S1, S1.y));
static assert(!__traits(isAnonymousUnion, S1, S1.a));
static assert(!__traits(isAnonymousUnion, S1, S1.b));

// Named union (not anonymous)
struct S2
{
    union U
    {
        int x;
        float y;
    }
    U u;
}
static assert(!__traits(isAnonymousUnion, S2, S2.u));

// Anonymous struct (not a union)
struct S3
{
    struct
    {
        int x;
        float y;
    }
}
static assert(!__traits(isAnonymousUnion, S3, S3.x));
static assert(!__traits(isAnonymousUnion, S3, S3.y));

// Nested case: anonymous union INSIDE a named union (limitation test)
struct S4
{
    union Outer
    {
        int x;
        // Anonymous union nested inside the named union Outer
        union
        {
            int nested1;
            float nested2;
        }
    }
    Outer outer;
}
static assert(!__traits(isAnonymousUnion, S4, S4.outer));
static assert(__traits(isAnonymousUnion, S4.Outer, S4.outer.nested1));
static assert(__traits(isAnonymousUnion, S4.Outer, S4.outer.nested2));
static assert(!__traits(isAnonymousUnion, S4.Outer, S4.outer.x));

// Class with anonymous union
class C1
{
    union
    {
        int x;
        float y;
    }
}
static assert(__traits(isAnonymousUnion, C1, C1.x));
static assert(__traits(isAnonymousUnion, C1, C1.y));
