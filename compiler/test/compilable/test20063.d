/* TEST_OUTPUT:
---
compilable/test20063.d(14): Deprecation: function `test20063.main.f!(delegate () pure nothrow @safe => new C).f` function requires a dual-context, which is deprecated
    void f(alias fun)() {}
         ^
compilable/test20063.d(23):        instantiated from here: `f!(delegate () pure nothrow @safe => new C)`
    S().f!(() => new C()).handleLazily;
       ^
---
*/

struct S
{
    void f(alias fun)() {}
}

auto handleLazily(T)(lazy T expr) {}

void main()
{
    class C {}

    S().f!(() => new C()).handleLazily;
}
