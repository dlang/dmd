/*
TEST_OUTPUT:
----
fail_compilation/fail5634.d(11): Error: function `D main()` conflicts with previous declaration at fail_compilation/fail5634.d(10)
void main() { }
     ^
---
*/

void main() { }
void main() { }
