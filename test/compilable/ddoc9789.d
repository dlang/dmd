// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -w -o- -c -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 9789

module ddoc9789;

///
struct S {}

///
alias A = S;
