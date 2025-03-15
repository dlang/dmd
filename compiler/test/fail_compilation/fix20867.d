/*
TEST_OUTPUT:
---
fail_compilation/fix20867.d(16): Error: cannot use `final switch` on enum `E` while it is being defined
fail_compilation/fix20867.d(31): Error: cannot use `final switch` on enum `E2` while it is being defined
fail_compilation/fix20867.d(63): Error: cannot use `final switch` on enum `E4` while it is being defined
---
*/

// Test case 1: The exact scenario Issue(From Github Issue(#20867))
enum E
{
    a = 3,
    b = () {
        E e;
        final switch (e)  // This should error out instead of segfaulting
        {
            case E.a: break;
        }
        return 4;
    } ()
}

// Test case 2: Variation with multiple members
enum E2
{
    x = 10,
    y = 20,
    z = () {
        E2 e;
        final switch (e)  // Should also error out safely
        {
            case E2.x: return 30;
            case E2.y: return 40;
        }
    } ()
}

// Test case 3: Regular use of final switch (this should still compile)
enum E3
{
    p = 1,
    q = 2
}

void testE3()
{
    E3 e = E3.p;
    final switch (e)
    {
        case E3.p: break;
        case E3.q: break;
    }
}

// Test case 4: Nested circular reference
enum E4
{
    r = 5,
    s = () {
        int foo() {
            E4 e;
            final switch (e)  // Should error out
            {
                case E4.r: return 6;
            }
        }
        return foo();
    } ()
}
