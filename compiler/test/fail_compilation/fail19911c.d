/*
DFLAGS:
TEST_OUTPUT:
---
fail_compilation/fail19911c.d(16): Error: function `object.fun` `object.TypeInfo` could not be found, but is implicitly used in D-style variadic functions
void fun(...)
     ^
---
*/

module object;

class Object { }
class TypeInfo_Tuple { }

void fun(...)
{
}
