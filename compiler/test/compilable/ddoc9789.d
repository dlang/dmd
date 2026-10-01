// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -w -o- -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc

module ddoc9789;

///
struct S {}

///
alias A = S;
