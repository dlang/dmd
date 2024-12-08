/*
EXTRA_FILES: imports/a14235.d
TEST_OUTPUT:
---
fail_compilation/diag14235.d(18): Error: undefined identifier `Undefined` in module `imports.a14235`
imports.a14235.Undefined!Object a;
                                ^
fail_compilation/diag14235.d(19): Error: undefined identifier `Something` in module `imports.a14235`, did you mean struct `SomeThing(T...)`?
imports.a14235.Something!Object b;
                                ^
fail_compilation/diag14235.d(20): Error: `SomeClass` isn't a template
imports.a14235.SomeClass!Object c;
                                ^
---
*/

import imports.a14235;
imports.a14235.Undefined!Object a;
imports.a14235.Something!Object b;
imports.a14235.SomeClass!Object c;
