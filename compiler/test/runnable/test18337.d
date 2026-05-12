// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov
// POST_SCRIPT: runnable/extra-files/coverage-postscript.sh
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

extern(C) void dmd_coverDestPath(string path);

pragma(inline, true)
int square(int x)
{
    int y = x * x;
    return y;
}

pragma(inline, true)
int addSquares(int a, int b)
{
    return square(a) + square(b);
}

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
    auto value = addSquares(2, 3);
    assert(value == 13);
}
