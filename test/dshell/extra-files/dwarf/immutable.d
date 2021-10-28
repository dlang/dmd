/*
EXTRA_ARGS: -gdwarf=5
MIN_OBJDUMP_VERSION: 2.30
*/

void main()
{
    immutable int I = 3;
}

immutable(int) foo()
{
    return 2;
}
