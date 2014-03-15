/*
TEST_OUTPUT:
---
fail_compilation/fail356a.d(13): Error: no property 'fail356' for type 'int'
---
*/

import imports.fail356;
int imports; // doesn't collide with package name

void main()
{
    auto x = imports.fail356.bar;
    // declared 'imports' hides module fully qualified name 'imports.fail356'
}
