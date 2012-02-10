// REQUIRED_ARGS: -d
// PERMUTE_ARGS: -di

// Test cases using deprecated features

/**************************************************
   Segfault. From compile1.d
   http://www.digitalmars.com/d/archives/6376.html
**************************************************/

alias float[2] vector2;
typedef vector2 point2;  // if I change this typedef to alias it works fine

float distance(point2 a, point2 b)
{
  point2 d;
  d[0] = b[0] - a[0]; // if I comment out this line it won't crash
  return 0.0f;
}

class A3836
{
    void fun() {}
}
class B3836 : A3836
{
    void fun() {}
}

/**************************************************
   Moved by fixing issue 7444
   From derivedarray.d
**************************************************/

void statictodynamicarrays()
{
    static class C {}
    static class D : C {}

    C[] a;
    D[] b;
    const(C)[] c;
    const(D)[] d;
    immutable(C)[] e;
    immutable(D)[] f;

    C[1] sa;
    D[1] sb;
    const(C)[1] sc = void;
    const(D)[1] sd = void;
    immutable(C)[1] se = void;
    immutable(D)[1] sf = void;

    static assert( __traits(compiles, a = sa));
    static assert(!__traits(compiles, a = sb));
    static assert(!__traits(compiles, a = sc));
    static assert(!__traits(compiles, a = sd));
    static assert(!__traits(compiles, a = se));
    static assert(!__traits(compiles, a = sf));

    static assert(!__traits(compiles, b = sa));
    static assert( __traits(compiles, b = sb));
    static assert(!__traits(compiles, b = sc));
    static assert(!__traits(compiles, b = sd));
    static assert(!__traits(compiles, b = se));
    static assert(!__traits(compiles, b = sf));

    static assert( __traits(compiles, c = sa));
    static assert( __traits(compiles, c = sb));
    static assert( __traits(compiles, c = sc));
    static assert( __traits(compiles, c = sd));
    static assert( __traits(compiles, c = se));
    static assert( __traits(compiles, c = sf));

    static assert(!__traits(compiles, d = sa));
    static assert( __traits(compiles, d = sb));
    static assert(!__traits(compiles, d = sc));
    static assert( __traits(compiles, d = sd));
    static assert(!__traits(compiles, d = se));
    static assert( __traits(compiles, d = sf));

    static assert(!__traits(compiles, e = sa));
    static assert(!__traits(compiles, e = sb));
    static assert(!__traits(compiles, e = sc));
    static assert(!__traits(compiles, e = sd));
    static assert( __traits(compiles, e = se));
    static assert( __traits(compiles, e = sf));

    static assert(!__traits(compiles, f = sa));
    static assert(!__traits(compiles, f = sb));
    static assert(!__traits(compiles, f = sc));
    static assert(!__traits(compiles, f = sd));
    static assert(!__traits(compiles, f = se));
    static assert( __traits(compiles, f = sf));
}
