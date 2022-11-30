enum E { a, b, c, d }
static assert (() {
    E a = $a;
    E b = $b;
    return a == E.a && b == E.b;
} ());

enum XYZ { x, y, z }

XYZ intToXYZ(int i)
{
    switch(i)
    {
        case 1 : return $x;
        case 2 : return $y;
        case 3 : return $z;
        default:
    }

    return assert(0);
}

static assert(intToXYZ(2) == XYZ.y);

int XYZtoTint(XYZ xyz)
{
    switch(xyz)
    {
        case $x : return 1;
        case $y : return 2;
        case $z : return 3;
        default:
    }

    return assert(0);
}
static assert(XYZtoTint(XYZ.z) == 3);

enum E1 { a = 3 }
enum E2 { a = 17 }
enum E3 { a = 1 << 0,
          b = 1 << 1,
          c = 1 << 2 }

struct S
{
    E1 a;
    E2 b;
}

static assert(()
{
    S s = {a: $a, b: $a};
    return s.a + s.b;
} () == 20);

static assert(()
{
    E3 e3 = $c | $b;
    return e3;
} () == (E3.c | E3.b));

static assert(()
{
    E3[] e3 = [$c , $b];
    return e3[0] + e3[1];
} () == 6);

static assert(()
{
    enum A{ a,b,c }
    int[A] myMap = [$a : 1, $b: 24];
    return myMap[$b];
} () == 24);

private {
    enum A { a, b, e }
    int foo(A a) { return 1; }

    enum B { b, c }
    int foo(B b) { return 2; }

    static assert(foo($a) == 1, "inference overload resolution is broken");
    static assert(foo($c) == 2, "inference overload resolution is broken");
}

static assert(()
{
    int[E] a;
    a[$a] = 10;
    return a[$a];
} () == 10);

static assert(()
{
    struct Ind{
        int opIndex(E x, E y){ return cast(int)x; }
    }
    Ind a;
    return a[$b,$a];
} () == 1);

    /* Examples from DIP1044... */
static assert(()
{// Initializers and assignments
    enum A{ a,b,c,d }

    struct S{ A one, two; }

    A    myA1 = $b;
    A    myA2 = $b | $c;

    S myS;
    myS.one = $c;
    myS.two = $d;

    return true;
} ());

static assert(()
{// Return statements
    enum A{ a,b,c,d }

    A myFn(){
        return $c; //returns A.c
    }

    return true;
} ());

static assert(()
{// Argument lists
    enum A{ a,b,c,d }

    struct S{ A one, two; }

    void myFn(A param){}
    void myDefaultFn(A param=$d){}
    void myTempFn(T)(T param){}

    S    myS1 = {one: $a, two: $b};
    auto myS2 = S($a, $b);

    myFn($a);
    myFn($b + $b);

    myDefaultFn();
    myDefaultFn($c);

    myTempFn!A($a);


    return true;
} ());



static assert(()
{// Indexing
    enum A{ a,b,c,d }
    enum B{ e,f,g,h }

    struct S{
        int opIndex(A param){ return cast(int)param; };
    }

    int[A] myMap = [$a: 1, $b: 24, $c: -13, $d: 37];
    assert(myMap[$b] == 24);
    myMap[$b] += 1;
    auto x = myMap[$b];
    assert(x == 25);

    return true;
} ());
