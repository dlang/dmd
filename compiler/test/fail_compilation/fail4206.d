/*
TEST_OUTPUT:
---
fail_compilation/fail4206.d(11): Error: initializer must be an expression, not `s`
enum var = s;
           ^
---
*/

struct s {}
enum var = s;

void main() {}
