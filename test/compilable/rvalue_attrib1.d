// REQUIRED_ARGS: -preview=rvalueattribute

ref int get1();
@rvalue ref int get2();

void test()
{
    auto a = cast(@rvalue ref) get1();
    auto b = cast(@rvalue ref) get2();
    auto c = cast(@rvalue ref) cast(@rvalue ref) a;
}
