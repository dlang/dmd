// PERMUTE_ARGS:
// REQUIRED_ARGS: -w -D -Dd${RESULTS_DIR}/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 5653
module ddoc5653;

/**
Params:
    i = integer
Template_Params:
    T = testing t
    U = testing u
    V = testing v
*/
void foo(T, U, V)(int i);

