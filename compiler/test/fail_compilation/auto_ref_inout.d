/*
TEST_OUTPUT:
---
fail_compilation/auto_ref_inout.d(16): Error: template `f` is not callable using argument types `!()(int)`
enum e = f(5);
          ^
fail_compilation/auto_ref_inout.d(14):        Candidate is: `f(T)(auto ref inout T a, auto ref inout T b)`
auto ref inout(T) f(T)(auto ref inout T a, auto ref inout T b);
                  ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24707
auto ref inout(T) f(T)(auto ref inout T a, auto ref inout T b);

enum e = f(5);
