// Verify that UDAs on tuple parameters are propagated to their
// expanded elements during semantic analysis.

module test_uda_tuple_propagation;

struct UDA {}

auto testTwoElements(Args...)(@UDA Args args)
{
    static foreach (i; 0 .. Args.length)
        static assert(__traits(getAttributes, args[i]).length >= 1,
                      "UDA not propagated to expanded parameter " ~ i.stringof);
    args[0] = args[0].init;
}

void main()
{
    int a; string b;
    testTwoElements(a, b);
}
