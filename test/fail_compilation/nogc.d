/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/nogc.d(26): Error: cannot use 'new' in @nogc function foo1
fail_compilation/nogc.d(43): Error: @nogc function 'nogc.foo4' cannot call non-@nogc function 'nogc.S4.this'
fail_compilation/nogc.d(43): Error: constructor for S4* may allocate in 'new' in @nogc function foo4
fail_compilation/nogc.d(55): Error: operator new in @nogc function foo6 may allocate
fail_compilation/nogc.d(74): Error: cannot use 'delete' in @nogc function foo9
fail_compilation/nogc.d(81): Error: cannot use operator ~ in @nogc function foo10
fail_compilation/nogc.d(88): Error: cannot use operator ~= in @nogc function foo11
fail_compilation/nogc.d(95): Error: indexing an associative array in @nogc function foo12 may cause gc allocation
fail_compilation/nogc.d(102): Error: associative array literal in @nogc function foo13 may cause GC allocation
fail_compilation/nogc.d(112): Error: array literals in @nogc function foo14 may cause GC allocation
fail_compilation/nogc.d(119): Error: Setting 'length' in @nogc function foo15 may cause GC allocation
fail_compilation/nogc.d(130): Error: @nogc function 'nogc.foo16' cannot call non-@nogc function 'nogc.bar16'
fail_compilation/nogc.d(150): Error: function nogc.foo18 @nogc function allocates a closure with the GC
---
*/

/***************** NewExp *******************/

@nogc int* foo1()
{
    return new int;
}

@nogc void foo2()
{
    scope int* p = new int;	// no error
}

struct S3 { }
@nogc void foo3()
{
    scope S3* p = new S3();	// no error
}

struct S4 { this(int); }
@nogc void foo4()
{
    scope S4* p = new S4(1);
}

struct S5 { this(int) @nogc; }
@nogc void foo5()
{
    scope S5* p = new S5(1);	// no error
}

struct S6 { new(size_t); }
@nogc void foo6()
{
    S6* p = new S6;
}

struct S7 { new(size_t); }
@nogc void foo7()
{
    scope S7* p = new S7;	// no error
}

struct S8 { @nogc new(size_t); }
@nogc void foo8()
{
    S8* p = new S8;		// no error
}

/***************** DeleteExp *******************/

@nogc void foo9(int* p)
{
    delete p;
}

/***************** CatExp *******************/

@nogc int[] foo10(int[] a)
{
    return a ~ 1;
}

/***************** CatAssignExp *******************/

@nogc void foo11(int[] a)
{
    a ~= 1;
}

/***************** IndexExp *******************/

@nogc int foo12(int[int] a)
{
    return a[1];
}

/***************** AssocArrayLiteralExp *******************/

@nogc void foo13()
{
    auto a = [1:1, 2:3, 4:5];
}

/***************** ArrayLiteralExp *******************/

@nogc int* bar14();

@nogc void foo14()
{
    int* p;
    auto a = [p, p, bar14()];
}

/***************** AssignExp *******************/

@nogc void foo15(int[] a)
{
    a.length = 3;
}

/***************** CallExp *******************/

void bar16();

@nogc void foo16()
{
    auto fp = &bar16;
    (*fp)();		// should give error, but for bugzilla 12622
    bar16();		// does give error
}


/***************** Covariance ******************/
  
class C17
{
    void foo() @nogc;
    void bar();
}

class D17 : C17
{
    override void foo();	// no error
    override void bar() @nogc;  // no error
}

/****************** Closure ***********************/

@nogc auto foo18()
{
    int x;

    int bar() { return x; }
    return &bar;
}
