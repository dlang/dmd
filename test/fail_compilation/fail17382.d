/*
TEST_OUTPUT:
---
fail_compilation/fail17382.d(9): Error: Cannot pass argument `main()` to `pragma msg` because it is `void`
---
*/

void main() {}
pragma(msg, main());
