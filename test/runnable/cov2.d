// PERMUTE_ARGS:
// POST_SCRIPT: runnable/extra-files/cov2-postscript.sh
// REQUIRED_ARGS: -cov

extern(C) void dmd_coverDestPath(string pathname);

int main()
{
    dmd_coverDestPath("test_results/runnable");

    int counter = 20;
    do {
        --counter;
    }
    while(counter > 0)

        return 0;
}
