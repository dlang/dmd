// 5962

struct S
{
          auto g()(){ return 1; }
    const auto g()(){ return 2; }
}
void main()
{
    auto ms = S();
    assert(ms.g() == 1);
    auto cs = const(S)();
    assert(cs.g() == 2);
}
