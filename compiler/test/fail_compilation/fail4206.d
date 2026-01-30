/*
TEST_OUTPUT:
---
fail_compilation/fail4206.d(10): Error: initializer must be an expression, not `s`
fail_compilation/fail4206.d(10):        perhaps use `s()` to construct a value of the type
---
*/

struct s {}
enum var = s;

void main() {}
