/*
TEST_OUTPUT:
---
fail_compilation/fail2350.d(10): Error: function `fail2350.test2350` naked assembly functions with contracts are not supported
void test2350()
     ^
---
*/

void test2350()
in
{
}
do
{
	asm { naked; }
}
