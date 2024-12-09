/*
EXTRA_FILES: imports/fail1900a.d imports/fail1900b.d
TEST_OUTPUT:
---
fail_compilation/fail1900.d(51): Error: template `fail1900.Mix1a!().Foo` matches more than one template declaration:
    alias x = Foo!1;
              ^
fail_compilation/fail1900.d(38):        `Foo(ubyte x)`
and:
    template Foo(ubyte x) {}
    ^
fail_compilation/fail1900.d(39):        `Foo(byte x)`
    template Foo(byte x) {}
    ^
fail_compilation/fail1900.d(59): Error: `Bar` matches conflicting symbols:
    enum x = Bar!1;
             ^
fail_compilation/imports/fail1900b.d(2):        template `imports.fail1900b.Bar(short n)`
template Bar(short n) { enum Bar = n; }
^
fail_compilation/imports/fail1900a.d(2):        template `imports.fail1900a.Bar(int n)`
template Bar(int n) { enum Bar = n; }
^
fail_compilation/fail1900.d(77): Error: `Baz` matches conflicting symbols:
    alias x = Baz!1;
              ^
fail_compilation/fail1900.d(69):        template `fail1900.Mix2b!().Baz(int x)`
    template Baz(int x) {}
    ^
fail_compilation/fail1900.d(65):        template `fail1900.Mix2a!().Baz(byte x)`
    template Baz(byte x) {}
    ^
---
*/

template Mix1a()
{
    template Foo(ubyte x) {}
    template Foo(byte x) {}
}
template Mix1b()
{
    template Foo(int x) {}
}

mixin Mix1a;
mixin Mix1b;

void test1900a()
{
    alias x = Foo!1;
}

import imports.fail1900a;
import imports.fail1900b;

void test1900b()
{
    enum x = Bar!1;
}


template Mix2a()
{
    template Baz(byte x) {}
}
template Mix2b()
{
    template Baz(int x) {}
}

mixin Mix2a;
mixin Mix2b;

void test1900c()
{
    alias x = Baz!1;
}
