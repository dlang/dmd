/*
TEST_OUTPUT:
---
fail_compilation/struct_rvalue_assign.d(16): Error: assignment to struct rvalue `foo()` is discarded
fail_compilation/struct_rvalue_assign.d(16):        if the assignment is needed to modify a global, call `opAssign` directly or use an lvalue
fail_compilation/struct_rvalue_assign.d(17): Error: assignment to struct rvalue `foo()` is discarded
fail_compilation/struct_rvalue_assign.d(17):        if the assignment is needed to modify a global, call `opOpAssign` directly or use an lvalue
fail_compilation/struct_rvalue_assign.d(18): Error: assignment to struct rvalue `foo()` is discarded
fail_compilation/struct_rvalue_assign.d(18):        if the assignment is needed to modify a global, call `opUnary` directly or use an lvalue
---
*/
module sra 2024;

void main()
{
    foo() = S.init;
    foo() += 5;
    ++foo();
    *foo(); // other unary ops may be OK

    // allowed
    foo().opAssign(S.init);
    foo().opOpAssign!"+"(5);
    foo().opUnary!"++"();
}

S foo() => S.init;

struct S
{
    int i;

    void opAssign(S s);
    void opOpAssign(string op : "+")(int);
    void opUnary(string op : "++")();
    void opUnary(string op : "*")();
}

void test()
{
	int i;

	static struct Ptr
	{
		int* p;
		void opAssign(int rhs) { *p = rhs; }
	}
	Ptr(&i) = 1; // allowed

	struct Nested
	{
		void opAssign(int rhs) { i = rhs; }
	}
	Nested() = 1; // allowed

	static struct StaticOp
	{
		static si = 0;
		static void opAssign(int rhs) { si = rhs; }
	}
	StaticOp() = 1; // allowed
}
