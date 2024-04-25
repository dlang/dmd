/*
EXTRA_SOURCES: imports/gdb22905b.d imports/gdb22905c.d
REQUIRED_ARGS: -g
GDB_SCRIPT:
---
b gdb22905c.d:6
commands
bt
cont
end
run
---
GDB_MATCH: (_D7imports9gdb22905b5funcBFZv|imports\.gdb22905b\.funcB\(\)) .. at runnable/imports/gdb22905b.d:7
*/
import imports.gdb22905b;

void main()
{
    funcB();
}
