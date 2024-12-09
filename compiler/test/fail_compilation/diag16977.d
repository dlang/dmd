/*
TEST_OUTPUT:
---
fail_compilation/diag16977.d(37): Error: undefined identifier `undefined`, did you mean function `undefinedId`?
    void undefinedId(int x, int y = undefined) {}
                                    ^
fail_compilation/diag16977.d(38): Error: cannot implicitly convert expression `"\x01string"` of type `string` to `int`
    void badOp(int x, int y = 1 ~ "string") {}
                              ^
fail_compilation/diag16977.d(39): Error: template `templ` is not callable using argument types `!()(int)`
    void lazyTemplate(int x, lazy int y = 4.templ) {}
                                           ^
fail_compilation/diag16977.d(32):        Candidate is: `templ(S)(S s)`
  with `S = int`
  must satisfy the following constraint:
`       false`
string templ(S)(S s) if(false) { return null; }
       ^
fail_compilation/diag16977.d(40): Error: cannot implicitly convert expression `5` of type `int` to `string`
    void funcTemplate(T)(T y = 5) {}
                               ^
fail_compilation/diag16977.d(42): Error: template instance `diag16977.test.funcTemplate!string` error instantiating
    funcTemplate!string();
    ^
---
*/

// when copying the expression of a default argument, location information is
//   replaced by the location of the caller to improve debug information
// verify error messages are displayed for the original location only

string templ(S)(S s) if(false) { return null; }

void test()
{
    // local functions to defer evaluation into semantic3 pass
    void undefinedId(int x, int y = undefined) {}
    void badOp(int x, int y = 1 ~ "string") {}
    void lazyTemplate(int x, lazy int y = 4.templ) {}
    void funcTemplate(T)(T y = 5) {}

    funcTemplate!string();
    undefinedId(1);
    badOp(2);
    lazyTemplate(3);
}
