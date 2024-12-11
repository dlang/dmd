/*
TEST_OUTPUT:
---
fail_compilation/diag8101b.d(46): Error: none of the overloads of `foo` are callable using argument types `(double)`
    s.foo(1.0);
         ^
fail_compilation/diag8101b.d(37):        Candidates are: `diag8101b.S.foo(int __param_0)`
    void foo(int) { }
         ^
fail_compilation/diag8101b.d(38):                        `diag8101b.S.foo(int __param_0, int __param_1)`
    void foo(int, int) { }
         ^
fail_compilation/diag8101b.d(48): Error: function `diag8101b.S.bar(int __param_0)` is not callable using argument types `(double)`
    s.bar(1.0);
         ^
fail_compilation/diag8101b.d(48):        cannot pass argument `1.0` of type `double` to parameter `int __param_0`
fail_compilation/diag8101b.d(51): Error: none of the overloads of `foo` are callable using a `const` object with argument types `(int)`
    cs.foo(1);
          ^
fail_compilation/diag8101b.d(37):        Candidates are: `diag8101b.S.foo(int __param_0)`
    void foo(int) { }
         ^
fail_compilation/diag8101b.d(38):                        `diag8101b.S.foo(int __param_0, int __param_1)`
    void foo(int, int) { }
         ^
fail_compilation/diag8101b.d(53): Error: mutable method `diag8101b.S.bar` is not callable using a `const` object
    cs.bar(1);
          ^
fail_compilation/diag8101b.d(40):        Consider adding `const` or `inout` here
    void bar(int) { }
         ^
---
*/

struct S
{
    void foo(int) { }
    void foo(int, int) { }

    void bar(int) { }
}

void main()
{
    S s;
    s.foo(1.0);

    s.bar(1.0);

    const(S) cs;
    cs.foo(1);

    cs.bar(1);
}
