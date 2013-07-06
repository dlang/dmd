// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 7656

module ddoc7656;

/**
--------
int x; // This is a $ comment (and here is some
int y; // more information about that comment)
--------
*/
void main() { }


/**
(Regression check)

Example:
----
assert(add(1, 1) == 2);
----
*/
int add(int a, int b) { return a + b; }
