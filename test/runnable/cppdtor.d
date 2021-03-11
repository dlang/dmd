/*
https://issues.dlang.org/show_bug.cgi?id=21693

RUN_OUTPUT:
---
4: C.~this
4: B.~this
4: A.~this
3: C.~this
3: B.~this
3: A.~this
2: B.~this
2: A.~this
1: A.~this
---
*/

extern (C) int printf(scope const char*, ...);

extern (C++) class A
{
	int num;
	this(int num)
	{
		this.num = num;
	}

	~this()
	{
		printf("%d: A.~this\n", num);
	}
}

extern (C++) class B : A
{
	this(int num)
	{
		super(num);
	}

	~this()
	{
		printf("%d: B.~this\n", num);
	}
}

extern (C++) class C : B
{
	this(int num)
	{
		super(num);
	}

	~this()
	{
		printf("%d: C.~this\n", num);
	}
}

extern (C++) class NoDestruct
{
	int num;
	this(int num)
	{
		this.num = num;
	}
}

void main()
{
	{
		scope a = new A(1);
		scope A b = new B(2);
		scope A c = new C(3);
		scope B c2 = new C(4);
	}
	{
		scope const nd = new NoDestruct(1);
	}
}
