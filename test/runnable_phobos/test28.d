module test;

import core.stdc.stdio;
import core.vararg;
import std.stdio;
import std.string;

/*******************************************/

void test8()
{
   int[] test;
   test.length = 10;
   // Show address of array start and its length (10)
   writefln("%s %s", cast(uint)test.ptr, test.length);

   test.length = 1;
   // Show address of array start and its length (1)
   writefln("%s %s", cast(uint)test.ptr, test.length);

   test.length = 8;
   // Show address of array start and its length (8)
   writefln("%s %s", cast(uint)test.ptr, test.length);

   test.length = 0;
   // Shows 0 and 0!
   writefln("%s %s", cast(uint)test.ptr, test.length);
   assert(test.length == 0);
   assert(test.ptr != null);
}

/*******************************************/

void test23()
{
    auto t=['a','b','c','d'];
    writeln(typeid(typeof(t)));
    assert(is(typeof(t) == char[]));

    const t2=['a','b','c','d','e'];
    writeln(typeid(typeof(t2)));
    assert(is(typeof(t2) == const(const(char)[])));
}

/*******************************************/

template a34(string name, T...)
{
    string a34(string name,T t)
    {
        string localchar;
        foreach (a34; T)
        {
            writefln(`hello`);
            localchar ~= a34.mangleof;
        }
        return localchar;
    }
}

void test34()
{
    writeln(a34!("Adf"[], typeof("adf"),uint)("Adf"[],"adf",1234));
}

/*******************************************/

template a36(AnotherT,string name,T...){
    AnotherT a36(M...)(M){
        AnotherT localchar;
        foreach(a;T)
        {
            writefln(`hello`);
            localchar~=a.mangleof;
        }
        return cast(AnotherT)localchar;
    }
}

void test36()
{
    string b="adf";
    uint i=123;
    char[3] c="Adf";
    writeln(a36!(typeof(b),"Adf")());
}

/*******************************************/

void test39()
{
    void print(string[] strs)
    {
        writeln(strs);
        assert(format("%s", strs) == `["Matt", "Andrew"]`);
    }

    print(["Matt", "Andrew"]);
}

/*******************************************/

void test40()
{
    class C
    {
        Object propName()
        {
            return this;
        }
    }

    auto c = new C;

    with (c.propName)
    {
        writeln(toString());
    }

    auto foo = c.propName;
}

/*******************************************/

void test41()
{
    auto test = new char [2];

    int x1, x2, x3;
    char[] foo1() { x1++; return test; }
    int foo2() { x2++; return 0; }
    int foo3() { x3++; return 1; }

    test [] = 'a';
    test = test [0 .. 1];

    foo1() [foo2() .. foo3()] = 'b';
    assert(x1 == 1);
    assert(x2 == 1);
    assert(x3 == 1);

    //test [0 .. 2] = 'b'; // this line should assert
    writef ("%s\n", test.ptr [0 .. 2]);
}

/*******************************************/

struct A43
{
    static const MY_CONST_STRING = "hello";

    void foo()
    {
        // This will either print garbage or throw a UTF exception.
        // But if never_called() is commented out, then it will work.
        writefln("%s", MY_CONST_STRING);
    }
}

void never_called43()
{
    // This can be anything; there just needs to be a reference to
    // A43.MY_CONST_STRING somewhere.
    writefln("%s", A43.MY_CONST_STRING);
}

void test43()
{
    A43 a;
    a.foo();
}

/*******************************************/

class A44
{
    static const MY_CONST_STRING = "hello";

    this()
    {
        // This will either print garbage or throw a UTF exception.
        // But if never_called() is commented out, then it will work.
        writefln("%s", MY_CONST_STRING);
    }
}

void never_called44()
{
    // This can be anything; there just needs to be a reference to
    // A44.MY_CONST_STRING somewhere.
    writefln("%s", A44.MY_CONST_STRING);
}

void test44()
{
    A44 a = new A44();
}

/*******************************************/

void test58()
{
    struct S
    {
        int i;
        int[4] bar = 4;
        float[4] abc;
    }

    static S a = {i: 1};
    static S b;

    writefln("a.bar: %s, %s", a.bar, a.abc);
    assert(a.i == 1);
    assert(a.bar[0] == 4);
    assert(a.bar[1] == 4);
    assert(a.bar[2] == 4);
    assert(a.bar[3] == 4);
    writefln("b.bar: %s, %s", b.bar, b.abc);
    assert(b.i == 0);
    assert(b.bar[0] == 4);
    assert(b.bar[1] == 4);
    assert(b.bar[2] == 4);
    assert(b.bar[3] == 4);
}

/*******************************************/

void bug59(string s)()
{
  writeln(s);
  writeln(s.length);
}

void test59()
{
    bug59!("1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234")();
}

/*******************************************/

void test62()
{
    Vector62 a;
    a.set(1,2,24);
    a = a * 2;
    writeln(a.x, a.y, a.z);
    assert(a.x == 2);
    assert(a.y == 4);
    assert(a.z == 48);
}

struct Vector62
{
    float x,y,z;

    // constructor
    void set(float _x, float _y, float _z)
    {
      x = _x;
      y = _y;
      z = _z;
    }

    Vector62 opBinary(string op : "*")(float s)
    {
      Vector62 ret;
      ret.x = x*s;
      ret.y = y*s;
      ret.z = z*s;
      return ret;
    }
}

/*******************************************/

struct Data63
{
    int x, y;

    /// To make size > 8 so NRVO is used.
    /// Program runs correctly with this line commented out:
    byte filler;
}

Data63 frob(ref Data63 d)
{
    Data63 ret;
    ret.y = d.x - d.y;
    ret.x = d.x + d.y;
    return ret;
}

void test63()
{
    Data63 d; d.x = 1; d.y = 2;
    d = frob(d);
    writeln(d.x);
    writeln(d.y);
    assert(d.x == 3 && d.y == -1);
}

/*******************************************/

class Foo64
{
    this() { writefln("Foo64 created"); }
    ~this() { writefln("Foo64 destroyed"); }
}

template Mix64()
{
    void init() {
        ptr = new Foo64;
    }
    Foo64 ptr;
}

class Container64
{
    this() { init(); }
    mixin Mix64;
}


void test64()
{
    auto x = new Container64;

    assert(!(x.classinfo.flags & 2));
}

/*******************************************/

void main()
{
    printf("Start\n");

    test23();
    test34();
    test36();
    test39();
    test40();
    test41();
    test43();
    test44();
    test58();
    test59();
    test62();
    test63();
    test64();

    printf("Success\n");
}

