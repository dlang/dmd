// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

int testswitch(string h)
{
    int x;

    switch (h)
    {
	case "abc":
	    printf("abc\n");
	    x = 4;
	    break;
	case "foo":
	    printf("foo\n");
	    x = 1;
	    break;
	case "bar":
	    printf("bar\n");
	    x = 2;
	    break;
	default:
	    printf("default\n");
	    x = 3;
	    break;
    }
    return x;
}

void test1()
{   int i;

    i = testswitch("foo");
    printf("i = %d\n", i);
    assert(i == 1);
    assert(testswitch("abc") == 4);
    assert(testswitch("bar") == 2);
    assert(testswitch("hello") == 3);
    printf("Success\n");
}

/*****************************************/

void test2()
{   int i;

    switch (5)
    {
	case 3,4,5,6:
	    i = 20;
	    break;

	case 7:
	default:
	    assert(0);
	    break;
    }
    assert(i == 20);
}


/*****************************************/

void test3()
{   int i;

    switch (5)
    {
	case 7:
	    i = 6;
	    goto default;
	default:
	    i = 8;
	    break;

	case 3,4,5,6:
	    i = 20;
	    goto default;
    }
    assert(i == 8);
}


/*****************************************/

void test4()
{   int i;

    switch (5)
    {
	case 3,4,5,6:
	    i = 20;
	    goto default;

	case 7:
	    i = 6;
	    goto default;

	default:
	    i = 8;
	    break;
    }
    assert(i == 8);
}


/*****************************************/

void test5()
{   int i;

    switch (5)
    {
	case 7:
	    i = 6;
	    goto case;
	default:
	    i = 8;
	    break;

	case 3,4,5,6:
	    i = 20;
	    break;
    }
    assert(i == 20);
}


/*****************************************/

void test6()
{   int i;

    switch (5)
    {
	case 7:
	    i = 6;
	    goto case 4;
	default:
	    i = 8;
	    break;

	case 3,4,5,6:
	    i = 20;
	    break;
    }
    assert(i == 20);
}


/*****************************************/

void test7()
{   int i;

    switch (5)
    {
	case 3,4,5,6:
	    i = 20;
	    break;

	case 7:
	    i = 6;
	    goto case 4;
	default:
	    i = 8;
	    break;
    }
    assert(i == 20);
}


/*****************************************/

void test8()
{
    dstring str = "xyz";
    switch (str)
    {
	case "xyz":
	    printf("correct\n");
	    return;

	case "abc":
	    break;

	default:
	    assert(0);
    }
    assert(0);
}

/*****************************************/

void test9()
{
    int i = 1;

    switch(i)
    {
	case 2:
	    return;
	case 1:
	    switch(i)
	    {
		case 1:
		    goto case 2;
		default:
		    assert(0);
	    }
	default:
	    assert(0);
    }
    assert(0);
}

/*****************************************/

void test10()
{
    int id1 = 0;
    int id;
    switch (id1)
    {
        case 0: ++id; goto case;
        case 7: ++id; goto case;
        case 6: ++id; goto case;
        case 5: ++id; goto case;
        case 4: ++id; goto case;
        case 3: ++id; goto case;
        case 2: ++id; goto case;
        case 1: ++id; goto default;
	default:
	    break;
    }
    assert(id == 8);
}

/*****************************************/

void test11()
{
    long foo = 4;
    switch (foo)
    {
	case 2: assert (false); break;
	case 3: break;
	case 4: break;
	case 5: break;
	default: assert(0);
    }
}

/*****************************************/

void test12()
{
  switch("#!")
  {
    case "#!": printf("----Found #!\n");    break;
    case "\xFF\xFE"c:                       break;
    default:
	assert(0);
	printf("----Found ASCII\n"); break;
  }
}

/*****************************************/

void test13()
{
  switch("#!")
  {
    case "#!": printf("----Found #!\n");    break;
    case "#\xFE"c:                       break;
    default:
	assert(0);
	printf("----Found ASCII\n"); break;
  }
}

/*****************************************/

void foo14(A...)(int i)
{
        switch (i)
        {
                foreach(a; A)
                {
			goto case;
                case a:
                        printf("%d\n", a);
                }
		break;
	    default:
		assert(0);
        }
}

void bar14(A...)(int i)
{
        switch (i)
        {
                foreach(j, a; A)
                {
			goto case;
                case A[j]:
                        printf("a = %d, A[%d] = %d\n", a, j, A[j]);
                }
		break;
	    default:
		assert(0);
        }
}

void test14()
{
        foo14!(1,2,3,4,5)(1); 
        bar14!(1,2,3,4,5)(1);
}

/*****************************************/

const int X15;
immutable int Y15;
const int Z15;

int foo15(int i)
{
    auto y = 1;
    switch (i)
    {
	case X15:
	    y += 1;
	    goto case;
	case 3:
	    y += 2;
	    break;
	case Y15:
	    y += 20;
	    goto case;
	case Z15:
	    y += 10;
	    break;
	default:
	    y += 4;
	    break;
    }
    printf("y = %d\n", y);
    return y;
}

static this()
{
    X15 = 4;
    Y15 = 4;
    Z15 = 5;
}

void test15()
{
    auto i = foo15(3);
    assert(i == 3);
    i = foo15(4);
    assert(i == 4);
    i = foo15(7);
    assert(i == 5);
    i = foo15(5);
    assert(i == 11);
}

/*****************************************/

enum E16
{
    A,B,C
}

void test16()
{
    E16 e = E16.A;
    final switch (e)
    {
	case E16.A:
	case E16.B:
	case E16.C:
	    ;
    }
}

/*****************************************/

void test17()
{
    int i = 2;
    switch (i)
    {
	case 1: .. case 3:
	    i = 5;
	    break;
	default:
	    assert(0);
    }
    if (i != 5)
	assert(0);

    switch (i)
    {
	case 1: .. case 3:
	    i = 4;
	    break;
	case 5:
	    i = 6;
	    break;
	default:
	    assert(0);
    }
    if (i != 6)
	assert(0);
}

/*****************************************/

int test19()
{
  enum foo{ bar };
  foo x;
  final switch(x){ case foo.bar: return 0; }
}

/*****************************************/

void test20()
{
    switch(1)
    {
	mixin("case 0:{}");
	case 1:
	case 2:
	default:
    }
}

/*****************************************/

void hang3139(int x)
{
   switch(x) {
        case -9: .. case -1:
        default:
   }
}

int wrongcode3139(int x)
{
   switch(x) {
        case -9: .. case 2: return 3;
        default:
        return 4;
   }   
}

static assert(wrongcode3139(-5)==3);

// bug 3139
static assert(!is(typeof(
        (long x) { switch(x) { case long.max: .. case -long.max:
        default:} return 4; }(3)
   )));


/*****************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    test14();
    test15();
    test16();
    test17();
    test19();
    test20();

    printf("Success\n");
    return 0;
}

