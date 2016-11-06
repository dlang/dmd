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
    import std.conv;

    int result = 0;
    foreach (i; 0 .. x)
    {
        __ctfeWrite(to!string(i));
        __ctfeWrite("^^2 == ");
       int power = i ^^ 2;
        __ctfeWrite(power.to!string ~ "\n");
        result += power;
    }
    __ctfeWrite("result == ");
    __ctfeWrite(to!string(result) ~ "\n");
    return result;

}

static assert(sum_of_sq(7) == 91);
