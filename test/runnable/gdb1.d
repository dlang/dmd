/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b 15
r ARG1 ARG2
echo RESULT=
p args
---
GDB_MATCH: RESULT=.*ARG1.*ARG2
*/
void main(string[] args)
{
    // BP
}
