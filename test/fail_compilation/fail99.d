
import std.stdio;

void foo(void delegate(int) dg)
{
    dg();
    //writefln("%s", dg(3));
}

void main()
{
    foo(delegate(int i)
	{
	    writefln("i = %d\n", i);
	}
       );
}
