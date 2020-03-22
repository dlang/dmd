/*
Small test to check whether the environment is propagated as expected
(not intended to stay, just checking in the CI)

REQUIRED_ARGS: -v -I../../druntime/src
PERMUTE_ARGS:
DFLAGS:
POST_SCRIPT: runnable/extra-files/printenv.sh

TRANSFORM_OUTPUT: remove_lines("^(?!(DFLAG))")
TEST_OUTPUT:
---
DFLAGS    (none)
---
*/

extern(C)
{
    char* getenv(scope const char*);
    int printf(scope const char*, ...);
}

int main()
{
    const char[7] key = "DFL" ~ "AGS\0";
    const val = getenv(key.ptr);

    // Dflags should be absent or empty
    if (!val || !*val)
        return 0;

    int len;
    const(char)* p = val;
    while (*(p++))
        len++;

    printf("Got unexpected value: `%.*s`", len, val);
    return 1;
}
