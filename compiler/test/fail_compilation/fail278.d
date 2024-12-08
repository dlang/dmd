/*
TEST_OUTPUT:
---
fail_compilation/fail278.d(17): Error: template instance `NONEXISTENT!()` template `NONEXISTENT` is not defined
template Foo() { mixin Id!(NONEXISTENT!()); }
                           ^
fail_compilation/fail278.d(18): Error: template instance `fail278.F!()` error instantiating
template Bar(alias F) { const int Bar = F!(); }
                                        ^
fail_compilation/fail278.d(19):        instantiated from here: `Bar!(Foo)`
alias Bar!(Foo) x;
      ^
---
*/

template Id(xs...) { const Id = xs[0]; }
template Foo() { mixin Id!(NONEXISTENT!()); }
template Bar(alias F) { const int Bar = F!(); }
alias Bar!(Foo) x;
