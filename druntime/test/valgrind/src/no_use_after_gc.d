// Use-after-GC (escaping heap reference).

struct S
{
    S* other;

    ~this()
    {
        // Dereferencing other GC-allocated values in a destructor is not allowed,
        // as the deallocation/destruction order is undefined,
        // and here even forms a loop.
        assert(other.other is &this);
    }
}

void main()
{
    auto a = new S;
    auto b = new S;
    a.other = b;
    b.other = a;
}
