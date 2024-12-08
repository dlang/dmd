module b20875;

/*
TEST_OUTPUT:
---
fail_compilation/b20875.d(34): Error: template instance `Foo!int` does not match template declaration `Foo(alias T : None!U, U...)`
static assert( Foo!(int));
               ^
fail_compilation/b20875.d(34):        while evaluating: `static assert(Foo!int)`
static assert( Foo!(int));
^
fail_compilation/b20875.d(35): Error: template instance `Bar!int` does not match template declaration `Bar(alias T : None!U, U...)`
static assert(!Bar!(int));
               ^
fail_compilation/b20875.d(35):        while evaluating: `static assert(!Bar!int)`
static assert(!Bar!(int));
^
fail_compilation/b20875.d(38): Error: template parameter specialization for a type must be a type and not `NotAType()`
enum Baz(alias T : NotAType) = false;
               ^
fail_compilation/b20875.d(39):        while looking for match for `Baz!int`
static assert(!Baz!(int));
               ^
fail_compilation/b20875.d(39):        while evaluating: `static assert(!Baz!int)`
static assert(!Baz!(int));
^
---
*/

// Line 7 starts here

enum Foo(alias T : None!U, U...) = true;
enum Bar(alias T : None!U, U...) = false;
static assert( Foo!(int));
static assert(!Bar!(int));

template NotAType(){}
enum Baz(alias T : NotAType) = false;
static assert(!Baz!(int));

void main(){}
