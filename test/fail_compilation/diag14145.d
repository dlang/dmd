/*
TEST_OUTPUT:
---
fail_compilation/diag14145.d(32): Error: expression `*this.ptr` of type `shared(int)` is not implicitly convertible to return type `ref int`
fail_compilation/diag14145.d(13): Error: template instance `diag14145.main.Capture!(i).Capture.opDispatch!"i"` error instantiating
---
*/

int main()
{
    int i;
    auto _ = capture!i;
    _.i;                   // the semantic analyzer stops after erroring here
    _.opDispatch!"i";      // the semantic analyzer stops after issuing an error for the above line
    return 0;
}

auto capture(alias c)()
{
    return Capture!c(c);
}

struct Capture(alias c)
{
    shared typeof(c)* ptr;
    this(ref typeof(c) _c)
    {
        ptr = cast(shared)&c;
    }
    ref shared typeof(c) opDispatch(string s)()
    {
        return *ptr;
    }
}
