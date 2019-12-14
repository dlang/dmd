void main()
{
    auto x = 9223372036854775808; // long.max + 1
    static assert(is(typeof(x) == ulong));
}
