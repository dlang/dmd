/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test22298.d(22): Error: scope variable `i` assigned to `p` with longer lifetime
		p = i;
    ^
fail_compilation/test22298.d(33): Error: scope variable `y` assigned to `x` with longer lifetime
    x = y;
      ^
---
*/

void g(scope void delegate(scope int*) @safe cb) @safe {
	int x = 42;
	cb(&x);
}

void main() @safe {
	int* p;
	void f(scope int* i) @safe {
		p = i;
	}

	g(&f);
	// address of x has escaped g
	assert(*p == 42);
}

void f() @safe {
    mixin("scope int* x;");
    scope int* y;
    x = y;
}
