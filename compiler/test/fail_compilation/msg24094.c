/* TEST_OUTPUT:
---
fail_compilation/msg24094.c(9): Error: extended-decl-modifier expected after `__declspec(`, saw `*` instead
__declspec(*) void* __cdecl _calloc_base(int, int);
           ^
---
*/

__declspec(*) void* __cdecl _calloc_base(int, int);
