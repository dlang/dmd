/* TEST_OUTPUT:
---
fail_compilation/test22408.d(105): Error: mutable method `test22408.S.f` is not callable using a `const` object
fail_compilation/test22408.d(101):        Consider adding `const` or `inout` here
fail_compilation/test22408.d(106): Error: mutable method `test22408.S.f` is not callable using a `immutable` object
fail_compilation/test22408.d(101):        Consider adding `const` or `inout` here
fail_compilation/test22408.d(107): Error: non-shared method `test22408.S.f` is not callable using a `shared` object
fail_compilation/test22408.d(101):        Consider adding `shared` here
---
*/

// https://github.com/dlang/dmd/issues/22408

#line 100

struct S { void f() {} }

void main()
{
    with (const S())     { f(); }
    with (immutable S()) { f(); }
    with (shared S())    { f(); }
}
