// Ideally this should work, at least give a nice error messae
/**
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/issue21203.d(14): Error: pragma `mangle` cannot apply to a template declaration
pragma(mangle,"gdkfjgh")
^
fail_compilation/issue21203.d(14):        use `template Class(Args...){ pragma(mangle, "other_name") class Class {} }`
---
*/

extern(C++)
pragma(mangle,"gdkfjgh")
class F(T)
{

}
void use(F!int a) {}
