// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_class_assign.d(18): Warning: variable `y` already `null`
compilable/diag_access_class_assign.d(19): Warning: returned expression is always `null`
compilable/diag_access_class_assign.d(26): Warning: returned expression is always `null`
---
*/

class C {}

C f()
{
	C x;
    C y;                        // no warn, because null
    y = x;                      // warn, already `null`
    return y;                   // warn, always `null` return
}

C g()
{
	C x;
    C y = x;                    // no warn, because leaks in return
    return y;
}
