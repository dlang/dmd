//https://github.com/dlang/dmd/issues/22384
struct S
{
    int a = 1;
    int b : 16 = 2;
    int c : 16 = 3;
    int d = 4;
}

struct T
{
    int a = 1;       // .long 1
    int b : 4 = 2;   // .byte 0x32 (b=2, c=3 merged)
    int c : 4 = 3;
    int d : 8 = 4;   // .byte 0x04
    int e : 4 = 5;   // .byte 0x65 (e=5, f_low=6 merged)
    int f : 12 = 6;  // .byte 0x00 (f_high)
    int g = 7;       // .long 7
}

struct M
{
    int a : 4 = 1;
    int   : 4;
    int b : 4 = 2;
}

S s;
T t;
M m;

void main()
{
    assert(s.a == 1);
    assert(s.b == 2);
    assert(s.c == 3);
    assert(s.d == 4);

    assert(t.a == 1);
    assert(t.b == 2);
    assert(t.c == 3);
    assert(t.d == 4);
    assert(t.e == 5);
    assert(t.f == 6);
    assert(t.g == 7);

    assert(m.a == 1);
    assert(m.b == 2);
}
