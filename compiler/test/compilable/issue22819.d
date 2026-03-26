extern(C++) struct S
{
    int opBinary(string op)(S rhs) if (op == "+")
    {
        return 0;
    }
    int opBinary(string op)(int rhs) if (op == "+")
    {
        return 0;
    }
    int opBinary(string op)(int rhs) if (op == "-")
    {
        return 0;
    }
}
size_t test()
{
    size_t count;
    static foreach (overload; __traits(getOverloads, S, "opBinary", true))
        static foreach(op; ["+", "-"])
            static if (__traits(compiles, overload!op))
            {
                cast(void)&overload!op;
                count++;
            }
    return count;
}
static assert(test() == 3);
