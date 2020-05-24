/*
DISABLED: win osx freebsd

EXTRA_ARTIFACT: lib19724a.a = ${DMD} -lib -of=$@ -Icompilable/imports compilable/imports/lib19724a.d
EXTRA_ARTIFACT: lib19724b.a = ${DMD} -lib -of=$@ -Icompilable/imports compilable/imports/lib19724b.d

REQUIRED_ARGS: -Icompilable/imports -L-L${RESULTS_DIR}/compilable
LINK:

# -l19724b -l19724a is wrong but for --start-group/--end-group,
# so --start-group and --end-group must not be reordered relative to the libraries
ARG_SETS:  -L=--start-group -L-l19724b -L-l19724a -L=--end-group

# analogously for lib19724b.a lib19724a.a
ARG_SETS: -L=--start-group -L=$@[1] -L=$@[0] -L=--end-group
*/

import lib19724a;

void main() {
    lib19724a.first(0);
}
