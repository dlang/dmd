// PERMUTE_ARGS:
// POST_SCRIPT: runnable/extra-files/coverage-postscript.sh
// REQUIRED_ARGS: -cov
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

struct A
{
    bool opEquals(A o) const
    {
        return false;
    }

}

extern(C) void dmd_coverDestPath(string pathname);

void main(string[] args)
{
    dmd_coverDestPath(args[1]);

    auto a = A();
    auto b = A();
    assert(a != b);
}
