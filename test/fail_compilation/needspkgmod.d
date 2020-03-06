// ARG_SETS: -i=,
// ARG_SETS: -i=imports.pkgmod313,
// ARG_SETS: -i=,imports.pkgmod313
// ARG_SETS: -i=imports.pkgmod313,-imports.pkgmod313.mod
// ARG_SETS: -i=imports.pkgmod313.package,-imports.pkgmod313.mod
// REQUIRED_ARGS: -Icompilable
// PERMUTE_ARGS:
// LINK:
/*
Can't really check for the missing function bar here because the error message
varies A LOT between different linkers. Assume that there is no other cause
of linking failure because then other tests would fail as well. Hence search
for the linker failure message issued by DMD:

TRANSFORM_OUTPUT: remove_lines("^(?!Error:).+$")
TEST_OUTPUT:
----
Error: linker exited with status $n$
----
*/
import imports.pkgmod313.mod;
void main()
{
    bar();
}
