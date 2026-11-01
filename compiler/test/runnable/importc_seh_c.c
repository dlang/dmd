// EXTRA_SOURCES: imports/importc_seh.d
// DISABLED: win64 - crashes LDC's backend, not dmd's
// Verifies __try/__except/__finally, lowered to try/catch/finally.

__import importc_seh;

int finallyRanOnNormalReturn;
int finallyRanOnException;

int normalPath(void)
{
    __try {
        return 1;
    } __finally {
        finallyRanOnNormalReturn = 1;
    }
}

int caughtPath(void)
{
    __try {
        throwIt();
        return 0; // unreached
    } __except(1) {
        return 2;
    }
}

int finallyRunsOnException(void)
{
    __try {
        __try {
            throwIt();
        } __finally {
            finallyRanOnException = 1;
        }
        return 0; // unreached
    } __except(1) {
        return 3;
    }
}

int main(void)
{
    if (normalPath() != 1) return 1;
    if (!finallyRanOnNormalReturn) return 2;

    if (caughtPath() != 2) return 3;

    if (finallyRunsOnException() != 3) return 4;
    if (!finallyRanOnException) return 5;

    return 0;
}
