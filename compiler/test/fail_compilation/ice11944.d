/*
TEST_OUTPUT:
---
fail_compilation/ice11944.d(105): Error: template instance `doCommand!(func)` does not match template declaration `doCommand(f, T)(f, T arg)`
fail_compilation/ice11944.d(105):        instantiated from here: `doCommand!(func)`
fail_compilation/ice11944.d(103):        Candidate match: doCommand(f, T)(f, T arg)
---
*/

#line 100

void func(int var) {}

void doCommand(f, T)(f, T arg) {}

auto var = &doCommand!func;
