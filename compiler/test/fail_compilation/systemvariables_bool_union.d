/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/systemvariables_bool_union.d(23): Deprecation: cannot access overlapped field `Box.b` with unsafe bit patterns in `@safe` code
    return u.b;
           ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24477

bool schrodingersCat() @safe
{
    union Box
    {
        bool b;
        ubyte y;
    }

    Box u;
    u.y = 2;
    return u.b;
}
