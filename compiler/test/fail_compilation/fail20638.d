/*
EXTRA_FILES: imports/fail20638b.d
TEST_OUTPUT:
---
fail_compilation/fail20638.d(15): Error: undefined identifier `foo` in module `imports.fail20638b`
    imports.fail20638b.foo;
                      ^
---
*/
module fail20638;

import imports.fail20638b;

void main() {
    imports.fail20638b.foo;
}
