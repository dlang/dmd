/*
TEST_OUTPUT:
---
fail_compilation/test12558.d(46): Deprecation: `catch` statement without an exception specification is deprecated
        handler();
        ^
fail_compilation/test12558.d(46):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(50): Deprecation: `catch` statement without an exception specification is deprecated
fail_compilation/test12558.d(50):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(57): Deprecation: `catch` statement without an exception specification is deprecated
        handler();
        ^
fail_compilation/test12558.d(57):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(61): Deprecation: `catch` statement without an exception specification is deprecated
fail_compilation/test12558.d(61):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(70): Deprecation: `catch` statement without an exception specification is deprecated
        assert(false);
        ^
fail_compilation/test12558.d(70):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(45): Error: `catch` statement without an exception specification is deprecated
    } catch
      ^
fail_compilation/test12558.d(45):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(50): Error: `catch` statement without an exception specification is deprecated
    } catch {
      ^
fail_compilation/test12558.d(50):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(56): Error: `catch` statement without an exception specification is deprecated
    } catch
      ^
fail_compilation/test12558.d(56):        use `catch(Throwable)` for old behavior
fail_compilation/test12558.d(61): Error: `catch` statement without an exception specification is deprecated
    } catch {
      ^
fail_compilation/test12558.d(61):        use `catch(Throwable)` for old behavior
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
