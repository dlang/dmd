/*
TEST_OUTPUT:
---
---
*/

module test34;

import std.stdio;
import std.string;
import std.format;
import core.exception;

/************************************************/

class Foo {}
class Bar {}

void test1()
{
    TypeInfo ti_foo = typeid(Foo);
    TypeInfo ti_bar = typeid(Bar);

    auto hfoo = ti_foo.toHash();
    auto hbar = ti_bar.toHash();
    writefln("typeid(Foo).toHash: ", hfoo);
    writefln("typeid(Bar).toHash: ", hbar);
    assert(hfoo != hbar);

    auto e = (ti_foo == ti_bar);
    writefln("opEquals: ", e ? "equal" : "not equal");
    assert(!e);

    auto c = (ti_foo.opCmp(ti_bar) == 0);
    writefln("opCmp: ", c ? "equal" : "not equal");
    assert(!c);
}

/************************************************/

struct Struct
{
    int langID;
    long _force_nrvo;
}

Struct[1] table;

Struct getfirst()
{
    foreach(v; table) {
        writeln(v.langID);
        assert(v.langID == 1);
        return v;
    }
    assert(0);
}

Struct getsecond()
{
    foreach(ref v; table) {
        writeln(v.langID);
        assert(v.langID == 1);
        return v;
    }
    assert(0);
}

void test3()
{
    table[0].langID = 1;

    auto v = getfirst();
    writeln(v.langID);
    assert(v.langID == 1);

    v = getsecond();
    writeln(v.langID);
    assert(v.langID == 1);
}

/************************************************/

template parseUinteger(string s)
{
    static if (s.length == 0)
    {   const char[] value = "";
        const char[] rest = "";
    }
    else static if (s[0] >= '0' && s[0] <= '9')
    {   const char[] value = s[0] ~ parseUinteger!(s[1..$]).value;
        const char[] rest = parseUinteger!(s[1..$]).rest;
    }
    else
    {   const char[] value = "";
        const char[] rest = s;
    }
}

template parseInteger(string s)
{
    static if (s.length == 0)
    {   const char[] value = "";
        const char[] rest = "";
    }
    else static if (s[0] >= '0' && s[0] <= '9')
    {   const char[] value = s[0] ~ parseUinteger!(s[1..$]).value;
        const char[] rest = parseUinteger!(s[1..$]).rest;
    }
    else static if (s.length >= 2 &&
                s[0] == '-' && s[1] >= '0' && s[1] <= '9')
    {   const char[] value = s[0..2] ~ parseUinteger!(s[2..$]).value;
        const char[] rest = parseUinteger!(s[2..$]).rest;
    }
    else
    {   const char[] value = "";
        const char[] rest = s;
    }
}

void test7()
{
    writeln(parseUinteger!("1234abc").value);
    writeln(parseUinteger!("1234abc").rest);
    writeln(parseInteger!("-1234abc").value);
    writeln(parseInteger!("-1234abc").rest);

    assert(parseUinteger!("1234abc").value == "1234");
    assert(parseUinteger!("1234abc").rest == "abc");
    assert(parseInteger!("-1234abc").value == "-1234");
    assert(parseInteger!("-1234abc").rest == "abc");
}

/************************************************/

class A34 { }
class B34 : A34 { }

void test11()
{
  A34 test=new B34;
  writefln("Test is ", test.toString);
  assert(test.toString == "test34.B34");
  A34 test_2=cast(A34)(new B34);
  writefln("Test 2 is ", test_2.toString);
  assert(test_2.toString == "test34.B34");
}

/************************************************/

struct Basic16(T, U) {}

struct Iterator16(T : Basic16!(T, U), U)
{
    static void Foo()
    {
        writeln(typeid(T), typeid(U));
        assert(is(T == int));
        assert(is(U == float));
    }
}

void test16()
{
    Iterator16!(Basic16!(int, float)).Foo();
}

/************************************************/

struct Vector34
{
    float x, y, z;

    public static Vector34 opCall(float x = 0, float y = 0, float z = 0)
    {
        Vector34 v;

        v.x = x;
        v.y = y;
        v.z = z;

        return v;
    }

    public string toString()
    {
        return std.string.format("<%f, %f, %f>", x, y, z);
    }
}

class Foo34
{
    private Vector34 v;

    public this()
    {
        v = Vector34(1, 0, 0);
    }

    public void foo()
    {
        bar();
    }

    private void bar()
    {
        auto s = foobar();
        writef("Returned: %s\n", s);
        assert(std.string.format("%s", s) == "<1.000000, 0.000000, 0.000000>");
    }

    public Vector34 foobar()
    {
        writef("Returning %s\n", v);

        return v;
        Vector34 b = Vector34();
        return b;
    }
}

void test34()
{
    Foo34 f = new Foo34();
    f.foo();
}

/************************************************/

void test39()
{
   double[][] foo = [[1.0],[2.0]];

   writeln(foo[0]); // --> [1] , ok
   writeln(foo[1]); // --> [2] , ok

   writeln(foo);       // --> [[1],4.63919e-306]  ack!
   writefln("%s", foo); // --> ditto
   auto f = std.string.format("%s", foo);
   assert(f == "[[1], [2]]");

   double[1][2] bar;
   bar[0][0] = 1.0;
   bar[1][0] = 2.0;

   writeln(bar);       // Error: Access violation
   auto r = std.string.format("%s", bar);
   assert(r == "[[1], [2]]");
}

/************************************************/

void test40()
{
    int[char] x;
    x['b'] = 123;
    writeln(x);
    auto r = std.string.format("%s", x);
    assert(r == "['b':123]");
    writeln(x['b']);
}

/************************************************/

void test49()
{
    struct A { int v; }

    A a = A(10);

  version (all)
  {
    writefln("Before test 1: ", a.v);
    if (a == a.init) { writeln(a.v,"(a==a.init)"); assert(0); }
    else { writeln(a.v,"(a!=a.init)"); assert(a.v == 10); }
  }
  else
  {
    writefln("Before test 1: ", a.v);
    if (a == a.init) { writeln(a.v,"(a==a.init)"); assert(a.v == 10); }
    else { writeln(a.v,"(a!=a.init)"); assert(0); }
  }

    a.v = 100;
    writefln("Before test 2: ", a.v);
    if (a == a.init) { writeln(a.v,"(a==a.init)"); assert(0); }
    else { writeln(a.v,"(a!=a.init)"); assert(a.v == 100); }

    a = A(1000);
    writefln("Before test 3: ", a.v);
    if (a == a.init) { writeln(a.v,"(a==a.init)"); assert(0); }
    else { writeln(a.v,"(a!=a.init)"); assert(a.v == 1000); }

  version (all)
    assert(a.init.v == 0);
  else
    assert(a.init.v == 10);
}

/************************************************/

struct TestStruct
{
    int dummy0 = 0;
    int dummy1 = 1;
    int dummy2 = 2;
}

void func53(TestStruct[2] testarg)
{
    writeln(testarg[0].dummy0);
    writeln(testarg[0].dummy1);
    writeln(testarg[0].dummy2);

    writeln(testarg[1].dummy0);
    writeln(testarg[1].dummy1);
    writeln(testarg[1].dummy2);

    assert(testarg[0].dummy0 == 0);
    assert(testarg[0].dummy1 == 1);
    assert(testarg[0].dummy2 == 2);

    assert(testarg[1].dummy0 == 0);
    assert(testarg[1].dummy1 == 1);
    assert(testarg[1].dummy2 == 2);
}

TestStruct[2] m53;

void test53()
{
    writeln(&m53);
    func53(m53);
}

/************************************************/

void test54()
{
    double a = 0;
    double b = 1;
    // Internal error: ..\ztc\cg87.c 3233
//    a += (1? b: 1+1i)*1i;
    writeln(a);
//    assert(a == 0);
    // Internal error: ..\ztc\cod2.c 1680
//    a += (b?1:b-1i)*1i;
    writeln(a);
//    assert(a == 0);
}

/************************************************/

void test57()
{
    alias long[char[]] AA;

    static if (is(AA T : T[U], U : const char[]))
    {
        writeln(typeid(T));
        writeln(typeid(U));

        assert(is(T == long));
        assert(is(U == const(char)[]));
    }

    static if (is(AA A : A[B], B : int))
    {
        assert(0);
    }

    static if (is(int[10] W : W[V], int V))
    {
        writeln(typeid(W));
        assert(is(W == int));
        writeln(V);
        assert(V == 10);
    }

    static if (is(int[10] X : X[Y], int Y : 5))
    {
        assert(0);
    }
}

/************************************************/

void main()
{
    test1();
    test3();
    test7();
    test11();
    test16();
    test34();
    test39();
    test40();
    test49();
    test53();
    test54();
    test57();

    writefln("Success");
}


