/*
TEST_OUTPUT:
---
fail_compilation/ice20545.d(10): Error: initializer expression expected following colon, not `]`
static initial = [{ }: ];
                       ^
---
*/

static initial = [{ }: ];
