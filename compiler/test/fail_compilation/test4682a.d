/*
TEST_OUTPUT:
----
fail_compilation/test4682a.d(18): Error: divide by 0
auto a = int.min / 0;
                   ^
fail_compilation/test4682a.d(19): Error: divide by 0
auto b = long.min / 0;
                    ^
fail_compilation/test4682a.d(20): Error: divide by 0
auto c = int.min % 0;
                   ^
fail_compilation/test4682a.d(21): Error: divide by 0
auto d = long.min % 0;
                    ^
----
*/
auto a = int.min / 0;
auto b = long.min / 0;
auto c = int.min % 0;
auto d = long.min % 0;
