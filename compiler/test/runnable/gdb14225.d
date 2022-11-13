/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b gdb14225.d:17
r
echo RESULT=
p lok
---
GDB_MATCH: RESULT=.*Something
*/
void main()
{
    string lok = "Something";
    auto chars = "Anything".dup;
    // BP
}
