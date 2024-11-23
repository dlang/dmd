/*
TEST_OUTPUT:
---
fail_compilation/ice11944.d(14): Error: template instance `doCommand!(func)` does not match template declaration `doCommand(f, T)(f, T arg)`
auto var = &doCommand!func;
            ^
---
*/

void func(int var) {}

void doCommand(f, T)(f, T arg) {}

auto var = &doCommand!func;
