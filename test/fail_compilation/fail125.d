/*
TEST_OUTPUT:
---
fail_compilation/fail125.d(16): Error: array index [2] is outside array bounds [0 .. 2]
fail_compilation/fail125.d(16): Error: cannot implicitly convert expression (tuple(a, b)) of type (int, int) to int
fail_compilation/fail125.d(19): Error: template instance fail125.main.recMove!(1, a, b) error instantiating
fail_compilation/fail125.d(26):        instantiated from here: recMove!(0, a, b)
fail_compilation/fail125.d(26): Error: template instance fail125.main.recMove!(0, a, b) error instantiating
---
*/

template recMove(int i, X...)
{
    void recMove()
    {
        X[i] = X[i+1];
        // I know the code is logically wrong, should test (i+2 < X.length)
        static if (i+1 < X.length)
            recMove!(i+1, X);
    }
}

void main()
{
    int a, b;
    recMove!(0, a, b);
}
