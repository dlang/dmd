// https://issues.dlang.org/show_bug.cgi?id=19320

// REQUIRED_ARGS: -O -cov

auto staticArray(U, T)(T)
{
    U[] theArray = void;
    return theArray;
}


void main()
{
    staticArray!(int, int)(3);
}
