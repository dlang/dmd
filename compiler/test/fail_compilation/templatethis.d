/*
TEST_OUTPUT:
---
fail_compilation/templatethis.d(9): Error: cannot use `this` outside an aggregate type
fail_compilation/templatethis.d(13): Error: cannot use `this` outside an aggregate type
---
*/

template t(this T)
{
}

enum e(this T) = 1;
