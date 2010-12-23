module foo.bar;
import core.vararg;
import std.stdio;
pragma (lib, "test");
pragma (msg, "Hello World");
typedef double mydbl = 10;
int main()
in
{
assert(1 + (2 + 3) == -(1 - 2 * 3));
}
out(result)
{
assert(result == 0);
}
body
{
float f = (float).infinity;
int i = cast(int)f;
writeln((i , 1),2);
writeln(cast(int)(float).max);
assert(i == cast(int)(float).max);
assert(i == -2147483648u);
return 0;
}
template Foo(T,int V)
{
int bar(double d, int x)
{
if (d)
{
d++;
}
else
d--;
asm { naked; }
asm { mov EAX,3; }
for (;;)
{
{
d = d + 1;
}
}
{
for (int i = 0;
 i < 10; i++)
{
{
d = i ? d + 1 : 5;
}
}
}
char[] s;
foreach (char c; s)
{
d *= 2;
if (d)
break;
else
continue;
}
switch (V)
{
case 1:
{
}
case 2:
{
break;
}
case 3:
{
goto case 1;
}
case 4:
{
goto default;
}
default:
{
d /= 8;
break;
}
}
loop:
while (x)
{
x--;
if (x)
break loop;
else
continue loop;
}
do
{
x++;
}
while (x < 10);
try
{
try
{
bar(1,2);
}
catch(Object o)
{
x++;
}
}
finally
{
x--;
}
Object o;
synchronized(o) {
x = ~x;
}
synchronized {
x = x < 3;
}
with (o)
{
toString();
}
}
}
static this();
interface iFoo
{
}
class xFoo : iFoo
{
}
class Foo3
{
    this(int a,...);
    this(int* a)
{
}
}
alias int myint;
static notquit = 1;
class Test
{
    void a()
{
}
    void b()
{
}
    void c()
{
}
    void d()
{
}
    void e()
{
}
    void f()
{
}
    void g()
{
}
    void h()
{
}
    void i()
{
}
    void j()
{
}
    void k()
{
}
    void l()
{
}
    void m()
{
}
    void n()
{
}
    void o()
{
}
    void p()
{
}
    void q()
{
}
    void r()
{
}
    void s()
{
}
    void t()
{
}
    void u()
{
}
    void v()
{
}
    void w()
{
}
    void x()
{
}
    void y()
{
}
    void z()
{
}
    void aa()
{
}
    void bb()
{
}
    void cc()
{
}
    void dd()
{
}
    void ee()
{
}
    template A(T)
{
}
    alias A!(uint) getHUint;
    alias A!(int) getHInt;
    alias A!(float) getHFloat;
    alias A!(ulong) getHUlong;
    alias A!(long) getHLong;
    alias A!(double) getHDouble;
    alias A!(byte) getHByte;
    alias A!(ubyte) getHUbyte;
    alias A!(short) getHShort;
    alias A!(ushort) getHUShort;
    alias A!(real) getHReal;
}
template templ(T)
{
void templ(T val)
{
pragma (msg, "Invalid destination type.");
}
}
static char[] charArray = ['"','\''];

class Point
{
    auto x = 10;
    uint y = 20;
}
template Foo2(bool bar)
{
void test()
{
static if(bar)
{
int i;
}
else
{
}

static if(!bar)
{
}
else
{
}

}
}
template Foo4()
{
void bar()
{
}
}
class Baz4
{
    mixin Foo4!() foo;
    alias foo.bar baz;
}
template test(T)
{
int test(T t)
{
if (auto o = cast(Object)t)
return 1;
return 0;
}
}
enum x6 = 1;
bool foo6(int a, int b, int c, int d)
{
return (a < b) != (c < d);
}
auto  foo7(int x)
{
return 5;
}
class D8
{
}
void func8()
{
scope a = new D8;
}
template func9(T)
{
T func9()
{
T i;
scope(exit) i = 1;
scope(success) i = 2;
scope(failure) i = 3;
return i;
}
}
template V10(T)
{
void func()
{
{
for (int i,j = 4; i < 3; i++)
{
{
}
}
}
}
}
int foo11(int function() fn)
{
return fn();
}
template bar11(T)
{
int bar11()
{
return foo11(function int()
{
return 0;
}
);
}
}
