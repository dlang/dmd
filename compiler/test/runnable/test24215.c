// https://github.com/dlang/dmd/issues/24215
int foo(int x) { return x * 2; }
extern typeof(foo) bar;
extern __typeof(foo) baz;
extern __typeof__(foo) qux;
int bar(int x) { return foo(x) + 1; }
int baz(int x) { return foo(x) + 2; }
int qux(int x) { return foo(x) + 3; }
int main(void)
{
    if (bar(5) != 11) return 1;
    if (baz(5) != 12) return 2;
    if (qux(5) != 13) return 3;
    return 0;
}
