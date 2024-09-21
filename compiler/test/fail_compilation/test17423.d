/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test17423.d(28): Error: reference to local `this` assigned to non-scope parameter `dlg` calling `opApply`
fail_compilation/test17423.d(17):        which is not `scope` because of `this.myDlg = dlg`
fail_compilation/test17423.d(27): Error: constructor `test17423.Foo.this` cannot close over `ref` variable `this`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17423

struct Bar
{
    int delegate(int) @safe myDlg;

    auto opApply(int delegate(int) @safe dlg) @safe {
        myDlg = dlg;
        return 0;
    }
}

struct Foo
{
    Bar o;
    int i = 3;

    this(int x) @safe {
        foreach(_; o) { i = 0; }
        i = x;
    }
}
