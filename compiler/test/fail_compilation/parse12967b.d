/*
TEST_OUTPUT:
---
fail_compilation/parse12967b.d(56): Error: function `parse12967b.C.pre_c` without `this` cannot be `const`
    const     static      pre_c() {}
                          ^
fail_compilation/parse12967b.d(57): Error: function `parse12967b.C.pre_i` without `this` cannot be `immutable`
    immutable static      pre_i() {}
                          ^
fail_compilation/parse12967b.d(58): Error: function `parse12967b.C.pre_w` without `this` cannot be `inout`
    inout     static      pre_w() {}
                          ^
fail_compilation/parse12967b.d(59): Error: function `parse12967b.C.pre_s` without `this` cannot be `shared`
    shared    static      pre_s() {}
                          ^
fail_compilation/parse12967b.d(61): Error: function `parse12967b.C.post_c` without `this` cannot be `const`
    static      post_c() const     {}
                ^
fail_compilation/parse12967b.d(62): Error: function `parse12967b.C.post_i` without `this` cannot be `immutable`
    static      post_i() immutable {}
                ^
fail_compilation/parse12967b.d(63): Error: function `parse12967b.C.post_w` without `this` cannot be `inout`
    static      post_w() inout     {}
                ^
fail_compilation/parse12967b.d(64): Error: function `parse12967b.C.post_s` without `this` cannot be `shared`
    static      post_s() shared    {}
                ^
fail_compilation/parse12967b.d(69): Error: function `parse12967b.D.pre_c` without `this` cannot be `const`
    const     static void pre_c() {}
                          ^
fail_compilation/parse12967b.d(70): Error: function `parse12967b.D.pre_i` without `this` cannot be `immutable`
    immutable static void pre_i() {}
                          ^
fail_compilation/parse12967b.d(71): Error: function `parse12967b.D.pre_w` without `this` cannot be `inout`
    inout     static void pre_w() {}
                          ^
fail_compilation/parse12967b.d(72): Error: function `parse12967b.D.pre_s` without `this` cannot be `shared`
    shared    static void pre_s() {}
                          ^
fail_compilation/parse12967b.d(73): Error: function `parse12967b.D.post_c` without `this` cannot be `const`
    static void post_c() const     {}
                ^
fail_compilation/parse12967b.d(74): Error: function `parse12967b.D.post_i` without `this` cannot be `immutable`
    static void post_i() immutable {}
                ^
fail_compilation/parse12967b.d(75): Error: function `parse12967b.D.post_w` without `this` cannot be `inout`
    static void post_w() inout     {}
                ^
fail_compilation/parse12967b.d(76): Error: function `parse12967b.D.post_s` without `this` cannot be `shared`
    static void post_s() shared    {}
                ^
---
*/
class C
{
    const     static      pre_c() {}
    immutable static      pre_i() {}
    inout     static      pre_w() {}
    shared    static      pre_s() {}

    static      post_c() const     {}
    static      post_i() immutable {}
    static      post_w() inout     {}
    static      post_s() shared    {}
}

class D
{
    const     static void pre_c() {}
    immutable static void pre_i() {}
    inout     static void pre_w() {}
    shared    static void pre_s() {}
    static void post_c() const     {}
    static void post_i() immutable {}
    static void post_w() inout     {}
    static void post_s() shared    {}
}
