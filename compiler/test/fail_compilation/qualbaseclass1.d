/* TEST_OUTPUT:
---
fail_compilation\qualbaseclass1.d(101): Error: basic type expected, not `const`
fail_compilation\qualbaseclass1.d(101): Error: { } expected following `class` declaration
fail_compilation\qualbaseclass1.d(101): Error: variable name expected after type `const(Object)`, not `{`
fail_compilation\qualbaseclass1.d(101): Error: declaration expected, not `{`
---
 */

#line 100

class C : const(Object) { }
