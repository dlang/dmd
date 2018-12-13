// REQUIRED_ARGS: -dw
/*
TEST_OUTPUT:
---
compilable/test19107.d(14): Deprecation: `imports.test19107b.I` is not visible from module `test19107`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19107

import imports.test19107b;

void all(alias pred, T)(T t)
    if (is(typeof(I!pred(t))))
{ }

void main(string[] args)
{
    args.all!(c => c);
}
