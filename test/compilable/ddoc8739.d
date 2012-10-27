// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 8739

module ddoc8739;

///
void delegate(int a) dg;

///
void delegate(int b) dg2;

///
void delegate(int c)[] dg3;

///
void delegate(int d)* dg4;

void main() {}
