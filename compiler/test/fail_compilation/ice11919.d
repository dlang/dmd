/*
EXTRA_FILES: imports/a11919.d
TEST_OUTPUT:
---
fail_compilation/ice11919.d(19): Error: initializer must be an expression, not `foo`
fail_compilation/imports/a11919.d(16):        used in initialization here
fail_compilation/imports/a11919.d(4): Error: template instance `a11919.doBar!(Foo).doBar.zoo!(t)` error instantiating
fail_compilation/imports/a11919.d(11):        instantiated from here: `doBar!(Foo)`
fail_compilation/ice11919.d(27):        instantiated from here: `doBar!(Bar)`
---
*/

import imports.a11919;

enum foo;

class Foo
{
    @foo bool _foo;
}

class Bar : Foo {}

void main()
{
    auto bar = new Bar();
    bar.doBar;
}
