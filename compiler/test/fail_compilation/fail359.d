/*
TEST_OUTPUT:
---
fail_compilation/fail359.d(9): Error: invalid filename for `#line` directive
#line 5 _BOOM
        ^
---
*/
#line 5 _BOOM
void main() { }
