// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -w -o- -c -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 9695

module ddoc9695;

/** EC */
enum EC : char
{
    /** one */
    one = '1',

    /** two */
    two,

    /** three */
    three = '3'
}

struct S { int x; int opCmp(S s) { return 0; } }

/** EArr */
enum EArr : S
{
    /** one */
    one = S(1),

    /** two */
    two = S(2),
}
