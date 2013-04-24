
import std.c.stdio;

void testgoto()
{
    int i;

    i = 3;
    goto L4;
L3: i++;
    goto L5;
L4: goto L3;
L5: assert(i == 4);
}

int testswitch()
{
    int i;

    i = 3;
    switch (i)
    {
	case 0:
	case 1:
	default:
	    assert(0);
	case 3:
	    break;
    }
    return 0;
}

void testdo()
{
    int x = 0;

    do
    {
	x++;
    } while (x < 10);
    printf("x == %d\n", x);
    assert(x == 10);
}


void testbreak()
{   int i, j;

  Louter:
    for (i = 0; i < 10; i++)
    {
	for (j = 0; j < 10; j++)
	{
	    if (j == 3)
		break Louter;
	}
    }

    printf("i = %d, j = %d\n", i, j);
    assert(i == 0);
    assert(j == 3);
}

///////////////////////

int foo(string s)
{
    int i;

    i = 0;
    switch (s)
    {
	case "hello":
	    i = 1;
	    break;
	case "goodbye":
	    i = 2;
	    break;
	case "goodb":
	    i = 3;
	    break;
	default:
	    i = 10;
	    break;
    }
    return i;
}


void teststringswitch()
{   int i;

    i = foo("hello");
    printf("i = %d\n", i);
    assert(i == 1);

    i = foo("goodbye");
    printf("i = %d\n", i);
    assert(i == 2);

    i = foo("goodb");
    printf("i = %d\n", i);
    assert(i == 3);

    i = foo("huzzah");
    printf("i = %d\n", i);
    assert(i == 10);
}


///////////////////////

struct Foo
{
    int a;
    char b;
    long c;
}

Foo test(Foo f)
{
    f.a += 1;
    f.b += 3;
    f.c += 4;
    return f;
}


void teststrarg()
{
    Foo g;
    g.a = 1;
    g.b = 2;
    g.c = 3;

    Foo q;
    q = test(g);
    assert(q.a == 2);
    assert(q.b == 5);
    assert(q.c == 7);
}

///////////////////////

align (1) struct Foo1
{
  align (1):
    int a;
    char b;
    long c;
}

struct Foo2
{
    int a;
    char b;
    long c;
}

struct Foo3
{
    int a;
    align (1) char b;
    long c;
}

struct Foo4
{
    int a;
    struct { char b; }
    long c;
}

void testsizes()
{
    printf("%d\n", Foo1.sizeof);
    assert(Foo1.a.offsetof == 0);
    assert(Foo1.b.offsetof == 4);
    assert(Foo1.c.offsetof == 5);
    assert(Foo1.sizeof == 13);

    assert(Foo2.a.offsetof == 0);
    assert(Foo2.b.offsetof == 4);
    assert(Foo2.c.offsetof == 8);
    assert(Foo2.sizeof == 16);

    assert(Foo3.a.offsetof == 0);
    assert(Foo3.b.offsetof == 4);
    assert(Foo3.c.offsetof == 8);
    assert(Foo3.b.sizeof == 1);
    assert(Foo3.sizeof == 16);

    assert(Foo4.sizeof == 16);
}

///////////////////////

int array1[3] = [1:1,2,0:3];

void testarrayinit()
{
    assert(array1[0] == 3);
    assert(array1[1] == 1);
    assert(array1[2] == 2);
}

///////////////////////

struct U { int a; union { char c; int d; } long b; }

U f = { b:3, d:2, a:1 };

void testU()
{
    assert(f.b == 3);
    assert(f.d == 2);
    assert(f.c == 2);
    assert(f.a == 1);
    assert(f.sizeof == 16);
    assert(U.sizeof == 16);
}


///////////////////////

void testulldiv()
{
    __gshared ulong[4][] vectors =
    [
	[10,3,3,1],
	[10,1,10,0],
	[3,10,0,3],
	[10,10,1,0],
	[10_000_000_000L, 11_000_000_000L, 0, 10_000_000_000L],
	[11_000_000_000L, 10_000_000_000L, 1, 1_000_000_000L],
	[11_000_000_000L, 11_000_000_000L, 1, 0],
	[10_000_000_000L, 10, 1_000_000_000L, 0],
	[0x8000_0000_0000_0000, 0x8000_0000_0000_0000, 1, 0],
	[0x8000_0000_0000_0001, 0x8000_0000_0000_0001, 1, 0],
	[0x8000_0001_0000_0000, 0x8000_0001_0000_0000, 1, 0],
	[0x8000_0001_0000_0000, 0x8000_0000_0000_0000, 1, 0x1_0000_0000],
	[0x8000_0001_0000_0000, 0x8000_0000_8000_0000, 1, 0x8000_0000],
	[0x8000_0000_0000_0000, 0x7FFF_FFFF_FFFF_FFFF, 1, 1],
	[0x8000_0000_0000_0000, 0x8000_0000_0000_0001, 0, 0x8000_0000_0000_0000],
	[0x8000_0000_0000_0000, 0x8000_0001_0000_0000, 0, 0x8000_0000_0000_0000],
    ];

    for (size_t i = 0; i < vectors.length; i++)
    {
	ulong q = vectors[i][0] / vectors[i][1];
	if (q != vectors[i][2])
	    printf("[%d] %lld / %lld = %lld, should be %lld\n",
		vectors[i][0], vectors[i][1], q, vectors[i][2]);

	ulong r = vectors[i][0] % vectors[i][1];
	if (r != vectors[i][3])
	    printf("[%d] %lld %% %lld = %lld, should be %lld\n",
		i, vectors[i][0], vectors[i][1], r, vectors[i][3]);
    }
}

////////////////////////////////////////////////////////////////////////


uint udiv10(uint x)
{
    return x / 10;
}

uint udiv14(uint x)
{
    return x / 14;
}

uint udiv14007(uint x)
{
    return x / 14007;
}

uint umod10(uint x)
{
    return x % 10;
}

uint umod14(uint x)
{
    return x % 14;
}

uint umod14007(uint x)
{
    return x % 14007;
}

uint uremquo10(uint x)
{
    return (x / 10) | (x % 10);
}

uint uremquo14(uint x)
{
    return (x / 14) | (x % 14);
}

uint uremquo14007(uint x)
{
    return (x / 14007) | (x % 14007);
}



ulong uldiv10(ulong x)
{
    return x / 10;
}

ulong uldiv14(ulong x)
{
    return x / 14;
}

ulong uldiv14007(ulong x)
{
    return x / 14007;
}

ulong ulmod10(ulong x)
{
    return x % 10;
}

ulong ulmod14(ulong x)
{
    return x % 14;
}

ulong ulmod14007(ulong x)
{
    return x % 14007;
}

ulong ulremquo10(ulong x)
{
    return (x / 10) | (x % 10);
}

ulong ulremquo14(ulong x)
{
    return (x / 14) | (x % 14);
}

ulong ulremquo14007(ulong x)
{
    return (x / 14007) | (x % 14007);
}


void testfastudiv()
{
  {
    static uint x10 = 10;
    static uint x14 = 14;
    static uint x14007 = 14007;

    uint u = 10000;
    uint r;
    r = udiv10(u);  assert(r == u/x10);
    r = udiv14(u);  assert(r == u/x14);
    r = udiv14007(u);  assert(r == u/x14007);
    r = umod10(u);  assert(r == u%x10);
    r = umod14(u);  assert(r == u%x14);
    r = umod14007(u);  assert(r == u%x14007);
    r = uremquo10(u);  assert(r == ((u/10)|(u%x10)));
    r = uremquo14(u);  assert(r == ((u/14)|(u%x14)));
    r = uremquo14007(u);  assert(r == ((u/14007)|(u%x14007)));
  }
  {
    static ulong y10 = 10;
    static ulong y14 = 14;
    static ulong y14007 = 14007;

    ulong u = 10000;
    ulong r;
    r = uldiv10(u);  assert(r == u/y10);
    r = uldiv14(u);  assert(r == u/y14);
    r = uldiv14007(u);  assert(r == u/y14007);
    r = ulmod10(u);  assert(r == u%y10);
    r = ulmod14(u);  assert(r == u%y14);
    r = ulmod14007(u);  assert(r == u%y14007);
    r = ulremquo10(u);  assert(r == ((u/10)|(u%y10)));
    r = ulremquo14(u);  assert(r == ((u/14)|(u%y14)));
    r = ulremquo14007(u);  assert(r == ((u/14007)|(u%y14007)));
  }
}


////////////////////////////////////////////////////////////////////////


int div10(int x)
{
    return x / 10;
}

int div14(int x)
{
    return x / 14;
}

int div14007(int x)
{
    return x / 14007;
}

int mod10(int x)
{
    return x % 10;
}

int mod14(int x)
{
    return x % 14;
}

int mod14007(int x)
{
    return x % 14007;
}

int remquo10(int x)
{
    return (x / 10) | (x % 10);
}

int remquo14(int x)
{
    return (x / 14) | (x % 14);
}

int remquo14007(int x)
{
    return (x / 14007) | (x % 14007);
}

////////////////////

int mdiv10(int x)
{
    return x / -10;
}

int mdiv14(int x)
{
    return x / -14;
}

int mdiv14007(int x)
{
    return x / -14007;
}

int mmod10(int x)
{
    return x % -10;
}

int mmod14(int x)
{
    return x % -14;
}

int mmod14007(int x)
{
    return x % -14007;
}

int mremquo10(int x)
{
    return (x / -10) | (x % -10);
}

int mremquo14(int x)
{
    return (x / -14) | (x % -14);
}

int mremquo14007(int x)
{
    return (x / -14007) | (x % -14007);
}

////////////////////


long ldiv10(long x)
{
    return x / 10;
}

long ldiv14(long x)
{
    return x / 14;
}

long ldiv14007(long x)
{
    return x / 14007;
}

long lmod10(long x)
{
    return x % 10;
}

long lmod14(long x)
{
    return x % 14;
}

long lmod14007(long x)
{
    return x % 14007;
}

long lremquo10(long x)
{
    return (x / 10) | (x % 10);
}

long lremquo14(long x)
{
    return (x / 14) | (x % 14);
}

long lremquo14007(long x)
{
    return (x / 14007) | (x % 14007);
}


////////////////////


long mldiv10(long x)
{
    return x / -10;
}

long mldiv14(long x)
{
    return x / -14;
}

long mldiv14007(long x)
{
    return x / -14007;
}

long mlmod10(long x)
{
    return x % -10;
}

long mlmod14(long x)
{
    return x % -14;
}

long mlmod14007(long x)
{
    return x % -14007;
}

long mlremquo10(long x)
{
    return (x / -10) | (x % -10);
}

long mlremquo14(long x)
{
    return (x / -14) | (x % -14);
}

long mlremquo14007(long x)
{
    return (x / -14007) | (x % -14007);
}



void testfastdiv()
{
  {
    static int x10 = 10;
    static int x14 = 14;
    static int x14007 = 14007;

    int u = 10000;
    int r;
    r = div10(u);  assert(r == u/x10);
    r = div14(u);  assert(r == u/x14);
    r = div14007(u);  assert(r == u/x14007);
    r = mod10(u);  assert(r == u%x10);
    r = mod14(u);  assert(r == u%x14);
    r = mod14007(u);  assert(r == u%x14007);
    r = remquo10(u);  assert(r == ((u/x10)|(u%x10)));
    r = remquo14(u);  assert(r == ((u/x14)|(u%x14)));
    r = remquo14007(u);  assert(r == ((u/x14007)|(u%x14007)));
  }
  {
    static int t10 = -10;
    static int t14 = -14;
    static int t14007 = -14007;

    int u = 10000;
    int r;
    r = mdiv10(u);  assert(r == u/t10);
    r = mdiv14(u);  assert(r == u/t14);
    r = mdiv14007(u);  assert(r == u/t14007);
    r = mmod10(u);  assert(r == u%t10);
    r = mmod14(u);  assert(r == u%t14);
    r = mmod14007(u);  assert(r == u%t14007);
    r = mremquo10(u);  assert(r == ((u/t10)|(u%t10)));
    r = mremquo14(u);  assert(r == ((u/t14)|(u%t14)));
    r = mremquo14007(u);  assert(r == ((u/t14007)|(u%t14007)));
  }
  {
    static long y10 = 10;
    static long y14 = 14;
    static long y14007 = 14007;

    long u = 10000;
    long r;
    r = ldiv10(u);  assert(r == u/y10);
    r = ldiv14(u);  assert(r == u/y14);
    r = ldiv14007(u);  assert(r == u/y14007);
    r = lmod10(u);  assert(r == u%y10);
    r = lmod14(u);  assert(r == u%y14);
    r = lmod14007(u);  assert(r == u%y14007);
    r = lremquo10(u);  assert(r == ((u/y10)|(u%y10)));
    r = lremquo14(u);  assert(r == ((u/y14)|(u%y14)));
    r = lremquo14007(u);  assert(r == ((u/y14007)|(u%y14007)));
  }
  {
    static long z10 = -10;
    static long z14 = -14;
    static long z14007 = -14007;

    long u = 10000;
    long r;
    r = mldiv10(u);  assert(r == u/z10);
    r = mldiv14(u);  assert(r == u/z14);
    r = mldiv14007(u);  assert(r == u/z14007);
    r = mlmod10(u);  assert(r == u%z10);
    r = mlmod14(u);  assert(r == u%z14);
    r = mlmod14007(u);  assert(r == u%z14007);
    r = mlremquo10(u);  assert(r == ((u/z10)|(u%z10)));
    r = mlremquo14(u);  assert(r == ((u/z14)|(u%z14)));
    r = mlremquo14007(u);  assert(r == ((u/z14007)|(u%z14007)));
  }
}

////////////////////////////////////////////////////////////////////////


T docond1(T)(T l, ubyte thresh, ubyte val) {
    l += (thresh < val);
    return l;
}

T docond2(T)(T l, ubyte thresh, ubyte val) {
    l -= (thresh >= val);
    return l;
}

T docond3(T)(T l, ubyte thresh, ubyte val) {
    l += (thresh >= val);
    return l;
}

T docond4(T)(T l, ubyte thresh, ubyte val) {
    l -= (thresh < val);
    return l;
}

void testdocond()
{
    assert(docond1!ubyte(10,3,5)  == 11);
    assert(docond1!ushort(10,3,5) == 11);
    assert(docond1!uint(10,3,5)   == 11);
    assert(docond1!ulong(10,3,5)  == 11);

    assert(docond2!ubyte(10,3,5)  == 10);
    assert(docond2!ushort(10,3,5) == 10);
    assert(docond2!uint(10,3,5)   == 10);
    assert(docond2!ulong(10,3,5)  == 10);

    assert(docond3!ubyte(10,3,5)  == 10);
    assert(docond3!ushort(10,3,5) == 10);
    assert(docond3!uint(10,3,5)   == 10);
    assert(docond3!ulong(10,3,5)  == 10);

    assert(docond4!ubyte(10,3,5)  == 9);
    assert(docond4!ushort(10,3,5) == 9);
    assert(docond4!uint(10,3,5)   == 9);
    assert(docond4!ulong(10,3,5)  == 9);


    assert(docond1!ubyte(10,5,3)  == 10);
    assert(docond1!ushort(10,5,3) == 10);
    assert(docond1!uint(10,5,3)   == 10);
    assert(docond1!ulong(10,5,3)  == 10);

    assert(docond2!ubyte(10,5,3)  == 9);
    assert(docond2!ushort(10,5,3) == 9);
    assert(docond2!uint(10,5,3)   == 9);
    assert(docond2!ulong(10,5,3)  == 9);

    assert(docond3!ubyte(10,5,3)  == 11);
    assert(docond3!ushort(10,5,3) == 11);
    assert(docond3!uint(10,5,3)   == 11);
    assert(docond3!ulong(10,5,3)  == 11);

    assert(docond4!ubyte(10,5,3)  == 10);
    assert(docond4!ushort(10,5,3) == 10);
    assert(docond4!uint(10,5,3)   == 10);
    assert(docond4!ulong(10,5,3)  == 10);
}

////////////////////////////////////////////////////////////////////////
 
int main()
{
    testgoto();
    testswitch();
    testdo();
    testbreak();
    teststringswitch();
    teststrarg();
    testsizes();
    testarrayinit();
    testU();
    testulldiv();
    testfastudiv();
    testfastdiv();
    testdocond();
    printf("Success\n");
    return 0;
}
