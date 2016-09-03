/*
TEST OUTPUT:
0^^2 == 1
1^^2 == 1
2^^2 == 4
3^^2 == 9
4^^2 == 16
5^^2 == 25
6^^2 == 36
result == 91
*/
int sum_of_sq(int x) pure nothrow @safe
{
    int result = 0;
    foreach (i; 0 .. x)
    {
        import std.conv;
        __ctfeWrite(to!string(i));
        __ctfeWrite("^^2 == ");
       int power = i ^^ 2;
        __ctfeWriteln(power);
        result += power;
    }
    __ctfeWrite("result == ");
    __ctfeWriteln(to!string(result));
    return result;

}

static assert(sum_of_sq(7) == 91);
