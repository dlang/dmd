/*
TEST_OUTPUT:
---
fail_compilation/test5412b.d(10): Error: static import `test5412b.A` conflicts with import `test5412b.A` at fail_compilation/test5412b.d(9)
---
*/
module test5412b;

import A = imports.test5412a;
static import A = imports.test5412b;
