// REQUIRED_ARGS: -c
/*
TEST_OUTPUT:
---
fail_compilation/imports/foo10727b.d(9): Error: no property `length` for type `CirBuff!(Foo)`
fail_compilation/imports/foo10727b.d(17): Error: template instance `foo10727b.CirBuff!(Foo)` error instantiating
fail_compilation/imports/foo10727b.d(22):        instantiated from here: `Bar!(Foo)`
fail_compilation/imports/foo10727b.d(25): Error: undefined identifier `Frop`
---
*/

import imports.foo10727b;
