/*
TEST_OUTPUT:
----
fail_compilation/fail5634.d(9): Error: only one `main`$?:windows=, `WinMain`, or `DllMain`$ allowed. Previously found `main` at fail_compilation/fail5634.d(8)
----
*/

void main() { }
void main() { }
