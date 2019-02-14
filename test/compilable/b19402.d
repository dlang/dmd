module b19402;

// TODO: remove me once deprecation for 19402 finished
__EOF__

void main()
{
    {
        long x;
        auto a = 1 >>> x;
        static assert(is(typeof(a) == long));
        auto b = 1 << x;
        static assert(is(typeof(b) == long));
        auto c = 1 >> x;
        static assert(is(typeof(c) == long));
    }
    {
        ulong x;
        auto a = 1u >>> x;
        static assert(is(typeof(a) == ulong));
        auto b = 1u << x;
        static assert(is(typeof(b) == ulong));
        auto c = 1u >> x;
        static assert(is(typeof(c) == ulong));
    }
    {
        ulong x;
        auto a = 1 >>> x;
        static assert(is(typeof(a) == ulong));
        auto b = 1 << x;
        static assert(is(typeof(b) == ulong));
        auto c = 1 >> x;
        static assert(is(typeof(c) == ulong));
    }
    {
        long x;
        auto a = 1u >>> x;
        static assert(is(typeof(a) == long));
        auto b = 1u << x;
        static assert(is(typeof(b) == long));
        auto c = 1u >> x;
        static assert(is(typeof(c) == long));
    }
}
