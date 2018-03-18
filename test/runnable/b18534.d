// REQUIRED_ARGS: -O

auto blah(char ch) { return ch; }
auto foo(int i)
{
    return blah(i ? 'A' : 'A');
}
void main()
{
    auto c = foo(0);
    assert(c == 'A');
}
