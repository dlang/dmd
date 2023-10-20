/* TEST_OUTPUT:
---
fail_compilation/fail21980.c(7): Error: functions cannot be `_Thread_local`
---
*/

_Thread_local void wat();
