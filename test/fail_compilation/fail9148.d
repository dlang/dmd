// Test case for issue 9148, found by the regression 14039

void impure() {}    // impure

/*
TEST_OUTPUT:
---
fail_compilation/fail9148.d(22): Error: pure function 'fail9148.fb1!int.fb1.A!int.A.fc!int.fc' cannot call impure function 'fail9148.impure'
fail_compilation/fail9148.d(44): Error: template instance fail9148.fb1!int.fb1.A!int.A.fc!int error instantiating
fail_compilation/fail9148.d(36): Error: impure function 'fc' cannot access variable 'x' declared in enclosing pure function 'fail9148.fb2!int.fb2'
fail_compilation/fail9148.d(45): Error: template instance fail9148.fb2!int.fb2.A!int.A.fc!int error instantiating
---
*/
auto fb1(T)()
{
    int x;
    struct A(S)
    {
        void fc(T2)()
        {
            x = 1;      // accessing pure function context makes fc as pure
            impure();   // error, impure function call
        }
        this(S a) {}
    }
    return A!int();
}
auto fb2(T)()
{
    int x;
    struct A(S)
    {
        void fc(T2)()
        {
            impure();   // impure function call makes fc as impure
            x = 1;      // error, accessing pure context
        }
        this(S a) {}
    }
    return A!int();
}
void test1()
{
    fb1!int().fc!int();
    fb2!int().fc!int();
}
