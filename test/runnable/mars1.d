
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

///////////////////////
 
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
    printf("Success\n");
    return 0;
}
