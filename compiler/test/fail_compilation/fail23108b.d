// https://issues.dlang.org/show_bug.cgi?id=23108
/* TEST_OUTPUT:
---
fail_compilation/fail23108b.d(14): Error: undefined identifier `_xopEquals` in module `object`
struct Interface
^
fail_compilation/fail23108b.d(14): Error: undefined identifier `_xopCmp` in module `object`
struct Interface
^
---
*/
module object;

struct Interface
{
    void[] vtbl;
    int opCmp() { return 0; }
}

class TypeInfo
{
}
