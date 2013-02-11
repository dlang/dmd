/*
TEST_OUTPUT:
---
fail_compilation/ice9494.d(8): Error: Variable 'test' used as its own key type in declaration 'int[test] test;'
---
*/

int[test] test;
