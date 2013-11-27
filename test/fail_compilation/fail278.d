/*
TEST_OUTPUT:
---
fail_compilation/fail278.d(12): Error: template instance NONEXISTENT!() template 'NONEXISTENT' is not defined
fail_compilation/fail278.d(13): Error: template instance fail278.F!() error instantiating
fail_compilation/fail278.d(14):        instantiated from here: Bar!(Foo)
fail_compilation/fail278.d(14): Error: template instance fail278.Bar!(Foo) error instantiating
---
*/

template Id(xs...) { const Id = xs[0]; }
template Foo() { mixin Id!(NONEXISTENT!()); }
template Bar(alias F) { const int Bar = F!(); }
alias Bar!(Foo) x;
