/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22304

int * __attribute__((__always_inline__)) foo(void)
{
    return 0;
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22312

typedef int Integer;
typedef int Integer;

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22333

enum E {
  oldval __attribute__((deprecated)) = 0,
  newval
};

int
fn (void)
{
  return oldval;
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22342

void func();
void booc(int);

void cooc(i)
int i;
{
}

void test22342()
{
    func(3);
    booc(3);
    cooc(1, 3);
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22398

const int a;
int b = a;

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22415

int test22415(int a)
{
    switch (a)
    {
        case 0:
            a = 1;
        case 1:
            return a;
        case 2:
        default:
            return -1;
    }
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22422

int foo22422(void *p __attribute__((align_value(64))))
{
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22432

struct S {
    int x;
};
typedef int T;
struct S F(struct S);

void test22432()
{
    struct S s;
    int x1 = (int)(s).x;
    int x2 = (T)(s).x;
    int x3 = (F)(s).x;
    struct S s1 = (F)(s);
    double d = 1.0;
    int x4 = (T)(d);
    int x5 = (T)(d)++;
    int x6 = (T)(d)--;
    struct S* p;
    int x7 = (T)(p)->x;
    int a[3];
    int x8 = (T)(a)[1]++;
}


/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22534

struct S22534 { int x; };

void test22534(struct S22534 *const p)
{
    p->x = 1;
}

/*************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22560

;;;
; struct S22560 { int x; };;;;
; int func22560();;;
;;;

/*************************************************/
// typeof()

void testTypeof(void)
{
    // general declarations
    short a;
    _Static_assert(sizeof(a) == sizeof(short), "1");

    typeof(a) b;
    _Static_assert(sizeof(b) == sizeof(short), "2");

    typeof(short) c;
    _Static_assert(sizeof(c) == sizeof(short), "3");

    typeof(a + 1) d;
    _Static_assert(sizeof(d) == sizeof(int), "4"); // promoted

    typeof(a += 1) e;
    _Static_assert(sizeof(e) == sizeof(short), "5");

    typeof(1, 1) f;
    _Static_assert(sizeof(f) == sizeof(int), "6");

    typeof(_Generic(1, default: 0)) g;
    _Static_assert(sizeof(g) == sizeof(int), "7");

    const typeof(a) h = (typeof(a))0;
    _Static_assert(sizeof(h) == sizeof(short), "8");

    typeof(const short) i = h;
    _Static_assert(sizeof(i) == sizeof(short), "9");


    // function parameters
    typeof(a) fun(typeof(a), typeof(h));
    fun(a, h);
    _Static_assert(sizeof(fun(a, h)) == sizeof(short), "10");


    // aggregate fields
    struct Foo { typeof(a) x; };
    typeof(((struct Foo){0}).x) fa;
    _Static_assert(sizeof(fa) == sizeof(short), "11");


    // typedefs
    typedef short Bar;
    Bar ta;
    _Static_assert(sizeof(ta) == sizeof(short), "12");

    typeof(ta) tb;
    _Static_assert(sizeof(tb) == sizeof(short), "13");

    typeof(Bar) tc;
    _Static_assert(sizeof(tc) == sizeof(short), "14");


    // pointers
    typeof(&a) pa;
    _Static_assert(sizeof(pa) == sizeof(void*), "15");

    typeof(*pa) pb;
    _Static_assert(sizeof(pb) == sizeof(short), "16");
}

short testTypeofA;
const typeof(testTypeofA) testTypeofB = 0;
_Static_assert(sizeof(testTypeofB) == sizeof(short), "17");

/*************************************************/

// https://issues.dlang.org/show_bug.cgi?id=23752
void *c23752 = &*((void*)(0));

/*************************************************/

// https://issues.dlang.org/show_bug.cgi?id=23767
const int arr23767[4];
void f23767(void)
{
    int x = *(0 ? (void*)0 : arr23767);
    int y = *(1 ? arr23767 : (void*)(3-3));
    int* p = (1 ? (void*)0 : (void*)0);
}

/*************************************************/
