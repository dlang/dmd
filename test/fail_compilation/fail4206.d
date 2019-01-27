/*
TEST_OUTPUT:
---
fail_compilation/fail4206.d(9): Error: cannot interpret `s` at compile time
---
*/

struct s {}
enum var = s;

void main() {}
