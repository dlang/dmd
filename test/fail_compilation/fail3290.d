// https://issues.dlang.org/show_bug.cgi?id=3290

void main()
{
    const(int)[] array;
    foreach (ref int i; array) {
        //i = 42;
    }
}
