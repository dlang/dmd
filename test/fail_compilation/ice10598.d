// EXTRA_SOURCES: imports/ice10598a.d imports/ice10598b.d
/*
TEST_OUTPUT:
---
fail_compilation/imports/ice10598a.d(5): Error: undefined identifier 'ice10598b', did you mean 'static import ice10598a'?
fail_compilation/imports/ice10598a.d(5): Error: undefined identifier 'ice10598b', did you mean 'static import ice10598a'?
fail_compilation/imports/ice10598a.d(5): Error: argument has no members
fail_compilation/imports/ice10598a.d(5): Error: false must be an array or pointer type, not bool
fail_compilation/imports/ice10598a.d(5): Error: string expected as second argument of __traits getMember instead of __error
fail_compilation/imports/ice10598a.d(5): Error: alias imports.ice10598a.notImportedType cannot alias an expression false
---
*/

void main() {}
