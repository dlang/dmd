// REQUIRED_ARGS: -verrors=simple
/* TEST_OUTPUT:
---
compilable/test20063.d(11): Deprecation: function `test20063.main.f!(delegate () pure nothrow @safe => new C).f` function requires a dual-context, which is deprecated
compilable/test20063.d(20):        instantiated from here: `f!(delegate () pure nothrow @safe => new C)`
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
