// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 10325

module ddoc10325;

/** */
template templ(T...)
    if (someConstraint!T)
{
}

/** */
void foo(T)(T t)
    if (someConstraint!T)
{
}
