/*
TEST_OUTPUT:
----
fail_compilation/ice9540.d(42): Error: function `dg` is not callable using argument types `()`
        dg.ptr = ctx;
        ^
fail_compilation/ice9540.d(42):        too few arguments, expected 1, got 0
fail_compilation/ice9540.d(39):        `ice9540.A.test.AddFront!(this, f).AddFront.dg(int __param_0)` declared here
        auto dg (Args dgArgs) {
             ^
fail_compilation/ice9540.d(33): Error: template instance `ice9540.A.test.AddFront!(this, f)` error instantiating
        test1 (&AddFront!(this, f));
                ^
----
*/

template Tuple(E...) { alias E Tuple; }
alias Tuple!(int) Args;

void main() {
    (new A).test ();
}

void test1 (int delegate (int) f) { f (-2); }

class A
{
    int f (int a) {
        return a;
    }

    void test () {
        test1 (&AddFront!(this, f));
    }
}

template AddFront (alias ctx, alias fun)  {
    auto AddFront(Args args) {
        auto dg (Args dgArgs) {
            return fun (dgArgs);
        }
        dg.ptr = ctx;
        return dg(args);
    }
}
