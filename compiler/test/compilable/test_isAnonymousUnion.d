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