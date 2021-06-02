/*
PERMUTE_ARGS:
REQUIRED_ARGS: -deps -Icompilable/extra-files
COMPILED_IMPORTS: extra-files/rdeps7016a.d extra-files/rdeps7016b.d

TRANSFORM_OUTPUT: remove_lines("druntime")
TEST_OUTPUT:
---
depsImport rdeps7016 ($p:rdeps7016.d$) : private : rdeps7016a ($p:rdeps7016a.d$)
depsImport rdeps7016a ($p:rdeps7016a.d$) : private : rdeps7016b ($p:rdeps7016b.d$)
depsImport rdeps7016b ($p:rdeps7016b.d$) : private : rdeps7016 ($p:rdeps7016.d$)
---
*/

module rdeps7016;
import rdeps7016a;

void main()
{
    f();
}
