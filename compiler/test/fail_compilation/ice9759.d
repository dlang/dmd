/*
TEST_OUTPUT:
---
fail_compilation/ice9759.d(26): Error: mutable method `opAssign` is not callable using a `const` object
fail_compilation/ice9759.d(18):        `ice9759.Json.opAssign(Json v)` declared here
fail_compilation/ice9759.d(18):        Consider adding `const` or `inout`
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
