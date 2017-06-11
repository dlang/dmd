// REQUIRED_ARGS: -Ifail_compilation/extra-files
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/extra-files/fail17489_file.d(2): Error: basic type expected, not )
fail_compilation/extra-files/fail17489_file.d(5): Error: enum fail17489_file.DirectoryChangeType enum `DirectoryChangeType` must have at least one member
---
*/
class VibedScheduler {
	import fail17489_file;
}
