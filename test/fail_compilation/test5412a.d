/*
TEST_OUTPUT:
---
fail_compilation/test5412a.d(10): Error: import `test5412a.A` conflicts with import `test5412a.A` at fail_compilation/test5412a.d(9)
---
*/
module test5412a;

import A = imports.test5412a;
import A = imports.test5412b;
