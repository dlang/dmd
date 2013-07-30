// REQUIRED_ARGS: -c
/*
TEST_OUTPUT:
---
fail_compilation/imports/foo10727a.d(34): Error: undefined identifier Frop
fail_compilation/imports/foo10727a.d(26): Error: template instance foo10727a.CirBuff!(Foo) error instantiating
fail_compilation/imports/foo10727a.d(31):        instantiated from here: Bar!(Foo)
fail_compilation/imports/foo10727a.d(31): Error: template instance foo10727a.Bar!(Foo) error instantiating
---
*/

import imports.foo10727a;
