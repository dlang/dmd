/**TEST_OUTPUT:
---
fail_compilation/testNonConstStaticAA.d(100): Error: only `const` or `immutable` `static` AAs are supported for now
---
*/


#line 100
static mutable_ct_createdAA = ["a":"b"];

