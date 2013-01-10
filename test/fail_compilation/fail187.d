// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail187.d(15): Error: catch at fail_compilation/fail187.d(18) hides catch at fail_compilation/fail187.d(21)
---
*/
// Issue 1285 - Exception typedefs not distinguished by catch
// On DMD 2.000 bug only with typedef, not alias

typedef Exception A;
typedef Exception B;

void main() {
  try {
    throw new A("test");
  }
  catch (B) {
    // this shouldn't happen, but does
  }
  catch (A) {
    // this ought to happen?
  }
}

