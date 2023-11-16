/*
TEST_OUTPUT:
---
fail_compilation/diag8101b.d(29): Error: none of the overloads of `foo` are callable using argument types `(double)`
fail_compilation/diag8101b.d(20):        Candidates are: `diag8101b.S.foo(int __param_0)`
fail_compilation/diag8101b.d(21):                        `diag8101b.S.foo(int __param_0, int __param_1)`
fail_compilation/diag8101b.d(31): Error: function `diag8101b.S.bar(int __param_0)` is not callable using argument types `(double)`
fail_compilation/diag8101b.d(31):        cannot pass argument `1.0` of type `double` to parameter `int __param_0`
fail_compilation/diag8101b.d(34): Error: none of the overloads of `foo` are callable using a `const` object
fail_compilation/diag8101b.d(20):        Candidates are: `diag8101b.S.foo(int __param_0)`
fail_compilation/diag8101b.d(21):                        `diag8101b.S.foo(int __param_0, int __param_1)`
fail_compilation/diag8101b.d(36): Error: mutable method `bar` is not callable using a `const` object
fail_compilation/diag8101b.d(23):        `diag8101b.S.bar(int __param_0)` declared here
fail_compilation/diag8101b.d(23):        Consider adding `const` or `inout`
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
