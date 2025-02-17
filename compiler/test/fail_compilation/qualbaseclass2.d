/* TEST_OUTPUT:
---
fail_compilation\qualbaseclass2.d(103): Error: basic type expected, not `const`
fail_compilation\qualbaseclass2.d(103): Error: `{ members }` expected for anonymous class
fail_compilation\qualbaseclass2.d(103): Error: semicolon expected following auto declaration, not `const`
fail_compilation/qualbaseclass2.d(103): Error: variable name expected after type `const(Object)`, not `{`
---
 */

#line 100

void test()
{
    auto obj = new class () const(Object) { };
}
