// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/diff-postscript.sh ddoc13.html

/// struct doc
struct Bug4107(T)
{
    /// templated function doc
    void foo(U)(U u) { }
}

/// alpha
struct Bug4107b(T) {
    /// beta
    struct B(U) {
        /// gamma
        struct C(V) {
            /// delta
            struct D(W) {
                /// epsilon
                B!W e(X)(C!V c, X[] x...) {}
            }
        }
    }
}

