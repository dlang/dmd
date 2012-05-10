// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

int sum_of_sq(int x) pure nothrow @safe
{
    int result = 0;
    foreach (i; 0 .. x)
    {
        __ctfeWrite(i, "^^2 == ");
        int power = i ^^ 2;
        __ctfeWriteln(power);
        result += power;
    }
    __ctfeWriteln("result == ", result);
    return result;

}

static assert(sum_of_sq(7) == 91);

