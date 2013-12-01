// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 11479

module ddoc11479;

///
struct S1(T)
{
    ///
    int a;

    ///
private:
    int x;

    ///
    int b;
}


///
struct S2(T)
{
    ///
    int a;

    ///
    private int x;

    ///
    int b;
}


///
struct S3(T)
{
    ///
    int a;

    ///
    private { int x; }

    ///
    int b;
}
