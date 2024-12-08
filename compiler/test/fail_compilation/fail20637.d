/*
EXTRA_FILES: imports/fail20637b.d
TEST_OUTPUT:
---
fail_compilation/fail20637.d(17): Error: no property `foo` for type `imports.fail20637b.A`
void main() { A.foo; }
              ^
fail_compilation/imports/fail20637b.d(3):        class `A` defined here
class A { private static void foo() { } }
^
---
*/
module fail20637;

import imports.fail20637b;

void main() { A.foo; }
