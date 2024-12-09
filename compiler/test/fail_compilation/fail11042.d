/*
TEST_OUTPUT:
---
fail_compilation/fail11042.d(12): Error: undefined identifier `error`, did you mean class `Error`?
static if ({ return true  || error; }()) {} // NG
                             ^
fail_compilation/fail11042.d(13): Error: undefined identifier `error`, did you mean class `Error`?
static if ({ return false && error; }()) {} // NG
                             ^
---
*/
static if ({ return true  || error; }()) {} // NG
static if ({ return false && error; }()) {} // NG
