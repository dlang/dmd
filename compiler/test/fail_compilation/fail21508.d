/*
REQUIRED_ARGS: -Ifail_compilation/imports/
EXTRA_FILES: imports/import21508.d
TEST_OUTPUT:
---
fail_compilation/fail21508.d(19): Error: import `fail21508.import21508` is used as a type
    auto c = new import21508();
             ^
---
*/
import import21508;

// import21508 is a private class, code should not compile
// The compiler used to "helpfully" look inside the import,
// bypassing the shadowing that this introduces.

void main ()
{
    auto c = new import21508();
}
