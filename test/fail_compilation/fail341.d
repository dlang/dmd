
import std.c.stdio;

struct T
{
    @nocall this(this)
    {
	printf("postblit\n");
    }
}

struct S
{
    T t;
}

@nocall void foo() { }

void main()
{
    S s;
    auto t = s;
    foo();
}
