module issue23177;
// This module existing should trigger ModuleInfo to be referenced.
// Therefore if the fix for issue23177 works, this won't cause a linker error.

shared static this() {
    assert(1);
}
