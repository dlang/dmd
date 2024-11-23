// https://issues.dlang.org/show_bug.cgi?id=21025
// REQUIRED_ARGS: -preview=dip1021

/*
TEST_OUTPUT:
---
fail_compilation/test21025.d(23): Error: variable `r` cannot be read at compile time
if (binaryFun(r, r)) {}
              ^
fail_compilation/test21025.d(23):        called from here: `binaryFun(r, r)`
if (binaryFun(r, r)) {}
             ^
fail_compilation/test21025.d(32): Error: template `uniq` is not callable using argument types `!()(void[])`
    uniq([]);
        ^
fail_compilation/test21025.d(22):        Candidate is: `uniq()(int[] r)`
void uniq()(int[] r)
     ^
---
*/

void uniq()(int[] r)
if (binaryFun(r, r)) {}

bool binaryFun(T, U)(T, U)
{
    return true;
}

void generateStatements()
{
    uniq([]);
}
