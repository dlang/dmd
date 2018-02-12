// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/a314.d
module imports.test314; // package imports

import imports.pkg.a314;

void main()
{
    imports.pkg.a314.bug("This should work.\n");
    renamed.bug("This should work.\n");
    bug("This should work.\n");
}
