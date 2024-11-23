/*
TEST_OUTPUT:
---
fail_compilation/fail14965.d(43): Error: forward reference to inferred return type of function `foo1`
auto foo1() { alias F = typeof(foo1); }     // TypeTypeof
                        ^
fail_compilation/fail14965.d(44): Error: forward reference to inferred return type of function `foo2`
auto foo2() { alias FP = typeof(&foo2); }   // TypeTypeof
                         ^
fail_compilation/fail14965.d(46): Error: forward reference to inferred return type of function `bar1`
auto bar1() { auto fp = &bar1; }            // ExpInitializer
                        ^
fail_compilation/fail14965.d(47): Error: forward reference to inferred return type of function `bar2`
auto bar2() { auto fp = cast(void function())&bar2; }   // castTo
                                             ^
fail_compilation/fail14965.d(49): Error: forward reference to inferred return type of function `baz1`
auto baz1() { return &baz1; }               // ReturnStatement
                     ^
fail_compilation/fail14965.d(50): Error: forward reference to inferred return type of function `baz2`
auto baz2() { (&baz2); }                    // ExpStatement
               ^
fail_compilation/fail14965.d(54): Error: forward reference to inferred return type of function `foo1`
    auto foo1() { alias F = typeof(this.foo1); }
                            ^
fail_compilation/fail14965.d(55): Error: forward reference to inferred return type of function `foo2`
    auto foo2() { alias FP = typeof(&this.foo2); }
                             ^
fail_compilation/fail14965.d(57): Error: forward reference to inferred return type of function `bar1`
    auto bar1() { auto fp = &this.bar1; }
                            ^
fail_compilation/fail14965.d(58): Error: forward reference to inferred return type of function `bar2`
    auto bar2() { auto dg = cast(void delegate())&this.bar2; }
                                                 ^
fail_compilation/fail14965.d(60): Error: forward reference to inferred return type of function `baz1`
    auto baz1() { return &baz1; }
                         ^
fail_compilation/fail14965.d(61): Error: forward reference to inferred return type of function `baz2`
    auto baz2() { (&baz2); }
                   ^
---
*/

auto foo1() { alias F = typeof(foo1); }     // TypeTypeof
auto foo2() { alias FP = typeof(&foo2); }   // TypeTypeof

auto bar1() { auto fp = &bar1; }            // ExpInitializer
auto bar2() { auto fp = cast(void function())&bar2; }   // castTo

auto baz1() { return &baz1; }               // ReturnStatement
auto baz2() { (&baz2); }                    // ExpStatement

class C
{
    auto foo1() { alias F = typeof(this.foo1); }
    auto foo2() { alias FP = typeof(&this.foo2); }

    auto bar1() { auto fp = &this.bar1; }
    auto bar2() { auto dg = cast(void delegate())&this.bar2; }

    auto baz1() { return &baz1; }
    auto baz2() { (&baz2); }
}
