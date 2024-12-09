/*
TEST_OUTPUT:
---
fail_compilation/fail127.d(13): Error: a struct is not a valid initializer for a `char[][]`
char[][] Level2Text1 = {"LOW", "MEDIUM", "HIGH"};
                       ^
fail_compilation/fail127.d(14): Error: a struct is not a valid initializer for a `string[]`
string[] Level2Text2 = {"LOW", "MEDIUM", "HIGH"};    // for D2
                       ^
---
*/

char[][] Level2Text1 = {"LOW", "MEDIUM", "HIGH"};
string[] Level2Text2 = {"LOW", "MEDIUM", "HIGH"};    // for D2
