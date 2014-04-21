
import std.stdio;

/***********************/

@nogc int test1()
{
    return 3;
}

/***********************/

int main()
{
    test1();

    writeln("Success");
    return 0;
}
