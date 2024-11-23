/*
TEST_OUTPUT:
----
fail_compilation/ice11968.d(11): Error: the `delete` keyword is obsolete
void main() {  delete __FILE__  ; }
               ^
fail_compilation/ice11968.d(11):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
----
*/

void main() {  delete __FILE__  ; }
