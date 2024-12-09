/*
TEST_OUTPUT:
---
fail_compilation/ice12836.d(13): Error: undefined identifier `C`
immutable C L = 1 << K;
            ^
fail_compilation/ice12836.d(13): Error: undefined identifier `K`
immutable C L = 1 << K;
                     ^
---
*/

immutable C L = 1 << K;
