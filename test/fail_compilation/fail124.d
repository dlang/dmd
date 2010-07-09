import std.stdio;

interface C
{
        void f();
}

class CC : C,C
{
        void f() { writefln("hello"); }
}

void main()
{
        CC cc = new CC();
        cc.f();
}

