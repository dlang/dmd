// REQUIRED_ARGS: -dw

/*
TEST_OUTPUT:
---
compilable/deprecate14283.d(17): Deprecation: this is not an lvalue
compilable/deprecate14283.d(18): Deprecation: super is not an lvalue
---
*/

class C
{
    void bug()
    {
        autoref(this); // suppress warning for auto ref
        autoref(super); // suppress warning for auto ref
        ref_(this); // still warns
        ref_(super); // still warns
    }
}

void autoref(T)(auto ref T t) {}
void ref_(T)(ref T) {}
