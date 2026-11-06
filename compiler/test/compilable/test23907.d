// https://github.com/dlang/dmd/issues/23907
// ICE: inout substitution through an enum base type

enum E : inout(int)[] { a = null }

E f(inout(int)[] x) { return E.a; }

void g()
{
    int[] a;
    auto r = f(a);
}
