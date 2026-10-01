// Basic out-of-order test
int f0(T0, T1)(T0 t0, T1 t1)
{
    static assert(is(T0 == int));
    static assert(is(T1 == string));
    return t0;
}

static assert(f0(t1: "a", t0: 10) == 10);

// Default argument at beginning instead of end
int f1(T0, T1)(T0 t0 = 20, T1 t1) { return t0; }
static assert(f1(t1: "a") == 20);

// Two default arguments
int f2(T0, T1)(T0 t0 = 20, T1 t1, T2 t2 = 30) { return t2; }

// Selecting overload based on name
string f3(T)(T x) { return "x"; }
string f3(T)(T y) { return "y"; }
static assert(f3(x: 0) == "x");
static assert(f3(y: 0) == "y");

// Variadic tuple cut short by named argument
int f4(T...)(T x, int y, int z) { assert(y == 30); assert(z == 50); return T.length; }
static assert(f4(10, 10, 10, y: 30, z: 50) == 3);
static assert(f4(10, 10, 30, z: 50) == 2);

// https://github.com/dlang/dmd/issues/21335
// Named args with template parameter defaults (IFTI)
void f5(A = int, B = int)(A a = A.init, B b = B.init)
{
    static assert(is(A == int));
    static assert(is(B == string));
}

void testIssue21335()
{
    f5(b: "hello");
}

// Variadic tuple with named argument for default parameter (post-tuple)
// https://github.com/dlang/dmd/issues/22878
int f6(T...)(T args, string file = __FILE__, int line = __LINE__) { return T.length; }
static assert(f6(1, 2, file: __FILE__) == 2);
static assert(f6(file: __FILE__) == 0);
static assert(f6(1, 2, 3) == 3);

static assert(f6(1, 2, file: __FILE__, 0) == 2);
static assert(f6(file: __FILE__, 0) == 0);
static assert(f6(1, 2, line: 0) == 2);
static assert(f6(1, 2, line: 0, file: __FILE__) == 2);

// Named argument for default parameter before the variadic tuple
int f7(T...)(int x = 0, T args) { return x + cast(int) T.length; }
static assert(f7(1, 2, 3) == 1 + 2);    // x=1, args=(2,3)
static assert(f7(x: 5, 1, 2) == 5 + 2); // x=5 (named), args=(1,2)
static assert(f7(x: 5) == 5 + 0);       // x=5 (named), args=()
