/*
TEST_OUTPUT:
---
fail_compilation/ice8630.d(13): Error: undefined identifier `v`
typeof(v) foo(R)(R v) { return map!(p=>p)(v); }
       ^
fail_compilation/ice8630.d(14): Error: template instance `ice8630.foo!(int[])` error instantiating
void main() { foo([1]); }
                 ^
---
*/
auto map(alias func, R)(R r) { return r; }
typeof(v) foo(R)(R v) { return map!(p=>p)(v); }
void main() { foo([1]); }
