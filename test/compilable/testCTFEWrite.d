/*
TEST_OUTPUT:
---
0^^2 == 0
1^^2 == 1
2^^2 == 4
3^^2 == 9
result == 14
---
*/
int sum_of_sq(int x) pure nothrow @safe
{
    const string newline = "\n";

    int result = 0;
    foreach (i; 0 .. x)
    {
        __ctfeWrite(toString(i));
        __ctfeWrite("^^2 == ");
        int power = i ^^ 2;
        __ctfeWrite(toString(power));
        __ctfeWrite(newline);
        result += power;
    }
    __ctfeWrite("result == ");
    __ctfeWrite(toString(result));
    __ctfeWrite(newline);

    return result;
}

static assert(sum_of_sq(4) == 14);

// Naive toString to avoid phobos
string toString(int number) pure nothrow @safe
{
    if (number == 0)
        return "0";

    string res;
    const isNeg = number < 0;
    if (isNeg)
        number = -number;

    while (number)
    {
        const dig = number % 10;
        number /= 10;
        res = "0123456789"[dig] ~ res;
    }

    if (isNeg)
        res = "-" ~ res;

    return res;
}
