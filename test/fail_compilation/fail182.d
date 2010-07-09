
struct S59
{
    int x;

    void foo() { x = 3; }
    const void bar()
    {	//x = 4;
	//this.x = 5;
    }
}

class C
{
    int x;

    void foo() { x = 3; }
    const void bar()
    {	//x = 4;
	//this.x = 5;
    }
}

void main()
{   S59 s;

    s.foo();
    s.bar();

    final S59 t;
    t.foo();
    t.bar();
}

void test()
{   C c = new C;

    c.foo();
    c.bar();

    final C d = new C;
    d.foo();
    d.bar();
}


