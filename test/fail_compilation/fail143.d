class Quux {
    uint x;

    final uint next ()
    {
        return x;
    }
}

template Foo(T) {
    void bar()
    {
        int r = Quux.next;
    }
}

int main(char[][] args)
{
    auto prng = new Quux();
    alias Foo!(int).bar baz;

    int x = prng.next;
    baz();

    return 0;
}

