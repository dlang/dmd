
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
