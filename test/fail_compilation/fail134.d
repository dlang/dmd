// 651

void f() {}
template foo(T) {}
template bar(T...){ alias foo!(T) buz; }
alias bar!(f) a;

