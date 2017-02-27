unittest
{
    alias T = int[10];
    auto a = new T;
    static assert(is(typeof(a) == int[10]*));
}
