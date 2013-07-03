module imports.template_ovs1;

/***************************************************/
// 1900 - template overload set

auto foo1900a(int num) { return 1; }
auto foo1900b(T)(T arg) if (is(T : const(char)[])) { return 2; }

auto bar1900a(T)(T arg) if (is(T : double)) { return 1; }
auto bar1900b(T)(T arg) if (is(T : const(char)[])) { return 2; }

auto baz1900(T)(T arg) if (is(T : double)) { return 1; }
auto baz1900(T)(T arg) if (is(T : int[int])) { return 2; }

auto bad1900(string op)() if (op == "++") { return 1; }

mixin template Mix1900_A()
{
    auto mixfooa() { return 1; }
    auto mixfoob(T)(T) { return 2; }

    mixin Mix1900_SubA;
}

mixin template Mix1900_SubA()
{
    auto mixsubfooa() { return 1; }
    auto mixsubfoob(T)(T) { return 2; }
}

auto merge1900(T)(int)
{
    return 1;
}
