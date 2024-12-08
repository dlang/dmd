/*
TEST_OUTPUT:
---
fail_compilation/ice12040.d(10): Error: circular reference to `ice12040.lol`
bool[lol.length] lol;
                 ^
---
*/

bool[lol.length] lol;
