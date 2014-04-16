/*
TEST_OUTPUT:
---
fail_compilation/fail9027.d(26): Error: cannot cast ambiguous expression & f2 to void function(int)
fail_compilation/fail9027.d(27): Error: cannot cast ambiguous expression & f3 to void function(int)
fail_compilation/fail9027.d(28): Error: cannot cast ambiguous expression & f4 to void function()
---
*/

void f1() { }
void f1(int) { }
extern(C) void f1(int) { }

void f2() { }
extern(C) void f2(int) { }

extern(C) void f3(int) { }
void f3() { }

extern(Windows) void f4(long) { }
extern(C) void f4(long) { }

void main()
{
    auto fp1 = cast(void function(int)) &f1;
    auto fp2 = cast(void function(int)) &f2;
    auto fp3 = cast(void function(int)) &f3;
    auto fp4 = cast(void function()) &f4;
}
