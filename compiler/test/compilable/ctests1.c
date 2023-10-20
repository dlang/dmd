// https://issues.dlang.org/show_bug.cgi?id=22252

/* Test conversion of parameter types:
 *    array of T => pointer to T
 *    function => pointer to function
 */

int test1(int a[])
{
    return *a;
}

int test2(int a[3])
{
    return *a;
}

int test3(int fp())
{
    return (*fp)();
}

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22275

void test22275(char *dest)
{
    char buf[1];
    if (dest != buf)
        return;
    if (test22275 != &test22275)
        return;
}

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22294

enum { A, B, C };

_Static_assert(A == 0 && B == 1 && C == 2, "in");

int array[C];

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22313

typedef int Integer;
int castint(int x){
    Integer a = (Integer)(x); // cast.c(4)
    Integer b = (Integer)(4); // cast.c(5)
    Integer c = (Integer)x;
    Integer d = (Integer)4;
    Integer e = (int)(x); // cast.c(8)
    int f = (Integer)x;
    Integer g = (int)x;
    Integer h = (int)(4); // cast.c(11)
    Integer i = (int)4;
    int j = (Integer)(x);
    return x;
}

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22314

enum E22314 {
    oldval __attribute__((deprecated)),
    newval
};

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22322

struct S22322
{
    float f;
    double d;
    long double ld;
};

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22362

typedef struct Foo22362 {
    int x, y;
} Foo22362;

Foo22362 gfoo = (Foo22362){0, 1};
int main(int argc, char** argv)
{
    Foo22362 foo1 = (Foo22362){0};
    Foo22362 foo2 = (Foo22362){0, 1};
}

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22623

struct S22623 {
    struct T *child;
};

typedef
struct T {
    int xyz;
} U;

void f22623()
{
    struct S22623 s;
    struct T t;
    if (s.child != &t)
	;
}

/*********************************************************/

//https://issues.dlang.org/show_bug.cgi?id=22267
typedef signed int int32_t;
int32_t ret22267()
{
    int32_t init = (1 + 3);
    return init;
}
_Static_assert(ret22267() == 4, "Ret != 4");

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22233

int foo22233();

void test22233()
{
    (foo22233)();
}

/*********************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22286

int foo122286(int);
int foo222286(int, int);
typedef int Int22286;

void test22286()
{
    Int22286 b;
    int x = (foo122286)(3);
    x = (foo222286)(3,4);
    x = (Int22286)(3);
    x = (Int22286)(3,4);
}
