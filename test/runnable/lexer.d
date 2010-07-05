// REQUIRED_ARGS: -d

import std.stdio;

/*********************************************************/

template Foo(T)
{
    static if ( is(T : int) )
	alias T t1;

    static if (T.sizeof == 4)
	alias T t2;

    static if ( is(T U : int) )
	alias U t3;

    static if ( is(T* V : V*) )
	alias V t4;

    static if ( is(T W) )
	alias W t5;
    else
	alias char t5;

    static if ( is(T* X : X*) )
    {
    }
}

void test1()
{
    Foo!(int).t1 x1;
    assert(typeid(typeof(x1)) == typeid(int));

    Foo!(int).t2 x2;
    assert(typeid(typeof(x2)) == typeid(int));

    Foo!(int).t3 x3;
    assert(typeid(typeof(x3)) == typeid(int));

    Foo!(int).t4 x4;
    assert(typeid(typeof(x4)) == typeid(int));

    Foo!(int).t5 x5;
    assert(typeid(typeof(x5)) == typeid(int));

    Foo!(int).X x6;
    assert(typeid(typeof(x6)) == typeid(int));
}

/*********************************************************/


void test2()
{
    alias int T;

    static if ( is(T : int) )
	alias T t1;

    static if (T.sizeof == 4)
	alias T t2;

    static if ( is(T U : int) )
	alias U t3;

    static if ( is(T* V : V*) )
	alias V t4;

    static if ( is(T W) )
	alias W t5;
    else
	alias char t5;

    static if ( is(T* X : X*) )
    {
    }

    t1 x1;
    assert(typeid(typeof(x1)) == typeid(int));

    t2 x2;
    assert(typeid(typeof(x2)) == typeid(int));

    t3 x3;
    assert(typeid(typeof(x3)) == typeid(int));

    t4 x4;
    assert(typeid(typeof(x4)) == typeid(int));

    t5 x5;
    assert(typeid(typeof(x5)) == typeid(int));

    X x6;
    assert(typeid(typeof(x6)) == typeid(int));
}

/*********************************************************/

void test3()
{
    static if ( is(short : int) )
    {	printf("1\n");
    }
    else
	assert(0);
    static if ( is(short == int) )
	assert(0);
    static if ( is(int == int) )
    {	printf("3\n");
    }
    else
	assert(0);
}

/*********************************************************/

void test4()
{
    alias void Function(int);

    static if (is(Function Void == function))
	printf("if\n");
    else
	assert(0);

//    static if (is(Void == void))
//	printf("if\n");
//    else
//	assert(0);


    alias byte delegate(int) Delegate;

    static if (is(Delegate Foo == delegate))
	printf("if\n");
    else
	assert(0);

    static if (is(Foo Byte == function))
	printf("if\n");
    else
	assert(0);

//    static if (is(Byte == byte))
//	printf("if\n");
//    else
//	assert(0);


    union Union { }

    static if (is(Union == union))
	printf("if\n");
    else
	assert(0);


    struct Struct { }

    static if (is(Struct == struct))
	printf("if\n");
    else
	assert(0);


    enum Enum : short { EnumMember }

    static if (is(Enum Short == enum))
	printf("if\n");
    else
	assert(0);

    static if (is(Short == short))
	printf("if\n");
    else
	assert(0);


    typedef char Typedef;

    static if (is(Typedef Char == typedef))
	printf("if\n");
    else
	assert(0);

    static if (is(Char == char))
	printf("if\n");
    else
	assert(0);


    class Class { }

    static if (is(Class == class))
	printf("if\n");
    else
	assert(0);


    interface Interface { }

    static if (is(Interface == interface))
	printf("if\n");
    else
	assert(0);

}

/*********************************************************/

class Foo5(T)
{
    Node sentinel;

    struct Node
    {
	int value;
    }
}

void test5()
{
    Foo5!(int) bar=new Foo5!(int);
    bar.sentinel.value = 7;
}


/*********************************************************/

void test6()
{
    string s = q"(foo(xxx))";
    assert(s == "foo(xxx)");

    s = q"[foo[xxx]]";
    assert(s == "foo[xxx]");

    s = q"{foo{xxx}}";
    assert(s == "foo{xxx}");

    s = q"<foo<xxx>>";
    assert(s == "foo<xxx>");

    s = q"[foo(]";
    assert(s == "foo(");

    s = q"/foo]/";
    assert(s == "foo]");


    s = q"HERE
foo
HERE";
    //writefln("'%s'", s);
    assert(s == "foo\n");


    s = q{ foo(xxx) };
    assert(s ==" foo(xxx) ");

    s = q{foo(};
    assert(s == "foo(");

    s = q{{foo}/*}*/};
    assert(s == "{foo}/*}*/");

    s = q{{foo}"}"};
    assert(s == "{foo}\"}\"");
}

/*********************************************************/

void test7()
{
    auto str = \xDB;
    assert(str.length == 1);
}

/*********************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();

    printf("Success\n");
    return 0;
}
