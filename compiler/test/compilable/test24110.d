// https://issues.dlang.org/show_bug.cgi?id=24110

struct S { int x; }
alias T = shared S;
static assert(__traits(compiles, (T[] a, T[] b) => a < b));
bool foo(T[] a, T[] b) { return a < b; }
