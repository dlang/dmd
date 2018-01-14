// ARG_SETS: -i=
// ARG_SETS: -i=,
// ARG_SETS: -i=imports.pkgmod313,
// ARG_SETS: -i=,imports.pkgmod313
// ARG_SETS: -i=imports.pkgmod313,-imports.pkgmod313.mod
// ARG_SETS: -i=imports.pkgmod313.package,-imports.pkgmod313.mod
// REQUIRED_ARGS: -Icompilable
// PERMUTE_ARGS:
// LINK:
import imports.pkgmod313.mod;
void main()
{
    bar();
}
