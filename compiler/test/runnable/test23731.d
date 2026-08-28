// https://github.com/dlang/dmd/issues/23731

import imports.test23731a;

void main()
{
    auto ti = typeid(Wrapper!int);
    auto a = Wrapper!int([1, 2]);
    auto b = Wrapper!int([1, 2]);
    assert(ti.equals(&a, &b));
    assert(ti.getHash(&a) == ti.getHash(&b));
}
