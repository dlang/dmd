/*
REQUIRED_ARGS: -preview=rvalueattribute
TEST_OUTPUT:
---
fail_compilation/rvalue_attrib1.d(25): Error: `rvalue_attrib1.foo` called with argument types `(int)` matches both:
fail_compilation/rvalue_attrib1.d(20):     `rvalue_attrib1.foo(@rvalue ref int _param_0)`
and:
fail_compilation/rvalue_attrib1.d(21):     `rvalue_attrib1.foo(int _param_0)`
fail_compilation/rvalue_attrib1.d(38): Error: function `rvalue_attrib1.fb(ref int)` is not callable using argument types `(int)`
fail_compilation/rvalue_attrib1.d(38):        cannot pass `@rvalue ref` argument `get()` of type `int` to parameter `ref int`
fail_compilation/rvalue_attrib1.d(42): Error: function `rvalue_attrib1.fc(@rvalue ref int)` is not callable using argument types `(int)`
fail_compilation/rvalue_attrib1.d(42):        cannot pass lvalue argument `i` of type `int` to parameter `@rvalue ref int`, perhaps you meant `cast(@rvalue ref)i`
fail_compilation/rvalue_attrib1.d(49): Error: cannot cast rvalue `cast(@rvalue ref)1` to `@rvalue ref`
fail_compilation/rvalue_attrib1.d(50): Error: cannot cast rvalue `cast(@rvalue ref)getv()` to `@rvalue ref`
fail_compilation/rvalue_attrib1.d(53): Error: cannot modify constant `0`
fail_compilation/rvalue_attrib1.d(56): Error: lvalue cannot be `@rvalue ref`, perhaps you meant `cast(@rvalue ref) l`
---
*/

void foo(@rvalue ref int) {}
void foo(int) {}

void test()
{
    foo(0);
    int i;
    foo(i);
}

@rvalue ref int get();
void fa(int);
void fb(ref int);
void fc(@rvalue ref int);

void test2()
{
    fa(get);
    fb(get);
    fc(get);

    int i;
    fc(i);
}

int getv();

void test3()
{
    auto a = cast(@rvalue ref) 1;
    auto b = cast(@rvalue ref) getv();
}

@rvalue ref int retV() {return 0; }

int l;
@rvalue ref int retL() {return l; }
