// PERMUTE_ARGS:

// Tests calling unshared dtors from shared objects.
// See issues 12004 and 13174.

struct B
{
    ~this() {}
}

struct C
{
    shared B b;
}

class D
{
    ~this() {}
}

class E
{
    shared D d;

    this(shared D d) { this.d = d; }
}

void test12004()
{
    C(shared(B)());
    new E(new shared(D)()); 
}
