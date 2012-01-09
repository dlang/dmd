
extern(C) int printf(const char*, ...);

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
    test7239();

    printf("Success\n");
    return 0;
}
