
import std.stdio;

template Tuple(A...)
{
    alias A Tuple;
}

template eval( A... )
{
    const typeof(A[0]) eval = A[0];
}

/************************************************/

int foo1()
{   int x;

    foreach (i; 0 .. 10)
	x += i;
    return x;
}

int bar1()
{   int x;

    foreach_reverse (i; 0 .. 10)
    {	x <<= 1;
	x += i;
    }
    return x;
}

void test1()
{
    const y = foo1();
    writeln(y);
    assert(y == 45);

    auto y1 = foo1();
    writeln(y1);
    assert(y1 == 45);

    const z = bar1();
    writeln(z);
    assert(z == 8194);

    auto z1 = bar1();
    writeln(z1);
    assert(z1 == 8194);
}

/************************************************/

int main()
{
    test1();

    writeln("Success");
    return 0;
}
