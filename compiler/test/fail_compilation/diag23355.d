/*
TEST_OUTPUT:
---
fail_compilation/diag23355.d(25): Error: undefined identifier `n`
void ffi1(T)(T[n] s) { }
          ^
fail_compilation/diag23355.d(28): Error: template `ffi1` is not callable using argument types `!()(int[4])`
void main() { int[4] x; ffi1(x); ffi2(x); }
                            ^
fail_compilation/diag23355.d(25):        Candidate is: `ffi1(T)(T[n] s)`
void ffi1(T)(T[n] s) { }
     ^
fail_compilation/diag23355.d(26): Error: undefined identifier `n`
void ffi2()(T[n] s) { }
     ^
fail_compilation/diag23355.d(28): Error: template `ffi2` is not callable using argument types `!()(int[4])`
void main() { int[4] x; ffi1(x); ffi2(x); }
                                     ^
fail_compilation/diag23355.d(26):        Candidate is: `ffi2()(T[n] s)`
void ffi2()(T[n] s) { }
     ^
---
*/
// Line 1 starts here
void ffi1(T)(T[n] s) { }
void ffi2()(T[n] s) { }

void main() { int[4] x; ffi1(x); ffi2(x); }
