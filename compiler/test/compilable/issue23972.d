// REQUIRED_ARGS: -vcg-ast -o-
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/issue23972.sh

// https://github.com/dlang/dmd/issues/23972

enum E
{
    E1
}

E[int] aa;

void main()
{
    assert(aa == aa);
}
