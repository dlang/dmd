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

// Anonymous union fields are overlapped
static assert(__traits(isOverlapped, S1.x));
static assert(__traits(isOverlapped, S1.y));
// Regular fields are not overlapped
static assert(!__traits(isOverlapped, S1.a));
static assert(!__traits(isOverlapped, S1.b));

// Named union as a field type
struct S2
{
    union U
    {
        int x;
        float y;
    }
    U u;
}
// The instance 'u' itself is not overlapped (it's a regular field)
static assert(!__traits(isOverlapped, S2.u));
static assert(__traits(isOverlapped, S2.U.x));
static assert(__traits(isOverlapped, S2.U.y));

// Named union accessed directly - its fields are overlapped
union NamedUnion
{
    int x;
    float y;
}
static assert(__traits(isOverlapped, NamedUnion.x));
static assert(__traits(isOverlapped, NamedUnion.y));

// Anonymous struct (not a union) - fields are NOT overlapped
struct S3
{
    struct
    {
        int x;
        float y;
    }
}
static assert(!__traits(isOverlapped, S3.x));
static assert(!__traits(isOverlapped, S3.y));

// Named union with nested anonymous union
struct S4
{
    union Outer
    {
        int x;  // This IS overlapped (it's in a named union)
        // Anonymous union nested inside the named union Outer
        union
        {
            int nested1;
            float nested2;
        }
    }
    Outer outer;
}
static assert(!__traits(isOverlapped, S4.outer));       // regular field, not overlapped
static assert(__traits(isOverlapped, S4.Outer.nested1)); // in union (both named and anonymous)
static assert(__traits(isOverlapped, S4.Outer.nested2)); // in union (both named and anonymous)
static assert(__traits(isOverlapped, S4.Outer.x));      // in named union - NOW true!

// Class with anonymous union
class C1
{
    union
    {
        int x;
        float y;
    }
}
static assert(__traits(isOverlapped, C1.x));
static assert(__traits(isOverlapped, C1.y));

// Non-field arguments should return false (not error)
static assert(!__traits(isOverlapped, S1));    // aggregate type
static assert(!__traits(isOverlapped, int));   // type
static assert(!__traits(isOverlapped, 42));    // literal value

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
static assert(__traits(isOverlapped, S5.x));  // outer anonymous union
static assert(__traits(isOverlapped, S5.y));  // inner anonymous union
static assert(__traits(isOverlapped, S5.z));  // inner anonymous union

// Union as top-level type
union TopLevelUnion1
{
    int a;
    float b;
    struct
    {
        int c;
        int d;
    }
}
static assert(__traits(isOverlapped, TopLevelUnion1.a));
static assert(__traits(isOverlapped, TopLevelUnion1.b));
static assert(__traits(isOverlapped, TopLevelUnion1.c));
static assert(!__traits(isOverlapped, TopLevelUnion1.d));

union TopLevelUnion2
{
    int a;
    double b;
    struct
    {
        int c;
        int d; // Now d is overlapped with b
    }
}
static assert(__traits(isOverlapped, TopLevelUnion2.a));
static assert(__traits(isOverlapped, TopLevelUnion2.b));
static assert(__traits(isOverlapped, TopLevelUnion2.c));
static assert(__traits(isOverlapped, TopLevelUnion2.d));

// Bug #22621
struct Bug22621
{
    struct D
    {
        void* ptr;
    }

    union
    {
        struct
        {
            D d;
        }
        uint b;
    }
}
static assert(__traits(isOverlapped, Bug22621.b));
// Bug #22621: DMD correctly detects that d is overlapped, but the destructor
// logic doesn't properly handle it - it calls d's destructor even when only b was initialized
static assert(__traits(isOverlapped, Bug22621.d));  // Correctly detected!

// Struct with both overlapped and non-overlapped fields
struct S6
{
    int regular1;
    union
    {
        int overlapped1;
        float overlapped2;
    }
    int regular2;
}
static assert(!__traits(isOverlapped, S6.regular1));
static assert(__traits(isOverlapped, S6.overlapped1));
static assert(__traits(isOverlapped, S6.overlapped2));
static assert(!__traits(isOverlapped, S6.regular2));
