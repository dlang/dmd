/*
TEST_OUTPUT:
---
fail_compilation/dip1029_2.d(211): Error: function `dip1029_2._t` is not `nothrow`
fail_compilation/dip1029_2.d(212): Error: function `dip1029_2.t` is not `nothrow`
fail_compilation/dip1029_2.d(213): Error: function `dip1029_2.n_t` is not `nothrow`
fail_compilation/dip1029_2.d(210): Error: `nothrow` function `dip1029_2.S1.foo` may throw
---
 */

#line 200

nothrow {
    void n_t() throw;
    void n_n();
}

void _t();
void t() throw;

struct S1 {
    nothrow void foo() {
        _t();
        t();
        n_t();
        n_n();
    }
}

