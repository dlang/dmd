/*
TEST_OUTPUT:
---
fail_compilation/issue23470.d(8): Error: function `issue23470.I.foo` cannot be `abstract` in `final` interface `I`
---
*/

final interface I { void foo(); }
