// https://issues.dlang.org/show_bug.cgi?id=23108
/* TEST_OUTPUT:
---
fail_compilation/fail23108a.d(11): Error: undefined identifier `_xopEquals` in module `object`
struct Interface
^
---
*/
module object;

struct Interface
{
    void[] vtbl;
}

class TypeInfo
{
}
