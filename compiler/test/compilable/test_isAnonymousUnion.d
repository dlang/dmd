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
static assert(__traits(isAnonymousUnion, S1.x));
static assert(__traits(isAnonymousUnion, S1.y));
static assert(!__traits(isAnonymousUnion, S1.a));
static assert(!__traits(isAnonymousUnion, S1.b));

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
static assert(!__traits(isAnonymousUnion, S2.u));

// Anonymous struct (not a union)
struct S3
{
    struct
    {
        int x;
        float y;
    }
}
static assert(!__traits(isAnonymousUnion, S3.x));
static assert(!__traits(isAnonymousUnion, S3.y));

// Nested case: anonymous union INSIDE a named union
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
static assert(!__traits(isAnonymousUnion, S4.outer));
static assert(__traits(isAnonymousUnion, S4.Outer.nested1));
static assert(__traits(isAnonymousUnion, S4.Outer.nested2));
static assert(!__traits(isAnonymousUnion, S4.Outer.x));

// Class with anonymous union
class C1
{
    union
    {
        int x;
        float y;
    }
}
static assert(__traits(isAnonymousUnion, C1.x));
static assert(__traits(isAnonymousUnion, C1.y));

// Non-field arguments should return false (not error)
static assert(!__traits(isAnonymousUnion, S1));    // aggregate type
static assert(!__traits(isAnonymousUnion, int));   // type
static assert(!__traits(isAnonymousUnion, 42));    // literal value

// Deeply nested anonymous unions within anonymous structs
struct S5
{
    union
    {
        int x;
        struct
        {
            union
            {
                int y;
                float z;
            }
        }
    }
}
static assert(__traits(isAnonymousUnion, S5.x));  // outer anonymous union
static assert(__traits(isAnonymousUnion, S5.y));  // inner anonymous union
static assert(__traits(isAnonymousUnion, S5.z));  // inner anonymous union
