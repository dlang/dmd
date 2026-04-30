// https://github.com/dlang/dmd/issues/19346
// Ddoc: ditto on struct should not prevent member documentation

// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

module ddoc19346;

/// Docs for foo and Foo
void foo() {}

/// ditto
struct Foo
{
    /// Docs for bar
    void bar() {}
}
