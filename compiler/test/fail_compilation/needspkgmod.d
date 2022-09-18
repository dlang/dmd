// ARG_SETS: -i=,
// ARG_SETS: -i=imports.pkgmod313,
// ARG_SETS: -i=,imports.pkgmod313
// ARG_SETS: -i=imports.pkgmod313,-imports.pkgmod313.mod
// ARG_SETS: -i=imports.pkgmod313.package,-imports.pkgmod313.mod
// REQUIRED_ARGS: -Icompilable
// LINK:
/*
TEST_OUTPUT:
----
$r:.+_D7imports9pkgmod3133mod3barFZv.*$
Error: $r:.+$ exited with status $n$
----
*/
import imports.pkgmod313.mod;
void main()
{
    bar();
}
