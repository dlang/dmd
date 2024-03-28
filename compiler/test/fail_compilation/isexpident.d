/* TEST_OUTPUT:
---
fail_compilation/isexpident.d(11): Error: can only declare type aliases within `static if` conditionals or `static assert`s
fail_compilation/isexpident.d(12): Error: can only declare type aliases within `static if` conditionals or `static assert`s
fail_compilation/isexpident.d(14): Error: can only declare type aliases within `static if` conditionals or `static assert`s
fail_compilation/isexpident.d(15): Error: can only declare type aliases within `static if` conditionals or `static assert`s
---
*/
void main()
{
    enum e = is(int Int);
    assert(is(int Int1 == const));

    if (is(int Int2)) {}
    auto x = is(int Int3 : float);
}
