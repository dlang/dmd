
extern(C) int printf(const char*, ...);

/***************************************************/
// 6475

class Foo6475(Value)
{
    template T1(size_t n){ alias int T1; }
}

void test6475()
{
    alias Foo6475!(int) C2;
    alias C2.T1!0 a1;
}

/***************************************************/
// 7239

struct vec7239
{
    float x, y, z, w;
    alias x r;  //! for color access
    alias y g;  //! ditto
    alias z b;  //! ditto
    alias w a;  //! ditto
}

void test7239()
{
    vec7239 a = {x: 0, g: 0, b: 0, a: 1};
    assert(a.r == 0);
    assert(a.g == 0);
    assert(a.b == 0);
    assert(a.a == 1);
}

/***************************************************/

int main()
{
    test6475();
    test7239();

    printf("Success\n");
    return 0;
}
