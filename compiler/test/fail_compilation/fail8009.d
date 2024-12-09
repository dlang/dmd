/*
TEST_OUTPUT:
---
fail_compilation/fail8009.d(13): Error: template `filter` is not callable using argument types `!()(void)`
void main() { filter(r => r); }
                    ^
fail_compilation/fail8009.d(12):        Candidate is: `filter(R)(scope bool delegate(ref BAD!R) func)`
void filter(R)(scope bool delegate(ref BAD!R) func) { }
     ^
---
*/
void filter(R)(scope bool delegate(ref BAD!R) func) { }
void main() { filter(r => r); }
