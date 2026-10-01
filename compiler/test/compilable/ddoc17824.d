// https://github.com/dlang/dmd/issues/17824
// DDOC_CONSTRAINT macro should be applied to non-function template constraints

// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// EXTRA_SOURCES: extra-files/ddoc17824.ddoc
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh

module ddoc17824;

/// A struct template with constraint
struct Foo(T) if (is(T == int)) {}

/// A class template with constraint
class Bar(T) if (is(T == int)) {}

/// A plain template with constraint
template Baz(T) if (is(T == int))
{
    alias Baz = T;
}

/// A function template with constraint
void qux(T)(T x) if (is(T == int)) {}
