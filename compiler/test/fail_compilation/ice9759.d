/*
TEST_OUTPUT:
---
fail_compilation/ice9759.d(29): Error: mutable method `ice9759.Json.opAssign` is not callable using a `const` object
    r = r.init;
      ^
fail_compilation/ice9759.d(21):        Consider adding `const` or `inout` here
    void opAssign(Json v)
         ^
---
*/

struct Json
{
    union
    {
        Json[] m_array;
        Json[string] m_object;
    }

    void opAssign(Json v)
    {
    }
}

void bug()
{
    const(Json) r;
    r = r.init;
}
