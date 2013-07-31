// REQUIRED_ARGS: -c
/*
TEST_OUTPUT:
---
fail_compilation/imports/foo10727b.d(25): Error: undefined identifier Frop
fail_compilation/imports/foo10727b.d(17): Error: template instance foo10727b.CirBuff!(Foo) error instantiating
fail_compilation/imports/foo10727b.d(22):        instantiated from here: Bar!(Foo)
fail_compilation/imports/foo10727b.d(22): Error: template instance foo10727b.Bar!(Foo) error instantiating
---
*/

import imports.foo10727b;
