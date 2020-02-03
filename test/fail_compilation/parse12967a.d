/*
TEST_OUTPUT:
---
fail_compilation/parse12967a.d(14): Error: function `parse12967a.post_i1` without `this` cannot be `immutable`
fail_compilation/parse12967a.d(15): Error: function `parse12967a.post_i2` without `this` cannot be `immutable`
fail_compilation/parse12967a.d(16): Error: function `parse12967a.post_c1` without `this` cannot be `const`
fail_compilation/parse12967a.d(17): Error: function `parse12967a.post_c2` without `this` cannot be `const`
fail_compilation/parse12967a.d(18): Error: function `parse12967a.post_w1` without `this` cannot be `inout`
fail_compilation/parse12967a.d(19): Error: function `parse12967a.post_w2` without `this` cannot be `inout`
fail_compilation/parse12967a.d(20): Error: function `parse12967a.post_s1` without `this` cannot be `shared`
fail_compilation/parse12967a.d(21): Error: function `parse12967a.post_s2` without `this` cannot be `shared`
---
*/
auto post_i1() immutable {}
void post_i2() immutable {}
auto post_c1() const     {}
void post_c2() const     {}
auto post_w1() inout     {}
void post_w2() inout     {}
auto post_s1() shared    {}
void post_s2() shared    {}
