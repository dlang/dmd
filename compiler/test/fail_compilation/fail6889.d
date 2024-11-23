/*
TEST_OUTPUT:
---
fail_compilation/fail6889.d(54): Error: cannot `goto` out of `scope(success)` block
    scope(success) { L2: goto L1; } // NG
                         ^
fail_compilation/fail6889.d(55): Error: cannot `goto` in to `scope(success)` block
    goto L2;                        // NG
    ^
fail_compilation/fail6889.d(57): Error: `return` statements cannot be in `scope(success)` bodies
    scope(success) { return; }      // NG (from fail102.d)
                     ^
fail_compilation/fail6889.d(61): Error: `continue` is not allowed inside `scope(success)` bodies
        scope(success) continue;    // NG
                       ^
fail_compilation/fail6889.d(62): Error: `break` is not allowed inside `scope(success)` bodies
        scope(success) break;       // NG
                       ^
fail_compilation/fail6889.d(67): Error: `continue` is not allowed inside `scope(success)` bodies
        scope(success) continue;    // NG
                       ^
fail_compilation/fail6889.d(68): Error: `break` is not allowed inside `scope(success)` bodies
        scope(success) break;       // NG
                       ^
fail_compilation/fail6889.d(88): Error: cannot `goto` in to `scope(failure)` block
    goto L2;                        // NG
    ^
fail_compilation/fail6889.d(120): Error: cannot `goto` out of `scope(exit)` block
    scope(exit) { L2: goto L1; }    // NG
                      ^
fail_compilation/fail6889.d(121): Error: cannot `goto` in to `scope(exit)` block
    goto L2;                        // NG
    ^
fail_compilation/fail6889.d(123): Error: `return` statements cannot be in `scope(exit)` bodies
    scope(exit) { return; }         // NG (from fail102.d)
                  ^
fail_compilation/fail6889.d(127): Error: `continue` is not allowed inside `scope(exit)` bodies
        scope(exit) continue;       // NG
                    ^
fail_compilation/fail6889.d(128): Error: `break` is not allowed inside `scope(exit)` bodies
        scope(exit) break;          // NG
                    ^
fail_compilation/fail6889.d(133): Error: `continue` is not allowed inside `scope(exit)` bodies
        scope(exit) continue;       // NG
                    ^
fail_compilation/fail6889.d(134): Error: `break` is not allowed inside `scope(exit)` bodies
        scope(exit) break;          // NG
                    ^
---
*/
void test_success()
{
L1:
    scope(success) { L2: goto L1; } // NG
    goto L2;                        // NG

    scope(success) { return; }      // NG (from fail102.d)

    foreach (i; 0..1)
    {
        scope(success) continue;    // NG
        scope(success) break;       // NG
    }

    foreach (i; Aggr())
    {
        scope(success) continue;    // NG
        scope(success) break;       // NG
    }
  /+
    // is equivalent with:
    switch (
      Aggr().opApply((int i){
        scope(success) return 0;    // NG
        scope(success) return 1;    // NG
        return 0;
      }))
    {
        default: break;
    }
  +/
}

void test_failure()
{
L1:
    scope(failure) { L2: goto L1; } // OK
    goto L2;                        // NG



    foreach (i; 0..1)
    {
        scope(failure) continue;    // OK
        scope(failure) break;       // OK
    }

    foreach (i; Aggr())
    {
        scope(failure) continue;    // OK
        scope(failure) break;       // OK
    }
  /+
    // is equivalent with:
    switch (
      Aggr().opApply((int i){
        scope(failure) return 0;    // OK
        scope(failure) return 1;    // OK
        return 0;
      }))
    {
        default: break;
    }
  +/
}

void test_exit()
{
L1:
    scope(exit) { L2: goto L1; }    // NG
    goto L2;                        // NG

    scope(exit) { return; }         // NG (from fail102.d)

    foreach (i; 0..1)
    {
        scope(exit) continue;       // NG
        scope(exit) break;          // NG
    }

    foreach (i; Aggr())
    {
        scope(exit) continue;       // NG
        scope(exit) break;          // NG
    }
  /+
    // is equivalent with:
    switch (
      Aggr().opApply((int i){
        scope(exit) return 0;       // NG
        scope(exit) return 1;       // NG
        return 0;
      }))
    {
        default: break;
    }
  +/
}

struct Aggr { int opApply(int delegate(int) dg) { return dg(0); } }
