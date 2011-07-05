// PERMUTE_ARGS:
// REQUIRED_ARGS: -H -Hdtest_results/compilable
// POST_SCRIPT: compilable/extra-files/xheader-postscript.sh

// for D 2.0 only

class C { }

void foo(const C c, const(char)[] s, const int* q, const (int*) p)
{
}

void bar(in void *p)
{
}

void f(void function() f2);

class C2;
void foo2(const C2 c);

struct Foo3
{
   int k;
   ~this() { k = 1; }
   this(this) { k = 2; }
}


class C3 { @property int get() { return 0; } }

T foo3(T)() {}

struct Foo4(T)
{
   T x;
}

class C4(T)
{
  T x;
}
