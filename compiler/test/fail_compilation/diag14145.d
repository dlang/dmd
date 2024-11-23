/*
TEST_OUTPUT:
---
fail_compilation/diag14145.d(24): Error: no property `i` for `_` of type `diag14145.main.Capture!(i)`
    _.i;
     ^
fail_compilation/diag14145.d(24):        potentially malformed `opDispatch`. Use an explicit instantiation to get a better error message
fail_compilation/diag14145.d(34):        struct `Capture` defined here
struct Capture(alias c)
^
fail_compilation/diag14145.d(43): Error: expression `*this.ptr` of type `shared(int)` is not implicitly convertible to return type `ref int`
        return *ptr;
               ^
fail_compilation/diag14145.d(25): Error: template instance `diag14145.main.Capture!(i).Capture.opDispatch!"i"` error instantiating
    _.opDispatch!"i";
     ^
---
*/

int main()
{
    int i;
    auto _ = capture!i;
    _.i;
    _.opDispatch!"i";
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
