/*
TEST_OUTPUT:
---
fail_compilation/ice11790.d(8): Error: cannot create a `string[string]` with `new`
---
*/

string[string] crash = new string[string];
