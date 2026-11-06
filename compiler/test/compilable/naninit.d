/* REQUIRED_ARGS: -vnan -d
TEST_OUTPUT:
---
compilable/naninit.d(11): default NaN initialization of floating point variable
compilable/naninit.d(10): default NaN initialization of floating point variable
compilable/naninit.d(12): default NaN initialization of floating point variable
compilable/naninit.d(13): default NaN initialization of complex floating point variable
---
*/
float f;
void test() { float g; }
struct S { float h; }
cfloat cf;
