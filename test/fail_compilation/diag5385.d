/*
TEST_OUTPUT:
---
fail_compilation/diag5385.d(27): Error: `imports.fail5385.C.privX` is not visible from module `diag5385`
fail_compilation/diag5385.d(27): Error: no property `privX` for type `imports.fail5385.C`, did you mean `imports.fail5385.C.privX`?
fail_compilation/diag5385.d(28): Error: `imports.fail5385.C.packX` is not visible from module `diag5385`
fail_compilation/diag5385.d(28): Error: no property `packX` for type `imports.fail5385.C`, did you mean `imports.fail5385.C.packX`?
fail_compilation/diag5385.d(29): Error: `imports.fail5385.C.privX2` is not visible from module `diag5385`
fail_compilation/diag5385.d(29): Error: no property `privX2` for type `imports.fail5385.C`, did you mean `imports.fail5385.C.privX2`?
fail_compilation/diag5385.d(30): Error: `imports.fail5385.C.packX2` is not visible from module `diag5385`
fail_compilation/diag5385.d(30): Error: no property `packX2` for type `imports.fail5385.C`, did you mean `imports.fail5385.C.packX2`?
fail_compilation/diag5385.d(31): Error: `imports.fail5385.S.privX` is not visible from module `diag5385`
fail_compilation/diag5385.d(31): Error: no property `privX` for type `S`, did you mean `imports.fail5385.S.privX`?
fail_compilation/diag5385.d(32): Error: `imports.fail5385.S.packX` is not visible from module `diag5385`
fail_compilation/diag5385.d(32): Error: no property `packX` for type `S`, did you mean `imports.fail5385.S.packX`?
fail_compilation/diag5385.d(33): Error: `imports.fail5385.S.privX2` is not visible from module `diag5385`
fail_compilation/diag5385.d(33): Error: no property `privX2` for type `S`, did you mean `imports.fail5385.S.privX2`?
fail_compilation/diag5385.d(34): Error: `imports.fail5385.S.packX2` is not visible from module `diag5385`
fail_compilation/diag5385.d(34): Error: no property `packX2` for type `S`, did you mean `imports.fail5385.S.packX2`?
---
*/

import imports.fail5385;

void main()
{
    C.privX = 1;
    C.packX = 1;
    C.privX2 = 1;
    C.packX2 = 1;
    S.privX = 1;
    S.packX = 1;
    S.privX2 = 1;
    S.packX2 = 1;
}
