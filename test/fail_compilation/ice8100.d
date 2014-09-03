/*
TEST_OUTPUT:
---
fail_compilation/ice8100.d(11): Error: class ice8100.Bar!bool.Bar is forward referenced when looking for 'Q'
fail_compilation/ice8100.d(11): Error: template instance ice8100.Foo!(Bar!bool) error instantiating
fail_compilation/ice8100.d(12):        instantiated from here: Bar!bool
---
*/

class Foo(T1) { T1.Q r; }
class Bar(T2) : Foo!(Bar!T2) {}
Bar!bool b;
