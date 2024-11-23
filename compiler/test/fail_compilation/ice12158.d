/*
TEST_OUTPUT:
---
fail_compilation/ice12158.d(9): Error: module `object` import `nonexisting` not found
import object : nonexisting;
       ^
---
*/
import object : nonexisting;
auto x = nonexisting.init;
