// EXTRA_SOURCES: imports/a20a.d
// PERMUTE_ARGS:
// REQUIRED_ARGS: -cov
// POST_SCRIPT: runnable/extra-files/coverage-postscript.sh
// EXECUTE_ARGS: ${RESULTS_DIR}/runnable

import a20a;

extern(C) void dmd_coverDestPath(string path);

void main(string[] args)
{
    dmd_coverDestPath(args[1]);
}

