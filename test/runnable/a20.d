// EXTRA_SOURCES: imports/a20a.d
// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov
// POST_SCRIPT: runnable/extra-files/a20-postscript.sh

import a20a;

extern(C) void dmd_coverDestPath(string path);

void main()
{
    dmd_coverDestPath("test_results/runnable");
}

