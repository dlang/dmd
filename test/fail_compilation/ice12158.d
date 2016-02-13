/*
TEST_OUTPUT:
---
fail_compilation/ice12158.d(8): Error: module object import 'nonexisting' not found
fail_compilation/ice12158.d(9): Error: undefined identifier 'nonexisting'
---
*/
import object : nonexisting;
auto x = nonexisting.init;
