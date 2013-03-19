// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 9474

module ddoc9474;

///
void func() { }

version(none)
unittest { }

/// Example
unittest { func(); }

/// doc
void bar() { }

version(none)
unittest { }

/// Example
unittest { bar(); }
