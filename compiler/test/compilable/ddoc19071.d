// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh
// EXTRA_SOURCES: extra-files/ddoc_minimal.ddoc

// https://github.com/dlang/dmd/issues/19071
module ddoc19071;

template case3(fun...)
{
    /++ Blah
    Params:
        r = a value
    +/
    void case3(R)(R r){}
}
