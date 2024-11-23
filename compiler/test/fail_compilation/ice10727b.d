// REQUIRED_ARGS: -c
// EXTRA_FILES: imports/foo10727b.d imports/stdtraits10727.d
/*
TEST_OUTPUT:
---
fail_compilation/imports/foo10727b.d(25): Error: undefined identifier `Frop`
class Foo : Frop {} // Frop is not defined
^
fail_compilation/imports/foo10727b.d(17): Error: template instance `foo10727b.CirBuff!(Foo)` error instantiating
    CirBuff!T _bar;
    ^
fail_compilation/imports/foo10727b.d(22):        instantiated from here: `Bar!(Foo)`
    Bar!Foo _foobar;
    ^
---
*/

import imports.foo10727b;
