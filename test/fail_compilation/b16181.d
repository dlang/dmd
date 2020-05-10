/* TEST_OUTPUT:
---
fail_compilation/b16181.d(114): Error: `b16181.foo` called with argument types `(int)` matches both:
fail_compilation/b16181.d(103):     `b16181.foo(int a)`
and:
fail_compilation/b16181.d(104):     `b16181.foo(int a, int b = 2)`
fail_compilation/b16181.d(115): Error: `b16181.bar` called with argument types `(int, int)` matches both:
fail_compilation/b16181.d(106):     `b16181.bar(int a, int b)`
and:
fail_compilation/b16181.d(107):     `b16181.bar(int a, int b = 2, int c = 3)`
fail_compilation/b16181.d(116): Error: `b16181.baz` called with argument types `()` matches both:
fail_compilation/b16181.d(109):     `b16181.baz(int a = 1)`
and:
fail_compilation/b16181.d(110):     `b16181.baz()`
---
*/
// https://issues.dlang.org/show_bug.cgi?id=16181

#line 100



void foo(int a){}
void foo(int a, int b = 2){}

void bar(int a, int b){}
void bar(int a, int b = 2, int c = 3){}

void baz(int a = 1){}
void baz(){}

void main()
{
	foo(5);
	bar(2, 4);
	baz();
}