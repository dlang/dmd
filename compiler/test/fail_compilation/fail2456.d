/*
TEST_OUTPUT:
---
fail_compilation/fail2456.d(40): Error: cannot put `scope(success)` statement inside `finally` block
        scope(success) {}           // NG
        ^
fail_compilation/fail2456.d(51): Error: cannot put `scope(failure)` statement inside `finally` block
        scope(failure) {}           // NG
        ^
fail_compilation/fail2456.d(70): Error: cannot put `scope(success)` statement inside `scope(success)`
        scope(success) {}   // NG
        ^
fail_compilation/fail2456.d(71): Error: cannot put `scope(failure)` statement inside `scope(success)`
        scope(failure) {}   // NG
        ^
fail_compilation/fail2456.d(84): Error: cannot put `scope(success)` statement inside `scope(exit)`
        scope(success) {}   // NG
        ^
fail_compilation/fail2456.d(85): Error: cannot put `scope(failure)` statement inside `scope(exit)`
        scope(failure) {}   // NG
        ^
fail_compilation/fail2456.d(95): Error: cannot put `catch` statement inside `scope(success)`
        catch (Throwable) {}    // NG
        ^
fail_compilation/fail2456.d(107): Error: cannot put `catch` statement inside `scope(exit)`
        catch (Throwable) {}    // NG
        ^
fail_compilation/fail2456.d(114): Deprecation: can only catch mutable or const qualified types, not `immutable(Exception)`
    } catch (immutable Exception e) {
      ^
---
*/
void test_success()
{
    try
    {
    }
    finally
    {
        scope(success) {}           // NG
    }
}

void test_failure()
{
    try
    {
    }
    finally
    {
        scope(failure) {}           // NG
    }
}

void test_exit()
{
    try
    {
    }
    finally
    {
        scope(exit) {}              // OK
    }
}

void test2456a()
{
    scope(success)
    {
        scope(success) {}   // NG
        scope(failure) {}   // NG
        scope(exit) {}      // OK
    }

    scope(failure)
    {
        scope(success) {}   // OK
        scope(failure) {}   // OK
        scope(exit) {}      // OK
    }

    scope(exit)
    {
        scope(success) {}   // NG
        scope(failure) {}   // NG
        scope(exit) {}      // OK
    }
}

void test2456b()
{
    scope(success)
    {
        try {}
        catch (Throwable) {}    // NG
    }

    scope(failure)
    {
        try {}
        catch (Throwable) {}    // OK
    }

    scope(exit)
    {
        try {}
        catch (Throwable) {}    // NG
    }
}

void main() {
    try {
        throw new Exception("");
    } catch (immutable Exception e) {
        assert(0);
    }
}
