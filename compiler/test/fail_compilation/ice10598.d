// REQUIRED_ARGS: -de
// EXTRA_SOURCES: imports/ice10598a.d imports/ice10598b.d
/* TEST_OUTPUT:
---
fail_compilation/imports/ice10598a.d(5): Deprecation: module imports.ice10598b is not accessible here, perhaps add 'static import imports.ice10598b;'
alias TypeTuple!(__traits(getMember, imports.ice10598b, (__traits(allMembers, imports.ice10598b)[1])))[0] notImportedType;
                 ^
fail_compilation/imports/ice10598a.d(5): Deprecation: module imports.ice10598b is not accessible here, perhaps add 'static import imports.ice10598b;'
alias TypeTuple!(__traits(getMember, imports.ice10598b, (__traits(allMembers, imports.ice10598b)[1])))[0] notImportedType;
                                                         ^
---
*/

void main() {}
