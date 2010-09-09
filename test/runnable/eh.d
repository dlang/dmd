// PERMUTE_ARGS: -O -fPIC

extern(C) int printf(const char*, ...);

/****************************************************/

class Abc { int i; }

int y;

alias int boo;

void foo(int x)
{
    y = cast(boo)1;
L6:
    try
    {
	printf("try 1\n");
	y += 4;
	if (y == 5)
	    goto L6;
	y += 3;
    }
    finally
    {
	y += 5;
	printf("finally 1\n");
    }
    try
    {
	printf("try 2\n");
	y = 1;
	if (y == 4)
	    goto L6;
	y++;
    }
    catch (Abc c)
    {
	printf("catch 2\n");
	y = 2 + c.i;
    }
    y++;
    printf("done\n");
}

/****************************************************/


class IntException
{
    this(int i)
    {
	m_i = i;
    }

    int getValue()
    {
	return m_i;
    }

    int m_i;
}


void test2()
{
    int	cIterations	=	10;

    int	i;
    long	total_x		=	0;
    long	total_nox	=	0;

    for(int WARMUPS = 2; WARMUPS-- > 0; )
    {
	for(total_x = 0, i = 0; i < cIterations; ++i)
	{
	    total_nox += fn2_nox();
	}
printf("foo\n");

	for(total_nox = 0, i = 0; i < cIterations; ++i)
	{
printf("i = %d\n", i);
	    try
	    {
		int z = 1;

		throw new IntException(z);
	    }
	    catch(IntException x)
	    {
printf("catch, i = %d\n", i);
		total_x += x.getValue();
	    }
	}
    }

    printf("iterations %d totals: %ld, %ld\n", cIterations, total_x, total_nox);
}

int fn2_nox()
{
    return 47;
}


/****************************************************/

void test3()
{
    static int x;
    try
    {
    }
    finally
    {
	printf("a\n");
	assert(x == 0);
	x++;
    }
    printf("--\n");
    assert(x == 1);
    try
    {
	printf("tb\n");
	assert(x == 1);
    }
    finally
    {
	printf("b\n");
	assert(x == 1);
	x++;
    }
    assert(x == 2);
}

/****************************************************/

class Tester
{
	this(void delegate() dg_) { dg = dg_; }
	void delegate() dg;
	void stuff() { dg(); }
}

void test4()
{
	printf("Starting test\n");

	int a = 0;
	int b = 0;
	int c = 0;
	int d = 0;

	try
	{
		a++;
		throw new Exception("test1");
		a++;
	}
	catch(Exception e)
	{
		auto es = e.toString();
                printf("%.*s\n", es.length, es.ptr);
		b++;
	}
	finally
	{
		c++;
	}

	printf("initial test.\n");

	assert(a == 1);
	assert(b == 1);
	assert(c == 1);

	printf("pass\n");

	Tester t = new Tester(
	delegate void()
	{
		try
		{
			a++;
			throw new Exception("test2");
			a++;
		}
		catch(Exception e)
		{
			b++;
			throw e;
			b++;
		}
	});

	try
	{
		c++;
		t.stuff();
		c++;
	}
	catch(Exception e)
	{
		d++;
		string es = e.toString;
		printf("%.*s\n", es.length, es.ptr);
	}

	assert(a == 2);
	assert(b == 2);
	assert(c == 2);
	assert(d == 1);


	int q0 = 0;
	int q1 = 0;
	int q2 = 0;
	int q3 = 0;
	
	Tester t2 = new Tester(
	delegate void()
	{
		try
		{
			q0++;
			throw new Exception("test3");
			q0++;
		}
		catch(Exception e)
		{
			printf("Never called.\n");
			q1++;
			throw e;
			q1++;
		}
	});

	try
	{
		q2++;
		t2.stuff();
		q2++;
	}
	catch(Exception e)
	{
		q3++;
                string es = e.toString;
		printf("%.*s\n", es.length, es.ptr);
	}

	assert(q0 == 1);
	assert(q1 == 1);
	assert(q2 == 1);
	assert(q3 == 1);

	printf("Passed!\n");
}

/****************************************************/

void test5()
{
    char[] result;
    int i = 3;
    while(i--)
    {
	try
	{
	    printf("i: %d\n", i);
	    result ~= 't';
	    if (i == 1)
		continue;
	}
	finally
	{
	    printf("finally\n");
	    result ~= cast(char)('a' + i);
	}
    }
    printf("--- %.*s", result.length, result.ptr);
    if (result != "tctbta")
	assert(0);
}

/****************************************************/

void test6()
{   char[] result;

    while (true)
    {
        try
        {
            printf("one\n");
	    result ~= 'a';
            break;
        }
        finally
        {
            printf("two\n");
	    result ~= 'b';
        }
    }
    printf("three\n");
    result ~= 'c';
    if (result != "abc")
	assert(0);
}

/****************************************************/

string a7;

void doScan(int i)
{
  a7 ~= "a";
  try
  {
    try
    {
	a7 ~= "b";
        return;
    }
    finally
    {
      a7 ~= "c";
    }
  }
  finally
  {
    a7 ~= "d";
  }
}

void test7()
{
        doScan(0);
	assert(a7 == "abcd");
}

/****************************************************/

int main()
{
    printf("start\n");
    foo(3);
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    printf("finish\n");
    return 0;
}
