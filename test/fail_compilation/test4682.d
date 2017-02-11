/*
TEST_OUTPUT:
----
fail_compilation/test4682.d(18): Error: integer overflow: int.min / -1
fail_compilation/test4682.d(18): Error: integer overflow: int.min / -1
fail_compilation/test4682.d(18): Error: integer overflow: int.min / -1
fail_compilation/test4682.d(19): Error: integer overflow: long.min / -1
fail_compilation/test4682.d(19): Error: integer overflow: long.min / -1
fail_compilation/test4682.d(19): Error: integer overflow: long.min / -1
fail_compilation/test4682.d(20): Error: integer overflow: int.min % -1
fail_compilation/test4682.d(20): Error: integer overflow: int.min % -1
fail_compilation/test4682.d(20): Error: integer overflow: int.min % -1
fail_compilation/test4682.d(21): Error: integer overflow: long.min % -1
fail_compilation/test4682.d(21): Error: integer overflow: long.min % -1
fail_compilation/test4682.d(21): Error: integer overflow: long.min % -1
----
*/
auto a = int.min / -1;
auto b = long.min / -1;
auto c = int.min % -1;
auto d = long.min % -1;
