/*
EXTRA_FILES: imports/a11919.d
TEST_OUTPUT:
---
fail_compilation/ice11919.d(26): Error: initializer must be an expression, not `foo`
    @foo bool _foo;
     ^
fail_compilation/imports/a11919.d(4): Error: template instance `a11919.doBar!(Foo).doBar.zoo!(t)` error instantiating
        if (zoo!t.length == 0) {}
            ^
fail_compilation/imports/a11919.d(11):        instantiated from here: `doBar!(Foo)`
        doBar(b);
             ^
fail_compilation/ice11919.d(34):        instantiated from here: `doBar!(Bar)`
    bar.doBar;
       ^
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
