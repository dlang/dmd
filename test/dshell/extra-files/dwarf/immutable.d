/*
EXTRA_ARGS: -gdwarf=5
*/

void main()
{
    immutable int I = 3;
}

immutable(int) foo()
{
    return 2;
}