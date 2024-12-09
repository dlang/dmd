// REQUIRED_ARGS: -preview=dip1000 -preview=dip1008 -Ifail_compilation/extra-files
// https://issues.dlang.org/show_bug.cgi?id=20023
/*
TEST_OUTPUT:
---
fail_compilation/imports/test20023b.d(8): Error: scope variable `e` may not be returned
        return e;
               ^
fail_compilation/test20023.d(19): Error: template instance `imports.test20023b.threw!()` error instantiating
    threw!()();
    ^
---
*/
import imports.test20023b;

@safe:
void main()
{
    threw!()();
}
