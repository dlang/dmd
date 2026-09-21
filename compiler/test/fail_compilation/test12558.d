/*
TEST_OUTPUT:
---
fail_compilation/test12558.d(24): Error: `catch` statement without an exception specification is disallowed
fail_compilation/test12558.d(24):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(28): Error: `catch` statement without an exception specification is disallowed
fail_compilation/test12558.d(28):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(35): Error: `catch` statement without an exception specification is disallowed
fail_compilation/test12558.d(35):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(39): Error: `catch` statement without an exception specification is disallowed
fail_compilation/test12558.d(39):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(48): Error: `catch` statement without an exception specification is disallowed
fail_compilation/test12558.d(48):        use `catch(Throwable)` for old behavior
---
*/

void main()
{
    auto handler = () { };

    try {
        assert(0);
    } catch
        handler();

    try {
        assert(0);
    } catch {
        handler();
    }

    try {
        assert(0);
    } catch
        handler();

    try {
        assert(0);
    } catch {
        handler();
    }
}

void foo()()
{
    try {}
    catch
        assert(false);
}
