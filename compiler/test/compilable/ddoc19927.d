// https://github.com/dlang/dmd/issues/19927
// DDoc dropped later overloads when a template contains
// multiple plain functions sharing the template's name.

// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

module ddoc19927;

/++
Foo
+/
template foo(T, U)
    if (is(T : int) && !is(U : int))
{
    ///
    void foo(T x, U y) {}
    ///
    void foo(U x, T y) {}
}
