// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
---
*/

module test;

import std.stdio;
import std.string;

/*******************************************/

void test4()
{
    writeln("",true);
}

/*******************************************/

class Foo11 : Bar11 { }

class Foo11T(V)
{
    public void foo() {}
}

class Bar11
{
    public this(){
        f = new Foo11T!(int);
    }
    Foo11T!(int) f;
}

void test11()
{
    Foo11 fooIt = new Foo11();
    if (fooIt !is null)
        writefln("fooIt should be valid");
    fooIt.f.foo();
    writefln("it worked");
}

/*******************************************/

interface Father {}

class Mother {
     Father test() {
         writefln("Called Mother.test!");
         return new Child(42);
     }
}

class Child : Mother, Father {
     int data;

     this(int d) { data = d; }

     override Child test() {
         writefln("Called Child.test!");
         return new Child(69);
     }
}

void test14()
{
     Child aChild = new Child(105);
     Mother childsMum = aChild;
     Child childsChild = aChild.test();
     Child mumsChild = cast(Child) childsMum.test();
     writefln("Success2");
}

/*******************************************/

void test25()
{
    char[6] cstr = "123456"c;
    auto str1 = cast(wchar[3])(cstr);

    writefln("str1: ", (cast(char[])str1).length , " : ", (cast(char[])str1));
    assert(cast(char[])str1 == "123456"c);

    auto str2 = cast(wchar[3])("789abc"c);
    writefln("str2: ", (cast(char[])str2).length , " : ", (cast(char[])str2));
    assert(cast(char[])str2 == "789abc"c);

    auto str3 = cast(wchar[3])("defghi");
    writefln("str3: ", (cast(char[])str3).length , " : ", (cast(char[])str3));
    version (LittleEndian)
        assert(cast(char[])str3 == "d\000e\000f\000"c);
    version (BigEndian)
        assert(cast(char[])str3 == "\000d\000e\000f"c);
}

/*******************************************/

uint intRes()
{
        return 4;
}

void test28()
{
        auto s = std.string.format("%s", "abc123"[intRes() % $] );
        writefln( "%s", s );
        assert(s == "2");

        static const char[] foo = "abc123";
        s = std.string.format("%s", foo[intRes() % $] );
        assert(s == "2");


        static string bar = "abc123";
        s = std.string.format("%s", bar[intRes() % $] );
        assert(s == "2");

        const char[] abc = "abc123";
        s = std.string.format("%s", abc[intRes() % $] );
        assert(s == "2");

        string def = "abc123";
        s = std.string.format("%s", def[intRes() % $] );
        assert(s == "2");
}

/*******************************************/

class Foo37
{
    float[4] array = 1.0;
    int count = 10;
}

void test37()
{
    Foo37 f = new Foo37();

    writefln("Foo.array[0] = %s", f.array[0] );
    writefln("Foo.array[1] = %s", f.array[1] );
    writefln("Foo.array[2] = %s", f.array[2] );
    writefln("Foo.array[3] = %s", f.array[3] );
    writefln("Foo.count = %s", f.count );

    assert(f.array[0] == 1.0);
    assert(f.array[1] == 1.0);
    assert(f.array[2] == 1.0);
    assert(f.array[3] == 1.0);
    assert(f.count == 10);
}

/*******************************************/

void test45()
{
   char[] buffer = "abcdefghijklmnopqrstuvwxyz".dup;
   foreach(ref char c; buffer)
   {
       if('a' <= c && c <= 'z')
       {
           c -= cast(char)'a' - 'A'; // segfault here
       }
   }
   for(int i = 0; i < buffer.length; i++)
   {
       if('a' <= buffer[i] && buffer[i] <= 'z')
       {
           buffer[i] -= cast(char)'a' - 'A'; // segfault here
       }
   }
   writeln(buffer);
}

/*******************************************/

struct S59
{
    string toString()
    {
        return "foo";
    }
}

void test59()
{   S59 s;
    writefln("s = %s", s);

    string p;
    p = std.string.format("s = %s", s);
    assert(p == "s = foo");
}

/*******************************************/

void test61()
{
    int[][] f = [[1,2],[3,4]];
    assert(f[0][0] == 1);
    assert(f[0][1] == 2);
    assert(f[1][0] == 3);
    assert(f[1][1] == 4);
    writeln(f);
}

/*******************************************/

void test64()
{
    printf("test64()\n");
    int[] x = [1,2,3,4];
    int j = 4;

    foreach_reverse(v; x)
    {
        writeln(v);
        assert(j == v);
        j--;
    }
    assert(j == 0);

    j = 4;
    foreach_reverse(i, v; x)
    {
        writefln("[%s] = %s", i, v);
        assert(i + 1 == j);
        assert(j == v);
        j--;
    }
    assert(j == 0);
    printf("-test64()\n");
}

/*******************************************/

void test70()
{
    void foo(char[0] p)
    {
    }

    static const char[0] altsep;
    string s = std.string.format("test%spath", altsep);
    assert(s == "testpath");
    foo(altsep);
}

/*******************************************/

void main()
{
    test4();
    test11();
    test14();
    test25();
    test28();

    test37();
    test45();
    test59();
    test61();
    test64();
    test70();

    printf("Success\n");
}
