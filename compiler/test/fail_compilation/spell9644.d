// REQUIRED_ARGS: -o-
// EXTRA_FILES: imports/spell9644a.d imports/spell9644b.d
/*
TEST_OUTPUT:
---
fail_compilation/spell9644.d(42): Error: undefined identifier `b`
    cast(void)b; // max distance 0, no match
              ^
fail_compilation/spell9644.d(43): Error: undefined identifier `xx`
    cast(void)xx; // max distance 1, no match
              ^
fail_compilation/spell9644.d(44): Error: undefined identifier `cb`, did you mean variable `ab`?
    cast(void)cb; // max distance 1, match
              ^
fail_compilation/spell9644.d(45): Error: undefined identifier `bc`, did you mean variable `abc`?
    cast(void)bc; // max distance 1, match
              ^
fail_compilation/spell9644.d(46): Error: undefined identifier `ccc`
    cast(void)ccc; // max distance 2, match
              ^
fail_compilation/spell9644.d(48): Error: undefined identifier `cor2`, did you mean variable `cor1`?
    cast(void)cor2; // max distance 1, match "cor1", but not cora from import (bug 13736)
              ^
fail_compilation/spell9644.d(49): Error: undefined identifier `pua`, did you mean variable `pub`?
    cast(void)pua;  // max distance 1, match "pub" from import
              ^
fail_compilation/spell9644.d(50): Error: undefined identifier `priw`
    cast(void)priw; // max distance 1, match "priv" from import, but do not report (bug 5839)
              ^
---
*/

import imports.spell9644a;

int a;
int ab;
int abc;
int cor1;

int main()
{
    cast(void)b; // max distance 0, no match
    cast(void)xx; // max distance 1, no match
    cast(void)cb; // max distance 1, match
    cast(void)bc; // max distance 1, match
    cast(void)ccc; // max distance 2, match

    cast(void)cor2; // max distance 1, match "cor1", but not cora from import (bug 13736)
    cast(void)pua;  // max distance 1, match "pub" from import
    cast(void)priw; // max distance 1, match "priv" from import, but do not report (bug 5839)
}
