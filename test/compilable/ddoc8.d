// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 8

/** foo */

class Foo(T) : Bar
{
    /// ensure test documented even if 'Bar' doesn't exist
    pure void test() { }
}
