/*
TEST_OUTPUT:
---
fail_compilation/dip1044.d(110): Error: cannot implicitly convert expression `2` of type `int` to `A`
fail_compilation/dip1044.d(111): Error: variable `dip1044.__lambda_L104_C15.myA3` - type `void` is inferred from initializer `$c`, and variables cannot be of type `void`
fail_compilation/dip1044.d(111): Error: inference expression only support enums for now
fail_compilation/dip1044.d(112): Error: cannot implicitly convert expression `1` of type `int` to `A`
fail_compilation/dip1044.d(104):        while evaluating: `static assert((__error)())`
fail_compilation/dip1044.d(122): Deprecation: `$c` has no effect
fail_compilation/dip1044.d(137): Error: undefined identifier `SS`, did you mean struct `S`?
fail_compilation/dip1044.d(142): Error: inference expression only support enums for now
fail_compilation/dip1044.d(129):        while evaluating: `static assert((__error)())`
fail_compilation/dip1044.d(158): Error: template `myTempFn` is not callable using argument types `!()(void)`
fail_compilation/dip1044.d(156):        Candidate is: `myTempFn(T)(T param)`
fail_compilation/dip1044.d(159): Error: template `myTempFn` is not callable using argument types `!()(void)`
fail_compilation/dip1044.d(156):        Candidate is: `myTempFn(T)(T param)`
fail_compilation/dip1044.d(148):        while evaluating: `static assert((__error)())`
---
*/


enum A{ a, b, e }
#line 51
void foo(A a){}

enum B { b, c, }
#line 52
void foo(B b){}

int f()
{
#line 100
    foo(:b);
}

    /* Examples from DIP1044... */
static assert(()
{// Initializers and assignments
    enum A{ a,b,c,d }

    struct S{ A one, two; }
    A    myA2 = :b | :c;
         myA2 = :d - 1;
    auto myA3 = :c;
    A    myA4 = :a + 1;

    return true;
} ());

static assert(()
{// Return statements
    enum A{ a,b,c,d }

    auto myBrokenFn(){
        return :c; // error, we don't know the type of ":c"!
    }

    return true;
} ());


static assert(()
{// Indexing
    enum A{ a,b,c,d }
    enum B{ e,f,g,h }

    struct S{
        int opIndex(A param){ return cast(int)param; };
    }
    SS myS;
    auto y = myS[:d];
    y = myS[:e];

    A[] myArr;
    auto z = myArr[:c];

    return true;
} ());


static assert(()
{// Argument lists
    enum A{ a,b,c,d }

    struct S{ A one, two; }

    void myFn(A param){}
    void myDefaultFn(A param=:d){}
    void myTempFn(T)(T param){}

    myTempFn(:a);       // error, can't infer a type to instantiate the template with from ":a"!
    myFn(myTempFn(:a)); // error, same as above

    return true;
} ());
