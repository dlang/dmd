/*
TEST_OUTPUT:
---
fail_compilation/ice8100.d(19): Error: no property `Q` for type `ice8100.Bar!bool`
class Foo(T1) { T1.Q r; }
                     ^
fail_compilation/ice8100.d(20):        class `Bar` defined here
class Bar(T2) : Foo!(Bar!T2) {}
^
fail_compilation/ice8100.d(20): Error: template instance `ice8100.Foo!(Bar!bool)` error instantiating
class Bar(T2) : Foo!(Bar!T2) {}
                ^
fail_compilation/ice8100.d(21):        instantiated from here: `Bar!bool`
Bar!bool b;
^
---
*/

class Foo(T1) { T1.Q r; }
class Bar(T2) : Foo!(Bar!T2) {}
Bar!bool b;
