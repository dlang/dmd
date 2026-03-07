struct Infidel(T)
{
    T value;
    T get() { return value; } // returns a copy
}

void main()
{
    static struct S
    {
        int x;
        this(this)
        {
            if (x > 0) throw new Exception("fail");
            else x = 1;
        }
    }

    // passes, cannot nothrow-copy
    static assert(!is(typeof(() nothrow { S* x; union U { S x; } U u = U(*x); })));

    // passes, copy may throw
    static assert(is(typeof(() { S* x; union U { S x; } U u = U(*x); })));

    S s;
    auto sneak = Infidel!S(s); // won't throw here, s.x was 0

    // should pass
    static assert(!is(typeof(() nothrow { auto x = sneak.get(); })));
}
