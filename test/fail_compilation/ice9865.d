/*
TEST_OUTPUT:
---
fail_compilation/ice9865.d(10): Error: undefined identifier 'Baz'
fail_compilation/ice9865.d(9): Error: module ice9865b import 'Baz' not found, did you mean class 'Bar'?
---
*/

import imports.ice9865b : Baz;
struct Foo { Baz f; }
