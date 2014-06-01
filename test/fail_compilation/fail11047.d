/*
TEST_OUTPUT:
---
fail_compilation/fail11047.d(14): Error: expression write(x++) is void and has no value
fail_compilation/fail11047.d(15): Error: expression writeln() is void and has no value
fail_compilation/fail11047.d(16): Error: static variable x cannot be read at compile time
---
*/

void write(T, A...)(T arg0, A args) {}
void writeln(A...)(A args) {}
int x;

@(write(x++),
  writeln(),
  x
 ) void foo(){}
