// Use-after-GC (escaping heap reference).

struct S
{
    S* other;

    ~this()
    {
        // Dereferencing other GC-allocated values in a destructor is not allowed,
        // as the deallocation/destruction order is undefined,
        // and here even forms a loop.
        int dummy = other.other !is &this;
        result += dummy;
    }
}

__gshared int result; // Trick the optimizer

int makeBadInstances()
{
    auto a = new S;
    auto b = new S;
    a.other = b;
    b.other = a;
    return result;
}

int destroyStack()
{
    int[1000] x = result;
    return x[123];
}

int main()
{
    int x = makeBadInstances();
    x += destroyStack();
    return x;
}
