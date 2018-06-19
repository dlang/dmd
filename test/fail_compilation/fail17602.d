/*
TEST_OUTPUT:
---
fail_compilation/fail17602.d(16): Error: cannot implicitly convert expression `cast(Status)0` of type `imports.imp17602.Status` to `fail17602.Status`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17602

import imports.imp17602;

enum Status { off }

void main()
{
    Status status = imports.imp17602.Status.on;
}
