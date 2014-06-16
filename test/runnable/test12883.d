static struct S
{
    int x;
    void* dummy;
    @property S mutable() const {return S(42);}
    alias mutable this;
}
void main()
{
    const c = S(13);

    S m1 = c;
    assert(m1.x == 42);

    S m2;
    m2 = c;
    assert(m2.x == 42);

    static void f(S s) {assert(s.x == 42);}
    f(c);
}
