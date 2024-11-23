/*
TEST_OUTPUT:
---
fail_compilation/parse12967a.d(54): Error: function `parse12967a.pre_i1` without `this` cannot be `immutable`
immutable      pre_i1() {}
               ^
fail_compilation/parse12967a.d(55): Error: function `parse12967a.pre_i2` without `this` cannot be `immutable`
immutable void pre_i2() {}
               ^
fail_compilation/parse12967a.d(56): Error: function `parse12967a.pre_c1` without `this` cannot be `const`
const          pre_c1() {}
               ^
fail_compilation/parse12967a.d(57): Error: function `parse12967a.pre_c2` without `this` cannot be `const`
const     void pre_c2() {}
               ^
fail_compilation/parse12967a.d(58): Error: function `parse12967a.pre_w1` without `this` cannot be `inout`
inout          pre_w1() {}
               ^
fail_compilation/parse12967a.d(59): Error: function `parse12967a.pre_w2` without `this` cannot be `inout`
inout     void pre_w2() {}
               ^
fail_compilation/parse12967a.d(60): Error: function `parse12967a.pre_s1` without `this` cannot be `shared`
shared         pre_s1() {}
               ^
fail_compilation/parse12967a.d(61): Error: function `parse12967a.pre_s2` without `this` cannot be `shared`
shared    void pre_s2() {}
               ^
fail_compilation/parse12967a.d(63): Error: function `parse12967a.post_i1` without `this` cannot be `immutable`
auto post_i1() immutable {}
     ^
fail_compilation/parse12967a.d(64): Error: function `parse12967a.post_i2` without `this` cannot be `immutable`
void post_i2() immutable {}
     ^
fail_compilation/parse12967a.d(65): Error: function `parse12967a.post_c1` without `this` cannot be `const`
auto post_c1() const     {}
     ^
fail_compilation/parse12967a.d(66): Error: function `parse12967a.post_c2` without `this` cannot be `const`
void post_c2() const     {}
     ^
fail_compilation/parse12967a.d(67): Error: function `parse12967a.post_w1` without `this` cannot be `inout`
auto post_w1() inout     {}
     ^
fail_compilation/parse12967a.d(68): Error: function `parse12967a.post_w2` without `this` cannot be `inout`
void post_w2() inout     {}
     ^
fail_compilation/parse12967a.d(69): Error: function `parse12967a.post_s1` without `this` cannot be `shared`
auto post_s1() shared    {}
     ^
fail_compilation/parse12967a.d(70): Error: function `parse12967a.post_s2` without `this` cannot be `shared`
void post_s2() shared    {}
     ^
---
*/
immutable      pre_i1() {}
immutable void pre_i2() {}
const          pre_c1() {}
const     void pre_c2() {}
inout          pre_w1() {}
inout     void pre_w2() {}
shared         pre_s1() {}
shared    void pre_s2() {}

auto post_i1() immutable {}
void post_i2() immutable {}
auto post_c1() const     {}
void post_c2() const     {}
auto post_w1() inout     {}
void post_w2() inout     {}
auto post_s1() shared    {}
void post_s2() shared    {}
