
import std.c.stdio;

/******************************************/

auto class Foo
{
    static int x;

    ~this()
    {
	printf("Foo.~this()\n");
	x++;
    }
}

int test1x()
{
    auto Foo f = new Foo();
    return 6;
}


void test1()
{
    {
	auto Foo f = new Foo();
    }
    int c;

    assert(Foo.x == 1);
    c = test1x();
    assert(c == 6);
    assert(Foo.x == 2);

    if (c != 6)
	auto Foo h = new Foo();
    assert(Foo.x == 2);

    if (c == 6)
	auto Foo j = new Foo();
    assert(Foo.x == 3);

    {
	auto Foo g = null, k = new Foo();
	assert(Foo.x == 3);
    }
    assert(Foo.x == 4);
}

/******************************************/

int ax;

auto class A2
{
  this()
  {
    printf("A2.this()\n");
    ax += 1;
  }

  ~this()
  {
    printf("A2.~this()\n");
    ax += 1000;
  }
};


void test2()
{
  {
    auto A2 a = new A2();
    printf("Hello world.\n");
  }
  assert(ax == 1001);
}



/******************************************/

int status3;

auto class Parent3
{
}

auto class Child3 : Parent3
{
	this(){
		assert(status3==0);
		status3=1;
	}    

	~this(){
		assert(status3==1);
		status3=2;
	}
}

void foo3()
{
	auto Parent3 o = new Child3();
	assert(status3==1);
}

void test3()
{
	foo3();
	assert(status3==2);
}

/******************************************/

int main()
{
    test1();
    test2();
    test3();

    printf("Success\n");
    return 0;
}
