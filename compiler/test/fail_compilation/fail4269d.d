/*
TEST_OUTPUT:
---
fail_compilation/fail4269d.d(11): Error: undefined identifier `Y`
alias Y X6;
      ^
---
*/

static if(is(typeof(X6.init))) {}
alias Y X6;

void main() {}
