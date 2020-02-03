/*
TEST_OUTPUT:
---
fail_compilation/parse12967b.d(16): Error: function `parse12967b.C.post_c` without `this` cannot be `const`
fail_compilation/parse12967b.d(17): Error: function `parse12967b.C.post_i` without `this` cannot be `immutable`
fail_compilation/parse12967b.d(18): Error: function `parse12967b.C.post_w` without `this` cannot be `inout`
fail_compilation/parse12967b.d(19): Error: function `parse12967b.C.post_s` without `this` cannot be `shared`
fail_compilation/parse12967b.d(24): Error: function `parse12967b.D.post_c` without `this` cannot be `const`
fail_compilation/parse12967b.d(25): Error: function `parse12967b.D.post_i` without `this` cannot be `immutable`
fail_compilation/parse12967b.d(26): Error: function `parse12967b.D.post_w` without `this` cannot be `inout`
fail_compilation/parse12967b.d(27): Error: function `parse12967b.D.post_s` without `this` cannot be `shared`
---
*/
class C
{
    static      post_c() const     {}
    static      post_i() immutable {}
    static      post_w() inout     {}
    static      post_s() shared    {}
}

class D
{
    static void post_c() const     {}
    static void post_i() immutable {}
    static void post_w() inout     {}
    static void post_s() shared    {}
}
