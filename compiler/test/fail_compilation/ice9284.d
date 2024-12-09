/*
TEST_OUTPUT:
---
fail_compilation/ice9284.d(20): Error: template `__ctor` is not callable using argument types `!()(int)`
        this(10);
            ^
fail_compilation/ice9284.d(18):        Candidate is: `this()(string)`
    this()(string)
    ^
fail_compilation/ice9284.d(26): Error: template instance `ice9284.C.__ctor!()` error instantiating
    new C("hello");
    ^
---
*/

class C
{
    this()(string)
    {
        this(10);
        // delegating to a constructor which not exists.
    }
}
void main()
{
    new C("hello");
}
