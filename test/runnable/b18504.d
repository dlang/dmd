/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
r
p $_exitcode
---
GDB_MATCH: \$1 = 1
*/
void main() { synchronized assert(0); }
