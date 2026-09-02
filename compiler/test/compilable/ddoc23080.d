// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc

// https://issues.dlang.org/show_bug.cgi?id=23080
module ddoc23080;

/// Base class holding the real implementation.
class Base23080
{
    /// call doc
    final void call() {}
}

/// Derived class forwarding call via a documented alias.
class Derived23080 : Base23080
{
    /// call doc
    alias call = Base23080.call;
}
