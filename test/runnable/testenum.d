// PERMUTE_ARGS:

extern(C) int printf(const char*, ...);

/**********************************************/

enum Bar
{
    bar2 = 2,
    bar3,
    bar4 = 0
}

void test1()
{
    Bar b;

    assert(b == 2);
}

/**********************************************/

void test2()
{
	enum E{
		a=-1
	}

	assert(E.min==-1);
	assert(E.max==-1);
}


/**********************************************/

void test3()
{
	enum E{
		a=1,
		b=-1,
		c=3,
		d=2
	}

	assert(E.min==-1);
	assert(E.max==3);
}

/**********************************************/

void test4()
{
	enum E{
		a=-1,
		b=-1,
		c=-3,
		d=-3
	}

	assert(E.min==-3);
	assert(E.max==-1);
}

/**********************************************/

enum Enum5
{
	A = 3,
	B = 10,
	E = -5,
}

void test5()
{
	assert(Enum5.init==Enum5.A);
	assert(Enum5.init==3);
	Enum5 e;
	assert(e==Enum5.A);
	assert(e==3);
}

/***********************************/

enum E6 : byte {
        NORMAL_VALUE = 0,
        REFERRING_VALUE = NORMAL_VALUE + 1,
        OTHER_NORMAL_VALUE = 2
}

void foo6(E6 e) {
}

void test6()
{
     foo6(E6.NORMAL_VALUE);
     foo6(E6.REFERRING_VALUE);
     foo6(E6.OTHER_NORMAL_VALUE);
} 


/**********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();

    printf("Success\n");
    return 0;
}


