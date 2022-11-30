/*
TEST_OUTPUT:
---
fail_compilation/dip1044.d(100): Error: `dip1044.foo` called with argument types `(void)` matches both:
fail_compilation/dip1044.d(51):     `dip1044.foo(A a)`
and:
fail_compilation/dip1044.d(52):     `dip1044.foo(B b)`
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
    foo($b);
}

    /* Examples from DIP1044... */
static assert(()
{// Initializers and assignments
    enum A{ a,b,c,d }

    struct S{ A one, two; }
    A    myA2 = $b | $c;
         myA2 = $d - 1;
    auto myA3 = $c;
    A    myA4 = $a + 1;

    return true;
} ());

static assert(()
{// Return statements
    enum A{ a,b,c,d }

    auto myBrokenFn(){
        return $c; // error, we don't know the type of "$c"!
    }

    return true;
} ());

static assert(()
{// Argument lists
    enum A{ a,b,c,d }

    struct S{ A one, two; }

    void myFn(A param){}
    void myDefaultFn(A param=$d){}
    void myTempFn(T)(T param){}

    myTempFn($a);       // error, can't infer a type to instantiate the template with from "$a"!
    myFn(myTempFn($a)); // error, same as above

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
    auto y = myS[$d];
    y = myS[$e];

    A[] myArr;
    auto z = myArr[$c];

    return true;
} ());
