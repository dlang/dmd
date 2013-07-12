// COMPILER: rdmd
// PERMUTE_ARGS:
// REQUIRED_ARGS: --loop="if (line == `foo`) writeln(line); if (line == `// break_out`) break;" < runnable/rdmd_loop.d
/*
TEST_OUTPUT:
---
foo
---
*/
void main() { }

// break_out
