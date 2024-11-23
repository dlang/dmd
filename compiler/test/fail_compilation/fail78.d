/*
TEST_OUTPUT:
---
fail_compilation/fail78.d(11): Error: undefined identifier `inch`
auto ft = inch * 12;
          ^
---
*/

auto yd = ft * 3;
auto ft = inch * 12;
