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
