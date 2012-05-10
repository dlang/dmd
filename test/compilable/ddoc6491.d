// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/diff-postscript.sh ddoc6491.html

module ddoc6491;

import core.cpuid;

enum int c6491 = 4;

/// test
void bug6491a(int a = ddoc6491.c6491, string b = core.cpuid.vendor);


